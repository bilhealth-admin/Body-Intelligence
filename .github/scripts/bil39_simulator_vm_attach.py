#!/usr/bin/env python3
"""Exact-simulator QA transport; actual test receipts remain mandatory.

Flutter 3.44.6 supports drive --use-existing-app. A missed live-log event must
not cause a 30-minute wait when that exact process already published its URL.
No app changes, entitlement changes, arbitrary URLs, network discovery or retry.
"""
import argparse
import os
import json
from pathlib import Path
import re
import subprocess
import signal
import sys
import time
from urllib.parse import urlsplit

from bil_native_bounded_command import run_bounded
from bil_ios_simulator_adhoc_sign import TARGETS

BUNDLE = 'com.bilhealth.bodyintelligencelog'
NATIVE_BOOTSTRAP_TIMEOUT_SECONDS = 180


def bootstrap_remaining(deadline, stage, *, cap=None):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError('Selected-app native bootstrap expired at ' + stage)
    return min(remaining, cap) if cap is not None else remaining


def collector_command(device):
    # macOS log buffers its readiness banner when stdout is a regular file.
    # A PTY makes the real banner line-buffered, before the selected Runner
    # exists. script only relays the original bytes; it invents no readiness.
    return ['/usr/bin/script', '-q', '/dev/null', 'xcrun', 'simctl', 'spawn',
            device, 'log', 'stream', '--style', 'json', '--predicate',
            'process == "Runner"']


def start_collector(command, output):
    # An inherited CI stdin EOF is forwarded by Apple script as VEOF. Keep our
    # own pipe open without input until collection ends; cold-start latency is
    # handled separately by the shared bootstrap deadline, not by this pipe.
    collector = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=output,
        stderr=subprocess.STDOUT, start_new_session=True)
    collector._bil_collector_group = True
    collector._bil_collector_stdin_owned = True
    return collector


def stop_collector(collector):
    def send(sig, *, force=False):
        if (os.name == 'posix' and
                getattr(collector, '_bil_collector_group', False) is True and
                type(collector.pid) is int and collector.pid > 0):
            try:
                os.killpg(collector.pid, sig)
            except ProcessLookupError:
                pass
        elif force:
            collector.kill()
        else:
            collector.terminate()
    try:
        if collector.poll() is None:
            send(signal.SIGTERM)
            try:
                collector.wait(timeout=5)
            except subprocess.TimeoutExpired:
                send(signal.SIGKILL if os.name == 'posix' else signal.SIGTERM, force=True)
                collector.wait(timeout=5)
    finally:
        if getattr(collector, '_bil_collector_stdin_owned', False) is True:
            collector.stdin.close()


def launch_to_file(command, output, timeout=NATIVE_BOOTSTRAP_TIMEOUT_SECONDS, *, receipt=None, deadline=None):
    # simctl's launched process can retain inherited descriptors. Waiting for
    # PIPE EOF would then wait for the app, even after simctl itself exited.
    # A queued OS launch may exceed60s before producing its exact PID. Give
    # this single command the existing native bootstrap allowance, not a retry
    # or permission to bypass PID/VM discovery or any application assertion.
    started = time.monotonic()
    process = None
    result = {'scope': 'SIMULATOR_LAUNCH_TRANSPORT_ONLY_NOT_APP_ACCEPTANCE',
              'timeout_seconds': timeout, 'timed_out': False,
              'shared_bootstrap_deadline': deadline is not None,
              'cleanup_attempted': False, 'retry_count': 0,
              'app_startup_verified': False, 'reason': 'launch_error'}
    try:
        with Path(output).open('wb') as stream:
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
            try:
                wait_timeout = (bootstrap_remaining(deadline, 'launch', cap=timeout)
                    if deadline is not None else timeout)
                result['wait_timeout_seconds'] = wait_timeout
                process.wait(timeout=wait_timeout)
                if deadline is not None:
                    bootstrap_remaining(deadline, 'launch')
            except (subprocess.TimeoutExpired, TimeoutError):
                result.update(reason='launch_timeout', timed_out=True, cleanup_attempted=True)
                process.kill()
                process.wait(timeout=5)
                raise
        if process.returncode:
            result['reason'] = 'launch_nonzero_exit'
            raise subprocess.CalledProcessError(process.returncode, ['selected-simulator-launch'])
        result['reason'] = 'launch_command_exit_zero'
        return Path(output).read_text(encoding='utf-8', errors='replace')
    finally:
        result['elapsed_seconds'] = round(time.monotonic() - started, 3)
        result['raw_returncode'] = process.returncode if process is not None else None
        if receipt is not None:
            Path(receipt).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')


