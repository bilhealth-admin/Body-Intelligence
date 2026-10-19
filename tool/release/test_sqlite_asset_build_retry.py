from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "tool/release/retry_sqlite_asset_build.py"
WORKFLOW = ROOT / ".github/workflows/bil_rc_mobile_test_build.yml"


class SqliteAssetBuildRetryContract(unittest.TestCase):
    def run_helper(self, source: str, *, delay: str = "0") -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory(prefix="sqlite-build-retry-", dir=ROOT) as temp:
            relative_state = (Path(temp).relative_to(ROOT) / "calls.txt").as_posix()
            environment = os.environ.copy()
            environment["BIL_TEST_STATE"] = relative_state
            environment["BIL_SQLITE_NATIVE_ASSET_RETRY_DELAY_SECONDS"] = delay
            command = [sys.executable, "-c", source]
            return subprocess.run(
                [sys.executable, str(HELPER), "--", *command],
                cwd=ROOT,
                env=environment,
                check=False,
                capture_output=True,
                text=True,
                timeout=30,
            )

    def test_successful_build_runs_once(self) -> None:
        result = self.run_helper("print('build-ok')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("Running iOS build command"), 1)
        self.assertIn("build-ok", result.stdout)

    def test_exact_sqlite_dns_failure_retries_then_succeeds(self) -> None:
        source = r'''
import os
from pathlib import Path
state = Path(os.environ['BIL_TEST_STATE'])
count = int(state.read_text() if state.exists() else '0') + 1
state.write_text(str(count))
if count == 1:
    print('Building assets for package:sqlite3 failed.')
    print("Original cause: SocketException: Failed host lookup: 'github.com'")
    raise SystemExit(7)
print('build-recovered')
'''
        result = self.run_helper(source)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("build-recovered", result.stdout)
        self.assertEqual(result.stdout.count("Running iOS build command"), 2)

    def test_other_failures_are_not_retried(self) -> None:
        failures = (
            "print('Compile error'); raise SystemExit(9)",
            "print('Failed host lookup: github.com'); raise SystemExit(8)",
            "print('Building assets for package:sqlite3 failed.'); print('Failed host lookup: other.invalid'); raise SystemExit(7)",
        )
        for failure in failures:
            with self.subTest(failure=failure):
                result = self.run_helper(failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout.count("Running iOS build command"), 1)

    def test_transient_failure_stops_after_three_attempts(self) -> None:
        source = r'''
print('Building assets for package:sqlite3 failed.')
print("Original cause: SocketException: Failed host lookup: 'github.com'")
raise SystemExit(7)
'''
        result = self.run_helper(source)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("Running iOS build command"), 3)

    def test_rejects_invalid_retry_delay_before_running_build(self) -> None:
        result = self.run_helper("print('should-not-run')", delay="not-a-number")
        self.assertEqual(result.returncode, 64)
        self.assertNotIn("should-not-run", result.stdout)

    def test_every_rc_ios_build_uses_the_bounded_retry_helper(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertEqual(workflow.count("flutter build ios"), 3)
        self.assertEqual(
            workflow.count("retry_sqlite_asset_build.py -- flutter build ios"),
            3,
        )
        production_ios = next(
            line for line in workflow.splitlines()
            if "retry_sqlite_asset_build.py -- flutter build ios --release" in line
        )
        for required_define in (
            "BIL_ENVIRONMENT=production",
            "BIL_MOBILE_INTEGRITY_REQUIRED=true",
            "BIL_PAYMENTS_ENABLED=true",
            "BIL_TERMS_URL=https://www.bilhealth.com/terms",
            "BIL_PRIVACY_URL=https://www.bilhealth.com/privacy",
            "BIL_MEAL_VISION_ENDPOINT=https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/analyze-meal",
            "BIL_RECIPE_IMAGE_DELIVERY_ENABLED=true",
            "BIL_FACEBOOK_LOGIN_ENABLED=true",
            "BIL_FACEBOOK_LOGIN_READY=true",
            "BIL_PUSH_ENABLED=true",
            "BIL_PUSH_PROVIDER_READY=true",
            "BIL_ADS_ENABLED=false",
            "BIL_AD_PROVIDER_READY=false",
            "BIL_ENABLE_CATALOG_TEST_ACCESS=false",
        ):
            with self.subTest(required_define=required_define):
                self.assertIn(f"--dart-define={required_define}", production_ios)


if __name__ == "__main__":
    unittest.main()
