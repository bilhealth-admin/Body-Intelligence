"""Isolated diagnostic ownership/cleanup controls, not actual macOS evidence."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from bil40_ipad_history_diagnostic import Diagnostic, select_device, valid_owned_uuid

UUID = '11111111-1111-4111-8111-111111111111'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'


class DiagnosticTest(unittest.TestCase):
    def test_selector_retains_ipad_and_latest_available_ios_without_phone_fallback(self):
        runtimes = {'runtimes': [
            {'isAvailable': True, 'identifier': RUNTIME, 'version': '26.5'},
            {'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-1', 'version': '26.1'}]}
        devices = {'devicetypes': [{'name': 'iPad Pro 13-inch (M4)', 'identifier': 'ipad-M4'},
                                  {'name': 'iPhone 16 Pro', 'identifier': 'iphone'}]}
        self.assertEqual(select_device(runtimes, devices), (RUNTIME, 'ipad-M4'))
        with self.assertRaises(ValueError):
            select_device(runtimes, {'devicetypes': [devices['devicetypes'][1]]})
        for invalid in ('', '../other', UUID + '\n' + UUID, 'g' * 36):
            self.assertFalse(valid_owned_uuid(invalid))
        self.assertTrue(valid_owned_uuid(UUID))

    def run_fixture(self, *, fail=None, created=UUID, collect_failure=False, cleanup_failure=False):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        runner = Diagnostic(root, root / 'evidence')
        calls = []
        def stage(label, seconds, command):
            calls.append((label, seconds, command))
            if label == fail or (cleanup_failure and label == 'delete'):
                raise RuntimeError('original-' + label)
            return {
                'source-head': 'a' * 40, 'source-tree': 'b' * 40,
                'runtimes': json.dumps({'runtimes': [{'isAvailable': True, 'identifier': RUNTIME, 'version': '26.5'}]}),
                'device-types': json.dumps({'devicetypes': [{'name': 'iPad Pro 13-inch (M4)', 'identifier': 'ipad-M4'}]}),
                'create': created,
            }.get(label, '')
        runner.stage = stage
        def collect():
            if collect_failure:
                raise ValueError('collection failed')
        runner.collect = collect
        with patch.dict('os.environ', {}, clear=False):
            code = runner.run()
        return runner, calls, code

    def test_exact_eight_coach_cases_one_drive_and_owned_cleanup(self):
        runner, calls, code = self.run_fixture()
        self.assertEqual(code, 0)
        self.assertEqual(runner.receipt['coach_cases'], 8)
        config = next(c for label, _, c in calls if label == 'feature-config')
        self.assertIn('--dart-define=BIL_QA_NATIVE_COACH_ONLY=true', config)
        self.assertFalse(any('BIL_QA_NATIVE_SCENE' in part for part in config))
        self.assertIn('--dart-define=BIL_USE_SUPABASE=false', config)
        self.assertIn('--dart-define=BIL_PAYMENTS_ENABLED=false', config)
        self.assertEqual(sum(label == 'drive' for label, _, _ in calls), 1)
        self.assertEqual([(label, seconds, command[-1]) for label, seconds, command in calls[-2:]],
                         [('shutdown', 30, UUID), ('delete', 30, UUID)])
        self.assertNotIn('system-crypto', [label for label, _, _ in calls])

    def test_invalid_uuid_stops_before_build_and_never_cleans_unknown_device(self):
        runner, calls, code = self.run_fixture(created='../bad')
        self.assertEqual(code, 1)
        self.assertIsNone(runner.device)
        self.assertFalse(any(label in ('feature-build', 'delete', 'shutdown') for label, _, _ in calls))

    def test_setup_failure_still_deletes_only_its_created_simulator(self):
        runner, calls, code = self.run_fixture(fail='native-preflight')
        self.assertEqual(code, 1)
        self.assertEqual(calls[-1], ('delete', 30, ['xcrun', 'simctl', 'delete', UUID]))
        self.assertFalse(any(label == 'drive' for label, _, _ in calls))

    def test_drive_failure_preserved_when_collection_and_cleanup_also_fail(self):
        runner, calls, code = self.run_fixture(fail='drive', collect_failure=True, cleanup_failure=True)
        self.assertEqual(code, 1)
        self.assertEqual(runner.receipt['error'], 'original-drive')
        self.assertEqual(runner.receipt['collection_error_type'], 'ValueError')
        self.assertEqual(runner.receipt['cleanup_errors'], [{'stage': 'delete', 'error_type': 'RuntimeError'}])
        self.assertFalse(runner.receipt['completed'])
        self.assertEqual(sum(label == 'drive' for label, _, _ in calls), 1)

    def test_cleanup_failure_cannot_be_a_clean_diagnostic_pass(self):
        runner, _, code = self.run_fixture(cleanup_failure=True)
        self.assertEqual(code, 1)
        self.assertTrue(runner.receipt['cleanup_errors'])
        self.assertEqual(runner.receipt['scope'], 'DIAGNOSTIC_ONLY_NOT_RELEASE_ACCEPTANCE')


if __name__ == '__main__':
    unittest.main()
