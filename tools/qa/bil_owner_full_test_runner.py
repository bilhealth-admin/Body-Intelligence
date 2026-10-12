"""One owner-observed root Flutter run; no shards, retries, builds or deployment."""
from __future__ import annotations

import argparse
from collections import Counter
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import subprocess
import time
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[2]
ALLOWED_BRANCH = 'integration/bil-qa-media-policy-20261011'


def utc():
    return datetime.now(timezone.utc).isoformat()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).rstrip('\r\n')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generated_comparison(name):
    return name.startswith('test/') and '/failures/' in name and name.endswith((
        '_masterImage.png', '_testImage.png', '_isolatedDiff.png', '_maskedDiff.png'))


class ExclusiveRun:
    """The OS lock is authoritative; a stale metadata file never blocks a run."""
    def __init__(self, path):
        self.path = path
        self.file = None

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.file = self.path.open('a+b')
        if self.path.stat().st_size == 0:
            self.file.write(b'0')
            self.file.flush()
        self.file.seek(0)
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(self.file.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(self.file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.file.close()
            raise RuntimeError('another full run holds the worktree lock; Flutter was not started')
        return self

    def __exit__(self, *_):
        self.file.seek(0)
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(self.file.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            fcntl.flock(self.file.fileno(), fcntl.LOCK_UN)
        self.file.close()


def accepted(state):
    return (state['exit_code'] == 0 and state['protocol_success'] is True
            and state['tests_completed'] > 0 and not state['in_progress']
            and not state['files_not_loaded'] and not state['files_without_test_outcome']
            and all(value == 0 for key, value in state['counts'].items() if key != 'success')
            and state['error_events'] == 0 and state['stable_source']
            and state['head_unchanged'] and state['branch_unchanged'])


def inputs():
    files = git('ls-files', '-co', '--exclude-standard').splitlines()
    selected = {}
    for name in sorted(set(files)):
        generated = generated_comparison(name)
        prefixes = ('lib/', 'test/', 'assets/', 'shaders/', 'android/app/',
                    'ios/Runner/', 'ios/Runner.xcodeproj/', 'supabase/',
                    'tools/qa/', 'tool/release/')
        path = ROOT / name
        if not generated and path.is_file() and (name.startswith(prefixes) or
                name in ('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml')):
            selected[name] = digest(path)
    return selected


def fingerprint(values):
    return hashlib.sha256('\n'.join(f'{name}:{sha}' for name, sha in sorted(values.items())).encode()).hexdigest()


def atomic_json(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
    os.replace(tmp, path)


class Ledger:
    def __init__(self):
        self.tests = {}
        self.suites = {}
        self.completed = set()
        self.outcomes = {}
        self.errors = []
        self.loaded_files = set()
        self.executed_files = set()
        self.done = None
        self.harness_pid = None

    def file_for(self, test):
        value = test.get('root_url') or self.suites.get(test.get('suiteID')) or test.get('url') or ''
        value = unquote(value).replace('file:///', '').replace('\\', '/')
        marker = '/test/'
        return 'test/' + value.split(marker, 1)[1] if marker in value else None

    def event(self, event):
        kind = event.get('type')
        if kind == 'start':
            self.harness_pid = event.get('pid')
        elif kind == 'suite':
            self.suites[event['suite']['id']] = event['suite']['path']
        elif kind == 'testStart':
            self.tests[event['test']['id']] = event['test']
        elif kind == 'error':
            self.errors.append(event)
        elif kind == 'testDone':
            key = event['testID']
            self.completed.add(key)
            test = self.tests.get(key, {})
            file = self.file_for(test)
            if file and test.get('name', '').startswith('loading ') and event['result'] == 'success':
                self.loaded_files.add(file)
            if not event.get('hidden'):
                self.outcomes[key] = 'skip' if event.get('skipped') else event['result']
                if file:
                    self.executed_files.add(file)
        elif kind == 'done':
            self.done = event.get('success')

    def snapshot(self):
        counts = Counter(self.outcomes.values())
        return {
            'counts': {key: counts[key] for key in ('success', 'failure', 'error', 'skip')},
            'tests_completed': len(self.outcomes),
            'files_loaded': len(self.loaded_files),
            'files_with_test_outcomes': len(self.executed_files),
            'harness_pid': self.harness_pid,
            'protocol_success': self.done,
            'in_progress': [test.get('name') for key, test in self.tests.items() if key not in self.completed],
            'error_events': len(self.errors),
        }


def resources():
    available = None
    total = None
    if os.name == 'nt':
        class Memory(ctypes.Structure):
            _fields_ = [('length', ctypes.c_ulong), ('load', ctypes.c_ulong),
                        *[(name, ctypes.c_ulonglong) for name in
                          ('total', 'available', 'total_page', 'available_page',
                           'total_virtual', 'available_virtual', 'extended')]]
        memory = Memory()
        memory.length = ctypes.sizeof(Memory)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(memory)):
            total, available = memory.total, memory.available
    return {'cpu_threads': os.cpu_count(), 'ram_total_bytes': total,
            'ram_available_bytes': available,
            'disk_free_bytes': shutil.disk_usage(ROOT).free}


def write_failure_state(folder, state):
    # A failure in termination must not leave the last owner-readable state
    # claiming the test is still running normally.
    try:
        atomic_json(folder / 'status.json', state)
    except OSError:
        print(json.dumps(state, ensure_ascii=True), file=sys.stderr, flush=True)


def native_wait_for_owned_exit(process):
    """Block on the real owned process, bypassing a failed Popen.wait wrapper."""
    if os.name == 'nt':
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
        kernel.WaitForSingleObject.restype = wintypes.DWORD
        kernel.GetExitCodeProcess.argtypes = (wintypes.HANDLE,
                                             ctypes.POINTER(wintypes.DWORD))
        kernel.GetExitCodeProcess.restype = wintypes.BOOL
        handle = wintypes.HANDLE(int(process._handle))
        result = kernel.WaitForSingleObject(handle, 0xFFFFFFFF)
        if result != 0:
            raise OSError(ctypes.get_last_error(), 'owned process wait was not confirmed')
        code = wintypes.DWORD()
        if not kernel.GetExitCodeProcess(handle, ctypes.byref(code)):
            raise OSError(ctypes.get_last_error(), 'owned process exit code unavailable')
        process.returncode = int(code.value)
    else:
        pid, status = os.waitpid(process.pid, 0)
        if pid != process.pid:
            raise RuntimeError('another process was returned by the owned PID wait')
        process.returncode = os.waitstatus_to_exitcode(status)
    return process.returncode


def terminate_owned_process(process, on_waiting):
    """Never release the run lock while a child has an unconfirmed exit."""
    report = {}
    if process.poll() is not None:
        return {'already_exited': process.returncode, 'confirmed_exited': True}
    try:
        if os.name == 'nt':
            killed = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                                    capture_output=True, check=False)
            report.update(method='owned PID tree taskkill', returncode=killed.returncode)
        else:
            process.kill()
            report.update(method='owned process kill')
    except BaseException as error:
        report['kill_error'] = f'{type(error).__name__}: {error}'
    try:
        report['exit_code'] = process.wait(timeout=20)
        report['confirmed_exited'] = True
        return report
    except BaseException as error:
        report['wait_error'] = f'{type(error).__name__}: {error}'
    report.update(still_running=True, confirmed_exited=False)
    on_waiting(report)
    try:
        # This is a blocking OS wait, not a polling loop or a test retry.
        report['exit_code'] = native_wait_for_owned_exit(process)
    except BaseException as error:
        report['native_wait_error'] = f'{type(error).__name__}: {error}'
        on_waiting(report)
        # If even the OS cannot confirm ownership/exit, fail closed. Keep the
        # exclusive lock and the failure evidence for an explicit owner stop;
        # never start another test or spin while the child may still be alive.
        from threading import Event
        Event().wait()
        raise RuntimeError('owned process exit requires owner intervention')
    report.update(still_running=False, confirmed_exited=True,
                  confirmation='blocking OS wait for owned process')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('label')
    parser.add_argument('--expect-head', required=True)
    parser.add_argument('--flutter', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{1,90}', args.label):
        parser.error('plain unique run label required')
    folder = ROOT / 'build/owner-full' / args.label
    folder.mkdir(parents=True, exist_ok=False)
    state = {'phase': 'preflight', 'label': args.label, 'expected_head': args.expect_head,
             'started_utc': utc(), 'runner_pid': os.getpid(), 'flutter_started': False,
             'accepted': False, 'automatic_retry': False}
    atomic_json(folder / 'status.json', state)
    owned = []
    lock = ExclusiveRun(ROOT / 'build/owner-full/active-run.lock')
    lock_acquired = False
    try:
        lock.__enter__()
        lock_acquired = True
        atomic_json(ROOT / 'build/owner-full/active-run-owner.json', state)
        return execute(args, folder, state, owned)
    except BaseException as error:
        phase = state['phase']
        state.update(phase='failed_preflight' if phase == 'preflight' else 'failed_start' if not state['flutter_started'] else 'failed_runner',
                     accepted=False, runner_error=f'{type(error).__name__}: {error}')
        write_failure_state(folder, state)
        termination = None
        if owned:
            def waiting(report):
                state.update(phase='failed_runner_waiting_for_exit',
                             owned_process_termination=dict(report))
                write_failure_state(folder, state)
            termination = terminate_owned_process(owned[0], waiting)
        state.update(phase='failed_preflight' if phase == 'preflight' else 'failed_start' if not state['flutter_started'] else 'failed_runner',
                     finished_utc=utc(), owned_process_termination=termination)
        write_failure_state(folder, state)
        print(json.dumps({'phase': state['phase'], 'flutter_started': state['flutter_started'], 'error': state['runner_error']}, ensure_ascii=True), file=sys.stderr)
        return 79
    finally:
        # Keep the system lock held until any owned child has been terminated.
        if lock_acquired:
            lock.__exit__(None, None, None)

def root_test_command(dart, snapshot):
    # Explicit owner-authorized full scope includes the existing public CDN
    # HEAD/range smoke. It reads32bytes, never authenticates or mutates a service.
    return [str(dart), str(snapshot), 'test', '--no-pub', '--concurrency=2',
            '--timeout=3m', '--reporter=json',
            '--dart-define=BIL_PAYMENTS_ENABLED=true',
            '--dart-define=BIL_TERMS_URL=https://billing-fixture.invalid/terms',
            '--dart-define=BIL_PRIVACY_URL=https://billing-fixture.invalid/privacy',
            '--dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true']


def execute(args, folder, state, owned):
    head, branch = git('rev-parse', 'HEAD'), git('branch', '--show-current')
    if head != args.expect_head or branch != ALLOWED_BRANCH:
        raise RuntimeError('the frozen SHA and authorized integration branch must match')
    # Generated failure comparisons may be preserved untracked. Every real
    # application/test/asset input must still match the frozen commit.
    dirty = git('status', '--porcelain=v1', '--untracked-files=all').splitlines()
    unexpected = [line for line in dirty if not generated_comparison(line[3:].strip('\"'))]
    if unexpected:
        raise RuntimeError('working tree changed after freezing; do not run a different source')
    machine = resources()
    if machine['ram_available_bytes'] is not None and machine['ram_available_bytes'] < 4 * 1024**3:
        raise RuntimeError('less than4GiB free RAM; do not start an unstable two-worker run')
    if machine['disk_free_bytes'] < 5 * 1024**3:
        raise RuntimeError('less than5GiB free disk')
    flutter_bin = Path(args.flutter).resolve().parent
    dart = flutter_bin / 'cache/dart-sdk/bin/dart.exe'
    snapshot = flutter_bin / 'cache/flutter_tools.snapshot'
    version = json.loads(subprocess.check_output([str(dart), str(snapshot), '--version', '--machine'], cwd=ROOT, text=True))
    if version.get('frameworkVersion') != '3.44.6':
        raise RuntimeError('Flutter3.44.6 required')
    frozen_inputs = inputs()
    atomic_json(folder / 'source-inputs.json', frozen_inputs)
    expected_files = sorted(str(p.relative_to(ROOT)).replace('\\', '/') for p in (ROOT / 'test').rglob('*_test.dart'))
    atomic_json(folder / 'expected-files.json', expected_files)
    command = root_test_command(dart, snapshot)
    state.update({'phase': 'starting', 'label': args.label, 'head': head, 'branch': branch,
             'started_utc': utc(), 'runner_pid': os.getpid(), 'command': command,
             'flutter': version, 'resources': machine, 'expected_test_files': len(expected_files),
             'source_fingerprint': fingerprint(frozen_inputs), 'fingerprint_version': 4,
             'assertions_disabled': False, 'shards': None, 'automatic_retry': False,
             'accepted': False, 'log': str(folder / 'flutter.jsonl'),
             'progress_log': str(folder / 'progress.log')})
    atomic_json(folder / 'status.json', state)
    ledger, started = Ledger(), time.monotonic()
    with (folder / 'flutter.jsonl').open('w', encoding='utf-8', buffering=1) as raw, (folder / 'progress.log').open('w', encoding='utf-8', buffering=1) as progress:
        progress.write(f'{utc()} START SHA={head} root test concurrency=2; no shards or automatic retries\n')
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8', errors='replace', bufsize=1)
        owned.append(process)
        state.update(phase='running', flutter_pid=process.pid, flutter_started=True)
        atomic_json(folder / 'status.json', state)
        last_written = 0.0
        for line in process.stdout:
            raw.write(line)
            try:
                event = json.loads(line)
            except ValueError:
                progress.write(line)
                continue
            ledger.event(event)
            if event.get('type') == 'testStart':
                progress.write(f'{utc()} START {event["test"]["name"]}\n')
            elif event.get('type') == 'testDone' and not event.get('hidden'):
                name = ledger.tests.get(event['testID'], {}).get('name', '?')
                result = 'SKIP' if event.get('skipped') else event['result'].upper()
                progress.write(f'{utc()} {result} {name}\n')
            elif event.get('type') == 'error':
                progress.write(f'{utc()} ERROR {event.get("error", "")}\n')
            now = time.monotonic()
            if now - last_written >= 1 or event.get('type') in ('error', 'done'):
                state.update(ledger.snapshot(), elapsed_seconds=round(now-started, 1), last_event_utc=utc())
                atomic_json(folder / 'status.json', state)
                last_written = now
        exit_code = process.wait()
        progress.write(f'{utc()} PROCESS_EXIT {exit_code}\n')
    end_inputs = inputs()
    state.update(ledger.snapshot(), phase='completed', finished_utc=utc(),
                 exit_code=exit_code, elapsed_seconds=round(time.monotonic()-started, 2),
                 end_fingerprint=fingerprint(end_inputs), stable_source=frozen_inputs == end_inputs)
    state['files_not_loaded'] = sorted(set(expected_files) - ledger.loaded_files)
    state['files_without_test_outcome'] = sorted(set(expected_files) - ledger.executed_files)
    state.update(end_head=git('rev-parse', 'HEAD'), end_branch=git('branch', '--show-current'))
    state['head_unchanged'] = state['head'] == state['end_head']
    state['branch_unchanged'] = state['branch'] == state['end_branch']
    state['accepted'] = accepted(state)
    atomic_json(folder / 'errors.json', ledger.errors)
    atomic_json(folder / 'test-outcomes.json', [{'id': key, 'name': ledger.tests.get(key, {}).get('name'), 'file': ledger.file_for(ledger.tests.get(key, {})), 'result': result} for key, result in ledger.outcomes.items()])
    atomic_json(folder / 'status.json', state)
    print(json.dumps({key: state[key] for key in ('head', 'exit_code', 'counts', 'accepted', 'stable_source')}, ensure_ascii=True), flush=True)
    return 0 if state['accepted'] else (exit_code or 79)



if __name__ == '__main__':
    raise SystemExit(main())
