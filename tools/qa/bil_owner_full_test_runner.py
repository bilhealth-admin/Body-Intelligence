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
import tempfile
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
        prefixes = ('.github/', 'lib/', 'test/', 'integration_test/', 'assets/',
                    'shaders/', 'android/', 'ios/', 'macos/', 'windows/',
                    'linux/', 'web/', 'supabase/', 'tool/', 'tools/',
                    'public_site/', 'docs/release/')
        path = ROOT / name
        if not generated and path.is_file() and (name.startswith(prefixes) or
                name in ('pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml',
                         'l10n.yaml', 'package.json', 'package-lock.json',
                         'deno.json', 'deno.lock', 'wrangler.site.jsonc')):
            selected[name] = digest(path)
    return selected


def fingerprint(values):
    return hashlib.sha256('\n'.join(f'{name}:{sha}' for name, sha in sorted(values.items())).encode()).hexdigest()


def verified_branch(head, branch):
    """Allow this runner's isolated detached worktree only at the exact remote SHA."""
    if branch == ALLOWED_BRANCH:
        return {'branch': branch, 'verified_remote_ref': None}
    if branch:
        raise RuntimeError('the frozen SHA and authorized integration branch must match')
    remote_ref = f'origin/{ALLOWED_BRANCH}'
    try:
        remote_head = git('rev-parse', '--verify', remote_ref)
    except subprocess.CalledProcessError as error:
        raise RuntimeError('detached HEAD requires the authorized origin ref to be available') from error
    if remote_head != head:
        raise RuntimeError('detached HEAD must exactly match the authorized origin integration ref')
    return {'branch': branch, 'verified_remote_ref': remote_ref}


def tail_lines(path, limit=100, block_size=8192):
    """Read only the newest progress lines for the live page."""
    with Path(path).open('rb') as stream:
        stream.seek(0, os.SEEK_END)
        position = stream.tell()
        content = bytearray()
        while position > 0 and content.count(b'\n') <= limit:
            size = min(block_size, position)
            position -= size
            stream.seek(position)
            content[:0] = stream.read(size)
    return content.decode('utf-8', errors='replace').splitlines()[-limit:]


def dashboard_snapshot(state, lines):
    """Shape the owned runner ledger for the local, read-only dashboard."""
    visible_lines = [line.rstrip('\r\n') for line in lines[-100:]
                     if 'PROGRESS ' in line or ' ERROR ' in line or ' START ' in line
                     or 'PROCESS_EXIT ' in line]
    return {**state, 'current': True, 'lines': visible_lines}


def publish_dashboard(directory, state, progress_lines=()):
    if directory is None:
        return
    snapshot = dashboard_snapshot(state, list(progress_lines))
    atomic_json(directory / 'state', snapshot)
    source_fingerprint = state.get('source_fingerprint') or state.get('expected_head') or ''
    step = {'name': 'owner full Flutter root suite',
            'exit_code': state.get('exit_code'),
            'stable_source': state.get('stable_source')}
    atomic_json(directory / 'current-work', {
        'phase': state.get('phase', 'preflight'),
        'fingerprint': source_fingerprint,
        'steps': [step],
    })


def console_safe_text(message, encoding):
    """Keep localized test names from terminating progress output on Windows."""
    try:
        message.encode(encoding)
        return message
    except UnicodeEncodeError:
        return message.encode(encoding, errors='backslashreplace').decode(encoding)


def console_print(message, *, stream=None):
    stream = stream or sys.stdout
    encoding = getattr(stream, 'encoding', None) or 'utf-8'
    print(console_safe_text(message, encoding), file=stream, flush=True)


def retryable_windows_publication_error(error):
    return os.name == 'nt' and getattr(error, 'winerror', None) in (5, 32, 33)


