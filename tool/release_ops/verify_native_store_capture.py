#!/usr/bin/env python3
"""Local/Actions guards for native store captures. No network or store writes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess

SOURCE = '5da21a5660b26e59e9ead7b0927d4ed7cf2c3996'


def command(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd)


def source_snapshot(directory):
    directory = Path(directory).resolve()
    head = command('git', 'rev-parse', 'HEAD', cwd=directory).decode().strip()
    if head != SOURCE:
        raise SystemExit('App checkout is not the frozen source commit')
    records = []
    for raw in command('git', 'ls-files', '-z', cwd=directory).split(b'\0'):
        if not raw:
            continue
        relative = os.fsdecode(raw)
        path = directory / relative
        if path.is_symlink():
            kind, data = 'symlink', os.fsencode(os.readlink(path))
        elif path.is_file():
            kind, data = 'file', path.read_bytes()
        else:
            raise SystemExit(f'Tracked source file missing: {relative}')
        records.append({'file': relative, 'kind': kind,
                        'sha256': hashlib.sha256(data).hexdigest()})
    return {'source': head, 'trackedFiles': sorted(records, key=lambda x: x['file'])}


def device_plan():
    runtimes = json.loads(command('xcrun', 'simctl', 'list', 'runtimes', 'available', '-j'))['runtimes']
    ios = [r for r in runtimes if r.get('isAvailable') and
           r.get('identifier', '').startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
    if not ios:
        raise SystemExit('No available native iOS runtime')
    runtime = max(ios, key=lambda r: tuple(int(x) for x in re.findall(r'\d+', r.get('version', '0'))))
    types = json.loads(command('xcrun', 'simctl', 'list', 'devicetypes', '-j'))['devicetypes']
    by_name = {d['name']: d for d in types}

    def pick(names):
        for name in names:
            if name in by_name:
                return by_name[name]
        raise SystemExit('Exact reviewed native device type unavailable: ' + ', '.join(names))

    phone = pick(['iPhone 16 Plus', 'iPhone 15 Pro Max', 'iPhone 14 Pro Max'])
    tablet = pick(['iPad Pro 13-inch (M4)', 'iPad Pro (13-inch) (M4)'])
    return {'runtime': {'identifier': runtime['identifier'], 'name': runtime['name'],
                        'version': runtime['version']},
            'devices': [dict(phone, role='iphone', expectedWidth=1290, expectedHeight=2796),
                        dict(tablet, role='ipad', expectedWidth=2064, expectedHeight=2752)],
            'storeCategoryCompleteness': 'REQUIRES_LIVE_ASC_UI_VERIFICATION'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    for name in ('source-snapshot', 'source-verify'):
        p = sub.add_parser(name)
        p.add_argument('app_directory')
        p.add_argument('snapshot_json')
    sub.add_parser('devices')
    p = sub.add_parser('check-png')
    p.add_argument('png')
    p.add_argument('width', type=int)
    p.add_argument('height', type=int)
    args = parser.parse_args()
    if args.mode == 'source-snapshot':
        if subprocess.call(['git', 'diff', '--quiet', 'HEAD', '--'], cwd=args.app_directory):
            raise SystemExit('Initial frozen checkout has tracked changes')
        Path(args.snapshot_json).write_text(json.dumps(source_snapshot(args.app_directory), indent=2) + '\n')
    elif args.mode == 'source-verify':
        before = json.loads(Path(args.snapshot_json).read_text())
        after = source_snapshot(args.app_directory)
        if before != after:
            left = {r['file']: r for r in before['trackedFiles']}
            right = {r['file']: r for r in after['trackedFiles']}
            changed = sorted(k for k in left.keys() | right.keys() if left.get(k) != right.get(k))
            raise SystemExit('Frozen tracked source changed: ' + ', '.join(changed))
        print(json.dumps({'source': SOURCE, 'trackedFileCount': len(after['trackedFiles']),
                          'trackedSourceByteIdentity': True}))
    elif args.mode == 'devices':
        print(json.dumps(device_plan(), indent=2))
    elif args.mode == 'check-png':
        data = Path(args.png).read_bytes()
        if len(data) < 32768 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise SystemExit('Capture is missing, unexpectedly small, or not a native PNG')
        actual = struct.unpack('>II', data[16:24])
        if actual != (args.width, args.height):
            raise SystemExit(f'Native dimensions differ from selected model: {actual}')
        print(json.dumps({'file': Path(args.png).name, 'width': actual[0], 'height': actual[1],
                          'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                          'expectedModelDimensionsMatch': True,
                          'nativeCaptureProvenance': 'REQUIRES_SIMCTL_LOG_AND_MANIFEST',
                          'physicalDeviceAcceptance': 'NOT_ESTABLISHED'}))


if __name__ == '__main__':
    main()
