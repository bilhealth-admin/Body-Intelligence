import base64
import json
from pathlib import Path
import tempfile
import unittest

import bil_ios_runner_tests as runner


ROOT = Path(__file__).resolve().parents[2]
DEVICE = "12345678-1234-5678-1234-1234567890ab"
DEFINES = ["BIL_ENVIRONMENT=testing", "BIL_USE_SUPABASE=false", "BIL_PAYMENTS_ENABLED=false",
           "BIL_ADS_ENABLED=false", "BIL_QA_IOS_SIMULATOR=true", "BIL_QA_SOURCE_HEAD=" + "a" * 40]


class ExistingRunnerTestsCoverage(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bil runner tests ")
        self.addCleanup(self.temp.cleanup)
        self.workspace = Path(self.temp.name).resolve()
        (self.workspace / "ios/Runner.xcworkspace").mkdir(parents=True)
        tests = self.workspace / "ios/RunnerTests/RunnerTests.swift"
        tests.parent.mkdir()
        tests.write_bytes((ROOT / "ios/RunnerTests/RunnerTests.swift").read_bytes())
        self.names = runner.expected_tests(tests.read_text(encoding="utf-8"))
        self.output = self.workspace / "artifacts/runner-tests"
        self.calls = []
        self.test_status = 0
        self.summary_status = 0
        self.create_bundle = True
        self.summary = {"totalTestCount": 5, "passedTests": 5, "failedTests": 0,
                        "skippedTests": 0, "expectedFailures": 0}
        self.log = "\n".join(f"Test Case '-[RunnerTests.RunnerTests {name}]' passed (0.01 seconds)."
                             for name in sorted(self.names))

    def fake_run(self, command, **options):
        self.calls.append((command, options))
        if command[:3] == ["xcrun", "xcodebuild", "test"]:
            if self.create_bundle:
                (self.output / "RunnerTests.xcresult").mkdir()
            options["log_path"].write_text(self.log, encoding="utf-8")
            return self.test_status
        self.assertEqual(command[:5], ["xcrun", "xcresulttool", "get", "test-results", "summary"])
        options["log_path"].write_text(json.dumps(self.summary), encoding="utf-8")
        return self.summary_status

    def invoke(self):
        code = runner.run_tests(self.workspace, self.output, DEVICE, DEFINES,
                                run=self.fake_run, host="darwin")
        return code, json.loads((self.output / "runner-tests-result.json").read_bytes())

    def test_build39_keeps_all_five_real_xctest_assertions_and_records_exact_build(self):
        code = runner.run_tests(self.workspace, self.output, DEVICE, DEFINES,
            run=self.fake_run, host='darwin', build_number='39')
        self.assertEqual(code, 0)
        self.assertIn('FLUTTER_BUILD_NUMBER=39', self.calls[0][0])
        receipt = json.loads((self.output / 'runner-tests-result.json').read_text())
        self.assertEqual(receipt['build_number'], '39')
        self.assertEqual(receipt['summary']['passedTests'], 5)

    def test_unreviewed_build_number_fails_before_any_xcode_execution(self):
        with self.assertRaises(ValueError):
            runner.run_tests(self.workspace, self.output, DEVICE, DEFINES,
                run=self.fake_run, host='darwin', build_number='38')
        self.assertEqual(self.calls, [])

    def test_actual_command_targets_existing_suite_on_exact_iphone_with_offline_host(self):
        code, receipt = self.invoke()
        self.assertEqual(code, 0)
        self.assertEqual(receipt["status"], "PASS")
        command, options = self.calls[0]
        self.assertEqual(command[:3], ["xcrun", "xcodebuild", "test"])
        for flag, value in {
            "-workspace": str(self.workspace / "ios/Runner.xcworkspace"),
            "-scheme": "Runner", "-sdk": "iphonesimulator", "-configuration": "Debug",
            "-destination": f"platform=iOS Simulator,id={DEVICE}",
            "-parallel-testing-enabled": "NO", "-resultBundlePath": str(self.output / "RunnerTests.xcresult"),
            "-clonedSourcePackagesDirPath": str(self.workspace / "build/ios/SourcePackages"),
        }.items():
            self.assertEqual(command[command.index(flag) + 1], value)
        self.assertIn("-only-testing:RunnerTests", command)
        self.assertIn(f"BUILD_DIR={self.workspace / 'build/ios'}", command)
        self.assertIn("CODE_SIGN_IDENTITY=-", command)
        self.assertIn("FLUTTER_BUILD_NUMBER=37", command)
        self.assertIn("FLUTTER_TARGET=lib/main.dart", command)
        self.assertNotIn("-skipPackagePluginValidation", command)
        self.assertNotIn("-skipPackageSignatureValidation", command)
        encoded = next(value.removeprefix("DART_DEFINES=") for value in command if value.startswith("DART_DEFINES="))
        self.assertEqual([base64.b64decode(value).decode() for value in encoded.split(",")], DEFINES)
        self.assertEqual(options["timeout_seconds"], 1800)
        self.assertEqual(self.calls[1][1]["timeout_seconds"], 60)
        self.assertEqual(set(receipt["summary"]["testNames"]), self.names)
        self.assertFalse(receipt["real_device_attestation_proven"])

    def test_modern_xcode_case_log_also_identifies_each_real_test(self):
        self.log = "\n".join(f"Test case 'RunnerTests.{name}()' passed on 'iPhone' (0.01 seconds)."
                             for name in self.names)
        self.assertEqual(self.invoke()[0], 0)

    def test_nonzero_test_exit_cannot_be_overridden_by_a_passing_result(self):
        self.test_status = 65
        code, receipt = self.invoke()
        self.assertEqual(code, 65)
        self.assertEqual(receipt["status"], "FAIL")
        self.assertEqual(len(self.calls), 2)  # Preserve actual failure summary for diagnosis.

    def test_timeout_remains_failure_even_with_a_complete_result_bundle(self):
        self.test_status = 124
        code, receipt = self.invoke()
        self.assertEqual(code, 124)
        self.assertEqual(receipt["status"], "FAIL")

    def test_zero_process_exit_without_xcresult_is_not_pass(self):
        self.create_bundle = False
        code, receipt = self.invoke()
        self.assertEqual(code, 1)
        self.assertEqual(receipt["summary_missing_reason"], "actual_xcresult_bundle_missing")

    def test_summary_command_failure_is_not_pass(self):
        self.summary_status = 2
        code, receipt = self.invoke()
        self.assertEqual(code, 2)
        self.assertEqual(receipt["status"], "FAIL")

    def test_missing_skipped_failed_or_wrong_counts_fail_closed(self):
        invalid = [
            {}, {**self.summary, "skippedTests": 1}, {**self.summary, "failedTests": 1},
            {**self.summary, "passedTests": 4}, {**self.summary, "totalTestCount": 6},
            {**self.summary, "expectedFailures": 1}, {**self.summary, "passedTests": True},
        ]
        for summary in invalid:
            with self.subTest(summary=summary), self.assertRaises(ValueError):
                runner.verified_summary(json.dumps(summary), self.log, self.names)

    def test_summary_five_passes_without_each_named_execution_is_not_pass(self):
        for log in ["** TEST SUCCEEDED **", "", self.log.splitlines()[0]]:
            with self.subTest(log=log), self.assertRaises(ValueError):
                runner.verified_summary(json.dumps(self.summary), log, self.names)

    def test_invalid_json_summary_is_not_pass(self):
        with self.assertRaises(ValueError):
            runner.verified_summary("not json", self.log, self.names)

    def test_old_result_bundle_is_refused_before_running_commands(self):
        (self.output / "RunnerTests.xcresult").mkdir(parents=True)
        with self.assertRaises(ValueError):
            self.invoke()
        self.assertEqual(self.calls, [])

    def test_offline_qa_defines_and_exact_simulator_udid_are_required(self):
        for device, defines in [("iPhone", DEFINES), (DEVICE, []),
                                 (DEVICE, [*DEFINES, "BIL_USE_SUPABASE=true"])]:
            with self.subTest(device=device, defines=defines), self.assertRaises(ValueError):
                runner.run_tests(self.workspace, self.output, device, defines,
                                 run=self.fake_run, host="darwin")
        self.assertEqual(self.calls, [])

    def test_actual_five_source_tests_and_native_script_wiring_are_retained(self):
        self.assertEqual(len(self.names), 5)
        script = (ROOT / ".github/scripts/bil_ios37_native_integration.sh").read_text(encoding="utf-8")
        self.assertLess(script.index("python3 .github/scripts/bil_ios_native_preflight.py"),
                        script.index("python3 .github/scripts/bil_ios_runner_tests.py"))
        self.assertLess(script.index("python3 .github/scripts/bil_ios_runner_tests.py"),
                        script.index('for KIND in "${KINDS[@]}"'))
        self.assertIn('--device "$IPHONE_UDID" "${DEFINES[@]}"', script)
        with self.assertRaises(ValueError):
            runner.expected_tests((ROOT / "ios/RunnerTests/RunnerTests.swift").read_text(encoding="utf-8") +
                                  "\nfunc testUnreviewedSixth() {}\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
