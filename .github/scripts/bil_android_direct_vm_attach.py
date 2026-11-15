#!/usr/bin/env python3
"""Owned API33 QA transport. No retries, renderer override or private URI logs.

The outer existing supervisor owns the original bootstrap/test/summary budgets.
Its worker emits only scrubbed bytes, including build/driver stderr and native
logcat messages. The VM authority and auth path exist only in worker memory.
"""
import argparse
import hashlib
import ipaddress
import json
import math
import os
from pathlib import Path
import queue
import re
import signal
import socket
import struct
import subprocess
import sys
import threading
import time
from urllib.parse import urlsplit, urlunsplit
import uuid
import zipfile

from bil_native_bounded_command import run_bounded

PACKAGE = 'com.bilhealth.bodyintelligencelog'
PARENT = 'fd106fd3ba6073f0474640a10062af6d7d55dadb'
BRANCH = 'refs/heads/codex/bil45-android-api33-direct-vm-diagnostic-20261115'
WORKFLOW = '.github/workflows/bil45_android_api33_direct_vm_diagnostic.yml'
SELF = '.github/scripts/bil_android_direct_vm_attach.py'
PUB_LOCK = 'bc3c559586313d4323233c0b5d66dde56441e0f03d7be45d00bae61efb4fa7ac'
SCOPES = {
    'system-crypto': ('integration_test/system_crypto_bridge_integration_test.dart', None),
    'native-settings': ('integration_test/native_settings_polish_test.dart', 'test_driver/native_settings_capture_driver.dart'),
    'native-feature-splashes': ('integration_test/native_feature_splashes_test.dart', 'test_driver/native_feature_splashes_driver.dart'),
}
URL = re.compile(r'\b(?:https?|wss?)://[^\s<>]+', re.I)
LINE = re.compile(r'^\d\d-\d\d\s+\d\d:\d\d:\d\d\.\d+\s+(\d+)\s+\d+\s+[VDIWEF]\s+([^:]+):\s?(.*)$')


def need(ok, code):
    if not ok:
        raise ValueError(code)


def scrub(text, private=()):
    for value in sorted(set(private), key=len, reverse=True):
        if value:
            text = text.replace(value, '[VM_PRIVATE_REDACTED]')
    return URL.sub('[URI_REDACTED]', text)


def vm_authority(text):
    try:
        value = urlsplit(text)
        valid = (value.scheme == 'http' and value.hostname in ('127.0.0.1', '::1')
                 and value.username is None and value.password is None
                 and not value.query and not value.fragment and value.port is not None
                 and 1024 <= value.port <= 65535
                 and re.fullmatch(r'/[A-Za-z0-9_=-]{8,128}/', value.path))
    except ValueError:
        valid = False
    need(valid, 'OWNED_LOOPBACK_VM_AUTHORITY_REQUIRED')
    return value


def vm_from_line(line, pid):
    match = LINE.fullmatch(line)
    if not match or int(match[1]) != pid or match[2].strip().lower() != 'flutter':
        return None
    announced = re.fullmatch(r'The Dart VM service is listening on (\S+)\s*', match[3])
    if announced is None:
        return None
    vm_authority(announced[1])
    return announced[1]


def own_forward(rows, serial, host, device):
    matches = [line.split() for line in rows.splitlines() if line.split()[1:2] == ['tcp:' + str(host)]]
    return matches == [[serial, 'tcp:' + str(host), 'tcp:' + str(device)]]


def loopback_listener(port):
    addresses = []
    for name, family in [('tcp', socket.AF_INET), ('tcp6', socket.AF_INET6)]:
        file = Path('/proc/net') / name
        if not file.is_file():
            continue
        for line in file.read_text().splitlines()[1:]:
            fields = line.split()
            address, raw_port = fields[1].split(':')
            if fields[3] != '0A' or int(raw_port, 16) != port:
                continue
            raw = bytes.fromhex(address)
            raw = (raw[::-1] if family == socket.AF_INET else b''.join(raw[i:i + 4][::-1] for i in range(0, 16, 4)))
            addresses.append(ipaddress.ip_address(socket.inet_ntop(family, raw)).is_loopback)
    return bool(addresses) and all(addresses)