def atomic_json(path, value, retry_timeout=0.25):
    # The retry budget is for replacement contention, not a new test run.
    # Close the unique temporary file before Windows tries to replace it.
    deadline = time.monotonic() + retry_timeout
    descriptor, name = tempfile.mkstemp(prefix=f'.{path.name}.', suffix='.tmp',
                                        dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
            stream.write(json.dumps(value, ensure_ascii=False, indent=2))
        delay = 0.01
        while True:
            try:
                os.replace(temporary, path)
                return
            except OSError as error:
                remaining = deadline - time.monotonic()
                if not retryable_windows_publication_error(error) or remaining <= 0:
                    raise
                time.sleep(min(delay, remaining))
                delay = min(delay * 2, 0.05)
    finally:
        temporary.unlink(missing_ok=True)


class LiveStatusPublisher:
    """Presentation failures must not interrupt the owned test event stream."""
    def __init__(self, path, progress, dashboard_dir=None):
        self.path = path
        self.progress = progress
        self.dashboard_dir = dashboard_dir
        self.failures = 0
        self.degraded = False
        self.last_success = None
        self.last_error = None

    def metadata(self, *, degraded, last_success):
        return {'degraded': degraded, 'failures': self.failures,
                'last_success_utc': last_success, 'last_error': self.last_error}

    def publish(self, state):
        candidate = dict(state)
        published_at = utc()
        candidate['status_publication'] = self.metadata(
            degraded=False, last_success=published_at)
        try:
            atomic_json(self.path, candidate)
        except OSError as error:
            if not retryable_windows_publication_error(error):
                raise
            self.failures += 1
            self.degraded = True
            self.last_error = f'{type(error).__name__}: {error}'
            state['status_publication'] = self.metadata(
                degraded=True, last_success=self.last_success)
            diagnostic = {'event': 'status_publication_degraded', 'utc': utc(),
                          'runner_pid': os.getpid(),
                          'flutter_pid': state.get('flutter_pid'),
                          'winerror': error.winerror,
                          **state['status_publication']}
            message = json.dumps(diagnostic, ensure_ascii=True)
            # Failures of either real log still propagate; this only tolerates
            # the recognized replacement/presentation failure above.
            self.progress.write(message + '\n')
            self.progress.flush()
            console_print(message, stream=sys.stderr)
            return False
        self.degraded = False
        self.last_success = published_at
        state['status_publication'] = candidate['status_publication']
        if self.dashboard_dir is not None:
            try:
                publish_dashboard(
                    self.dashboard_dir, candidate,
                    tail_lines(self.progress.name),
                )
            except OSError as error:
                diagnostic = json.dumps({
                    'event': 'dashboard_publication_degraded', 'utc': utc(),
                    'runner_pid': os.getpid(), 'error': f'{type(error).__name__}: {error}',
                }, ensure_ascii=True)
                if not self.progress.closed:
                    self.progress.write(diagnostic + '\n')
                    self.progress.flush()
                console_print(diagnostic, stream=sys.stderr)
        return True


def write_final_result(folder, state):
    # The child has already exited and its outcomes have been saved. Keep a
    # separately named final artifact even if a status viewer blocks replace.
    candidate = dict(state)
    publication = state.get('status_publication')
    if publication is not None:
        candidate['status_publication'] = dict(
            publication, degraded=False, last_success_utc=utc())
    try:
        atomic_json(folder / 'status.json', candidate)
    except OSError as error:
        state.update(phase='failed_runner', accepted=False,
                     final_status_error=f'{type(error).__name__}: {error}')
        if publication is not None:
            state['status_publication'] = dict(
                publication, degraded=True,
                failures=publication['failures'] + 1,
                last_error=state['final_status_error'])
        atomic_json(folder / 'final-result.json', state)
        raise
    state.update(candidate)
    atomic_json(folder / 'final-result.json', state)


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
    parser.add_argument('--dashboard-dir', type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{1,90}', args.label):
        parser.error('plain unique run label required')
    folder = ROOT / 'build/owner-full' / args.label
    folder.mkdir(parents=True, exist_ok=False)
    dashboard_dir = args.dashboard_dir
    if dashboard_dir is not None:
        if not dashboard_dir.is_absolute():
            dashboard_dir = ROOT / dashboard_dir
        dashboard_dir.mkdir(parents=True, exist_ok=False)
        args.dashboard_dir = dashboard_dir
        shutil.copyfile(ROOT / 'tools/qa/owner_full_dashboard.html',
                        dashboard_dir / 'index.html')
    state = {'phase': 'preflight', 'label': args.label, 'expected_head': args.expect_head,
             'started_utc': utc(), 'runner_pid': os.getpid(), 'flutter_started': False,
             'accepted': False, 'automatic_retry': False}
    atomic_json(folder / 'status.json', state)
    if dashboard_dir is not None:
        atomic_json(dashboard_dir / 'github-state', {
            'snapshot_utc': utc(), 'runs': [],
        })
        publish_dashboard(dashboard_dir, state)
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
        if dashboard_dir is not None:
            publish_dashboard(dashboard_dir, state)
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
            '--ignore-timeouts', '--reporter=json',
            '--dart-define=BIL_PAYMENTS_ENABLED=true',
            '--dart-define=BIL_LIVE_WORKOUT_STREAM_CHECK=true']


def execute(args, folder, state, owned):
    head, branch = git('rev-parse', 'HEAD'), git('branch', '--show-current')
    if head != args.expect_head:
        raise RuntimeError('the frozen SHA and authorized integration branch must match')
    branch_evidence = verified_branch(head, branch)
    # Freeze the exact local working source, including intentional edits that
    # have not been committed yet. The input manifest below, not a clean-tree
    # requirement, defines what this run tested.
    dirty = git('status', '--porcelain=v1', '--untracked-files=all').splitlines()
    state.update(working_tree_status_entries=len(dirty),
                 working_tree_status_fingerprint=hashlib.sha256(
                     '\n'.join(dirty).encode()).hexdigest())
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
             **branch_evidence,
             'started_utc': utc(), 'runner_pid': os.getpid(), 'command': command,
             'flutter': version, 'resources': machine, 'expected_test_files': len(expected_files),
             'source_fingerprint': fingerprint(frozen_inputs), 'fingerprint_version': 4,
             'assertions_disabled': False, 'shards': None, 'automatic_retry': False,
             'accepted': False, 'log': str(folder / 'flutter.jsonl'),
             'progress_log': str(folder / 'progress.log')})
    atomic_json(folder / 'status.json', state)
    ledger, started = Ledger(), time.monotonic()
    with (folder / 'flutter.jsonl').open('w', encoding='utf-8', buffering=1) as raw, (folder / 'progress.log').open('w', encoding='utf-8', buffering=1) as progress:
        start_message = f'{utc()} START SHA={head} root test concurrency=2; no shards or automatic retries'
        progress.write(start_message + '\n')
        console_print(start_message)
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8', errors='replace', bufsize=1)
        owned.append(process)
        state.update(phase='running', flutter_pid=process.pid, flutter_started=True)
        publisher = LiveStatusPublisher(folder / 'status.json', progress, args.dashboard_dir)
        publisher.publish(state)
        last_written = time.monotonic()
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
                completed = len(ledger.outcomes)
                if completed % 25 == 0 or result != 'SUCCESS':
                    counts = ledger.snapshot()['counts']
                    visible = (f'{utc()} PROGRESS completed={completed} '
                               f'passed={counts["success"]} failed={counts["failure"]} '
                               f'errors={counts["error"]} skipped={counts["skip"]} '
                               f'latest={result} {name}')
                    progress.write(visible + '\n')
                    console_print(visible)
            elif event.get('type') == 'error':
                error_message = f'{utc()} ERROR {event.get("error", "")}'
                progress.write(error_message + '\n')
                console_print(error_message)
            now = time.monotonic()
            if now - last_written >= 1 or (not publisher.degraded and event.get('type') in ('error', 'done')):
                state.update(ledger.snapshot(), elapsed_seconds=round(now-started, 1), last_event_utc=utc())
                publisher.publish(state)
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
    if 'publisher' in locals():
        publisher.publish(state)
    write_final_result(folder, state)
    console_print(json.dumps({key: state[key] for key in ('head', 'exit_code', 'counts', 'accepted', 'stable_source')}, ensure_ascii=True))
    return 0 if state['accepted'] else (exit_code or 79)



if __name__ == '__main__':
    raise SystemExit(main())
