"""The ledger counts real Flutter events, including loading errors and skips."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import argparse
import json
import os
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location('owner_runner', Path(__file__).with_name('bil_owner_full_test_runner.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class LedgerTests(unittest.TestCase):
    def test_loading_failure_cannot_be_reported_as_empty_success(self):
        ledger = runner.Ledger()
        ledger.event({'type': 'suite', 'suite': {'id': 2, 'path': 'G:/fixture/test/broken_test.dart'}})
        ledger.event({'type': 'testStart', 'test': {'id': 1, 'suiteID': 2, 'name': 'loading broken'}})
        ledger.event({'type': 'error', 'testID': 1, 'error': 'compile failure'})
        ledger.event({'type': 'testDone', 'testID': 1, 'result': 'error', 'hidden': False})
        self.assertEqual(ledger.snapshot()['counts']['error'], 1)
        self.assertFalse(ledger.loaded_files)
        self.assertEqual(ledger.executed_files, {'test/broken_test.dart'})

    def test_hidden_loading_pass_does_not_inflate_pass_count(self):
        ledger = runner.Ledger()
        ledger.event({'type': 'suite', 'suite': {'id': 0, 'path': 'G:/fixture/test/a_test.dart'}})
        ledger.event({'type': 'testStart', 'test': {'id': 1, 'suiteID': 0, 'name': 'loading a'}})
        ledger.event({'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': True})
        ledger.event({'type': 'testStart', 'test': {'id': 2, 'suiteID': 0, 'name': 'real case'}})
        ledger.event({'type': 'testDone', 'testID': 2, 'result': 'success', 'hidden': False})
        ledger.event({'type': 'done', 'success': True})
        self.assertEqual(ledger.snapshot()['counts']['success'], 1)
        self.assertEqual(ledger.loaded_files, {'test/a_test.dart'})
        self.assertTrue(ledger.done)

    def test_skip_and_unfinished_cases_remain_visible(self):
        ledger = runner.Ledger()
        for key in (1, 2):
            ledger.event({'type': 'testStart', 'test': {'id': key, 'name': str(key), 'root_url': 'file:///G:/fixture/test/space%20name_test.dart'}})
        ledger.event({'type': 'testDone', 'testID': 2, 'result': 'success', 'hidden': False, 'skipped': True})
        self.assertEqual(ledger.snapshot()['counts']['skip'], 1)
        self.assertEqual(ledger.snapshot()['in_progress'], ['1'])
        self.assertEqual(ledger.executed_files, {'test/space name_test.dart'})

    def test_skip_only_loaded_suite_is_not_accepted(self):
        state = dict(exit_code=0, protocol_success=True, tests_completed=1, in_progress=[],
                     files_not_loaded=[], files_without_test_outcome=[],
                     counts={'success': 0, 'failure': 0, 'error': 0, 'skip': 1},
                     error_events=0, stable_source=True, head_unchanged=True, branch_unchanged=True)
        self.assertFalse(runner.accepted(state))
        state['counts'] = {'success': 1, 'failure': 0, 'error': 0, 'skip': 0}
        self.assertTrue(runner.accepted(state))
        state['files_without_test_outcome'] = ['test/a_test.dart']
        self.assertFalse(runner.accepted(state))

    def test_changed_dart_in_failures_is_not_an_ignored_raster(self):
        self.assertFalse(runner.generated_comparison('test/failures/a_test.dart'))
        self.assertFalse(runner.generated_comparison('test/failures/user_photo.png'))
        self.assertTrue(runner.generated_comparison('test/failures/a_testImage.png'))
        self.assertFalse(runner.generated_comparison('lib/failures/a_testImage.png'))

    def test_real_git_status_preserves_first_modified_comparison_and_rejects_dart(self):
        # A real porcelain record begins with an index/worktree status pair.
        # Trimming its leading space corrupts the first path sliced at [3:].
        environment = os.environ.copy()
        for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE',
                    'GIT_COMMON_DIR', 'GIT_PREFIX'):
            environment.pop(key, None)
        with tempfile.TemporaryDirectory() as name, patch.dict(os.environ, environment, clear=True):
            fixture = Path(name)
            repository = fixture / 'repository'
            repository.mkdir()
            template = fixture / 'empty-template'
            template.mkdir()
            hooks = fixture / 'empty-hooks'
            hooks.mkdir()
            attributes = fixture / 'empty-attributes'
            attributes.write_text('', encoding='utf-8')

            def actual_git(*arguments):
                return subprocess.run(['git', *arguments], cwd=repository,
                                      check=True, capture_output=True, text=True).stdout

            actual_git('init', '--template=' + str(template),
                       '--initial-branch=' + runner.ALLOWED_BRANCH)
            actual_git('config', '--local', 'core.hooksPath', str(hooks))
            actual_git('config', '--local', 'core.attributesFile', str(attributes))
            actual_git('config', '--local', 'commit.gpgsign', 'false')
            actual_git('config', '--local', 'user.name', 'Runner Regression Fixture')
            actual_git('config', '--local', 'user.email', 'runner-fixture@example.invalid')
            comparison_name = 'test/features/commerce/failures/z_isolatedDiff.png'
            dart_name = 'test/features/commerce/failures/a_test.dart'
            comparison = repository / comparison_name
            comparison.parent.mkdir(parents=True)
            comparison.write_bytes(b'comparison before\n')
            dart = repository / dart_name
            dart.write_text('void main() {}\n', encoding='utf-8')
            actual_git('add', '--', comparison_name, dart_name)
            actual_git('commit', '--no-gpg-sign', '-m', 'synthetic preflight fixture')
            comparison.write_bytes(b'comparison after\n')

            with patch.object(runner, 'ROOT', repository):
                dirty = runner.git('status', '--porcelain=v1',
                                   '--untracked-files=all').splitlines()
                self.assertEqual(dirty, [' M ' + comparison_name])
                self.assertTrue(runner.generated_comparison(dirty[0][3:]))
                args = argparse.Namespace(expect_head=runner.git('rev-parse', 'HEAD'),
                                          flutter='never-invoked/flutter.bat')
                state = dict(phase='preflight', flutter_started=False)
                owned = []
                with patch.object(runner, 'resources',
                                  side_effect=RuntimeError('passed frozen Git preflight')) as machine:
                    with self.assertRaisesRegex(RuntimeError, '^passed frozen Git preflight$'):
                        runner.execute(args, repository / 'not-created', state, owned)
                    machine.assert_called_once_with()
                self.assertFalse(state['flutter_started'])
                self.assertEqual(owned, [])
                self.assertFalse((repository / 'not-created').exists())

                dart.write_text('void main() { throw StateError("changed"); }\n',
                                encoding='utf-8')
                dirty = runner.git('status', '--porcelain=v1',
                                   '--untracked-files=all').splitlines()
                self.assertEqual(dirty[0], ' M ' + dart_name)
                self.assertFalse(runner.generated_comparison(dirty[0][3:]))
                with patch.object(runner, 'resources') as machine:
                    with self.assertRaisesRegex(RuntimeError, 'working tree changed after freezing'):
                        runner.execute(args, repository / 'not-created', state, owned)
                    machine.assert_not_called()
                self.assertFalse(state['flutter_started'])
                self.assertEqual(owned, [])
                self.assertFalse((repository / 'not-created').exists())

    def test_second_process_cannot_hold_an_active_run_lock(self):
        with tempfile.TemporaryDirectory() as name:
            lock = Path(name) / 'active.lock'
            code = "import importlib.util; from pathlib import Path; s=importlib.util.spec_from_file_location('r',r'" + str(Path(runner.__file__)) + "');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);m.ExclusiveRun(Path(r'" + str(lock) + "')).__enter__()"
            with runner.ExclusiveRun(lock):
                second = subprocess.run([sys.executable, '-c', code], capture_output=True, text=True)
                self.assertNotEqual(second.returncode, 0)
                self.assertIn('Flutter was not started', second.stderr)
            with runner.ExclusiveRun(lock):
                pass

    def test_root_command_opts_into_public_smoke_without_filter_or_retry(self):
        command = runner.root_test_command('dart', 'flutter_tools.snapshot')
        self.assertEqual(command[:3], ['dart', 'flutter_tools.snapshot', 'test'])
        self.assertIn('--dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true', command)
        self.assertIn('--concurrency=2', command)
        self.assertNotIn('--name', command)
        self.assertNotIn('--plain-name', command)
        self.assertNotIn('--update-goldens', command)
        self.assertFalse(any(item.endswith('_test.dart') for item in command))

    def test_preflight_failure_has_no_flutter_process(self):
        with tempfile.TemporaryDirectory() as name, patch.object(runner, 'ROOT', Path(name)), patch.object(runner, 'git', return_value='wrong-sha'), patch.object(runner.subprocess, 'Popen') as launch, patch.object(sys, 'argv', ['runner', 'wrong-head', '--expect-head', 'frozen', '--flutter', 'fake/flutter.bat']):
            self.assertEqual(runner.main(), 79)
            launch.assert_not_called()
            state = json.loads((Path(name) / 'build/owner-full/wrong-head/status.json').read_text(encoding='utf-8'))
            self.assertEqual(state['phase'], 'failed_preflight')
            self.assertFalse(state['flutter_started'])

    def test_popen_failure_is_visible_and_never_running(self):
        with tempfile.TemporaryDirectory() as name:
            def git(*args):
                return 'frozen' if args == ('rev-parse', 'HEAD') else runner.ALLOWED_BRANCH if args == ('branch', '--show-current') else ''
            with patch.object(runner, 'ROOT', Path(name)), patch.object(runner, 'git', side_effect=git), patch.object(runner, 'inputs', return_value={}), patch.object(runner, 'resources', return_value={'ram_available_bytes': 8*1024**3, 'disk_free_bytes': 10*1024**3}), patch.object(runner.subprocess, 'check_output', return_value='{"frameworkVersion":"3.44.6"}'), patch.object(runner.subprocess, 'Popen', side_effect=OSError('synthetic spawn failure')) as launch, patch.object(sys, 'argv', ['runner', 'spawn-failed', '--expect-head', 'frozen', '--flutter', 'fake/flutter.bat']):
                self.assertEqual(runner.main(), 79)
                self.assertEqual(launch.call_count, 1)
                state = json.loads((Path(name) / 'build/owner-full/spawn-failed/status.json').read_text(encoding='utf-8'))
                self.assertEqual(state['phase'], 'failed_start')
                self.assertFalse(state['flutter_started'])


    def test_kill_and_wait_failure_keep_lock_until_real_child_exits(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            lock_path = folder / 'active.lock'
            runner_path = str(Path(runner.__file__))
            contender_code = (
                "import importlib.util; from pathlib import Path; "
                f"s=importlib.util.spec_from_file_location('r', {runner_path!r}); "
                "m=importlib.util.module_from_spec(s); s.loader.exec_module(m); "
                f"m.ExclusiveRun(Path({str(lock_path)!r})).__enter__(); "
                f"Path({str(folder / 'second-flutter-started')!r}).write_text('started')")
            run_real = subprocess.run
            child = subprocess.Popen([sys.executable, '-c',
                                      'import sys; sys.stdin.readline()'],
                                     stdin=subprocess.PIPE)
            state = dict(phase='failed_runner', flutter_started=True,
                         flutter_pid=child.pid, accepted=False)
            waiting_records = []

            def waiting(report):
                state.update(phase='failed_runner_waiting_for_exit',
                             owned_process_termination=dict(report))
                runner.write_failure_state(folder, state)
                saved = json.loads((folder / 'status.json').read_text(encoding='utf-8'))
                waiting_records.append(saved)
                contender = run_real([sys.executable, '-c', contender_code],
                                     capture_output=True, text=True, timeout=5)
                self.assertNotEqual(contender.returncode, 0)
                self.assertIn('Flutter was not started', contender.stderr)
                self.assertFalse((folder / 'second-flutter-started').exists())
                self.assertIsNone(child.poll())
                child.stdin.write(b'release\n')
                child.stdin.flush()

            try:
                with runner.ExclusiveRun(lock_path):
                    with patch.object(child, 'wait', side_effect=RuntimeError('synthetic wait failure')):
                        if runner.os.name == 'nt':
                            with patch.object(runner.subprocess, 'run', side_effect=OSError('synthetic taskkill failure')):
                                report = runner.terminate_owned_process(child, waiting)
                        else:
                            with patch.object(child, 'kill', side_effect=OSError('synthetic kill failure')):
                                report = runner.terminate_owned_process(child, waiting)
                    self.assertTrue(report['confirmed_exited'])
                    self.assertFalse(report['still_running'])
                    self.assertEqual(report['exit_code'], 0)
                    self.assertEqual(len(waiting_records), 1)
                    self.assertIn('kill_error', report)
                    self.assertIn('wait_error', report)
                self.assertEqual(child.poll(), 0)
                after_exit = run_real([sys.executable, '-c', contender_code],
                                      capture_output=True, text=True, timeout=5)
                self.assertEqual(after_exit.returncode, 0, after_exit.stderr)
                self.assertTrue((folder / 'second-flutter-started').exists())
            finally:
                child.stdin.close()
                if child.poll() is None:
                    child.kill()
                    child.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
