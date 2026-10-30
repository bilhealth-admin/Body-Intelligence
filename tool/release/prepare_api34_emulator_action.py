#!/usr/bin/env python3
"""Patch one MENU injection in an owned, exact-pinned API34 action checkout."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PIN = '4c44018e59b437e86cdfc41da381398f93ed8808'
COMMIT = 'a421e43855164a8197daf9d8d40fe71c6996bb0d'
OWNED = Path('artifacts/tooling/bil-api34-emulator-action')
EVIDENCE = Path('artifacts/release/android_emulator_smoke/api-34')
PINNED_FILES = {
    'action.yml': ('a7c4de9a466ae7d70a599ffdc5a27b2bccadd7b2d602e24b44f8b490cb7bbdfe',
                   '4f9767ce6c4ecbe37e35cf0c1246ec1c79dfd51a'),
    'lib/main.js': ('8121ea56f1c89d470071e89f80e15f932b2d8d5f711c28fc99476f34a442bc35',
                    '98f6404696c17f8923ebf7ff7b81f249576fcaf4'),
    'lib/emulator-manager.js': ('a63db8fe9ffb4fb3651e9a2c97f8bac5ca4ce0078a7bbe61ef2e02019082c577',
                                'e878461a849d9f71420dea8cbd7e30e98a1e8710'),
}
MENU = b'        await adb(port, `shell input keyevent 82`);\n'


def checked_path(value: Path, expected: Path) -> Path:
    target = ROOT / value
    expected = ROOT / expected
    if target.absolute() != expected.absolute():
        raise ValueError('Refusing a path outside the exact owned API34 location')
    for path in (target, *target.parents):
        if path.is_symlink():
            raise ValueError('Refusing a symlinked API34 tooling path')
        if path == ROOT:
            break
    if target.resolve() != expected.absolute():
        raise ValueError('Owned API34 path did not resolve as expected')
    return target


def git(action: Path, *args: str) -> str:
    return subprocess.check_output(
        ['git', '-C', str(action), *args], text=True, timeout=10,
        stderr=subprocess.PIPE,
    ).strip()


def prepare(action_dir: Path, evidence_dir: Path) -> dict:
    action = checked_path(action_dir, OWNED)
    evidence = checked_path(evidence_dir, EVIDENCE)
    if not (action / '.git').is_dir() or (action / '.git').is_symlink():
        raise ValueError('A separate owned Git checkout is required')
    if git(action, 'rev-parse', '--show-toplevel').replace('\\', '/') != action.as_posix():
        raise ValueError('The action Git root is not its owned checkout')
    # This exact upstream pin is an annotated tag object; verify both immutable objects.
    if (git(action, 'cat-file', '-t', PIN) != 'tag' or
            git(action, 'rev-parse', PIN + '^{commit}') != COMMIT or
            git(action, 'rev-parse', 'HEAD') != COMMIT):
        raise ValueError('The emulator action HEAD differs from the reviewed pin')
    if git(action, 'remote', 'get-url', 'origin').removesuffix('.git').casefold() != (
            'https://github.com/reactivecircus/android-emulator-runner'):
        raise ValueError('Unexpected emulator action origin')
    if (git(action, 'status', '--porcelain', '--untracked-files=all') or
            git(action, 'ls-files', '--others', '--ignored', '--exclude-standard')):
        raise ValueError('The owned action checkout is not pristine')
    if not (action / 'node_modules').is_dir():
        raise ValueError('The pin must supply its original checked-in dependencies')
    sources = {}
    for name, (sha256, blob) in PINNED_FILES.items():
        path = action / name
        for parent in (path, *path.parents):
            if parent.is_symlink():
                raise ValueError('Refusing a symlinked action entrypoint')
            if parent == action:
                break
        data = path.read_bytes()
        if (hashlib.sha256(data).hexdigest() != sha256 or
                hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() != blob):
            raise ValueError('Pinned action source identity mismatch: ' + name)
        sources[name] = data
    source = sources['lib/emulator-manager.js']
    if source.count(MENU) != 1:
        raise ValueError('Expected exactly one reviewed unconditional MENU statement')
    helper = ROOT / 'tool/release/android_api34_unlock.py'
    if not helper.is_file() or helper.is_symlink():
        raise ValueError('The reviewed state-aware helper is unavailable')
    # exec receives an argv array; neither workspace nor evidence paths become shell code.
    replacement = ('        await exec.exec(\'python3\', [' + json.dumps(str(helper)) +
                   ', \'--serial\', `emulator-${port}`, \'--evidence-dir\', ' +
                   json.dumps(str(evidence)) + ']);\n').encode()
    patched = source.replace(MENU, replacement)
    (action / 'lib/emulator-manager.js').write_bytes(patched)
    return {
        'status': 'PIN_VERIFIED_SINGLE_MENU_REPLACED',
        'action_pin_object': PIN, 'action_commit': COMMIT,
        'action_path': str(action), 'original_files': {
            name: {'sha256': hashes[0], 'git_blob': hashes[1]}
            for name, hashes in PINNED_FILES.items()
        },
        'changed_file': 'lib/emulator-manager.js', 'replacements': 1,
        'patched_sha256': hashlib.sha256(patched).hexdigest(),
        'helper_sha256': hashlib.sha256(helper.read_bytes()).hexdigest(),
        'scope': 'Owned API34 bootstrap only; no emulator or BIL acceptance claim',
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action-dir', type=Path, required=True)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args()
    evidence = checked_path(args.evidence_dir, EVIDENCE)
    evidence.mkdir(parents=True, exist_ok=True)
    receipt = evidence / 'api34-action-preparation.json'
    if receipt.exists():
        raise ValueError('Preserving an existing action preparation receipt')
    try:
        result = prepare(args.action_dir, args.evidence_dir)
        code = 0
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        result = {'status': 'FAIL', 'error_type': type(error).__name__,
                  'reason': str(error), 'action_pin_object': PIN, 'action_commit': COMMIT}
        code = 1
    receipt.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
