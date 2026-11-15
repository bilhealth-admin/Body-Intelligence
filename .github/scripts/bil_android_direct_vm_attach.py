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
REPOSITORY = 'bilhealth-admin/Body-Intelligence'
WORKFLOW = '.github/workflows/bil_codeql_security_extended.yml'
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
    return [str(adb), '-s', serial, 'shell', 'am', 'start', '-a', 'android.intent.action.MAIN',
            '-c', 'android.intent.category.LAUNCHER', '-f', '0x20000000',
            '--ez', 'enable-dart-profiling', 'true', '--ez', 'enable-checked-mode', 'true',
            '--ez', 'verify-entry-points', 'true', '--ez', 'start-paused', 'true', PACKAGE + '/.MainActivity']


def require_source_caller(deadline=None):
    # Existing workflow owns branch/input selection. Preserve push, PR merge
    # commits and explicitly selected manual native QA; this is not signing.
    event = os.environ.get('GITHUB_EVENT_NAME')
    ref = os.environ.get('GITHUB_REF', '')
    need(os.environ.get('GITHUB_ACTIONS') == 'true'
         and os.environ.get('GITHUB_REPOSITORY') == REPOSITORY
         and os.environ.get('GITHUB_JOB') == 'android-native-only'
         and os.environ.get('GITHUB_WORKFLOW_REF') == REPOSITORY + '/' + WORKFLOW + '@' + ref
         and event in ('push', 'pull_request', 'workflow_dispatch')
         and ((event == 'pull_request' and re.fullmatch(r'refs/pull/[1-9][0-9]*/merge', ref))
              or (event in ('push', 'workflow_dispatch') and re.fullmatch(r'refs/(?:heads|tags)/[^\s]+', ref))),
         'EXACT_EXISTING_CODEQL_NATIVE_CALLER_REQUIRED')
    remaining = 30 if deadline is None else min(30, deadline - time.monotonic())
    need(remaining > 0, 'ORIGINAL_CALLER_DEADLINE_EXPIRED')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True, timeout=remaining).strip()
    need(re.fullmatch(r'[a-f0-9]{40}', head) and head == os.environ.get('GITHUB_SHA'), 'EXACT_CURRENT_SOURCE_HEAD_REQUIRED')


def raw_commit_parents(raw, tree):
    # Revision walking hides shallow-boundary parents. The commit object's
    # header retains every actual parent, including both parents of a PR merge.
    header = raw.split('\n\n', 1)[0].splitlines()
    need(bool(header) and header[0] == 'tree ' + tree, 'ACTUAL_COMMIT_TREE_HEADER_REQUIRED')
    parents = [line[7:] for line in header if line.startswith('parent ')]
    need(all(re.fullmatch(r'[a-f0-9]{40}', parent) for parent in parents), 'ACTUAL_COMMIT_PARENT_HEADERS_REQUIRED')
    return parents


def redacted_failure_logcat(device):
    """Bounded fixed read, memory only until every private VM token is known."""
    adb = Path(os.environ['ANDROID_HOME']).resolve() / 'platform-tools/adb'
    need(adb.is_file(), 'EXISTING_ADB_REQUIRED')
    process = subprocess.Popen([str(adb), '-s', device, 'logcat', '-d', '-t', '1000'],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = Lines(process)
    captured, size = [], 0
    deadline = time.monotonic() + 25
    try:
        while process.poll() is None or not lines.done.is_set() or not lines.rows.empty():
            need(time.monotonic() < deadline, 'PUBLIC_LOGCAT_MEMORY_CAPTURE_DEADLINE')
            row = lines.take()
            if row is not None:
                need(row != '[OVERSIZED_LINE_OMITTED]', 'PUBLIC_LOGCAT_OVERSIZED_LINE_REFUSED')
                size += len(row.encode('utf-8'))
                need(size <= 2 * 1024 * 1024, 'PUBLIC_LOGCAT_MEMORY_CAPTURE_LIMIT')
                captured.append(row)
        code = process.wait(timeout=1)
        need(code == 0, 'PUBLIC_LOGCAT_CAPTURE_FAILED')
        private = []
        for row in captured:
            for match in URL.finditer(row):
                try:
                    value = vm_authority(match[0])
                    private += [value.path, value.path.strip('/')]
                except ValueError:
                    pass
        for row in captured:
            emit(row, private)
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=1)
        process.stdout.close()


