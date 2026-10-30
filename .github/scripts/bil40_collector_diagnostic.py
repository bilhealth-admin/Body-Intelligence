#!/usr/bin/env python3
"""No-app macOS transport experiment; no application test acceptance.

Two newly created owned Simulators counterbalance DEVNULL/held-open PIPE.
The exact candidate collector and its unchanged readiness deadline are reused.
No Flutter, Pods, BIL installation/launch, signing, account or network requests.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

import bil39_simulator_vm_attach as attach

OUT = Path('artifacts/qa/bil40-collector-diagnostic')
MODES = ('devnull', 'pipe-open')
BASE = 'ef42de6126325f40e1afa8806c59de93bcfd193b'


def snapshot(label, collector, *, sample=False):
    """Read only the owned collector's process ancestry, never host arguments."""
    receipt = {'collector_pid': collector.pid, 'owned_descendants': []}
    if collector.poll() is not None:
        receipt['reason'] = 'COLLECTOR_ALREADY_EXITED_NO_SAMPLING'
        dump(OUT / (label + '-processes.json'), receipt)
        return
    try:
        raw = subprocess.run(['/bin/ps', '-axo', 'pid=,ppid=,pgid=,comm='],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            check=True, timeout=5).stdout
        rows = []
        for line in raw.splitlines():
            columns = line.split(None, 3)
            if len(columns) == 4:
                rows.append({'pid': int(columns[0]), 'ppid': int(columns[1]),
                    'pgid': int(columns[2]), 'executable': columns[3]})
        owned = {collector.pid}
        for _ in rows:
            added = {row['pid'] for row in rows if row['ppid'] in owned}
            if added <= owned:
                break
            owned |= added
        receipt['owned_descendants'] = [row for row in rows if row['pid'] in owned]
        if sample:
            selected = [row for row in receipt['owned_descendants']
                if Path(row['executable']).name in ('script', 'simctl', 'log')][:2]
            for row in selected:
                if collector.poll() is not None:
                    receipt['reason'] = 'COLLECTOR_EXITED_BEFORE_SAMPLING'
                    break
                try:
                    run(label + '-sample-' + str(row['pid']), ['/usr/bin/sample',
                        str(row['pid']), '1', '1', '-file',
                        str(OUT / (label + '-sample-' + str(row['pid']) + '.txt'))], timeout=5)
                except (subprocess.SubprocessError, OSError) as error:
                    receipt.setdefault('sample_errors', []).append(type(error).__name__)
    except (subprocess.SubprocessError, OSError) as error:
        receipt['error_type'] = type(error).__name__
    dump(OUT / (label + '-processes.json'), receipt)


def ready_bytes(path):
    with path.open('r', encoding='utf-8', errors='replace') as stream:
        prefix = stream.read(16384)
    return ('Filtering the log data using' in prefix or bool(attach.decode_events(prefix)[0]))


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def run(label, command, *, timeout=30):
    started = time.monotonic()
    record = {'command': command, 'timeout_seconds': timeout, 'retry_count': 0}
    path = OUT / (label + '.log')
    process = None
    try:
        with path.open('wb') as output:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            process._bil_collector_group = True
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                record['timed_out'] = True
                raise
            if process.returncode:
                raise subprocess.CalledProcessError(process.returncode, command)
        return path.read_text(encoding='utf-8', errors='replace')
    except BaseException as error:
        record['error_type'] = type(error).__name__
        raise
    finally:
        if process is not None and process.poll() is None:
            attach.stop_collector(process)
        record.update(elapsed_seconds=round(time.monotonic() - started, 3),
            returncode=None if process is None else process.returncode)
        dump(OUT / (label + '.json'), record)