def decode_events(buffer):
    """Decode complete Apple --style json objects without waiting for EOF."""
    decoder = json.JSONDecoder()
    rows = []
    while True:
        start = buffer.find('{')
        if start < 0:
            return rows, ''
        buffer = buffer[start:]
        try:
            row, end = decoder.raw_decode(buffer)
        except json.JSONDecodeError:
            if len(buffer) > 1024 * 1024:
                raise ValueError('Unbounded or malformed simulator log object')
            return rows, buffer
        rows.append(row)
        buffer = buffer[end:]


def wait_for_collector(path, collector, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if collector.poll() is not None:
            raise RuntimeError('Selected-app log collector exited before readiness')
        with Path(path).open('r', encoding='utf-8', errors='replace') as stream:
            prefix = stream.read(16384)
        if 'Filtering the log data using' in prefix or decode_events(prefix)[0]:
            return
        time.sleep(.05)
    raise TimeoutError('Selected-app log collector did not become ready')


def discover_vm_from_capture(path, pid, collector, timeout=90):
    deadline = time.monotonic() + timeout
    buffer = ''
    with Path(path).open('r', encoding='utf-8', errors='replace') as stream:
        while time.monotonic() < deadline:
            buffer += stream.read(65536)
            rows, buffer = decode_events(buffer)
            url = vm_url_from_log(json.dumps(rows), pid)
            if url is not None:
                return url
            if collector.poll() is not None:
                raise RuntimeError('Selected-app log collector exited before VM discovery')
            time.sleep(.05)
    raise TimeoutError('Selected BIL process did not publish a VM service within 90s')


def relay_driver(arguments):
    parser = argparse.ArgumentParser(description='Internal selected-app log relay')
    parser.add_argument('--native-log', type=Path, required=True)
    parser.add_argument('--driver-log', type=Path, required=True)
    parser.add_argument('--pid', type=int, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args(arguments)
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if args.pid <= 0 or not command or command[0] != 'flutter':
        parser.error('Expected the owned Flutter driver and selected process')
    root = Path.cwd().resolve()
    for path in (args.native_log, args.driver_log):
        path.resolve().relative_to(root)
    with args.driver_log.open('wb') as output, args.native_log.open('r', encoding='utf-8', errors='replace') as native:
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        buffer = ''
        finished_at = None
        with args.driver_log.open('rb') as host:
            while True:
                chunk = host.read(65536)
                if chunk:
                    sys.stdout.buffer.write(chunk)
                buffer += native.read(65536)
                rows, buffer = decode_events(buffer)
                for row in rows:
                    if (isinstance(row, dict) and row.get('processID') == args.pid
                            and str(row.get('processImagePath', '')).endswith('/Runner.app/Runner')
                            and isinstance(row.get('eventMessage'), str)):
                        sys.stdout.buffer.write((row['eventMessage'] + '\n').encode())
                sys.stdout.buffer.flush()
                if process.poll() is not None:
                    if finished_at is None:
                        finished_at = time.monotonic()
                    # The driver response can precede the OS log flush. Drain
                    # its actual final counter without inventing a summary.
                    if not chunk and not rows and time.monotonic() - finished_at >= 2:
                        return process.returncode
                time.sleep(.02)


def vm_url_from_log(raw, pid):
    rows = json.loads(raw)
    if not isinstance(rows, list):
        raise ValueError('Unified log must contain an array')
    urls = set()
    for row in rows:
        if not isinstance(row, dict) or row.get('processID') != pid:
            continue
        if not str(row.get('processImagePath', '')).endswith('/Runner.app/Runner'):
            continue
        message = row.get('eventMessage', '')
        if not isinstance(message, str):
            continue
        match = re.fullmatch(r'flutter: The Dart VM service is listening on (\S+)\s*', message)
        if not match:
            continue
        url = match.group(1)
        parsed = urlsplit(url)
        if (parsed.scheme != 'http' or parsed.hostname != '127.0.0.1'
                or parsed.username is not None or parsed.password is not None
                or parsed.query or parsed.fragment or parsed.port is None
                or not 1024 <= parsed.port <= 65535
                or not re.fullmatch(r'/[A-Za-z0-9_=-]+/', parsed.path)):
            raise ValueError('Only this simulator loopback VM service is permitted')
        urls.add(url)
    if len(urls) > 1:
        raise ValueError('Ambiguous VM service for the selected process')
    return next(iter(urls), None)


def launch_pid(raw):
    matches = re.findall(r'^([A-Za-z0-9_.-]+): ([1-9][0-9]*)\s*$', raw, re.MULTILINE)
    if len(matches) != 1 or matches[0][0] != BUNDLE:
        raise ValueError('Simulator launch did not identify exactly the BIL process')
    return int(matches[0][1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qa-simulator-only', action='store_true', required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--target', choices=sorted(TARGETS), required=True)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--label', default='direct-vm-drive')
    parser.add_argument('--log', type=Path)
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args()
    if sys.platform != 'darwin' or not re.fullmatch(r'[0-9A-Fa-f-]{36}', args.device):
        parser.error('Only a selected local macOS QA Simulator is permitted')
    if not re.fullmatch(r'[A-Za-z0-9_.-]{1,100}', args.label):
        parser.error('A safe native stage label is required')
    root = Path.cwd().resolve()
    app = args.app.resolve()
    if app != root / 'build/ios/Debug-iphonesimulator/Runner.app' or not app.is_dir():
        parser.error('Expected the prebuilt exact QA simulator bundle')
    args.output.resolve().relative_to(root)
    args.driver.resolve().relative_to(root)
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    raw_log = args.log or output / 'direct-vm-drive.log'
    native_receipt = args.receipt or output / 'direct-vm-drive-result.json'
    for path in (raw_log, native_receipt):
        path.resolve().relative_to(root)
        if path.is_symlink():
            parser.error('Native evidence may not be symlinked')
    started = time.monotonic()
    result = {'scope': 'QA_SIMULATOR_TRANSPORT_ONLY_NOT_A_TEST_VERDICT', 'device': args.device,
              'target': args.target, 'vm_uri_saved_in_receipt': False, 'retry_count': 0,
              'launch_timeout_seconds': NATIVE_BOOTSTRAP_TIMEOUT_SECONDS,
              'launch_receipt': 'exact-app-launch-result.json'}
    collector = None
    collector_output = None
    stage = 'install'
    bootstrap_started = None
    bootstrap_deadline = None
    bootstrap_finished = None
    stage_started = None
    bootstrap_stages = ('log_collector', 'launch', 'discover_vm')
    result.update(native_bootstrap_total_seconds=NATIVE_BOOTSTRAP_TIMEOUT_SECONDS,
        bootstrap_stage_elapsed_seconds={}, bootstrap_expired=False)

    def command(label, command, timeout=60):
        completed = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        (output / f'{label}.log').write_text(completed.stdout + completed.stderr)
        completed.check_returncode()
        return completed.stdout

    try:
        command('exact-app-install', ['xcrun', 'simctl', 'install', args.device, str(app)], 180)
        stage = 'log_collector'
        bootstrap_started = stage_started = time.monotonic()
        bootstrap_deadline = bootstrap_started + NATIVE_BOOTSTRAP_TIMEOUT_SECONDS
        native_log = output / 'selected-runner-events.json'
        collector_output = native_log.open('wb')
        collector = start_collector(collector_command(args.device), collector_output)
        wait_for_collector(native_log, collector,
            timeout=bootstrap_remaining(bootstrap_deadline, stage))
        bootstrap_remaining(bootstrap_deadline, stage)
        result['bootstrap_stage_elapsed_seconds'][stage] = round(time.monotonic() - stage_started, 3)
        stage = 'launch'
        stage_started = time.monotonic()
        raw = launch_to_file(['xcrun', 'simctl', 'launch', args.device, BUNDLE,
            '--enable-dart-profiling', '--disable-vm-service-publication', '--start-paused',
            '--enable-checked-mode', '--verify-entry-points'], output / 'exact-app-launch.log',
            timeout=bootstrap_remaining(bootstrap_deadline, stage),
            receipt=output / 'exact-app-launch-result.json', deadline=bootstrap_deadline)
        bootstrap_remaining(bootstrap_deadline, stage)
        pid = launch_pid(raw)
        result['pid'] = pid
        result['bootstrap_stage_elapsed_seconds'][stage] = round(time.monotonic() - stage_started, 3)
        stage = 'discover_vm'
        stage_started = time.monotonic()
        url = discover_vm_from_capture(native_log, pid, collector,
            timeout=bootstrap_remaining(bootstrap_deadline, stage, cap=90))
        bootstrap_remaining(bootstrap_deadline, stage)
        bootstrap_finished = time.monotonic()
        result['bootstrap_stage_elapsed_seconds'][stage] = round(bootstrap_finished - stage_started, 3)
        result['bootstrap_elapsed_seconds'] = round(bootstrap_finished - bootstrap_started, 3)
        result['vm_discovered_after_seconds'] = round(time.monotonic() - started, 3)
        result['vm_origin'] = 'http://127.0.0.1:' + str(urlsplit(url).port)
        stage = 'native_driver'
        command_line = ['flutter', '--verbose', 'drive', '--no-pub', '--keep-app-running',
            '--device-id', args.device, '--timeout', '1200', '--use-existing-app', url,
            '--target', args.target, '--driver', str(args.driver),
            '--test-arguments=--packages=' + str(root / '.dart_tool/package_config.json')]
        relay = [sys.executable, str(Path(__file__).resolve()), '--relay',
            '--native-log', str(native_log), '--driver-log', str(output / 'driver-raw.log'),
            '--pid', str(pid), '--', *command_line]
        code = run_bounded(relay, label=args.label,
            log_path=raw_log, receipt_path=native_receipt,
            timeout_seconds=NATIVE_BOOTSTRAP_TIMEOUT_SECONDS,
            running_timeout_seconds=1200, summary_grace_seconds=60,
            fail_on_launch_error=True,
            allow_capture_progress=args.target == 'integration_test/native_feature_splashes_test.dart')
        result['drive_exit'] = code
        return code
    except Exception as error:
        result['error_type'] = type(error).__name__
        raise
    finally:
        stopped_at = time.monotonic()
        if bootstrap_started is not None and bootstrap_finished is None:
            result['bootstrap_elapsed_seconds'] = round(stopped_at - bootstrap_started, 3)
            if stage in bootstrap_stages:
                result['bootstrap_stage_elapsed_seconds'][stage] = round(stopped_at - stage_started, 3)
            if stopped_at >= bootstrap_deadline:
                result.update(bootstrap_expired=True, bootstrap_expired_stage=stage)
        cleanup_error = None
        active_error = sys.exc_info()[0] is not None
        try:
            if collector is not None:
                stop_collector(collector)
        except Exception as error:
            cleanup_error = error
            result['collector_cleanup_error_type'] = type(error).__name__
        if collector_output is not None:
            collector_output.close()
        result['last_stage'] = stage
        result['elapsed_seconds'] = round(time.monotonic() - started, 3)
        (output / 'attachment-receipt.json').write_text(json.dumps(result, indent=2) + '\n')
        if cleanup_error is not None and not active_error:
            raise cleanup_error


if __name__ == '__main__':
    if sys.argv[1:2] == ['--relay']:
        raise SystemExit(relay_driver(sys.argv[2:]))
    raise SystemExit(main())