def fresh_log_capture(adb, serial, deadline, receipt):
    """One subscription handshake; all waits/write/echo share the same20s."""
    started = time.monotonic()
    end = min(deadline, started + 20)
    need(end > started, 'ORIGINAL_BOOTSTRAP_DEADLINE_EXPIRED')
    state = {'status': 'WAITING_FIRST_VALID_ENTRY', 'rows': 0, 'valid_rows': 0,
             'first_valid_tag': None, 'first_valid_after_seconds': None,
             'marker_writes': 0, 'marker_exit': None}
    receipt['fresh_log_handshake'] = state
    collector = subprocess.Popen([str(adb), '-s', serial, 'shell', '-x', 'logcat',
                                  '-v', 'threadtime', '-T', '1'],
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    native = Lines(collector)

    def remaining():
        seconds = end - time.monotonic()
        need(seconds > 0, 'FRESH_LOG_HANDSHAKE_DEADLINE_EXPIRED')
        need(collector.poll() is None and not native.done.is_set(), 'FRESH_LOG_READER_ENDED')
        return seconds

    def read():
        row = native.take(timeout=min(.02, remaining()))
        remaining()  # A blocking read cannot turn a late record into PASS.
        if row is None:
            return None
        state['rows'] += 1
        match = LINE.fullmatch(row)
        if match:
            state['valid_rows'] += 1
        return match

    try:
        first = None
        while first is None:
            first = read()
        tag = first[2].strip()
        state['first_valid_tag'] = tag if tag in ('flutter', 'BIL_DIRECT_VM', 'ActivityManager', 'logd') else 'OTHER'
        state['first_valid_after_seconds'] = round(time.monotonic() - started, 3)
        state['status'] = 'WRITING_ONE_MARKER'
        marker = uuid.uuid4().hex
        timeout = remaining()
        state['marker_writes'] = 1
        result = subprocess.run([str(adb), '-s', serial, 'shell', 'log', '-p', 'i', '-t', 'BIL_DIRECT_VM', marker],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        state['marker_exit'] = result.returncode
        remaining()
        need(result.returncode == 0, 'FRESH_LOG_MARKER_COMMAND_FAILED')
        state['status'] = 'WAITING_EXACT_MARKER'
        while True:
            match = read()
            if match and match[2].strip() == 'BIL_DIRECT_VM' and match[3] == marker:
                break
        state['status'] = 'EXACT_FRESH_MARKER_OBSERVED'
        receipt['fresh_log_barrier_observed'] = True
        return collector, native
    except Exception as error:
        state['failed_stage'] = state['status']
        state['status'] = 'FAILED'
        state.update(collector_exit_at_failure=collector.poll(), reader_eof_at_failure=native.done.is_set() and not native.failed,
                     reader_failed_at_failure=native.failed, failure_error_type=type(error).__name__,
                     failure_code=str(error) if re.fullmatch(r'[A-Z0-9_]+', str(error)) else 'NO_RAW_EXCEPTION_RECORDED')
        try:
            if collector.poll() is None:
                collector.terminate()
                try:
                    collector.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    collector.kill()
                    collector.wait(timeout=1)
            state['owned_reader_cleanup_completed'] = True
        except Exception as cleanup_error:
            state.update(owned_reader_cleanup_completed=False, cleanup_error_type=type(cleanup_error).__name__)
        raise
    finally:
        state.update(elapsed_seconds=round(time.monotonic() - started, 3),
                     collector_exit=collector.poll(), reader_eof=native.done.is_set() and not native.failed, reader_failed=native.failed)

def barrier_preflight(args):
    # The existing outer30s collector bounds property/PID reads, the shared20s
    # handshake and owned-reader teardown. This is not an application test.
    receipt = {'status': 'LOG_BARRIER_PREFLIGHT_FAILED', 'application_test_cases': 0,
               'release_acceptance': False, 'private_body_or_nonce_saved': False}
    collector = None
    output = Path(args.receipt).resolve()
    need(output == Path.cwd().resolve() / 'artifacts/qa/text18/android-api33/barrier-preflight.json', 'EXACT_PREFLIGHT_RECEIPT_REQUIRED')
    deadline = time.monotonic() + 25
    adb = Path(os.environ['ANDROID_HOME']).resolve() / 'platform-tools/adb'
    need(adb.is_file(), 'EXISTING_ADB_REQUIRED')
    try:
        for prop, expected in [('ro.kernel.qemu', '1'), ('ro.build.version.sdk', '33'), ('ro.product.cpu.abi', 'x86_64')]:
            result = subprocess.run([str(adb), '-s', args.device, 'shell', 'getprop', prop], stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=max(.001, min(3, deadline - time.monotonic())))
            need(result.returncode == 0 and result.stdout.decode().strip() == expected, 'EXACT_API33_X64_OWNED_EMULATOR_REQUIRED')
        result = subprocess.run([str(adb), '-s', args.device, 'shell', 'pidof', PACKAGE], stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=max(.001, min(3, deadline - time.monotonic())))
        need(result.returncode == 1 and not result.stdout.strip(), 'PREFLIGHT_REQUIRES_NO_APP_PID')
        collector, _ = fresh_log_capture(adb, args.device, deadline, receipt)
        receipt['status'] = 'LOG_BARRIER_PREFLIGHT_PASS_NO_APP_CASES'
        return 0
    except Exception as error:
        receipt.update(error_type=type(error).__name__, error_code=str(error) if re.fullmatch(r'[A-Z0-9_]+', str(error)) else 'NO_RAW_EXCEPTION_RECORDED')
        return 1
    finally:
        cleanup_error = None
        if collector is not None and collector.poll() is None:
            try:
                collector.terminate()
                try:
                    collector.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    collector.kill()
                    collector.wait(timeout=1)
            except Exception as error:
                cleanup_error = type(error).__name__
                receipt.update(status='LOG_BARRIER_PREFLIGHT_FAILED', cleanup_error_type=cleanup_error)
        receipt['owned_cleanup_completed'] = cleanup_error is None and receipt.get('fresh_log_handshake', {}).get('owned_reader_cleanup_completed', True)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(receipt, indent=2) + '\n')
        if not receipt['owned_cleanup_completed']:
            raise RuntimeError('PREFLIGHT_OWNED_CLEANUP_FAILED')


def worker(args):
    root = Path.cwd().resolve()
    output = Path(args.output).resolve()
    output.relative_to(root / 'artifacts/qa/text18/android-api33')
    output.mkdir(parents=True, exist_ok=False)
    target, driver = SCOPES[args.scope]
    sdk = Path(os.environ['ANDROID_HOME']).resolve()
    adb = sdk / 'platform-tools/adb'
    need(adb.is_file() and re.fullmatch(r'emulator-[0-9]+', args.device), 'EXACT_EMULATOR_AND_EXISTING_ADB_REQUIRED')
    receipt = {'scope': args.scope, 'target': target, 'driver': driver,
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

    def current_pid(*, cleanup=False, cap=30):
        _, raw = capture('current-pid', [str(adb), '-s', args.device, 'shell', 'pidof', PACKAGE], allow=True, cleanup=cleanup, cap=cap)
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
        raw_commit = subprocess.check_output(['git', 'cat-file', '-p', 'HEAD'], text=True, timeout=remaining(30))
        parents = raw_commit_parents(raw_commit, tree)
        need(head == os.environ['GITHUB_SHA'] and hashlib.sha256((root / 'pubspec.lock').read_bytes()).hexdigest() == PUB_LOCK, 'EXACT_SOURCE_AND_PUB_LOCK_REQUIRED')
        receipt.update(source_head=head, source_tree=tree, source_parents=parents,
                       source_event=os.environ['GITHUB_EVENT_NAME'], source_ref=os.environ['GITHUB_REF'],
                       source_workflow=WORKFLOW, source_job='android-native-only')
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
        collector, native = fresh_log_capture(adb, args.device, args.deadline, receipt)
        launch_exit, launched = capture('one-owned-launch', launch_command(adb, args.device), allow=True)
        end = time.monotonic() + remaining(90)
        # Like the SDK, am start is nonwaiting. The one existing90s window
        # covers both process creation and its actual VM announcement.
        seconds = end - time.monotonic()
        need(seconds > 0, 'CURRENT_PID_VM_DISCOVERY_FAILED')
        owned_pid = current_pid(cap=min(3, seconds))
        need(launch_exit == 0 and 'Error: ' not in launched, 'ONE_LAUNCH_NOT_CONFIRMED')
        while owned_pid is None:
            seconds = end - time.monotonic()
            need(seconds > 0 and collector.poll() is None and not native.done.is_set(), 'NEW_OWNED_LAUNCH_PID_REQUIRED')
            owned_pid = current_pid(cap=min(3, seconds))
        need(time.monotonic() < end, 'CURRENT_PID_VM_DISCOVERY_FAILED')
        receipt['pid'] = owned_pid
        uri = None
        while uri is None:
            seconds = end - time.monotonic()
            need(seconds > 0 and collector.poll() is None and not native.done.is_set(), 'CURRENT_PID_VM_DISCOVERY_FAILED')
            row = native.take(timeout=min(.02, seconds))
            need(time.monotonic() < end, 'CURRENT_PID_VM_DISCOVERY_FAILED')
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
            receipt['owned_cleanup_completed'] = receipt.get('fresh_log_handshake', {}).get('owned_reader_cleanup_completed', True)
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
    parser.add_argument('--scope', choices=sorted(SCOPES))
    parser.add_argument('--device', required=True)
    parser.add_argument('--output')
    parser.add_argument('--log')
    parser.add_argument('--receipt')
    parser.add_argument('--redact-logcat', action='store_true')
    parser.add_argument('--barrier-preflight', action='store_true')
    parser.add_argument('--worker', action='store_true')
    parser.add_argument('--deadline', type=float)
    args = parser.parse_args()
    started = time.monotonic()
    need(sys.platform == 'linux' and re.fullmatch(r'emulator-[0-9]+', args.device), 'LINUX_OWNED_EMULATOR_ONLY')
    if args.worker:
        need(args.deadline is not None and math.isfinite(args.deadline)
             and args.deadline <= started + 1800, 'ORIGINAL_BOOTSTRAP_DEADLINE_REQUIRED')
    require_source_caller(args.deadline if args.worker else started + (30 if args.redact_logcat or args.barrier_preflight else 1800))
    if args.barrier_preflight:
        need(not args.redact_logcat and not args.worker and args.scope is None and args.output is None
             and args.log is None and args.receipt is not None and args.deadline is None, 'EXACT_PREFLIGHT_ARGUMENTS_REQUIRED')
        return barrier_preflight(args)
    if args.redact_logcat:
        need(not args.worker and args.scope is None and args.output is None and args.log is None
             and args.receipt is None and args.deadline is None, 'FIXED_FAILURE_LOGCAT_READ_ONLY')
        return redacted_failure_logcat(args.device)
    need(args.scope is not None and args.output and args.log and args.receipt, 'EXACT_NATIVE_SCOPE_ARGUMENTS_REQUIRED')
    base = Path.cwd().resolve() / 'artifacts/qa/text18/android-api33'
    need(Path(args.output).resolve() == base / (args.scope + '-transport')
         and Path(args.log).resolve() == base / (args.scope + '.log')
         and Path(args.receipt).resolve() == base / (args.scope + '-result.json'), 'EXACT_SCOPE_EVIDENCE_PATHS_REQUIRED')
    if args.worker:
        def interrupt(signum, frame):
            raise InterruptedError('SUPERVISOR_INTERRUPTED')
        signal.signal(signal.SIGTERM, interrupt)
        return worker(args)
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
