"""Synthetic receipt validation, not an actual native test PASS."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import bil39_native_receipts as native
from bil_ios_runner_tests import expected_tests


class NativeReceiptTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bil39-native-receipts-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source_root = self.root / 'source'
        self.source = self.source_root / 'ios/RunnerTests/RunnerTests.swift'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes((Path(__file__).resolve().parents[2] / 'ios/RunnerTests/RunnerTests.swift').read_bytes())
        for kind in native.KINDS:
            log = self.root / f'ipad-{kind}.log'
            log.write_bytes(b'00:02 +3: All tests passed!\n')
            value = {'label': f'ipad-{kind}-drive', 'effective_returncode': 0, 'raw_returncode': 0,
                'timed_out': False, 'first_test_after_seconds': 1, 'terminal_summary_after_seconds': 2,
                'native_failure_summary_seen': False, 'native_summary': '00:02 +3: All tests passed!',
                'output_complete': True, 'output_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
            (self.root / f'ipad-{kind}-drive-result.json').write_text(json.dumps(value))
        self.write_xctest()

    def write_xctest(self, names=None):
        names = expected_tests(self.source.read_text()) if names is None else names
        folder = self.root / 'runner-tests'
        folder.mkdir(exist_ok=True)
        counts = {'totalTestCount': len(names), 'passedTests': len(names), 'failedTests': 0, 'skippedTests': 0}
        (folder / 'runner-tests-summary.json').write_text(json.dumps({**counts, 'expectedFailures': 0}))
        (folder / 'runner-tests.log').write_text('\n'.join(
            "Test Case '-[RunnerTests.RunnerTests " + name + "]' passed (0.01 seconds)." for name in sorted(names)))
        (folder / 'runner-tests-result.json').write_text(json.dumps({'status': 'PASS', 'build_number': '39',
            'source_test_sha256': hashlib.sha256(self.source.read_bytes()).hexdigest(),
            'summary': {**counts, 'testNames': sorted(names)}}))

    def check(self, label='ipad'):
        return native.verify(self.root, label=label, sha='a' * 40, source_root=self.source_root)

    def test_all_scopes_and_xctest_are_required_for_the_selected_device(self):
        result = self.check()
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual([item['kind'] for item in result['scopes']], list(native.KINDS))
        self.assertEqual(result['xctest']['testNames'], sorted(expected_tests(self.source.read_text())))
        self.assertEqual(result['xctest']['passedTests'], len(expected_tests(self.source.read_text())))
        with self.assertRaises(FileNotFoundError):
            self.check('iphone')

    def test_zero_exit_without_first_test_or_summary_is_not_a_native_pass(self):
        path = self.root / 'ipad-system-crypto-drive-result.json'
        original = json.loads(path.read_text())
        for field, value in [('first_test_after_seconds', None), ('native_summary', None),
            ('terminal_summary_after_seconds', None), ('raw_returncode', 1), ('output_complete', False),
            ('launch_error', 'flutter_debug_log_reader_failed'), ('label', 'iphone-system-crypto-drive')]:
            with self.subTest(field=field):
                path.write_text(json.dumps({**original, field: value}))
                with self.assertRaises(ValueError):
                    self.check()

    def test_changed_log_and_missing_scope_are_rejected(self):
        (self.root / 'ipad-native-settings.log').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            self.check()

    def test_xctest_failure_or_skip_cannot_pass(self):
        path = self.root / 'runner-tests/runner-tests-result.json'
        value = json.loads(path.read_text())
        value['summary']['skippedTests'] = 1
        path.write_text(json.dumps(value))
        with self.assertRaises(ValueError):
            self.check()

    def test_current_eight_named_source_tests_and_a_future_extra_declaration_are_not_hardcoded(self):
        names = expected_tests(self.source.read_text())
        self.assertEqual(len(names), 8)
        self.assertEqual(self.check()['xctest']['passedTests'], 8)
        names.add('testAdditionalSourceDeclaredReceiptRegression')
        self.source.write_text('import XCTest\nclass RunnerTests: XCTestCase {\n' + '\n'.join(
            '  func ' + name + '() {}' for name in sorted(names)) + '\n}\n')
        self.write_xctest()
        self.assertEqual(self.check()['xctest']['passedTests'], 9)

    def test_old_five_count_cannot_hide_missing_newly_declared_tests(self):
        from bil_ios_runner_tests import ORIGINAL_TEST_NAMES
        self.write_xctest(names=set(ORIGINAL_TEST_NAMES))
        with self.assertRaises(ValueError):
            self.check()

    def test_missing_duplicate_foreign_class_and_fabricated_execution_names_are_rejected(self):
        path = self.root / 'runner-tests/runner-tests.log'
        original = path.read_text()
        names = sorted(expected_tests(self.source.read_text()))
        for changed in ('\n'.join(original.splitlines()[1:]), original + '\n' + original.splitlines()[0],
                        original.replace('RunnerTests.RunnerTests', 'ForeignTests.ForeignTests'),
                        original.replace(names[-1], 'testInventedName')):
            with self.subTest(log_hash=hashlib.sha256(changed.encode()).hexdigest()):
                path.write_text(changed)
                with self.assertRaises(ValueError):
                    self.check()

    def test_wrong_source_hash_missing_raw_summary_and_expected_failure_are_rejected(self):
        path = self.root / 'runner-tests/runner-tests-result.json'
        original = json.loads(path.read_text())
        path.write_text(json.dumps({**original, 'source_test_sha256': '0' * 64}))
        with self.assertRaises(ValueError):
            self.check()
        path.write_text(json.dumps(original))
        summary = self.root / 'runner-tests/runner-tests-summary.json'
        raw = json.loads(summary.read_text())
        summary.write_text(json.dumps({**raw, 'expectedFailures': 1}))
        with self.assertRaises(ValueError):
            self.check()
        summary.unlink()
        with self.assertRaises(ValueError):
            self.check()


if __name__ == '__main__':
    unittest.main()
