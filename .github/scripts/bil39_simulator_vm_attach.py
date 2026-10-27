#!/usr/bin/env python3
"""Discovery-only exact-simulator attachment; never a release receipt.

Flutter 3.44.6 supports drive --use-existing-app. A missed live-log event must
not cause a 30-minute wait when that exact process already published its URL.
No app changes, entitlement changes, arbitrary URLs, network discovery or retry.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urlsplit

from bil_native_bounded_command import run_bounded

BUNDLE = 'com.bilhealth.bodyintelligencelog'
TARGETS = {
    'integration_test/system_crypto_bridge_integration_test.dart',
    'integration_test/native_feature_splashes_test.dart',
}


def launch_to_file(command, output, timeout=60):
    # simctl's launched process can retain inherited descriptors. Waiting for
    # PIPE EOF would then wait for the app, even after simctl itself exited.
    with Path(output).open('wb') as stream:
        process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
            raise
    if process.returncode:
        raise subprocess.CalledProcessError(process.returncode, ['selected-simulator-launch'])
    return Path(output).read_text(errors='replace')


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
    with args.driver_log.open('wb') as output, args.native_log.open('r', errors='replace') as native:
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
    args = parser.parse_args()
    if sys.platform != 'darwin' or not re.fullmatch(r'[0-9A-Fa-f-]{36}', args.device):
        parser.error('Only a selected local macOS QA Simulator is permitted')
    root = Path.cwd().resolve()
    app = args.app.resolve()
    if app != root / 'build/ios/Debug-iphonesimulator/Runner.app' or not app.is_dir():
        parser.error('Expected the prebuilt exact QA simulator bundle')
    args.output.resolve().relative_to(root)
    args.driver.resolve().relative_to(root)
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    result = {'scope': 'DISCOVERY_ONLY_NOT_RELEASE_ACCEPTANCE', 'device': args.device,
              'target': args.target, 'vm_uri_saved_in_receipt': False, 'retry_count': 0}
    collector = None
    collector_output = None
    stage = 'install'

    def command(label, command, timeout=60):
        completed = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        (output / f'{label}.log').write_text(completed.stdout + completed.stderr)
        completed.check_returncode()
        return completed.stdout

    try:
        command('exact-app-install', ['xcrun', 'simctl', 'install', args.device, str(app)], 180)
        stage = 'log_collector'
        native_log = output / 'selected-runner-events.json'
        collector_output = native_log.open('wb')
        collector = subprocess.Popen(['xcrun', 'simctl', 'spawn', args.device, 'log', 'stream',
            '--style', 'json', '--predicate', 'process == "Runner"'],
            stdout=collector_output, stderr=subprocess.STDOUT)
        stage = 'launch'
        raw = launch_to_file(['xcrun', 'simctl', 'launch', args.device, BUNDLE,
            '--enable-dart-profiling', '--disable-vm-service-publication', '--start-paused',
            '--enable-checked-mode', '--verify-entry-points'], output / 'exact-app-launch.log')
        pid = launch_pid(raw)
        result['pid'] = pid
        stage = 'discover_vm'
        url = None
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline and url is None:
            if collector.poll() is not None:
                raise RuntimeError('Selected-app log collector exited before VM discovery')
            raw = subprocess.run(['xcrun', 'simctl', 'spawn', args.device, 'log', 'show',
                '--last', '2m', '--style', 'json', '--predicate',
                'process == "Runner" AND eventMessage CONTAINS "The Dart VM service is listening on"'],
                capture_output=True, text=True, timeout=15)
            raw.check_returncode()
            url = vm_url_from_log(raw.stdout, pid)
            if url is None:
                time.sleep(1)
        if url is None:
            raise TimeoutError('Selected BIL process did not publish a VM service within 90s')
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
        code = run_bounded(relay, label='direct-vm-drive',
            log_path=output / 'direct-vm-drive.log', receipt_path=output / 'direct-vm-drive-result.json',
            timeout_seconds=180, running_timeout_seconds=1200, summary_grace_seconds=60,
            fail_on_launch_error=True)
        result['drive_exit'] = code
        return code
    except Exception as error:
        result['error_type'] = type(error).__name__
        raise
    finally:
        if collector is not None:
            collector.terminate()
            try:
                collector.wait(timeout=5)
            except subprocess.TimeoutExpired:
                collector.kill()
                collector.wait(timeout=5)
        if collector_output is not None:
            collector_output.close()
        result['last_stage'] = stage
        result['elapsed_seconds'] = round(time.monotonic() - started, 3)
        (output / 'attachment-receipt.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    if sys.argv[1:2] == ['--relay']:
        raise SystemExit(relay_driver(sys.argv[2:]))
    raise SystemExit(main())