class Lines:
    """Bounded memory-only lines. Never persist an unredacted partial line."""
    def __init__(self, process):
        self.process, self.rows = process, queue.Queue(maxsize=512)
        self.failed = False
        self.done = threading.Event()
        self.thread = threading.Thread(target=self.read, daemon=True)
        self.thread.start()

    def read(self):
        dropping = False
        try:
            while True:
                raw = self.process.stdout.readline(65537)
                if not raw:
                    return
                if dropping or len(raw) > 65536:
                    dropping = not raw.endswith(b'\n')
                    row = '[OVERSIZED_LINE_OMITTED]' if not dropping else None
                else:
                    row = raw.decode('utf-8', errors='replace').rstrip('\r\n')
                if row is not None:
                    self.rows.put(row, timeout=1)
        except Exception:
            self.failed = True
        finally:
            self.done.set()

    def take(self, timeout=.02):
        need(not self.failed, 'MEMORY_LINE_CAPTURE_FAILED_OR_OVERFLOWED')
        try:
            return self.rows.get(timeout=timeout)
        except queue.Empty:
            return None


def emit(text, private=()):
    print(scrub(text, private), flush=True)


def launch_command(adb, serial):
    # Exact debug-drive defaults from pinned Flutter3.44.6 run.dart169 and
    # android_device.dart: profiling, checked mode, entry verification, paused.
    return [str(adb), '-s', serial, 'shell', 'am', 'start', '-W', '-a', 'android.intent.action.MAIN',
            '-c', 'android.intent.category.LAUNCHER', '-f', '0x20000000',
            '--ez', 'enable-dart-profiling', 'true', '--ez', 'enable-checked-mode', 'true',
            '--ez', 'verify-entry-points', 'true', '--ez', 'start-paused', 'true', PACKAGE + '/.MainActivity']


