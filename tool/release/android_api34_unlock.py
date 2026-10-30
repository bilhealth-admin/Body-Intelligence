#!/usr/bin/env python3
"""Observe an API34 emulator; wake/dismiss keyguard only when actually needed."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

from prepare_api34_emulator_action import EVIDENCE, checked_path
from verify_android_startup_frame import inspect_window_state, WINDOW_FAILURE_CODES

DEADLINE_SECONDS = 30
COMMAND_SECONDS = 5
OUTPUT_LIMIT = 2 * 1024 * 1024


class BootstrapFailure(RuntimeError):
    def __init__(self, reason: str, code: int = 3):
        super().__init__(reason)
        self.code = code


class InitialStateNotReady(BootstrapFailure):
    """A boot policy field has not been published; never a license to send input."""


def known_boolean(values: list[str], label: str) -> bool:
    if not values:
        raise InitialStateNotReady('Missing ' + label)
    if any(value not in ('true', 'false') for value in values) or len(set(values)) != 1:
        raise BootstrapFailure('Unknown or conflicting ' + label)
    return values[0] == 'true'


def window_flags(text: str) -> tuple[bool, bool, bool]:
    # Ignore the saved LAST ANR snapshot, just as the unchanged startup focus guard does.
    history = re.search(r'^WINDOW MANAGER LAST ANR\b', text, re.MULTILINE)
    if history:
        live = re.search(r'^WINDOW MANAGER POLICY STATE\b', text[history.end():], re.MULTILINE)
        text = text[history.end() + live.start():] if live else ''
    awake = re.findall(r'\bmAwake=(\S+)', text)
    showing = re.findall(r'\bmKeyguardShowing=(\S+)', text)
    showing += re.findall(r'\bKeyguardServiceDelegate\s*\n\s*showing=(\S+)', text)
    restricted = re.findall(
        r'\bKeyguardServiceDelegate\s*\n\s*showing=\S+\s*\n\s*inputRestricted=(\S+)', text)
    # A missing field cannot conceal a contradictory field already present.
    for values, label in ((awake, 'awake state'), (showing, 'keyguard state'),
                          (restricted, 'keyguard input restriction')):
        if values:
            known_boolean(values, label)
    return (known_boolean(awake, 'awake state'), known_boolean(showing, 'keyguard state'),
            known_boolean(restricted, 'keyguard input restriction'))


def bootstrap(serial: str, evidence: Path, *, run=subprocess.run,
              clock=time.monotonic, sleep=time.sleep) -> dict:
    result = {'source_sha': os.environ.get('GITHUB_SHA'), 'serial': serial,
              'status': 'FAIL', 'commands': [], 'observations': [],
              'input_command_count': 0, 'command_retries': 0,
              'scope': 'API34 emulator unlock only; BIL has not been installed or launched'}
    start = clock()
    deadline = start + DEADLINE_SECONDS
    evidence.mkdir(parents=True, exist_ok=True)
    receipt = evidence / 'api34-state-aware-unlock.json'
    if receipt.exists():
        raise BootstrapFailure('Preserving an existing unlock receipt')

    def command(args: list[str], *, global_adb: bool = False) -> str:
        remaining = deadline - clock()
        if remaining <= 0:
            raise BootstrapFailure('API34 unlock observation deadline expired')
        argv = ['adb', *([] if global_adb else ['-s', serial]), *args]
        row = {'argv': argv, 'timeout_seconds': min(COMMAND_SECONDS, remaining)}
        result['commands'].append(row)
        completed = run(argv, capture_output=True, text=True,
                        timeout=row['timeout_seconds'], check=False)
        row['returncode'] = completed.returncode
        if clock() >= deadline:
            raise BootstrapFailure('API34 unlock observation deadline expired after command')
        if completed.returncode:
            raise BootstrapFailure('ADB command failed; no input retry')
        if len((completed.stdout + completed.stderr).encode()) > OUTPUT_LIMIT:
            raise BootstrapFailure('ADB state exceeded the bounded capture limit')
        return completed.stdout.replace('\r\n', '\n').strip()

    def observe(*, initial_readiness: bool = False) -> dict:
        text = command(['shell', 'dumpsys', 'window'])
        path = evidence / f'api34-unlock-window-{len(result["observations"]):02d}.txt'
        path.write_text(text + '\n', encoding='utf-8')
        focus = inspect_window_state(path)
        row = {**focus, 'elapsed_seconds': round(clock() - start, 3), 'state_file': path.name}
        result['observations'].append(row)
        if focus['window_status'] in ('APP_ANR', 'EXTERNAL_APP_ANR', 'EMULATOR_SYSTEM_UI_ANR'):
            raise BootstrapFailure('Live ANR blocks unlock input: ' + focus['window_status'],
                                   WINDOW_FAILURE_CODES[focus['window_status']])
        if focus.get('focus_reason') == 'CONFLICTING_LIVE_FOCUS':
            raise BootstrapFailure('Contradictory live focus; refusing synthetic unlock input')
        try:
            awake, showing, restricted = window_flags(text)
        except InitialStateNotReady as error:
            if not initial_readiness:
                raise
            row.update(policy_ready=False, initial_readiness=str(error))
            return row
        row.update(awake=awake, keyguard_showing=showing,
                   keyguard_input_restricted=restricted, keyguard_locked=showing or restricted,
                   policy_ready=True)
        if focus['window_status'] == 'FOCUSED_WINDOW_UNAVAILABLE':
            if not initial_readiness:
                raise BootstrapFailure('Unknown live focus after input; no repeated unlock')
            row['initial_readiness'] = 'Live focus not yet published'
        return row

    def wait_for(predicate, *, initial_readiness: bool = False) -> dict:
        while True:
            state = observe(initial_readiness=initial_readiness)
            if predicate(state):
                return state
            if clock() >= deadline:
                raise BootstrapFailure('Initial readiness observation deadline expired' if initial_readiness
                                       else 'State did not confirm the one-time unlock action')
            sleep(min(0.25, max(0, deadline - clock())))

    try:
        if not re.fullmatch(r'emulator-[0-9]{4,5}', serial):
            raise BootstrapFailure('Only an emulator serial is permitted')
        devices = command(['devices', '-l'], global_adb=True).splitlines()
        if not devices or devices[0].strip() != 'List of devices attached':
            raise BootstrapFailure('Unknown ADB target inventory')
        rows = [line.split() for line in devices[1:] if line.strip()]
        if len(rows) != 1 or rows[0][:2] != [serial, 'device']:
            raise BootstrapFailure('Require exactly one online emulator and no other ADB targets')
        if command(['shell', 'getprop', 'ro.kernel.qemu']) != '1':
            raise BootstrapFailure('Refusing a non-emulator target')
        if command(['shell', 'getprop', 'ro.build.version.sdk']) != '34':
            raise BootstrapFailure('This bootstrap is restricted to API34')
        if command(['shell', 'getprop', 'sys.boot_completed']) != '1':
            raise BootstrapFailure('The action must first confirm boot completion')
        state = wait_for(lambda value: value.get('policy_ready') is True and
                         value['window_status'] != 'FOCUSED_WINDOW_UNAVAILABLE',
                         initial_readiness=True)
        if not state['awake'] or state['keyguard_locked']:
            if not re.search(r'^Service input: found\b', command(['shell', 'service', 'check', 'input'])):
                raise BootstrapFailure('Input service is not ready; no synthetic input sent')
        if not state['awake']:
            result['input_command_count'] += 1
            command(['shell', 'input', 'keyevent', '224'])  # KEYCODE_WAKEUP, never MENU/toggle.
            state = wait_for(lambda value: value['awake'])
        if state['keyguard_locked']:
            result['input_command_count'] += 1
            command(['shell', 'wm', 'dismiss-keyguard'])
            state = wait_for(lambda value: value['awake'] and not value['keyguard_locked'])
        result['status'] = 'AWAKE_UNLOCKED_FOCUS_CONFIRMED'
        result['final_state'] = state
        result['exit_code'] = 0
    except (BootstrapFailure, OSError, subprocess.SubprocessError) as error:
        result.update(reason=str(error), error_type=type(error).__name__,
                      exit_code=error.code if isinstance(error, BootstrapFailure) else 2)
    finally:
        result['elapsed_seconds'] = round(clock() - start, 3)
        receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    result = bootstrap(args.serial, checked_path(args.evidence_dir, EVIDENCE))
    print(json.dumps({key: result[key] for key in ('status', 'exit_code', 'input_command_count')}))
    return result['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