def capture(label, command, mode, *, synthetic=False):
    started = time.monotonic()
    path = OUT / (label + '.log')
    record = {'mode': mode, 'command': command, 'readiness_timeout_seconds': 20,
        'retry_count': 0, 'synthetic': synthetic, 'ready': False,
        'scope': 'TRANSPORT_DIAGNOSIS_ONLY_NOT_APP_ACCEPTANCE'}
    process = None
    phase = 'popen'
    try:
        with path.open('wb') as output:
            kwargs = {'stdout': output, 'stderr': subprocess.STDOUT,
                'start_new_session': True}
            if mode == 'devnull':
                kwargs['stdin'] = subprocess.DEVNULL
            elif mode == 'pipe-open':
                kwargs['stdin'] = subprocess.PIPE
            elif mode != 'inherit':
                raise ValueError('Unknown diagnostic mode')
            process = subprocess.Popen(command, **kwargs)
            process._bil_collector_group = True
            record['collector_pid'] = process.pid
            record['stdin_pipe_open_during_capture'] = (
                process.stdin is not None and not process.stdin.closed)
            phase = 'wait'
            if synthetic:
                try:
                    process.wait(timeout=10)
                    record['synthetic_completed'] = True
                except subprocess.TimeoutExpired:
                    # A PTY stall is evidence for this experiment. Preserve it
                    # and continue to the actual simctl counterbalanced cases.
                    record.update(synthetic_completed=False, timed_out=True,
                        error_type='TimeoutExpired')
                record['returncode_before_cleanup'] = process.poll()
            else:
                try:
                    attach.wait_for_collector(path, process, timeout=20)
                    record['ready'] = True
                except (RuntimeError, TimeoutError) as error:
                    record.update(ready=False, error_type=type(error).__name__)
                record['acceptance_elapsed_seconds'] = round(time.monotonic() - started, 3)
                if not record['ready']:
                    # Supplementary observation is not another readiness test.
                    # Keep the original20s failure and the very same process.
                    record.update(late_ready=False, observation_timeout_seconds=80)
                    observe_started = time.monotonic()
                    snapshot(label + '-failed-20s', process, sample=True)
                    while time.monotonic() - observe_started < 80:
                        if process.poll() is not None:
                            break
                        if ready_bytes(path):
                            record.update(late_ready=True,
                                late_ready_elapsed_seconds=round(time.monotonic() - started, 3))
                            break
                        time.sleep(.25)
                    record['observation_elapsed_seconds'] = round(time.monotonic() - observe_started, 3)
                    snapshot(label + '-after-observation', process)
                record['returncode_before_cleanup'] = process.poll()
            record['capture_elapsed_seconds'] = round(time.monotonic() - started, 3)
    except Exception as error:
        record.update(ready=False, error_type=type(error).__name__,
            capture_error_phase=phase)
    finally:
        try:
            if process is not None and process.poll() is None:
                attach.stop_collector(process)
        except Exception as error:
            record['cleanup_error_type'] = type(error).__name__
        finally:
            if process is not None and process.stdin is not None:
                try:
                    process.stdin.close()
                except Exception as error:
                    record['stdin_close_error_type'] = type(error).__name__
            data = path.read_bytes() if path.exists() else b''
            record.update(byte_count=len(data), first_64_bytes_hex=data[:64].hex(),
                sha256=hashlib.sha256(data).hexdigest(),
                collector_returncode=None if process is None else process.returncode,
                stdin_pipe_closed_after_cleanup=(process is not None and
                    process.stdin is not None and process.stdin.closed),
                elapsed_seconds=round(time.monotonic() - started, 3))
            if synthetic:
                record['observed_eof'] = b'SYNTHETIC_STDIN_EOF' in data
                record['observed_no_input'] = b'SYNTHETIC_STDIN_NO_INPUT' in data
            dump(OUT / (label + '.json'), record)
    print(json.dumps({'case': label, **record}), flush=True)
    return record