def worker(args):
    root = Path.cwd().resolve()
    output = Path(args.output).resolve()
    output.relative_to(root / 'artifacts/qa/text18/android-api33-direct-vm')
    output.mkdir(parents=True, exist_ok=False)
    target, driver = SCOPES[args.scope]
    sdk = Path(os.environ['ANDROID_HOME']).resolve()
    adb = sdk / 'platform-tools/adb'
    need(adb.is_file() and re.fullmatch(r'emulator-[0-9]+', args.device), 'EXACT_EMULATOR_AND_EXISTING_ADB_REQUIRED')
    receipt = {'scope': args.scope, 'source_parent': PARENT, 'target': target, 'driver': driver,
               'serial': args.device, 'retry_count': 0, 'status': 'PREPARING',
               'private_vm_uri_saved': False, 'renderer_or_permissions_changed': False}
    private, collector, owned_pid, forward = [], None, None, None
    active = None

    def save():
        (output / 'transport-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')

    def remaining(cap=1800):
        seconds = min(cap, args.deadline - time.monotonic())
        need(seconds > 0, 'ORIGINAL_BOOTSTRAP_DEADLINE_EXPIRED')
        return seconds

    def capture(label, command, *, allow=False, cap=30, cleanup=False):
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=2 if cleanup else remaining(cap))
        raw = result.stdout.decode('utf-8', errors='replace')
        (output / (label + '.log')).write_text(scrub(raw, private), encoding='utf-8')
        receipt.setdefault('commands', []).append({'label': label, 'exit': result.returncode})
        need(allow or result.returncode == 0, 'COMMAND_FAILED_' + label.upper().replace('-', '_'))
        return result.returncode, raw

    def current_pid(*, cleanup=False):
        _, raw = capture('current-pid', [str(adb), '-s', args.device, 'shell', 'pidof', PACKAGE], allow=True, cleanup=cleanup)
        need(not raw.strip() or re.fullmatch(r'[1-9][0-9]*', raw.strip()), 'ONE_EXACT_PACKAGE_PID_REQUIRED')
        return int(raw.strip()) if raw.strip() else None

    def stream_command(label, command, cap=1800, *, bootstrap_only=True):
        nonlocal active
        active = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        lines = Lines(active)
        deadline = time.monotonic() + remaining(cap)
        with (output / (label + '.log')).open('x', encoding='utf-8') as safe:
            while active.poll() is None or not lines.done.is_set() or not lines.rows.empty():
                need(not bootstrap_only or time.monotonic() < deadline, 'COMMAND_DEADLINE_' + label.upper())
                row = lines.take()
                if row is not None:
                    clean = scrub(row, private)
                    safe.write(clean + '\n')
                    emit(clean)
        code = active.wait(timeout=1)
        active = None
        need(hashlib.sha256((root / 'pubspec.lock').read_bytes()).hexdigest() == PUB_LOCK, 'SOURCE_PUB_LOCK_CHANGED_DURING_COMMAND')
        need(code == 0, 'COMMAND_FAILED_' + label.upper())

    def cleanup():
        nonlocal active
        for process in (active, collector):
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=1)
        if forward is not None:
            host_port, device_port = forward
            _, rows = capture('cleanup-forward-list', [str(adb), '-s', args.device, 'forward', '--list'], cleanup=True)
            if own_forward(rows, args.device, host_port, device_port):
                capture('cleanup-owned-forward', [str(adb), '-s', args.device, 'forward', '--remove', 'tcp:' + str(host_port)], cleanup=True)
                _, after = capture('cleanup-forward-after', [str(adb), '-s', args.device, 'forward', '--list'], cleanup=True)
                need(not any(line.split()[1:2] == ['tcp:' + str(host_port)] for line in after.splitlines()), 'OWNED_FORWARD_REMOVAL_NOT_CONFIRMED')
            else:
                need(not any(line.split()[1:2] == ['tcp:' + str(host_port)] for line in rows.splitlines()), 'CLEANUP_MAPPING_OWNERSHIP_CHANGED')
        if owned_pid is not None and current_pid(cleanup=True) == owned_pid:
            capture('cleanup-owned-app', [str(adb), '-s', args.device, 'shell', 'am', 'force-stop', PACKAGE], cleanup=True)

    try:
        for prop, expected in [('ro.kernel.qemu', '1'), ('ro.build.version.sdk', '33'), ('ro.product.cpu.abi', 'x86_64')]:
            _, raw = capture('device-' + prop.replace('.', '-'), [str(adb), '-s', args.device, 'shell', 'getprop', prop])
            need(raw.strip() == expected, 'EXACT_API33_X64_OWNED_EMULATOR_REQUIRED')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], text=True).strip()
        need(head == os.environ['GITHUB_SHA'] and hashlib.sha256((root / 'pubspec.lock').read_bytes()).hexdigest() == PUB_LOCK, 'EXACT_SOURCE_AND_PUB_LOCK_REQUIRED')
        receipt.update(source_head=head, source_tree=tree)
        defines = ['BIL_ENVIRONMENT=testing', 'BIL_USE_SUPABASE=false']
        if args.scope == 'system-crypto':
            stream_command('original-system-crypto', ['flutter', 'test', target, '--no-pub', '--device-id', args.device,
                           '--reporter', 'expanded', '--dart-define=BIL_ENVIRONMENT=testing',
                           '--dart-define=BIL_USE_SUPABASE=false', '--dart-define=BIL_PAYMENTS_ENABLED=false', '--dart-define=BIL_ADS_ENABLED=false'], bootstrap_only=False)
            receipt['status'] = 'ORIGINAL_CRYPTO_COMMAND_EXIT_ZERO_REQUIRES_ACTUAL_TEST_RECEIPT'
            return 0
        defines += ['BIL_QA_SOURCE_HEAD=' + head, 'BIL_QA_SOURCE_FINGERPRINT=' + tree]
        if args.scope == 'native-feature-splashes':
            defines += ['BIL_QA_ANDROID_EMULATOR=true', 'BIL_QA_DEVICE_NAME=github-api33-pixel6']
        stream_command('same-debug-apk-build', ['flutter', 'build', 'apk', '--debug', '--no-pub',
                       '--target-platform', 'android-x64', '--target', target, *['--dart-define=' + d for d in defines]])
        apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
        need(apk.is_file() and not apk.is_symlink(), 'EXACT_QA_DEBUG_APK_REQUIRED')
        with zipfile.ZipFile(apk) as archive:
            need({n for n in archive.namelist() if n.endswith('/libflutter.so')} == {'lib/x86_64/libflutter.so'}, 'ACTUAL_X64_FLUTTER_APK_REQUIRED')
        aapts = sorted((sdk / 'build-tools').glob('*/aapt'))
        need(bool(aapts), 'EXISTING_SDK_AAPT_REQUIRED')
        _, badging = capture('actual-apk-badging', [str(aapts[-1]), 'dump', 'badging', str(apk)])
        need("package: name='" + PACKAGE + "'" in badging and 'application-debuggable' in badging
             and "launchable-activity: name='" + PACKAGE + ".MainActivity'" in badging, 'ACTUAL_DEBUG_PACKAGE_AND_ACTIVITY_REQUIRED')
        version = re.search(r'^version:\s*([^+\s]+)\+([0-9]+)\s*$', (root / 'pubspec.yaml').read_text(), re.M)
        need(version is not None and "versionCode='" + version[2] + "'" in badging
             and "versionName='" + version[1] + "'" in badging, 'ACTUAL_UNCHANGED_SOURCE_QA_VERSION_REQUIRED')
        need(hashlib.sha256((root / 'pubspec.lock').read_bytes()).hexdigest() == PUB_LOCK, 'SOURCE_PUB_LOCK_CHANGED_DURING_BUILD')
        receipt['apk_sha256'] = hashlib.sha256(apk.read_bytes()).hexdigest()
        receipt['defines'] = defines
        capture('force-stop-owned-package', [str(adb), '-s', args.device, 'shell', 'am', 'force-stop', PACKAGE])
        need(current_pid() is None, 'OLD_APP_PID_MUST_BE_GONE')
        capture('install-exact-apk', [str(adb), '-s', args.device, 'install', '-r', '-t', str(apk)], cap=120)
        need(current_pid() is None, 'NO_APP_PID_BEFORE_FRESH_CAPTURE')
        collector = subprocess.Popen([str(adb), '-s', args.device, 'shell', '-x', 'logcat', '-v', 'threadtime', '-T', '0'],
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        native = Lines(collector)
        marker = uuid.uuid4().hex
        capture('live-log-barrier', [str(adb), '-s', args.device, 'shell', 'log', '-p', 'i', '-t', 'BIL_DIRECT_VM', marker])
        end = time.monotonic() + remaining(20)
        while True:
            need(time.monotonic() < end and collector.poll() is None and not native.done.is_set(), 'FRESH_LOG_BARRIER_NOT_OBSERVED')
            row = native.take()
            if row and 'BIL_DIRECT_VM' in row and row.endswith(marker):
                break
        receipt['fresh_log_barrier_observed'] = True
        _, launched = capture('one-owned-launch', launch_command(adb, args.device))
        need('Error:' not in launched and 'Status: ok' in launched and 'not started' not in launched, 'ONE_LAUNCH_NOT_CONFIRMED')
        owned_pid = current_pid()
        need(owned_pid is not None, 'NEW_OWNED_LAUNCH_PID_REQUIRED')
        receipt['pid'] = owned_pid
        end = time.monotonic() + remaining(90)
        uri = None
        while uri is None:
            need(time.monotonic() < end and collector.poll() is None and not native.done.is_set(), 'CURRENT_PID_VM_DISCOVERY_FAILED')
            row = native.take()
            if row is not None:
                uri = vm_from_line(row, owned_pid)
        parsed = vm_authority(uri)
        private += [uri, parsed.path, parsed.path.strip('/')]
        need(current_pid() == owned_pid, 'OWNED_PID_CHANGED_BEFORE_FORWARD')
        _, allocated = capture('allocate-owned-forward', [str(adb), '-s', args.device, 'forward', 'tcp:0', 'tcp:' + str(parsed.port)])
        need(re.fullmatch(r'[1-9][0-9]{3,4}', allocated.strip()), 'ACTUAL_EPHEMERAL_FORWARD_PORT_REQUIRED')
        host = int(allocated.strip())
        need(1024 <= host <= 65535, 'BOUNDED_FORWARD_PORT_REQUIRED')
        forward = host, parsed.port
        _, mappings = capture('verify-owned-forward', [str(adb), '-s', args.device, 'forward', '--list'])
        need(own_forward(mappings, args.device, host, parsed.port) and loopback_listener(host), 'OWNED_LOOPBACK_ONLY_FORWARD_REQUIRED')
        host_uri = urlunsplit(('http', '127.0.0.1:' + str(host), parsed.path, '', ''))
        private.append(host_uri)
        receipt.update(device_port=parsed.port, host_port=host, loopback_listener_verified=True,
                       bootstrap_elapsed_seconds=1800 - max(0, args.deadline - time.monotonic()))
        need(current_pid() == owned_pid, 'OWNED_PID_CHANGED_BEFORE_DRIVER')
        save()
        command = ['flutter', '--verbose', 'drive', '--no-pub', '--device-id', args.device, '--target', target,
                   '--driver', driver, '--use-existing-app=' + host_uri, '--timeout', '1200']
        active = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        driver_lines = Lines(active)
        with (output / 'redacted-driver.log').open('x', encoding='utf-8') as safe:
            finished = None
            while True:
                need(collector.poll() is None and not native.done.is_set(), 'OWNED_NATIVE_LOG_STREAM_ENDED_DURING_DRIVER')
                line = driver_lines.take()
                if line is not None:
                    clean = scrub(line, private)
                    safe.write(clean + '\n')
                    emit(clean)
                for _ in range(64):
                    line = native.take(timeout=0)
                    if line is None:
                        break
                    match = LINE.fullmatch(line)
                    if match and int(match[1]) == owned_pid:
                        announced = vm_from_line(line, owned_pid)
                        need(announced is None or announced == uri, 'AMBIGUOUS_OR_CHANGED_OWNED_VM_AUTHORITY')
                        emit(match[3], private)
                if active.poll() is not None and driver_lines.done.is_set() and driver_lines.rows.empty():
                    finished = finished or time.monotonic()
                    # Same original iOS relay policy: final native counters may
                    # reach logcat shortly after the actual host driver exits.
                    if time.monotonic() - finished >= 2:
                        break
        code = active.wait(timeout=1)
        active = None
        need(hashlib.sha256((root / 'pubspec.lock').read_bytes()).hexdigest() == PUB_LOCK, 'SOURCE_PUB_LOCK_CHANGED_DURING_DRIVER')
        receipt['driver_exit'] = code
        receipt['status'] = 'DRIVER_EXIT_ZERO_ACTUAL_CASE_EVIDENCE_REQUIRED' if code == 0 else 'DRIVER_FAILED'
        return code
    except Exception as error:
        receipt.update(status='TRANSPORT_FAILED', error_type=type(error).__name__,
                       error_code=str(error) if re.fullmatch(r'[A-Z0-9_]+', str(error)) else 'NO_RAW_EXCEPTION_RECORDED')
        if collector is not None:
            receipt['collector_exit_at_failure'] = collector.poll()
        emit('BIL_ANDROID_DIRECT_VM_FAILURE ' + receipt.get('error_code', ''), private)
        return 1
    finally:
        try:
            save()
        except Exception:
            receipt['evidence_save_failed'] = True
        try:
            cleanup()
            receipt['owned_cleanup_completed'] = True
        except Exception as error:
            receipt['owned_cleanup_completed'] = False
            receipt['cleanup_error_type'] = type(error).__name__
        try:
            save()
        except Exception:
            emit('BIL_ANDROID_DIRECT_VM_EVIDENCE_SAVE_FAILED')
            receipt['evidence_save_failed'] = True
        if receipt.get('evidence_save_failed') or receipt.get('owned_cleanup_completed') is False:
            raise RuntimeError('OWNED_CLEANUP_OR_EVIDENCE_FAILURE')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=sorted(SCOPES), required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--log', required=True)
    parser.add_argument('--receipt', required=True)
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--deadline', type=float)
    args = parser.parse_args()
    need(sys.platform == 'linux' and re.fullmatch(r'emulator-[0-9]+', args.device), 'LINUX_OWNED_EMULATOR_ONLY')
    base = Path.cwd().resolve() / 'artifacts/qa/text18/android-api33-direct-vm'
    need(Path(args.output).resolve() == base / (args.scope + '-transport')
         and Path(args.log).resolve() == base / (args.scope + '.log')
         and Path(args.receipt).resolve() == base / (args.scope + '-result.json'), 'EXACT_SCOPE_EVIDENCE_PATHS_REQUIRED')
    if args.worker:
        need(args.deadline is not None and math.isfinite(args.deadline)
             and args.deadline <= time.monotonic() + 1800, 'ORIGINAL_BOOTSTRAP_DEADLINE_REQUIRED')
        def interrupt(signum, frame):
            raise InterruptedError('SUPERVISOR_INTERRUPTED')
        signal.signal(signal.SIGTERM, interrupt)
        return worker(args)
    started = time.monotonic()
    need(os.environ.get('GITHUB_EVENT_NAME') == 'push' and os.environ.get('GITHUB_REF') == BRANCH, 'EXACT_DIAGNOSTIC_PUSH_ONLY')
    command = [sys.executable, str(Path(__file__).resolve()), '--worker', '--scope', args.scope,
               '--device', args.device, '--output', args.output, '--log', args.log, '--receipt', args.receipt,
               '--deadline', str(started + 1800)]
    code = run_bounded(command, label=args.scope, log_path=args.log, receipt_path=args.receipt,
                       timeout_seconds=max(.001, 1800 - (time.monotonic() - started)),
                       running_timeout_seconds=1200, summary_grace_seconds=60)
    result = json.loads(Path(args.receipt).read_text())
    actual_tests = (result.get('first_test_after_seconds') is not None
                    and isinstance(result.get('native_summary'), str)
                    and 'All tests passed!' in result['native_summary']
                    and result.get('native_failure_summary_seen') is False)
    result['direct_vm_actual_case_summary_required'] = actual_tests
    result['direct_vm_final_exit'] = code if code else (0 if actual_tests else 1)
    Path(args.receipt).write_text(json.dumps(result, indent=2) + '\n')
    return result['direct_vm_final_exit']


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as error:
        print(json.dumps({'status': 'DIRECT_VM_REFUSAL', 'error_type': type(error).__name__}), flush=True)
        raise SystemExit(1)
