"""Synthetic receipt validation, not an actual native test PASS."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import bil39_native_receipts as native


class NativeReceiptTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bil39-native-receipts-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for kind in native.KINDS:
            log = self.root / f'ipad-{kind}.log'
            log.write_bytes(b'00:02 +3: All tests passed!\n')
            value = {'label': f'ipad-{kind}-drive', 'effective_returncode': 0, 'raw_returncode': 0,
                'timed_out': False, 'first_test_after_seconds': 1, 'terminal_summary_after_seconds': 2,
                'native_failure_summary_seen': False, 'native_summary': '00:02 +3: All tests passed!',
                'output_complete': True, 'output_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
            (self.root / f'ipad-{kind}-drive-result.json').write_text(json.dumps(value))
        path = self.root / 'runner-tests/runner-tests-result.json'
        path.parent.mkdir()
        path.write_text(json.dumps({'status': 'PASS', 'build_number': '39',
            'summary': {'passedTests': 5, 'failedTests': 0, 'skippedTests': 0}}))

    def check(self, label='ipad'):
        return native.verify(self.root, label=label, sha='a' * 40)

    def test_all_scopes_and_xctest_are_required_for_the_selected_device(self):
        result = self.check()
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual([item['kind'] for item in result['scopes']], list(native.KINDS))
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


if __name__ == '__main__':
    unittest.main()
