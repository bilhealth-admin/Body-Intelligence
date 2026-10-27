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
    match = re.fullmatch(re.escape(BUNDLE) + r': ([1-9][0-9]*)\s*', raw)
    if not match:
        raise ValueError('Simulator launch did not identify exactly the BIL process')
    return int(match.group(1))


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
              'target': args.target, 'vm_uri_recorded': False, 'retry_count': 0}

    def command(label, command, timeout=60):
        completed = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        (output / f'{label}.log').write_text(completed.stdout + completed.stderr)
        completed.check_returncode()
        return completed.stdout

    try:
        command('exact-app-install', ['xcrun', 'simctl', 'install', args.device, str(app)], 180)
        raw = command('exact-app-launch', ['xcrun', 'simctl', 'launch', args.device, BUNDLE,
            '--enable-dart-profiling', '--disable-vm-service-publication', '--start-paused',
            '--enable-checked-mode', '--verify-entry-points'])
        pid = launch_pid(raw)
        result['pid'] = pid
        url = None
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline and url is None:
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
        command_line = ['flutter', '--verbose', 'drive', '--no-pub', '--keep-app-running',
            '--device-id', args.device, '--timeout', '1200', '--use-existing-app', url,
            '--target', args.target, '--driver', str(args.driver),
            '--test-arguments=--packages=' + str(root / '.dart_tool/package_config.json')]
        code = run_bounded(command_line, label='direct-vm-drive',
            log_path=output / 'direct-vm-drive.log', receipt_path=output / 'direct-vm-drive-result.json',
            timeout_seconds=180, running_timeout_seconds=1200, summary_grace_seconds=60,
            fail_on_launch_error=True)
        result['drive_exit'] = code
        return code
    finally:
        result['elapsed_seconds'] = round(time.monotonic() - started, 3)
        (output / 'attachment-receipt.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    raise SystemExit(main())
