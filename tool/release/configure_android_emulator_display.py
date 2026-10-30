#!/usr/bin/env python3
"""Bound the API34/36 CI framebuffer without changing their OS or GPU.

The pinned emulator-runner hook executes after AVD creation and before launch.
Only Android's supported hw.lcd.width/height/density configuration properties
are changed. Runtime physical-display readback must match; no wm override,
ANR dismissal, launch retry, or startup acceptance is performed here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

REVIEWED_APIS = (26, 29, 33, 34, 35, 36)
DISPLAY = {'hw.lcd.width': '720', 'hw.lcd.height': '1280', 'hw.lcd.density': '320'}
WM_TIMEOUT_SECONDS = 8


class DisplayContractError(ValueError):
    def __init__(self, message: str, receipt: dict | None = None):
        super().__init__(message)
        self.receipt = receipt or {}


def required_display(api: int) -> dict[str, str] | None:
    if api not in REVIEWED_APIS:
        raise ValueError('Unsupported Android API')
    return dict(DISPLAY) if api in (34, 36) else None


def configure_display(api: int, config: Path) -> dict:
    expected = required_display(api)
    if expected is None:
        return {'status': 'UNCHANGED_API', 'api_level': api, 'changed': False}
    if config.name != 'config.ini' or not config.parent.name.endswith('.avd'):
        raise DisplayContractError('Expected an existing AVD config.ini')
    if config.is_symlink() or not config.is_file():
        raise DisplayContractError('AVD configuration is missing or is a symbolic link')
    original = config.read_bytes()
    text = original.decode('utf-8')
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = []
    written = set()
    for line in text.splitlines(keepends=True):
        match = re.match(r'^\s*(hw\.lcd\.(?:width|height|density))\s*=', line)
        if match:
            key = match[1]
            if key not in written:
                lines.append(f'{key}={expected[key]}{newline}')
                written.add(key)
        else:
            lines.append(line)
    if lines and not lines[-1].endswith(('\n', '\r')):
        lines[-1] += newline
    for key, value in expected.items():
        if key not in written:
            lines.append(f'{key}={value}{newline}')
    configured = ''.join(lines).encode('utf-8')
    changed = configured != original
    if changed:
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=config.parent, prefix='.bil-display-', delete=False) as stream:
                temporary = Path(stream.name)
                stream.write(configured)
            os.chmod(temporary, config.stat().st_mode & 0o777)
            os.replace(temporary, config)
        finally:
            if temporary is not None and temporary.exists():
                temporary.unlink()
    actual = config.read_bytes()
    for key, value in expected.items():
        values = re.findall(r'^\s*' + re.escape(key) + r'\s*=\s*([^\r\n]*)', actual.decode('utf-8'), re.MULTILINE)
        if values != [value]:
            raise DisplayContractError('AVD display configuration readback did not match')
    return {
        'status': 'CONFIGURED', 'api_level': api, 'changed': changed,
        'config_path': str(config), 'display': expected,
        'before_sha256': hashlib.sha256(original).hexdigest(),
        'after_sha256': hashlib.sha256(actual).hexdigest(),
    }


def _single_physical(output: str, kind: str, pattern: str) -> tuple[int, ...]:
    matches = re.findall(r'^Physical ' + kind + ': ' + pattern + r'\s*$', output, re.MULTILINE)
    if len(matches) != 1:
        raise DisplayContractError(f'Expected exactly one physical {kind} readback')
    values = matches[0] if isinstance(matches[0], tuple) else (matches[0],)
    return tuple(int(value) for value in values)


def _check_override(output: str, kind: str, pattern: str, expected: tuple[int, ...]) -> None:
    lines = [line.strip() for line in output.splitlines() if line.startswith('Override ' + kind + ':')]
    if not lines:
        return
    if len(lines) != 1:
        raise DisplayContractError(f'Ambiguous runtime {kind} override')
    match = re.fullmatch('Override ' + kind + ': ' + pattern, lines[0])
    if match is None or tuple(int(value) for value in match.groups()) != expected:
        raise DisplayContractError(f'Runtime {kind} override conflicts with the configured display')


def verify_runtime_display(api: int, run=subprocess.run) -> dict:
    if required_display(api) is None:
        return {'status': 'UNCHANGED_API', 'api_level': api, 'commands': []}
    receipt = {'api_level': api, 'commands': []}
    outputs = {}
    try:
        for kind in ('size', 'density'):
            command = ['adb', 'shell', 'wm', kind]
            try:
                result = run(command, capture_output=True, text=True, check=False, timeout=WM_TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired as error:
                receipt['commands'].append({'command': command, 'status': 'TIMEOUT', 'timeout_seconds': WM_TIMEOUT_SECONDS})
                raise DisplayContractError('Runtime display readback timed out') from error
            record = {'command': command, 'return_code': result.returncode, 'timeout_seconds': WM_TIMEOUT_SECONDS}
            if len(result.stdout) + len(result.stderr) > 65536:
                raise DisplayContractError('Runtime display output exceeded its bounded limit')
            record.update(stdout=result.stdout, stderr=result.stderr)
            receipt['commands'].append(record)
            if result.returncode:
                raise DisplayContractError(f'Runtime wm {kind} failed')
            outputs[kind] = result.stdout.replace('\r', '')
        physical_size = _single_physical(outputs['size'], 'size', r'(\d+)x(\d+)')
        physical_density = _single_physical(outputs['density'], 'density', r'(\d+)')
        if physical_size != (720, 1280) or physical_density != (320,):
            raise DisplayContractError('Physical framebuffer must be 720x1280 at density 320')
        _check_override(outputs['size'], 'size', r'(\d+)x(\d+)', (720, 1280))
        _check_override(outputs['density'], 'density', r'(\d+)', (320,))
        receipt.update(status='MATCHED', physical_size=list(physical_size), physical_density=physical_density[0])
        return receipt
    except DisplayContractError as error:
        raise DisplayContractError(str(error), receipt) from error


def main(arguments=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('configure', 'verify-runtime'))
    parser.add_argument('--api-level', type=int, choices=REVIEWED_APIS, required=True)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    args = parser.parse_args(arguments)
    name = 'avd-display-config.json' if args.operation == 'configure' else 'runtime-display.json'
    try:
        if args.operation == 'configure':
            if args.config is None:
                raise DisplayContractError('Configure requires an AVD config path')
            receipt = configure_display(args.api_level, args.config)
        else:
            receipt = verify_runtime_display(args.api_level)
        code = 0
    except (OSError, ValueError) as error:
        receipt = dict(getattr(error, 'receipt', {}), status='FAILED', api_level=args.api_level, error=str(error))
        code = 5
    receipt['app_startup_proven'] = False
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    (args.evidence_dir / name).write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