def select_device(runtimes, types):
    ios = [item for item in runtimes['runtimes'] if item.get('isAvailable') and
        item['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
    if not ios:
        raise RuntimeError('No available iOS runtime')
    runtime = max(ios, key=lambda item: tuple(map(int, re.findall(r'\d+', item['version']))))
    iphones = [item for item in types['devicetypes'] if item['name'].startswith('iPhone')]
    preferred = ['iPhone 16 Pro', 'iPhone 16', 'iPhone 15 Pro']
    device = next((item for name in preferred for item in iphones if item['name'] == name),
        iphones[-1] if iphones else None)
    if device is None:
        raise RuntimeError('No available iPhone type')
    return runtime, device


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This experiment requires actual macOS; Windows is not native proof')
    OUT.mkdir(parents=True, exist_ok=False)
    summary = {'scope': 'TRANSPORT_DIAGNOSIS_ONLY_NOT_APP_ACCEPTANCE',
        'candidate_base': BASE, 'cases': [], 'owned_simulators': [],
        'retry_count': 0, 'app_built': False, 'app_installed': False,
        'app_launched': False, 'cleanup_errors': []}
    fatal = None
    try:
        for key, label, command in [
            ('source_sha', 'source-sha', ['git', 'rev-parse', 'HEAD']),
            ('os_version', 'os-version', ['sw_vers']),
            ('xcode_version', 'xcode-version', ['xcodebuild', '-version']),
        ]:
            try:
                summary[key] = run(label, command).strip()
            except (OSError, subprocess.SubprocessError) as error:
                summary[key] = {'status': 'UNKNOWN', 'error_type': type(error).__name__}
        summary['python_version'] = sys.version
        summary['parent_stdin_is_tty'] = os.isatty(0)
        for binary in ['/usr/bin/script', '/usr/bin/log', '/usr/bin/xcrun']:
            try:
                value = hashlib.sha256(Path(binary).read_bytes()).hexdigest()
            except OSError as error:
                value = {'status': 'UNKNOWN', 'error_type': type(error).__name__}
            summary.setdefault('binary_sha256', {})[binary] = value
        # Actual Apple script + canonical PTY observation, not a simulated stall.
        source = ('import select,sys,time;time.sleep(.1);'
            'ready=select.select([sys.stdin],[],[],1)[0];'
            'data=sys.stdin.read(1) if ready else None;'
            'print("SYNTHETIC_STDIN_EOF" if data=="" else '
            '"SYNTHETIC_STDIN_NO_INPUT" if data is None else "SYNTHETIC_STDIN_DATA",flush=True)')
        for mode in ['inherit', *MODES]:
            summary['cases'].append(capture('synthetic-' + mode,
                ['/usr/bin/script', '-q', '/dev/null', sys.executable, '-E', '-c', source],
                mode, synthetic=True))
        runtimes = json.loads(run('runtimes', ['xcrun', 'simctl', 'list', 'runtimes', 'available', '-j'], timeout=120))
        types = json.loads(run('device-types', ['xcrun', 'simctl', 'list', 'devicetypes', '-j'], timeout=120))
        runtime, device_type = select_device(runtimes, types)
        summary.update(runtime=runtime, device_type=device_type)
        for index, modes in enumerate([MODES, tuple(reversed(MODES))], 1):
            label = 'pair-' + str(index)
            device = run(label + '-create', ['xcrun', 'simctl', 'create',
                'BIL40-collector-' + os.environ.get('GITHUB_RUN_ID', 'local') + '-' + str(index),
                device_type['identifier'], runtime['identifier']], timeout=120).strip()
            if not re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', device):
                raise RuntimeError('Invalid created Simulator identity; no broad cleanup permitted')
            summary['owned_simulators'].append(device)
            try:
                setup_incomplete = False
                for operation, command, limit in [
                    ('boot', ['xcrun', 'simctl', 'boot', device], 120),
                    ('bootstatus', ['xcrun', 'simctl', 'bootstatus', device, '-b'], 180),
                ]:
                    try:
                        run(label + '-' + operation, command, timeout=limit)
                    except (OSError, subprocess.SubprocessError) as error:
                        setup_incomplete = True
                        summary.setdefault('setup_failures', []).append({'pair': index,
                            'operation': operation, 'error_type': type(error).__name__,
                            'precondition': 'UNKNOWN'})
                # These collectors only observe this owned UUID. An unknown or
                # failed setup is recorded, rather than placing another simctl
                # query before the actual experiment. No BIL app is launched.
                state_evidence = ('UNKNOWN_SETUP_FAILED' if setup_incomplete else
                    'exact_uuid_bootstatus_exit_zero')
                for order, mode in enumerate(modes, 1):
                    record = capture(label + '-' + str(order) + '-' + mode,
                        attach.collector_command(device), mode)
                    record.update(pair=index, order=order, device=device,
                        setup_incomplete=setup_incomplete,
                        state_evidence=state_evidence,
                        boot_complete_at_start=None if setup_incomplete else True,
                        boot_completion_after_failed_probe=(
                            'UNKNOWN_SETUP_FAILED' if setup_incomplete else None))
                    summary['cases'].append(record)
            finally:
                for operation in ['shutdown', 'delete']:
                    try:
                        run(label + '-' + operation, ['xcrun', 'simctl', operation, device])
                    except BaseException as error:
                        summary['cleanup_errors'].append({'device': device,
                            'operation': operation, 'error_type': type(error).__name__})
        for record in summary['cases']:
            for field in ['cleanup_error_type', 'stdin_close_error_type']:
                if field in record:
                    summary['cleanup_errors'].append({'scope': 'collector',
                        'pair': record.get('pair'), 'device': record.get('device'),
                        'mode': record['mode'], 'operation': field,
                        'error_type': record[field]})
        summary['experiment_completed'] = True
    except BaseException as error:
        fatal = error
        summary.update(experiment_completed=False, error_type=type(error).__name__)
    finally:
        dump(OUT / 'summary.json', summary)
    if fatal:
        raise fatal
    if summary['cleanup_errors']:
        raise RuntimeError('Owned diagnostic resource cleanup failed; inspect receipts')
    # Readiness failures are experiment data, never a passed BIL app test.
    print('Completed controlled no-app transport experiment; inspect per-case outcomes.', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
