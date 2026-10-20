#!/usr/bin/env python3
"""Capture-only full tracked-source receipts with reviewed Pods generation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

SOURCE = '5775d082a1b4c7a29e4ed4d6e01693b31923dc31'
TREE = '7ea15defb433ad134ee5066f538d8e790c45f809'
WORKFLOW = '.github/workflows/bil_apple_workout_native_capture_20261020.yml'
GUARD_ORIGIN = 'a673f24338dced5b53603a0bee375b48cbb15372'
BINDINGS = ('applicationSource', 'applicationTree', 'controllerSource',
            'workflowPath', 'workflowRun', 'workflowAttempt')


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def command(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd)


def fingerprint(rows):
    return sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode())


def source_snapshot(directory):
    directory = Path(directory).resolve()
    head = command('git', 'rev-parse', 'HEAD', cwd=directory).decode().strip()
    tree = command('git', 'rev-parse', 'HEAD^{tree}', cwd=directory).decode().strip()
    if head != SOURCE or tree != TREE:
        raise ValueError('App checkout is not the frozen final source and tree')
    controller, run, attempt = (os.environ[k] for k in
                               ('GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'))
    if not re.fullmatch(r'[0-9a-f]{40}', controller) or not run.isdecimal() or not attempt.isdecimal():
        raise ValueError('Actual controller/run identity required')
    records = []
    for entry in command('git', 'ls-tree', '-r', '-z', 'HEAD', cwd=directory).split(b'\0'):
        if not entry:
            continue
        metadata, raw = entry.split(b'\t', 1)
        mode, kind, blob = metadata.decode().split()
        relative = os.fsdecode(raw)
        path = directory / relative
        if kind != 'blob' or relative.startswith('/') or '..' in Path(relative).parts:
            raise ValueError('Unexpected tracked source entry')
        if path.is_symlink():
            actual_kind, data = 'symlink', os.fsencode(os.readlink(path))
        elif path.is_file():
            actual_kind, data = 'file', path.read_bytes()
        else:
            raise ValueError('Tracked source file missing: ' + relative)
        records.append({'file': relative, 'kind': actual_kind, 'gitMode': mode,
                        'gitBlobSha': blob, 'executable': bool(path.lstat().st_mode & 0o111),
                        'sha256': sha256(data)})
    if not records:
        raise ValueError('Full tracked source inventory is empty')
    return {'applicationSource': head, 'applicationTree': tree,
            'controllerSource': controller, 'workflowPath': WORKFLOW,
            'workflowRun': run, 'workflowAttempt': attempt,
            'trackedFiles': sorted(records, key=lambda x: x['file'])}


def assert_source_delta(initial, actual, derived_paths):
    """Keep every original tracked file, mode and blob; only four bytes may vary."""
    if initial.get('phase') != 'checkout' or initial.get('initialTrackedCheckoutClean') is not True:
        raise ValueError('Initial clean checkout receipt required')
    if any(initial.get(key) != actual.get(key) for key in BINDINGS):
        raise ValueError('Source, controller, workflow or run identity changed')
    before = {row['file']: row for row in initial['trackedFiles']}
    after = {row['file']: row for row in actual['trackedFiles']}
    if len(before) != len(initial['trackedFiles']) or len(after) != len(actual['trackedFiles']) or set(before) != set(after):
        raise ValueError('Original full tracked inventory changed or is ambiguous')
    changed = {path for path in before if before[path] != after[path]}
    if changed != set(derived_paths):
        raise ValueError('Expected only four reviewed Pods files; changed: ' + ', '.join(sorted(changed)))
    for path in derived_paths:
        left, right = dict(before[path]), dict(after[path])
        left.pop('sha256')
        right.pop('sha256')
        if left != right or right['kind'] != 'file' or right['executable'] or right['gitMode'] != '100644':
            raise ValueError('Derived source must retain regular file identity and mode')
    return before, after


def record_derived(args, phase):
    app, control = Path(args.app_directory).resolve(), Path(args.control_directory).resolve()
    scripts = control / '.github/scripts'
    origin = json.loads((scripts / 'capture-guard-origin-manifest.json').read_text())
    if origin['approvedGuardController'] != GUARD_ORIGIN:
        raise ValueError('Reviewed semantic guard origin mismatch')
    for row in origin['files']:
        if sha256((control / row['path']).read_bytes()) != row['sha256']:
            raise ValueError('Reviewed guard/test/fixture changed: ' + row['path'])
    sys.path.insert(0, str(scripts))
    import bil_cocoapods_derived_proof as guard
    initial = json.loads(Path(args.initial_receipt).read_text())
    actual = source_snapshot(app)
    before, after = assert_source_delta(initial, actual, guard.DERIVED_PATHS)
    originals = {p: command('git', 'show', 'HEAD:' + p, cwd=app) for p in guard.DERIVED_PATHS}
    if any(before[p]['sha256'] != sha256(originals[p]) for p in guard.DERIVED_PATHS):
        raise ValueError('Original bytes differ from the actual clean checkout')
    generated = {p: (app / p).read_bytes() for p in guard.DERIVED_PATHS}
    contract_data = (scripts / 'cocoapods-derived-contract.json').read_bytes()
    # Production always requires Apple plutil agreement; no CLI bypass exists.
    rows = guard.validate(originals, generated, json.loads(contract_data))
    toolchain_data = Path(args.toolchain_json).read_bytes()
    locks = guard.validate_toolchain(app, json.loads(toolchain_data))
    output = Path(args.output_receipt)
    output.parent.mkdir(parents=True, exist_ok=True)
    public_inputs = {'Podfile.lock': (app / 'ios/Podfile.lock').read_bytes(),
                     'Manifest.lock': (app / 'ios/Pods/Manifest.lock').read_bytes(),
                     'toolchain.json': toolchain_data}
    for name, data in public_inputs.items():
        if re.search(rb'https?://[^\s/]+:[^\s/@]+@|(?i:authorization|bearer|password|token)\s*[:=]', data):
            raise ValueError('Potential credential in public generated evidence')
        target = output.parent / 'cocoapods-derived' / phase / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    for path in guard.DERIVED_PATHS:
        for label, data in [('original', originals[path]), ('generated', generated[path])]:
            target = output.parent / 'cocoapods-derived' / phase / label / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    result = {'schema': 'bil.qa.capture-full-tracked-source.v2', **actual, 'phase': phase,
              'initialTrackedCheckoutClean': True, 'allOtherTrackedFilesUnchanged': True,
              'unchangedTrackedFileCount': len(after) - len(guard.DERIVED_PATHS),
              'initialTrackedFingerprint': fingerprint(initial['trackedFiles']),
              'workingTrackedFingerprint': fingerprint(actual['trackedFiles']),
              'reviewedGuardOrigin': GUARD_ORIGIN, 'contractSha256': sha256(contract_data),
              'toolchainSha256': sha256(toolchain_data), **locks,
              'derivedFiles': rows, 'untrackedControlEntrypointRecordedSeparately': True,
              'claim': 'Full tracked source retained; separately validated Pods generation; no physical/store acceptance'}
    if phase == 'after':
        prior = json.loads(Path(args.before_receipt).read_text())
        if prior.get('phase') != 'before':
            raise ValueError('Successful derived-before receipt required')
        for key in [*BINDINGS, 'trackedFiles', 'initialTrackedFingerprint', 'workingTrackedFingerprint',
                    'contractSha256', 'toolchainSha256', 'podfile_lock_sha256', 'manifest_lock_sha256',
                    'derivedFiles', 'reviewedGuardOrigin']:
            if prior.get(key) != result.get(key):
                raise ValueError('Actual source/generated inputs changed during capture: ' + key)
        result['beforeAfterWorkingBytesIdentical'] = True
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'phase': phase, 'trackedFiles': len(after),
                      'allOtherTrackedFilesUnchanged': True, 'reviewedDerivedFiles': len(rows)}))


def device_plan():
    runtimes = json.loads(command('xcrun', 'simctl', 'list', 'runtimes', 'available', '-j'))['runtimes']
    ios = [r for r in runtimes if r.get('isAvailable') and
           r.get('identifier', '').startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
    if not ios:
        raise ValueError('No available native iOS runtime')
    runtime = max(ios, key=lambda r: tuple(int(x) for x in re.findall(r'\d+', r.get('version', '0'))))
    types = json.loads(command('xcrun', 'simctl', 'list', 'devicetypes', '-j'))['devicetypes']
    by_name = {d['name']: d for d in types}
    def pick(names):
        for name in names:
            if name in by_name:
                return by_name[name]
        raise ValueError('Exact reviewed native model unavailable: ' + ', '.join(names))
    phone = pick(['iPhone 16 Plus', 'iPhone 15 Pro Max', 'iPhone 14 Pro Max'])
    tablet = pick(['iPad Pro 13-inch (M4)', 'iPad Pro (13-inch) (M4)'])
    return {'runtime': {k: runtime[k] for k in ('identifier', 'name', 'version')},
            'devices': [dict(phone, role='iphone', expectedWidth=1290, expectedHeight=2796),
                        dict(tablet, role='ipad', expectedWidth=2064, expectedHeight=2752)],
            'storeCategoryCompleteness': 'REQUIRES_LIVE_ASC_UI_VERIFICATION'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    p = sub.add_parser('source-checkout')
    p.add_argument('app_directory')
    p.add_argument('output_receipt')
    for name in ('source-before', 'source-after'):
        p = sub.add_parser(name)
        for argument in ('app_directory', 'initial_receipt', 'output_receipt', 'control_directory', 'toolchain_json'):
            p.add_argument(argument)
        if name == 'source-after':
            p.add_argument('before_receipt')
    sub.add_parser('devices')
    p = sub.add_parser('check-png')
    p.add_argument('png')
    p.add_argument('width', type=int)
    p.add_argument('height', type=int)
    args = parser.parse_args()
    if args.mode == 'source-checkout':
        if subprocess.call(['git', 'diff', '--quiet', 'HEAD', '--'], cwd=args.app_directory):
            raise ValueError('Initial frozen checkout has tracked changes')
        result = {'schema': 'bil.qa.capture-full-tracked-source.v2', **source_snapshot(args.app_directory),
                  'phase': 'checkout', 'initialTrackedCheckoutClean': True}
        Path(args.output_receipt).write_text(json.dumps(result, indent=2) + '\n')
    elif args.mode in ('source-before', 'source-after'):
        record_derived(args, args.mode.removeprefix('source-'))
    elif args.mode == 'devices':
        print(json.dumps(device_plan(), indent=2))
    elif args.mode == 'check-png':
        data = Path(args.png).read_bytes()
        if len(data) < 32768 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
            raise ValueError('Capture missing, unexpectedly small, or not a PNG')
        if struct.unpack('>II', data[16:24]) != (args.width, args.height):
            raise ValueError('Capture dimensions differ from selected native model')
        print(json.dumps({'width': args.width, 'height': args.height, 'sha256': sha256(data),
                          'nativeProvenance': 'REQUIRES_SIMCTL_LOG_AND_CAPTURE_MANIFEST'}))


if __name__ == '__main__':
    main()
