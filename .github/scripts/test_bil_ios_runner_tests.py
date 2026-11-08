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
        self.summary = {"totalTestCount": len(self.names), "passedTests": len(self.names), "failedTests": 0,
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
        self.assertEqual(receipt['summary']['passedTests'], len(self.names))

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
            {**self.summary, "passedTests": len(self.names) - 1}, {**self.summary, "totalTestCount": len(self.names) + 1},
            {**self.summary, "expectedFailures": 1}, {**self.summary, "expectedFailures": False},
            {**self.summary, "passedTests": True},
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
        self.assertTrue(runner.ORIGINAL_TEST_NAMES.issubset(self.names))
        script = (ROOT / ".github/scripts/bil_ios37_native_integration.sh").read_text(encoding="utf-8")
        self.assertLess(script.index("python3 .github/scripts/bil_ios_native_preflight.py"),
                        script.index("python3 .github/scripts/bil_ios_runner_tests.py"))
        self.assertLess(script.index("python3 .github/scripts/bil_ios_runner_tests.py"),
                        script.index('for KIND in "${KINDS[@]}"'))
        self.assertIn('--device "$IPHONE_UDID" "${DEFINES[@]}"', script)
        # A fixture or top-level function is not a declared RunnerTests XCTest.
        self.assertEqual(runner.expected_tests((ROOT / "ios/RunnerTests/RunnerTests.swift").read_text(encoding="utf-8") +
            "\nfunc testUnrelatedTopLevel() {}\n"), self.names)


class NamedSourceRegistryTests(unittest.TestCase):
    @staticmethod
    def source(extra=''):
        return ('import XCTest\nclass RunnerTests: XCTestCase {\n' +
            '\n'.join('  func ' + name + '() throws {}' for name in sorted(runner.ORIGINAL_TEST_NAMES)) +
            '\n' + extra + '\n}\n')

    @staticmethod
    def summary(names):
        return json.dumps({'totalTestCount':len(names),'passedTests':len(names),
            'failedTests':0,'skippedTests':0,'expectedFailures':0})

    @staticmethod
    def log(names):
        return '\n'.join("Test Case '-[RunnerTests.RunnerTests " + name + "]' passed (0.01 seconds)." for name in sorted(names))

    def test_old_source_keeps_exact_five_and_new_source_requires_every_declared_test(self):
        old = runner.expected_tests(self.source())
        self.assertEqual(old, runner.ORIGINAL_TEST_NAMES)
        new = runner.expected_tests(self.source('  @MainActor func testNewCapsulePixels() throws {}\n  func testNewCapsuleRTL() {}'))
        self.assertEqual(len(new), 7)
        self.assertEqual(set(runner.verified_summary(self.summary(new), self.log(new), new)['testNames']), new)
        with self.assertRaises(ValueError):
            runner.verified_summary(self.summary(old), self.log(old), new)

    def test_comments_literals_nested_functions_and_foreign_classes_are_not_tests(self):
        extra = '''// func testCommentFake() {}
        /* nested /* func testNestedCommentFake() {} */ comment */
        let fixture = "func testStringFake() {}"
        let rawFixture = #"func testRawStringFake() {}"#
        let multiline = """func testMultilineFake() {}"""
        func helper() { func testNestedFunctionFake() {} }
        '''
        source = self.source(extra) + 'class OtherFixture { func testForeignClassFake() {} }'
        self.assertEqual(runner.expected_tests(source), runner.ORIGINAL_TEST_NAMES)

    def test_actual_runner_extension_is_included(self):
        source = self.source() + 'extension RunnerTests { @MainActor func testExtensionCapsule() throws {} }'
        self.assertEqual(runner.expected_tests(source), runner.ORIGINAL_TEST_NAMES | {'testExtensionCapsule'})

    def test_missing_original_duplicate_or_non_xctest_source_fails_closed(self):
        original = sorted(runner.ORIGINAL_TEST_NAMES)[0]
        values = [self.source().replace('func ' + original, 'func renamedOriginal'),
            self.source('func ' + original + '() {}'),
            self.source().replace('class RunnerTests: XCTestCase', 'class Fixture: XCTestCase'),
            'class Container { ' + self.source() + ' }',
            self.source('func testInvalidParameter(value: Int) {}'),
            self.source() + 'class RunnerTests: XCTestCase {}', self.source() + '/* unclosed']
        for source in values:
            with self.subTest(kind=len(source)), self.assertRaises(ValueError):
                runner.expected_tests(source)

    def test_foreign_class_duplicate_and_unknown_executions_cannot_supply_named_passes(self):
        names = runner.expected_tests(self.source())
        good = self.log(names)
        values = [good.replace('RunnerTests.RunnerTests', 'OtherRunnerTests.RunnerTests'),
            good.replace('RunnerTests.RunnerTests', 'RunnerTests.OtherClass'),
            good + '\n' + good.splitlines()[0], good.replace(sorted(names)[0], 'testUnknownFromAnotherSource'),
            good + "\nTest Case '-[OtherTests.OtherTests testForeign]' passed (0.01 seconds).",
            'A fixture says ' + good.replace('\n', '\nA fixture says ')]
        for log in values:
            with self.subTest(kind=len(log)), self.assertRaises(ValueError):
                runner.verified_summary(self.summary(names), log, names)


if __name__ == "__main__":
    unittest.main(verbosity=2)
