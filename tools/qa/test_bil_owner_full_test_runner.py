"""The ledger counts real Flutter events, including loading errors and skips."""
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time

spec = importlib.util.spec_from_file_location('owner_runner', Path(__file__).with_name('bil_owner_full_test_runner.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerPreflightTests(unittest.TestCase):
    def test_detached_head_requires_exact_authorized_remote_sha(self):
        with patch.object(runner, 'git', return_value='frozen') as git:
            evidence = runner.verified_branch('frozen', '')
        self.assertEqual(evidence, {
            'branch': '',
            'verified_remote_ref': f'origin/{runner.ALLOWED_BRANCH}',
        })
        git.assert_called_once_with('rev-parse', '--verify', f'origin/{runner.ALLOWED_BRANCH}')

    def test_detached_head_mismatch_is_rejected(self):
        with patch.object(runner, 'git', return_value='different'):
            with self.assertRaisesRegex(RuntimeError, 'exactly match'):
                runner.verified_branch('frozen', '')

    def test_unrelated_named_branch_is_rejected(self):
        with patch.object(runner, 'git') as git:
            with self.assertRaisesRegex(RuntimeError, 'authorized integration branch'):
                runner.verified_branch('frozen', 'codex/other-work')
        git.assert_not_called()

    def test_dashboard_snapshot_shows_current_counts_and_only_progress_lines(self):
        state = {'phase': 'running', 'tests_completed': 25,
                 'counts': {'success': 24, 'failure': 1, 'error': 0, 'skip': 0}}
        snapshot = runner.dashboard_snapshot(state, [
            '2026-10-19T00:00 START case one\n',
            '2026-10-19T00:01 PROGRESS completed=25 failed=1\n',
            '2026-10-19T00:02 SUCCESS hidden detail\n',
        ])
        self.assertTrue(snapshot['current'])
        self.assertEqual(snapshot['tests_completed'], 25)
        self.assertEqual(len(snapshot['lines']), 2)
        self.assertIn('PROGRESS completed=25', snapshot['lines'][-1])

    def test_dashboard_tail_keeps_latest_progress_without_reading_full_log(self):
        with tempfile.TemporaryDirectory() as name:
            log = Path(name) / 'progress.log'
            log.write_text(''.join(f'line-{n:04d}\n' for n in range(1000)),
                           encoding='utf-8')
            self.assertEqual(runner.tail_lines(log, limit=4, block_size=64), [
                'line-0996', 'line-0997', 'line-0998', 'line-0999',
            ])

    def test_live_publisher_updates_dashboard_and_source_summary(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            dashboard = root / 'dashboard'
            dashboard.mkdir()
            progress_path = root / 'progress.log'
            status_path = root / 'status.json'
            state = {'phase': 'running', 'head': 'frozen',
                     'verified_remote_ref': f'origin/{runner.ALLOWED_BRANCH}',
                     'source_fingerprint': 'source-hash', 'tests_completed': 25,
                     'counts': {'success': 25, 'failure': 0, 'error': 0, 'skip': 0}}
            with progress_path.open('w', encoding='utf-8') as progress:
                progress.write('2026-10-19 PROGRESS completed=25 failed=0\n')
                publisher = runner.LiveStatusPublisher(status_path, progress, dashboard)
                publisher.publish(state)
            visible = json.loads((dashboard / 'state').read_text(encoding='utf-8'))
            work = json.loads((dashboard / 'current-work').read_text(encoding='utf-8'))
            self.assertTrue(visible['current'])
            self.assertEqual(visible['tests_completed'], 25)
            self.assertEqual(work['fingerprint'], 'source-hash')
            self.assertEqual(work['steps'][0]['name'], 'owner full Flutter root suite')

    def test_dashboard_publication_error_after_suite_does_not_break_final_result(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            progress_path = root / 'progress.log'
            with progress_path.open('w', encoding='utf-8') as progress:
                progress.write('completed\n')
                publisher = runner.LiveStatusPublisher(
                    root / 'status.json', progress, root / 'missing-dashboard'
                )
            state = {'phase': 'completed', 'tests_completed': 1,
                     'counts': {'success': 1, 'failure': 0, 'error': 0, 'skip': 0}}
            with patch.object(runner, 'console_print') as output:
                self.assertTrue(publisher.publish(state))
            self.assertTrue((root / 'status.json').is_file())
            output.assert_called_once()


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

    def test_source_fingerprint_covers_workflows_native_builds_and_test_tools(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            included = (
                '.github/workflows/verify.yml',
                'integration_test/native_test.dart',
                'android/settings.gradle',
                'ios/Runner.xcodeproj/project.pbxproj',
                'macos/Runner/AppDelegate.swift',
                'tool/prebuild/check.py',
                'tools/qa/runner.py',
                'public_site/app.js',
                'docs/release/frozen-manifest.md',
                'test/visual_closure/goldens/page.png',
                'test/visual_closure/failures/page_testImage.png',
                'docs/qa_next/report.md',
            )
            for relative in included:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(relative.encode())

            with patch.object(runner, 'ROOT', root), patch.object(
                runner, 'git', return_value='\n'.join(included)
            ):
                values = runner.inputs()

            self.assertEqual(
                set(values),
                set(included) - {
                    'test/visual_closure/failures/page_testImage.png',
                    'docs/qa_next/report.md',
                },
            )

    def test_real_git_status_records_dirty_source_without_rejecting_it(self):
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
                self.assertEqual(state['working_tree_status_entries'], 1)
                self.assertEqual(
                    state['working_tree_status_fingerprint'],
                    hashlib.sha256('\n'.join(dirty).encode()).hexdigest())
                self.assertFalse(state['flutter_started'])
                self.assertEqual(owned, [])
                self.assertFalse((repository / 'not-created').exists())

                dart.write_text('void main() { throw StateError("changed"); }\n',
                                encoding='utf-8')
                dirty = runner.git('status', '--porcelain=v1',
                                   '--untracked-files=all').splitlines()
                self.assertEqual(dirty[0], ' M ' + dart_name)
                self.assertFalse(runner.generated_comparison(dirty[0][3:]))
                with patch.object(runner, 'resources',
                                  side_effect=RuntimeError('passed frozen Git preflight')) as machine:
                    with self.assertRaisesRegex(RuntimeError, '^passed frozen Git preflight$'):
                        runner.execute(args, repository / 'not-created', state, owned)
                    machine.assert_called_once_with()
                self.assertEqual(state['working_tree_status_entries'], 2)
                self.assertEqual(
                    state['working_tree_status_fingerprint'],
                    hashlib.sha256('\n'.join(dirty).encode()).hexdigest())
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
        self.assertIn('--reporter=json', command)
        self.assertIn('--ignore-timeouts', command)
        self.assertFalse(any(item.startswith('--timeout=') for item in command))
        self.assertNotIn('--name', command)
        self.assertNotIn('--plain-name', command)
        self.assertNotIn('--update-goldens', command)
        self.assertFalse(any(item.endswith('_test.dart') for item in command))
        self.assertFalse(any('BIL_TERMS_URL=https://billing-fixture.invalid' in item for item in command))
        self.assertFalse(any('BIL_PRIVACY_URL=https://billing-fixture.invalid' in item for item in command))

    def test_localized_progress_name_cannot_crash_windows_console_output(self):
        message = 'PROGRESS latest=SUCCESS CommunityTextPolicy напиши мне в Signal'
        rendered = runner.console_safe_text(message, 'cp1252')
        self.assertIn('PROGRESS latest=SUCCESS CommunityTextPolicy', rendered)
        self.assertIn(r'\u', rendered)
        rendered_utf8 = runner.console_safe_text(message, 'utf-8')
        self.assertEqual(rendered_utf8, message)

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


class _WindowsStatusLock:
    # This child owns only the provided temporary file. It deliberately grants
    # read/write sharing but denies delete/rename sharing until told to release.
    def __init__(self, path):
        self.path = path
        self.process = None
        self.release_sent = False

    def __enter__(self):
        if os.name != 'nt':
            raise RuntimeError('this regression requires a real Windows sharing lock')
        code = r'''import ctypes, sys, time
from ctypes import wintypes
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.CreateFileW.argtypes = (wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                              wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD,
                              wintypes.HANDLE)
kernel.CreateFileW.restype = wintypes.HANDLE
kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
kernel.CloseHandle.restype = wintypes.BOOL
handle = kernel.CreateFileW(sys.argv[1], 0x80000000, 3, None, 3, 0, None)
if handle == ctypes.c_void_p(-1).value:
    raise ctypes.WinError(ctypes.get_last_error())
print('locked', flush=True)
try:
    delay = sys.stdin.readline().strip()
    if delay:
        time.sleep(float(delay))
finally:
    if not kernel.CloseHandle(handle):
        raise ctypes.WinError(ctypes.get_last_error())
print('released', flush=True)
'''
        self.process = subprocess.Popen([sys.executable, '-c', code, str(self.path)],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, text=True)
        if self.process.stdout.readline().strip() != 'locked':
            _, error = self.process.communicate(timeout=3)
            raise RuntimeError('Windows fixture did not acquire its file: ' + error)
        return self

    def release_after(self, seconds=0):
        if self.release_sent:
            raise RuntimeError('the owned Windows holder was already released')
        self.release_sent = True
        self.process.stdin.write(str(seconds) + '\n')
        self.process.stdin.flush()

    def wait_released(self):
        code = self.process.wait(timeout=3)
        if code != 0:
            raise RuntimeError('Windows fixture release failed: ' + self.process.stderr.read())

    def __exit__(self, *_):
        try:
            if self.process.poll() is None and not self.release_sent:
                self.release_after()
            self.wait_released()
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait(timeout=3)
            self.process.stdin.close()
            self.process.stdout.close()
            self.process.stderr.close()


class StatusPublicationTests(unittest.TestCase):
    def test_atomic_json_uses_unique_closed_temporary_files(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            path = folder / 'status.json'
            sources = []
            replace = runner.os.replace

            def actual_replace(source, destination):
                source = Path(source)
                sources.append(source)
                self.assertEqual(destination, path)
                self.assertNotEqual(source, path.with_suffix('.tmp'))
                with source.open(encoding='utf-8') as stream:
                    self.assertIn(json.load(stream), ({'value': 1}, {'value': 2}))
                return replace(source, destination)

            with patch.object(runner.os, 'replace', side_effect=actual_replace):
                runner.atomic_json(path, {'value': 1})
                runner.atomic_json(path, {'value': 2})
            self.assertEqual(len(set(sources)), 2)
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')), {'value': 2})
            self.assertFalse(any(folder.glob('*.tmp')))

    @unittest.skipUnless(os.name == 'nt', 'Requires real Windows file-sharing semantics; covered by the Windows owner suite')
    def test_real_windows_replace_lock_releases_within_retry_budget(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            path = folder / 'status.json'
            old, new = {'sequence': 1}, {'sequence': 2, 'complete': True}
            runner.atomic_json(path, old)
            replace = runner.os.replace
            failures = []
            with _WindowsStatusLock(path) as holder:
                def actual_replace(source, destination):
                    try:
                        return replace(source, destination)
                    except OSError as error:
                        failures.append(error.winerror)
                        self.assertIn(error.winerror, (5, 32, 33))
                        self.assertEqual(json.loads(path.read_text(encoding='utf-8')), old)
                        if len(failures) == 1:
                            holder.release_after(0.03)
                        raise

                started = time.monotonic()
                with patch.object(runner.os, 'replace', side_effect=actual_replace):
                    runner.atomic_json(path, new)
                self.assertLess(time.monotonic() - started, 1)
                holder.wait_released()
            self.assertTrue(failures)
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')), new)
            self.assertFalse(any(folder.glob('*.tmp')))

    @unittest.skipUnless(os.name == 'nt', 'Requires real Windows file-sharing semantics; covered by the Windows owner suite')
    def test_real_windows_replace_lock_outlasts_bounded_retry_then_recovers(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            path = folder / 'status.json'
            old, new = {'sequence': 1}, {'sequence': 2}
            runner.atomic_json(path, old)
            with _WindowsStatusLock(path) as holder:
                started = time.monotonic()
                with self.assertRaises(OSError) as failure:
                    runner.atomic_json(path, new, retry_timeout=0.06)
                self.assertIn(failure.exception.winerror, (5, 32, 33))
                self.assertLess(time.monotonic() - started, 1)
                self.assertEqual(json.loads(path.read_text(encoding='utf-8')), old)
                self.assertFalse(any(folder.glob('*.tmp')))
                holder.release_after()
                holder.wait_released()
            runner.atomic_json(path, new)
            self.assertEqual(json.loads(path.read_text(encoding='utf-8')), new)

    @unittest.skipUnless(os.name == 'nt', 'Requires real Windows file-sharing semantics; covered by the Windows owner suite')
    def test_live_progress_keeps_ledger_and_os_lock_after_real_windows_status_contention(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            path = folder / 'status.json'
            old = {'phase': 'starting', 'accepted': False}
            runner.atomic_json(path, old)
            lock_path = folder / 'active.lock'
            runner_path = str(Path(runner.__file__))
            contender_code = (
                'import importlib.util; from pathlib import Path; '
                f's=importlib.util.spec_from_file_location("r", {runner_path!r}); '
                'm=importlib.util.module_from_spec(s); s.loader.exec_module(m); '
                f'm.ExclusiveRun(Path({str(lock_path)!r})).__enter__()')
            ledger = runner.Ledger()
            state = dict(phase='running', accepted=False, automatic_retry=False,
                         flutter_pid=123, **ledger.snapshot())
            stderr = io.StringIO()
            with (folder / 'progress.log').open('a', encoding='utf-8') as progress:
                publisher = runner.LiveStatusPublisher(path, progress)
                with runner.ExclusiveRun(lock_path), _WindowsStatusLock(path) as holder:
                    with patch.object(sys, 'stderr', stderr):
                        self.assertFalse(publisher.publish(state))
                    self.assertTrue(state['status_publication']['degraded'])
                    self.assertEqual(state['status_publication']['failures'], 1)
                    self.assertEqual(json.loads(path.read_text(encoding='utf-8')), old)
                    for key in (1, 2):
                        ledger.event({'type': 'testStart', 'test': {'id': key, 'name': str(key)}})
                        ledger.event({'type': 'testDone', 'testID': key, 'result': 'success',
                                      'hidden': False})
                    state.update(ledger.snapshot())
                    contender = subprocess.run([sys.executable, '-c', contender_code],
                                               capture_output=True, text=True, timeout=5)
                    self.assertNotEqual(contender.returncode, 0)
                    self.assertIn('Flutter was not started', contender.stderr)
                    holder.release_after()
                    holder.wait_released()
                    self.assertTrue(publisher.publish(state))
                    self.assertFalse(state['status_publication']['degraded'])
                    self.assertEqual(state['status_publication']['failures'], 1)
            published = json.loads(path.read_text(encoding='utf-8'))
            self.assertEqual(published['counts']['success'], 2)
            self.assertFalse(published['automatic_retry'])
            self.assertIn('status_publication_degraded', stderr.getvalue())
            self.assertIn('status_publication_degraded',
                          (folder / 'progress.log').read_text(encoding='utf-8'))

    @unittest.skipUnless(os.name == 'nt', 'Requires real Windows file-sharing semantics; covered by the Windows owner suite')
    def test_final_status_remains_strict_with_real_windows_lock_and_preserves_results(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            path = folder / 'status.json'
            old = {'phase': 'running', 'accepted': False}
            runner.atomic_json(path, old)
            ledger = runner.Ledger()
            events = [{'type': 'testStart', 'test': {'id': 1, 'name': 'unit fixture'}},
                      {'type': 'testDone', 'testID': 1, 'result': 'success', 'hidden': False},
                      {'type': 'done', 'success': True}]
            for event in events:
                ledger.event(event)
            state = dict(phase='completed', exit_code=0, automatic_retry=False,
                         files_not_loaded=[], files_without_test_outcome=[],
                         stable_source=True, head_unchanged=True, branch_unchanged=True,
                         **ledger.snapshot())
            state['accepted'] = runner.accepted(state)
            self.assertTrue(state['accepted'])
            outcomes = [{'id': 1, 'result': 'success'}]
            runner.atomic_json(folder / 'errors.json', [])
            runner.atomic_json(folder / 'test-outcomes.json', outcomes)
            raw = ''.join(json.dumps(event) + '\n' for event in events)
            (folder / 'flutter.jsonl').write_text(raw, encoding='utf-8')
            with _WindowsStatusLock(path):
                with self.assertRaises(OSError) as failure:
                    runner.write_final_result(folder, state)
                self.assertIn(failure.exception.winerror, (5, 32, 33))
                self.assertEqual(json.loads(path.read_text(encoding='utf-8')), old)
                final = json.loads((folder / 'final-result.json').read_text(encoding='utf-8'))
                self.assertEqual(final['phase'], 'failed_runner')
                self.assertFalse(final['accepted'])
                self.assertFalse(final['automatic_retry'])
                self.assertEqual(final['counts']['success'], 1)
                self.assertTrue(final['protocol_success'])
            self.assertEqual(json.loads((folder / 'test-outcomes.json').read_text(encoding='utf-8')),
                             outcomes)
            self.assertEqual((folder / 'flutter.jsonl').read_text(encoding='utf-8'), raw)

    def test_live_progress_does_not_swallow_an_unknown_os_error(self):
        state = {'phase': 'running', 'accepted': False}
        publisher = runner.LiveStatusPublisher(Path('not-opened.json'), io.StringIO())
        with patch.object(runner, 'atomic_json', side_effect=OSError(5, 'synthetic I/O failure')):
            with self.assertRaisesRegex(OSError, 'synthetic I/O failure'):
                publisher.publish(state)
        self.assertFalse(publisher.degraded)
        self.assertEqual(publisher.failures, 0)
        self.assertNotIn('status_publication', state)


if __name__ == '__main__':
    unittest.main()
