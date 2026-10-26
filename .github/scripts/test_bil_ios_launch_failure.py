"""Run real bounded subprocesses for the explicit Flutter bootstrap failure."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('bil_native_bounded_command.py')
ERROR = 'Error waiting for a debug connection: The log reader failed unexpectedly'


class LaunchFailureTest(unittest.TestCase):
    def run_child(self, code, *, enabled=True):
        with tempfile.TemporaryDirectory(prefix='bil39-launch-failure-') as folder:
            path = Path(folder)
            command = [sys.executable, str(SCRIPT), '--label', 'launch-fixture',
                '--log', str(path / 'raw.log'), '--receipt', str(path / 'receipt.json'),
                '--timeout-seconds', '8', '--kill-grace-seconds', '.1']
            if enabled:
                command.append('--fail-on-launch-error')
            result = subprocess.run(command + ['--', sys.executable, '-u', '-c', code],
                                    capture_output=True, timeout=14)
            return result, json.loads((path / 'receipt.json').read_text()), (path / 'raw.log').read_bytes()

    def test_explicit_launch_failure_stops_owned_hang_without_waiting_for_bootstrap_deadline(self):
        result, receipt, raw = self.run_child(f'import time; print({ERROR!r}); time.sleep(30)')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(receipt['reason'], 'bootstrap_launch_error')
        self.assertEqual(receipt['launch_error'], 'flutter_debug_log_reader_failed')
        self.assertTrue(receipt['cleanup_attempted'])
        self.assertFalse(receipt['timed_out'])
        self.assertLess(receipt['elapsed_seconds'], 7)
        self.assertIn(ERROR.encode(), raw)

    def test_verbose_flutter_error_with_zero_child_exit_cannot_become_success(self):
        result, receipt, _ = self.run_child(f'print({("[ +123 ms] " + ERROR)!r})')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(receipt['reason'], 'bootstrap_launch_error')

    def test_option_is_explicit_and_legacy_behavior_is_unchanged(self):
        result, receipt, _ = self.run_child(f'print({ERROR!r})', enabled=False)
        self.assertEqual(result.returncode, 0)
        self.assertIsNone(receipt['launch_error'])

    def test_post_start_test_output_and_unrelated_text_do_not_trigger_bootstrap_guard(self):
        for code in (f'print("00:01 +0: first test"); print({ERROR!r}); print("00:02 +1: All tests passed!")',
                     'print("Documentation mentions a log reader; this is not a launch failure")'):
            with self.subTest(code=code):
                result, receipt, _ = self.run_child(code)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIsNone(receipt['launch_error'])


if __name__ == '__main__':
    unittest.main()
