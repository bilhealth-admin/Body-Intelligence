import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("isolated_pods", Path(__file__).with_name("install_isolated_cocoapods.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class IsolatedCocoaPodsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {"RUNNER_TEMP": str(self.root), "GITHUB_ENV": str(self.root / "env"),
                    "GITHUB_PATH": str(self.root / "path"), "PATH": "/runner/ruby/bin",
                    "GEM_HOME": "/existing/global", "GEM_PATH": "/existing/global"}
        self.calls = []
        self.probe_version = "1.16.2"
        self.executable_version = "1.16.2"
        self.escape_dependency = False
        self.fail_install = False
        self.fail_probe = False
        self.timeout_probe = False

    def fake_run(self, args, **kwargs):
        self.calls.append((args, kwargs))
        env = kwargs["env"]
        # RubyGems parses the command before command-scoped common options.
        # Reject the exact argv that failed on the actual macOS runner.
        if Path(args[0]).name == "gem" and args[1] != "install":
            raise subprocess.CalledProcessError(1, args, stderr="Invalid option: --norc")
        if "install" in args:
            if self.fail_install:
                raise subprocess.CalledProcessError(7, args, output="synthetic-secret-output", stderr="synthetic-secret-error")
            return SimpleNamespace(stdout="", returncode=0)
        if "-e" in args:
            if self.fail_probe:
                raise subprocess.CalledProcessError(8, args, output="synthetic-secret-output", stderr="synthetic-secret-error")
            if self.timeout_probe:
                raise subprocess.TimeoutExpired(args, 90, output="synthetic-secret-output", stderr="synthetic-secret-error")
            home = Path(env["GEM_HOME"])
            value = {"cocoapods_version": self.probe_version, "xcodeproj_version": "1.28.1",
                     "cocoapods_gem_path": str(home / "gems/cocoapods-1.16.2"),
                     "xcodeproj_gem_path": "/existing/global/xcodeproj" if self.escape_dependency else str(home / "gems/xcodeproj-1.28.1"),
                     "resolved_gems": [{"name": "cocoapods", "version": self.probe_version}, {"name": "xcodeproj", "version": "1.28.1"}]}
            return SimpleNamespace(stdout=json.dumps(value), returncode=0)
        return SimpleNamespace(stdout=self.executable_version + "\n", returncode=0)

    def install(self):
        with patch.object(module.shutil, "which", side_effect=lambda x, **_: "/runner/ruby/bin/" + x):
            return module.install(self.root / "receipt.json", run=self.fake_run, environ=self.env)

    def failure_receipt(self, stage, exit_code=1):
        raw = (self.root / "receipt.json").read_bytes()
        value = json.loads(raw)
        self.assertEqual(value["status"], "FAIL")
        self.assertEqual(value["stage"], stage)
        self.assertEqual(value["exit_code"], exit_code)
        for field in ("cocoapods_version", "xcodeproj_version", "resolved_gems",
                      "isolated_installation_verified"):
            self.assertNotIn(field, value)
        self.assertNotIn(b"synthetic-secret", raw)
        self.assertNotIn(b"/existing/global", raw)
        self.assertNotIn(b"\r\n", raw)
        self.assertEqual(list(self.root.glob(".bil-cocoapods-receipt-*.tmp")), [])
        return value

    def test_exact_version_and_fresh_isolation_without_global_mutation(self):
        before = dict(self.env)
        receipt = self.install()
        self.assertEqual(before, self.env)
        args, options = self.calls[0]
        self.assertEqual(args[:6], ["/runner/ruby/bin/gem", "install", "cocoapods", "--norc", "--version", "1.16.2"])
        self.assertIn("--clear-sources", args)
        self.assertIn("https://rubygems.org", args)
        self.assertEqual(options["timeout"], 600)
        self.assertTrue(Path(options["env"]["GEM_HOME"]).resolve().is_relative_to(self.root.resolve()))
        self.assertEqual(options["env"]["GEM_HOME"], options["env"]["GEM_PATH"])
        self.assertNotIn("/existing/global", options["env"]["GEM_PATH"])
        shim = next(self.root.glob("bil-cocoapods-*/bin/pod"))
        self.assertIn("gem 'cocoapods', '=1.16.2'", shim.read_text())
        self.assertIn("Gem.bin_path('cocoapods', 'pod', '=1.16.2')", shim.read_text())
        self.assertEqual(receipt["xcodeproj_version"], "1.28.1")
        self.assertEqual(receipt["status"], "PASS")
        self.assertEqual(receipt["exit_code"], 0)
        self.assertFalse(receipt["global_gem_directories_modified"])
        self.assertIn("GEM_PATH=", (self.root / "env").read_text())

    def test_runner_temp_directory_alias_keeps_canonical_isolation(self):
        real = self.root / "real-runner-temp"
        real.mkdir()
        alias = self.root / "runner-temp-alias"
        alias.symlink_to(real, target_is_directory=True)
        self.env["RUNNER_TEMP"] = str(alias)
        self.install()
        home = Path(self.calls[0][1]["env"]["GEM_HOME"])
        self.assertTrue(home.is_relative_to(real.resolve()))
        self.assertFalse(home.is_relative_to(alias))
        self.assertTrue(home.resolve().is_relative_to(alias.resolve()))
        self.assertIn(str(home), (self.root / "env").read_text())

    def test_observed_runner_pod117_remains_rejected(self):
        self.probe_version = "1.17.0"
        with self.assertRaisesRegex(ValueError, "Exact CocoaPods"):
            self.install()
        self.assertFalse((self.root / "env").exists())
        self.failure_receipt("dependency_validation")

    def test_executable_selection_mismatch_blocks_publication(self):
        self.executable_version = "1.17.0"
        with self.assertRaisesRegex(ValueError, "pod executable"):
            self.install()
        self.assertFalse((self.root / "path").exists())
        self.failure_receipt("pod_version_validation")

    def test_preinstalled_xcodeproj_escape_blocks_publication(self):
        self.escape_dependency = True
        with self.assertRaisesRegex(ValueError, "escaped"):
            self.install()
        self.assertFalse((self.root / "env").exists())
        self.failure_receipt("dependency_validation")

    def test_dependency_symlink_outside_isolated_gem_home_is_rejected(self):
        isolated = self.root / "isolated-home"
        (isolated / "gems").mkdir(parents=True)
        outside = self.root / "outside-global-gem"
        outside.mkdir()
        link = isolated / "gems" / "linked-xcodeproj"
        link.symlink_to(outside, target_is_directory=True)
        probe = {"cocoapods_version": "1.16.2", "xcodeproj_version": "1.28.1",
                 "cocoapods_gem_path": str(isolated / "gems" / "cocoapods-1.16.2"),
                 "xcodeproj_gem_path": str(link),
                 "resolved_gems": [{"name": "cocoapods", "version": "1.16.2"}]}
        self.assertTrue(link.is_relative_to(isolated / "gems"))
        with self.assertRaisesRegex(ValueError, "escaped"):
            module.validate_probe(probe, isolated)

    def test_install_failure_does_not_export_selection(self):
        self.fail_install = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.install()
        self.assertFalse((self.root / "env").exists())
        self.assertEqual(len(self.calls), 1)
        receipt = self.failure_receipt("gem_install", 7)
        self.assertEqual(receipt["subprocess_exit_code"], 7)

    def test_missing_or_multiline_job_path_is_rejected(self):
        self.env["GITHUB_ENV"] += "\ninjected=value"
        with self.assertRaisesRegex(ValueError, "safe GitHub"):
            self.install()
        self.assertEqual(self.calls, [])
        self.failure_receipt("preflight")

    def test_active_bundler_is_rejected(self):
        self.env["BUNDLE_GEMFILE"] = "/unreviewed/Gemfile"
        with self.assertRaisesRegex(ValueError, "Bundler"):
            self.install()
        self.failure_receipt("preflight")

    def test_probe_failure_receipt_preserves_exit_without_raw_output(self):
        self.fail_probe = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.install()
        self.failure_receipt("dependency_probe", 8)
        self.assertFalse((self.root / "env").exists())

    def test_probe_timeout_is_recorded_without_claiming_an_exit_from_the_child(self):
        self.timeout_probe = True
        with self.assertRaises(subprocess.TimeoutExpired):
            self.install()
        receipt = self.failure_receipt("dependency_probe", 124)
        self.assertTrue(receipt["timed_out"])
        self.assertNotIn("subprocess_exit_code", receipt)

    def test_export_failure_cannot_leave_a_success_receipt(self):
        (self.root / "env").mkdir()
        with self.assertRaises(OSError):
            self.install()
        self.failure_receipt("environment_export")
        self.assertFalse((self.root / "path").exists())

    def test_failed_attempt_atomically_replaces_a_stale_success_receipt(self):
        (self.root / "receipt.json").write_text('{"status":"PASS","stale":true}')
        self.fail_install = True
        with self.assertRaises(subprocess.CalledProcessError):
            self.install()
        self.assertNotIn("stale", self.failure_receipt("gem_install", 7))

    def test_success_receipt_write_failure_is_retained_as_failure(self):
        replace = module.os.replace

        def fail_success(source, target):
            if json.loads(Path(source).read_bytes()).get("status") == "PASS":
                raise OSError("synthetic-secret-receipt-error")
            return replace(source, target)

        with patch.object(module.os, "replace", side_effect=fail_success):
            with self.assertRaises(OSError):
                self.install()
        self.failure_receipt("receipt_publication")


if __name__ == "__main__":
    unittest.main()
