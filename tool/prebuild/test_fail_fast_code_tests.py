"""Check full-suite scheduling without starting Flutter or changing assertions."""
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

import run_code_tests as runner


class FailFastCodeTests(unittest.TestCase):
    def run_suite(self, exits, *, fail_fast=True):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = ['test/a_test.dart', 'test/b_test.dart',
                     'test/performance_budget_test.dart']
            portable = SimpleNamespace(partition_test_batches=lambda command, paths: [[p] for p in paths])
            spec = SimpleNamespace(loader=SimpleNamespace(exec_module=lambda module: None))
            output = io.StringIO()
            with mock.patch.object(runner, 'ROOT', root), \
                 mock.patch.object(runner, 'EVIDENCE', root / 'evidence'), \
                 mock.patch.object(runner, 'discover', return_value=(files, files.copy())), \
                 mock.patch.object(runner, 'MIXED_NAMES', {'test/mixed_test.dart': '^code only$'}), \
                 mock.patch.object(runner, 'flutter_test_command', return_value=['dart', 'test']), \
                 mock.patch.object(runner.shutil, 'which', return_value='flutter.bat'), \
                 mock.patch.object(runner.importlib.util, 'spec_from_file_location', return_value=spec), \
                 mock.patch.object(runner.importlib.util, 'module_from_spec', return_value=portable), \
                 mock.patch.object(runner, 'run_gate', side_effect=exits) as gate, \
                 mock.patch('sys.argv', ['run_code_tests.py', 'final', *(['--fail-fast'] if fail_fast else [])]), \
                 redirect_stdout(output):
                code = runner.main()
            saved = json.loads((root / 'evidence/final_flutter_summary.json').read_text())
            return code, gate.call_args_list, saved, output.getvalue()

    def test_first_failed_group_stops_without_scheduling_remaining_groups(self):
        code, calls, saved, output = self.run_suite([7])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 1)
        self.assertEqual([r['exit_code'] for r in saved], [7])
        self.assertIn('remaining groups NOT RUN', output)

    def test_later_failure_preserves_success_and_failure_without_running_mixed(self):
        code, calls, saved, _ = self.run_suite([0, 9])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 2)
        self.assertEqual([r['exit_code'] for r in saved], [0, 9])

    def test_mixed_failure_stops_before_performance_group(self):
        code, calls, saved, _ = self.run_suite([0, 0, 8])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 3)
        self.assertEqual(saved[-1]['gate'], 'final_flutter_mixed_00')
        self.assertEqual(saved[-1]['exit_code'], 8)

    def test_success_still_runs_every_group_including_performance(self):
        code, calls, saved, _ = self.run_suite([0, 0, 0, 0])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 4)
        self.assertEqual(saved[-1]['gate'], 'final_flutter_performance')

    def test_default_audit_mode_still_collects_all_results(self):
        code, calls, saved, _ = self.run_suite([7, 0, 0, 0], fail_fast=False)
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 4)
        self.assertEqual([r['exit_code'] for r in saved], [7, 0, 0, 0])


if __name__ == '__main__':
    unittest.main()
