"""Require OS provisioning within one budget; never claim application acceptance."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import sys
import time

from bil_native_bounded_command import run_bounded


def budget_seconds(runtime):
    match = re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)(?:-[A-Za-z0-9]+)*', runtime)
    if not match:
        raise ValueError('Exact selected iOS runtime identifier required')
    return 600 if int(match.group(1)) == 27 else 180


def host_resources(output):
    values = {'cpu_count': os.cpu_count()}
    for name, read in [('load_average', os.getloadavg if hasattr(os, 'getloadavg') else lambda: None),
                       ('physical_memory_bytes', lambda: os.sysconf('SC_PHYS_PAGES') * os.sysconf('SC_PAGE_SIZE')),
                       ('free_disk_bytes', lambda: shutil.disk_usage(output).free)]:
        try:
            values[name] = read()
        except (AttributeError, OSError, ValueError):
            values[name] = None
    return values


def require_os_readiness(device, runtime, output, label, *, run=run_bounded,
                         clock=time.monotonic, resources=host_resources, host=sys.platform):
    if not re.fullmatch(r'[A-Za-z0-9_.-]{1,70}', label):
        raise ValueError('Safe OS provisioning label required')
    if not re.fullmatch(r'[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}', device):
        raise ValueError('Exact Simulator UUID required')
    budget = budget_seconds(runtime)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = output / (label + '-os-readiness.json')
    if receipt_path.exists():
        raise ValueError('Fresh OS provisioning receipt required; no repeat')
    started = clock()
    commands, code, reason, boot_request = [], 0, 'completed', 'NOT_ISSUED'
    before = after = None

    def command(suffix, argv):
        remaining = budget - (clock() - started)
        if remaining <= 0:
            raise TimeoutError('OS budget exhausted before ' + suffix)
        phase = {'stage': suffix, 'remaining_budget_before_seconds': remaining,
                 'elapsed_before_seconds': clock() - started}
        commands.append(phase)
        log = output / (label + '-' + suffix + '.log')
        result = output / (label + '-' + suffix + '-result.json')
        if log.exists() or result.exists():
            raise ValueError('Fresh OS stage evidence required')
        began = clock()
        status = None
        try:
            status = run(argv, label=label + '-' + suffix, log_path=log,
                         receipt_path=result, timeout_seconds=remaining,
                         kill_grace_seconds=min(5, remaining))
        finally:
            phase.update(returncode=status, actual_elapsed_seconds=clock() - began,
                         total_elapsed_after_seconds=clock() - started,
                         deadline_overshoot_seconds=max(0, clock() - started - budget))
        if not isinstance(status, int) or isinstance(status, bool):
            raise ValueError('Exact bounded subprocess exit required')
        if status != 0:
            raise ChildProcessError(status, 'OS command failed: ' + suffix)
        if clock() - started >= budget:
            raise TimeoutError('OS command returned after total deadline: ' + suffix)
        return log

    def device_state(suffix):
        log = command(suffix, ['xcrun', 'simctl', 'list', 'devices', '-j'])
        rows = json.loads(log.read_text(encoding='utf8'))['devices'].get(runtime, [])
        exact = [row for row in rows if row.get('udid') == device]
        if len(exact) != 1:
            raise ValueError('Exact device in selected runtime required')
        return exact[0]['state']

    try:
        if host != 'darwin':
            raise ValueError('OS provisioning runs only on the native macOS QA host')
        before = resources(output)
        state = device_state('os-initial-state')
        if state == 'Shutdown':
            boot_request = 'ISSUED_ONCE'
            command('boot', ['xcrun', 'simctl', 'boot', device])
        elif state in {'Booted', 'Booting'}:
            boot_request = 'SKIPPED_ALREADY_' + state.upper()
        else:
            raise ValueError('Unsupported initial Simulator state: ' + state)
        command('bootstatus', ['xcrun', 'simctl', 'bootstatus', device, '-b'])
        if device_state('os-ready-state') != 'Booted':
            raise ValueError('Booted OS state required after bootstatus')
        screenshot = output / (label + '-os-readiness.png')
        if screenshot.exists():
            raise ValueError('Fresh OS screenshot required')
        command('os-screenshot', ['xcrun', 'simctl', 'io', device, 'screenshot', str(screenshot)])
        with screenshot.open('rb') as handle:
            header = handle.read(24)
        if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n' or min(struct.unpack('>II', header[16:24])) <= 0:
            raise ValueError('Nonempty OS screenshot PNG required')
        guest = command('os-guest-health', ['xcrun', 'simctl', 'spawn', device, 'launchctl', 'print', 'system'])
        if guest.stat().st_size == 0:
            raise ValueError('Responsive guest launchctl output required')
    except TimeoutError as error:
        code, reason = 124, str(error)
    except ChildProcessError as error:
        code, reason = error.args
    except Exception as error:
        code, reason = 2, type(error).__name__ + ':' + str(error)
    finally:
        try:
            after = resources(output)
        except Exception as error:
            after = {'resource_capture_error': type(error).__name__}
        elapsed = clock() - started
        if code == 0 and elapsed >= budget:
            code, reason = 124, 'OS total deadline exceeded before application work'
        receipt = {'scope': 'OS provisioning only; no application build, installation, XCTest or frame acceptance',
                   'runtime': runtime, 'device': device, 'total_budget_seconds': budget,
                   'actual_elapsed_seconds': elapsed, 'deadline_overshoot_seconds': max(0, elapsed - budget),
                   'boot_request': boot_request, 'commands': commands, 'resources_before': before,
                   'resources_after': after, 'effective_returncode': code, 'reason': reason,
                   'status': 'OS_READY' if code == 0 else 'FAILED_CLOSED',
                   'application_acceptance': False, 'native_tests_proven': False, 'no_retry': True}
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--runtime', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    return require_os_readiness(args.device, args.runtime, args.output, args.label)


if __name__ == '__main__':
    raise SystemExit(main())
