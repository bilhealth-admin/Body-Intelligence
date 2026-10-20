#!/usr/bin/env python3
"""Offline tests: no SDK download, emulator, build, app test, or network call."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location(
    "prepare_cmake", Path(__file__).with_name("bil_prepare_android_cmake.py")
)
cmake = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cmake)

# Actual first stdout line of Android/Sdk/cmake/3.22.1/bin/cmake.exe --version.
OFFICIAL_ANDROID_CMAKE_STDOUT = "cmake version 3.22.1-g37088a8-dirty\n"


class ProvisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.sdk = self.base / "sdk"
        self.manager = self.sdk / "cmdline-tools/latest/bin/sdkmanager"
        self.manager.parent.mkdir(parents=True)
        self.manager.write_text("offline fixture", encoding="utf-8")
        self.receipt = self.base / "evidence/cmake.json"
        self.calls = []
        self.sleeps = []

    def install_fixture(self, revision="3.22.1", extra=""):
        target = self.sdk / "cmake/3.22.1"
        (target / "bin").mkdir(parents=True, exist_ok=True)
        (target / "bin/cmake").write_text("offline fixture", encoding="utf-8")
        (target / "source.properties").write_text(
            f"Pkg.Revision = {revision}\n{extra}", encoding="utf-8"
        )

    def invoke(self, exits=(0,), *, probe_code=0, version="3.22.1", probe_timeout=False, fixture=True, probe_stdout=None):
        outcomes = iter(exits)

        def run(command, **kwargs):
            self.calls.append((command, kwargs))
            if command[-1] == cmake.PACKAGE:
                outcome = next(outcomes)
                if outcome == "timeout":
                    raise subprocess.TimeoutExpired(command, kwargs["timeout"])
                if outcome == "oserror":
                    raise OSError("SENSITIVE OUTPUT MUST NOT ENTER RECEIPT")
                if outcome == 0 and fixture:
                    self.install_fixture()
                return subprocess.CompletedProcess(command, outcome, "download output", "private stderr")
            if probe_timeout:
                raise subprocess.TimeoutExpired(command, kwargs["timeout"])
            stdout = f"cmake version {version}\n" if probe_stdout is None else probe_stdout
            return subprocess.CompletedProcess(command, probe_code, stdout, "")

        code = cmake.provision(self.sdk, self.receipt, run=run, sleep=self.sleeps.append)
        return code, json.loads(self.receipt.read_text(encoding="utf-8"))

    def test_success_requires_exact_metadata_and_executable_version(self):
        code, receipt = self.invoke()
        self.assertEqual(code, 0)
        self.assertEqual((receipt["status"], receipt["stage"]), ("PASS", "complete"))
        self.assertEqual(receipt["verified_revision"], "3.22.1")
        self.assertFalse(receipt["app_build_or_tests_executed"])
        self.assertEqual(self.calls[0][0], [str(self.manager.resolve()), f"--sdk_root={self.sdk.resolve()}", "cmake;3.22.1"])
        self.assertEqual(self.calls[1][0], [str((self.sdk / "cmake/3.22.1/bin/cmake").resolve()), "--version"])
        self.assertFalse(list(self.receipt.parent.glob("*.pending")))
        self.assertNotIn(b"\r", self.receipt.read_bytes())

    def test_corrupt_download_nonzero_can_recover_with_one_bounded_retry(self):
        code, receipt = self.invoke(exits=(1, 0))
        self.assertEqual(code, 0)
        self.assertEqual([item["exit_code"] for item in receipt["attempts"]], [1, 0])
        self.assertEqual(self.sleeps, [5])
        self.assertEqual([call[1]["timeout"] for call in self.calls], [300, 300, 30])

    def test_three_install_failures_never_run_probe_or_claim_pass(self):
        code, receipt = self.invoke(exits=(1, 2, 3))
        self.assertEqual(code, 1)
        self.assertEqual((receipt["status"], receipt["stage"]), ("FAIL", "install"))
        self.assertEqual([item["exit_code"] for item in receipt["attempts"]], [1, 2, 3])
        self.assertEqual(len(self.calls), 3)
        self.assertEqual(self.sleeps, [5, 5])
        self.assertNotIn("verified_revision", receipt)

    def test_install_timeout_is_recorded_before_retry(self):
        code, receipt = self.invoke(exits=("timeout", 0))
        self.assertEqual(code, 0)
        self.assertEqual(receipt["attempts"][0], {"number": 1, "status": "TIMEOUT", "exit_code": None})

    def test_repeated_install_timeouts_fail_after_three_attempts(self):
        code, receipt = self.invoke(exits=("timeout", "timeout", "timeout"))
        self.assertEqual(code, 1)
        self.assertEqual(len(receipt["attempts"]), 3)
        self.assertEqual(len(self.calls), 3)
        self.assertNotIn("verified_revision", receipt)

    def test_installer_zero_without_package_files_fails_verification(self):
        code, receipt = self.invoke(fixture=False)
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(len(receipt["attempts"]), 1)

    def test_wrong_metadata_revision_fails_without_probe_or_retry(self):
        self.install_fixture(revision="3.22.2")
        code, receipt = self.invoke(fixture=False)
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(self.calls), 1)

    def test_duplicate_revision_metadata_is_rejected(self):
        self.install_fixture(extra="Pkg.Revision = 3.22.1\n")
        code, receipt = self.invoke(fixture=False)
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(self.calls), 1)

    def test_wrong_executable_version_is_not_retried(self):
        code, receipt = self.invoke(version="3.22.10")
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(receipt["attempts"]), 1)
        self.assertEqual(len(self.calls), 2)

    def test_official_android_git_build_stdout_succeeds(self):
        code, receipt = self.invoke(probe_stdout=OFFICIAL_ANDROID_CMAKE_STDOUT)
        self.assertEqual(code, 0)
        self.assertEqual(receipt["verified_revision"], "3.22.1")
        self.assertEqual(len(self.calls), 2)

    def test_clean_git_build_suffix_succeeds(self):
        code, receipt = self.invoke(version="3.22.1-g37088a8")
        self.assertEqual(code, 0)
        self.assertEqual(receipt["verified_revision"], "3.22.1")

    def test_git_build_stdout_cannot_override_wrong_package_revision(self):
        self.install_fixture(revision="3.22.2")
        code, receipt = self.invoke(fixture=False, probe_stdout=OFFICIAL_ANDROID_CMAKE_STDOUT)
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(self.calls), 1)

    def test_unknown_git_or_custom_suffixes_are_rejected_without_retry(self):
        for version in [
            "3.22.10-g37088a8-dirty",
            "3.22.1-custom",
            "3.22.1-dirty",
            "3.22.1-g",
            "3.22.1-gnothex",
            "3.22.1-g37088a8-extra",
            "3.22.1-g37088a8-dirty-extra",
        ]:
            with self.subTest(version=version):
                self.calls.clear()
                code, receipt = self.invoke(version=version)
                self.assertEqual(code, 1)
                self.assertEqual(receipt["stage"], "verify")
                self.assertEqual(len(receipt["attempts"]), 1)
                self.assertEqual(len(self.calls), 2)

    def test_empty_probe_output_cannot_pass(self):
        code, receipt = self.invoke(probe_stdout="")
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(self.calls), 2)

    def test_nonzero_probe_is_not_retried(self):
        code, receipt = self.invoke(probe_code=7)
        self.assertEqual(code, 1)
        self.assertEqual(receipt["stage"], "verify")
        self.assertEqual(len(self.calls), 2)

    def test_probe_timeout_is_not_retried(self):
        code, receipt = self.invoke(probe_timeout=True)
        self.assertEqual(code, 1)
        self.assertEqual(receipt["error_type"], "TimeoutExpired")
        self.assertEqual(len(self.calls), 2)

    def test_execution_exception_fails_without_leaking_raw_output(self):
        code, receipt = self.invoke(exits=("oserror",))
        self.assertEqual(code, 1)
        self.assertEqual((receipt["stage"], receipt["error_type"]), ("install", "OSError"))
        self.assertNotIn("SENSITIVE", self.receipt.read_text(encoding="utf-8"))
        self.assertEqual(len(self.calls), 1)

    def test_missing_sdk_root_records_preflight_failure(self):
        code = cmake.provision(None, self.receipt)
        receipt = json.loads(self.receipt.read_text(encoding="utf-8"))
        self.assertEqual(code, 1)
        self.assertEqual((receipt["status"], receipt["stage"]), ("FAIL", "preflight"))
        self.assertEqual(receipt["attempts"], [])

    def test_missing_sdkmanager_records_preflight_failure(self):
        self.manager.unlink()
        code = cmake.provision(self.sdk, self.receipt)
        receipt = json.loads(self.receipt.read_text(encoding="utf-8"))
        self.assertEqual(code, 1)
        self.assertEqual((receipt["status"], receipt["stage"]), ("FAIL", "preflight"))
        self.assertEqual(receipt["attempts"], [])

    def test_sdk_tool_path_cannot_escape_root(self):
        with self.assertRaises(cmake.ProvisionError):
            cmake.inside_sdk(self.base / "outside-sdk/cmake", self.sdk.resolve())


if __name__ == "__main__":
    unittest.main()
