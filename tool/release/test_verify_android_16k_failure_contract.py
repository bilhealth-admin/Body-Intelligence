"""Fail-closed regression tests for the final Android AAB 16 KB validator.

Only stdlib and missing-file fixtures. No signing, devices, network, or AAB.
"""
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

CHECKER = pathlib.Path(__file__).with_name("verify_android_16k_alignment.py")


class AndroidAlignmentFailureContract(unittest.TestCase):
    def test_missing_aab_exposes_original_gate_error_and_writes_fail_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            evidence = root / "evidence"
            result = subprocess.run(
                [
                    sys.executable,
                    str(CHECKER),
                    "--aab",
                    str(root / "missing.aab"),
                    "--bundletool",
                    str(root / "missing.jar"),
                    "--evidence-dir",
                    str(evidence),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("final release AAB is missing or empty", result.stderr)
            self.assertNotIn("NameError", result.stderr)
            payload = json.loads(
                (evidence / "BIL-android-16k-summary.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(payload["status"], "FAIL")
            self.assertIn("missing or empty", payload["error"])
            self.assertNotIn(
                "ANDROID_FINAL_AAB_PAGE_ALIGNMENT_16K=PASS", result.stdout
            )

    def test_missing_pinned_bundletool_cannot_be_misreported_as_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            aab = root / "fake.aab"
            aab.write_bytes(b"only-a-nonempty-fixture-not-a-real-bundle")
            evidence = root / "evidence"
            result = subprocess.run(
                [
                    sys.executable,
                    str(CHECKER),
                    "--aab",
                    str(aab),
                    "--bundletool",
                    str(root / "missing.jar"),
                    "--evidence-dir",
                    str(evidence),
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("bundletool JAR is missing or empty", result.stderr)
            data = json.loads(
                (evidence / "BIL-android-16k-summary.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(data["status"], "FAIL")

    def test_internal_16k_alignment_self_test_still_passes(self):
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--self-test"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ANDROID_16K_ALIGNMENT_SELF_TEST=PASS", result.stdout)


if __name__ == "__main__":
    unittest.main()
