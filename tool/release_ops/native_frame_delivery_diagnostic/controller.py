#!/usr/bin/env python3
"""One frozen-source Android33 DIAGNOSTIC_ONLY wrapper; never changes a pass gate."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

APP_SOURCE = '5775d082a1b4c7a29e4ed4d6e01693b31923dc31'
APP_TREE = '7ea15defb433ad134ee5066f538d8e790c45f809'
ORIGINAL_SCRIPT = '.github/scripts/bil_android33_native_integration.sh'
ORIGINAL_SCRIPT_SHA256 = '50f833b4a96c222585061778055f916d4e742084b439c71ee9f2af37db025e7a'
EXPECTED_IMAGE_VBMETA = 'cc2acf6c582b63336b71fe51ed136e1a7a577e9e868ae7ba916ef6b3965324e5'
WRAPPER_TARGET = 'integration_test/bil_native_frame_delivery_diagnostic.dart'
BUFFER_TEST = 'test/bil_native_frame_delivery_diagnostic_test.dart'
OUT_REL = 'artifacts/qa/text18/android-api33'
PROTECTED = ('lib', 'android', 'integration_test', 'test', 'tools/qa/flutter',
             ORIGINAL_SCRIPT, 'pubspec.yaml', 'pubspec.lock')
ALLOWED_UNTRACKED = {WRAPPER_TARGET, BUFFER_TEST}
MAX_BUNDLE_BYTES = 24 * 1024 * 1024


def command(args, cwd=None, check=True):
    return subprocess.run(args, cwd=cwd, check=check, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def git(app, *args):
    return command(['git', '-C', str(app), *args]).stdout.strip()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, data):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, indent=2) + '\n')


def assert_source(app, expected_head=APP_SOURCE, expected_tree=APP_TREE):
    if git(app, 'rev-parse', 'HEAD') != expected_head:
        raise ValueError('Application HEAD is not the frozen source')
    if git(app, 'rev-parse', 'HEAD^{tree}') != expected_tree:
        raise ValueError('Application tree is not the frozen source')
    changed = git(app, 'diff', '--name-only', 'HEAD', '--')
    if changed:
        raise ValueError('Tracked source changed: ' + changed)
    untracked = git(app, 'ls-files', '--others', '--exclude-standard', '--', *PROTECTED)
    unexpected = set(untracked.splitlines()) - ALLOWED_UNTRACKED
    if unexpected:
        raise ValueError('Unexpected untracked compiled source: ' + ', '.join(sorted(unexpected)))
    return {'head': expected_head, 'tree': expected_tree,
            'protected_tracked_diff': [], 'untracked_qa_targets': sorted(untracked.splitlines())}


def controlled_script(original, controller_head, wrapper_sha256):
    if not re.fullmatch(r'[0-9a-f]{40}', controller_head) or not re.fullmatch(r'[0-9a-f]{64}', wrapper_sha256):
        raise ValueError('Invalid controller/hash identity')
    needle = '--target=integration_test/native_feature_splashes_test.dart'
    if original.count(needle) != 1:
        raise ValueError('Original compile target is missing or duplicated')
    replacement = (f'--target={WRAPPER_TARGET} '
                   f'--dart-define=BIL_DIAGNOSTIC_CONTROLLER_HEAD={controller_head} '
                   f'--dart-define=BIL_DIAGNOSTIC_WRAPPER_SHA256={wrapper_sha256}')
    return original.replace(needle, replacement, 1)


def prepare(app, controller, output):
    before = assert_source(app)
    controller_head = git(controller, 'rev-parse', 'HEAD')
    if controller_head != os.environ.get('GITHUB_SHA'):
        raise ValueError('Controller HEAD does not match the actual workflow head')
    script = app / ORIGINAL_SCRIPT
    if sha(script) != ORIGINAL_SCRIPT_SHA256:
        raise ValueError('Frozen native script hash mismatch')
    source_dir = Path(__file__).resolve().parent
    for relative, source_name in ((WRAPPER_TARGET, 'wrapper.dart'), (BUFFER_TEST, 'buffer_test.dart')):
        target = app / relative
        if target.exists() or target.is_symlink():
            raise ValueError('Refusing to replace an existing QA target: ' + relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source_dir / source_name, target)
    wrapper_sha = sha(app / WRAPPER_TARGET)
    output.mkdir(parents=True, exist_ok=True)
    generated = output / 'controlled-native-script.sh'
    generated.write_text(controlled_script(script.read_text(), controller_head, wrapper_sha))
    command(['bash', '-n', str(generated)])
    receipt = {
        'classification': 'DIAGNOSTIC_ONLY', 'native_release_certification': False,
        'source_before': before, 'source_after': assert_source(app),
        'controller_head': controller_head,
        'controller_helper_sha256': sha(Path(__file__)),
        'wrapper_target': WRAPPER_TARGET, 'wrapper_sha256': wrapper_sha,
        'buffer_test_target': BUFFER_TEST, 'buffer_test_sha256': sha(app / BUFFER_TEST),
        'original_main_target': 'integration_test/native_feature_splashes_test.dart',
        'original_script_sha256': sha(script), 'controlled_script_sha256': sha(generated),
        'script_change': 'Exactly one compile-target substitution plus two diagnostic identity dart-defines',
        'matcher_and_budgets_changed': False, 'route_or_frame_scheduling_added': False,
        'original_cases_filtered': False,
        'environment': {'api': 33, 'image': 'google_apis/x86_64', 'profile': 'pixel_6',
                        'cores': 2, 'gpu': 'swiftshader_indirect', 'emulator_build': '16428233',
                        'ram_input': None,
                        'historical_api33_log': 'No ram-size input; emulator increased RAM to2048MB',
                        'guest_ram_intentionally_increased': False,
                        'difference': 'Separate diagnostic job, no preceding CodeQL/crypto/settings; actual runtime recorded'},
    }
    write_json(output / 'controller-provenance.json', receipt)
    return receipt


def snapshot_environment(app, output):
    captures = {
        'guest-properties': ['adb', '-s', 'emulator-5554', 'shell', 'getprop'],
        'guest-memory': ['adb', '-s', 'emulator-5554', 'shell', 'cat', '/proc/meminfo'],
        'guest-cpu': ['adb', '-s', 'emulator-5554', 'shell', 'cat', '/proc/cpuinfo'],
        'host-load': ['cat', '/proc/loadavg'],
        'host-memory': ['cat', '/proc/meminfo'],
        'host-cpu': ['lscpu'],
        'emulator-version': [str(Path(os.environ['ANDROID_HOME']) / 'emulator/emulator'), '-no-window', '-version'],
    }
    receipt = {}
    for name, args in captures.items():
        result = command(args, cwd=app, check=False)
        (output / f'{name}.log').write_text(result.stdout + result.stderr)
        receipt[name] = {'exit': result.returncode}
    config = Path.home() / '.android/avd/test.avd/config.ini'
    if config.is_file():
        shutil.copyfile(config, output / 'emulator-config.ini.txt')
    else:
        raise ValueError('Actual emulator config is unavailable')
    if receipt['guest-memory']['exit'] or receipt['emulator-version']['exit']:
        raise ValueError('Cannot record emulator and guest memory')
    version = (output / 'emulator-version.log').read_text()
    if '37.2.12' not in version or '16428233' not in version:
        raise ValueError('Emulator version differs from original producer')
    sdk = command(['adb', '-s', 'emulator-5554', 'shell', 'getprop', 'ro.build.version.sdk']).stdout.strip()
    if sdk != '33':
        raise ValueError('Expected Android API33')
    vbmeta = command(['adb', '-s', 'emulator-5554', 'shell', 'getprop', 'ro.boot.vbmeta.digest']).stdout.strip()
    if vbmeta != EXPECTED_IMAGE_VBMETA:
        raise ValueError('Android33 system image differs from the original producer')
    source_properties = Path(os.environ['ANDROID_HOME']) / 'system-images/android-33/google_apis/x86_64/source.properties'
    shutil.copyfile(source_properties, output / 'system-image-source.properties.txt')
    receipt['system_image_vbmeta_digest'] = vbmeta
    write_json(output / 'environment-snapshots.json', receipt)


def final_status(original_status, guard_ok, diagnostic_ok):
    if original_status:
        return original_status
    return 0 if guard_ok and diagnostic_ok else 1


def run_original(app, output):
    receipt = json.loads((output / 'controller-provenance.json').read_text())
    assert_source(app)
    if sha(app / WRAPPER_TARGET) != receipt['wrapper_sha256']:
        raise ValueError('Compiled wrapper hash changed')
    generated = output / 'controlled-native-script.sh'
    if sha(generated) != receipt['controlled_script_sha256']:
        raise ValueError('Controlled invocation changed')
    snapshot_environment(app, output)
    env = dict(os.environ, GITHUB_WORKSPACE=str(app), BIL_NATIVE_TARGET='feature-splashes')
    log_handle = (output / 'whole-diagnostic-logcat.log').open('wb')
    logcat = subprocess.Popen(['adb', '-s', 'emulator-5554', 'logcat', '-v', 'threadtime'],
                              stdout=log_handle, stderr=subprocess.STDOUT)
    original_status = None
    guard_ok = False
    diagnostic_ok = False
    errors = []
    try:
        original_status = subprocess.run(['bash', str(generated)], cwd=app, env=env).returncode
    finally:
        logcat.terminate()
        try:
            logcat.wait(timeout=10)
        except subprocess.TimeoutExpired:
            logcat.kill()
            logcat.wait()
        log_handle.close()
        try:
            receipt['source_after_native_execution'] = assert_source(app)
            if sha(app / WRAPPER_TARGET) != receipt['wrapper_sha256']:
                raise ValueError('Wrapper changed during native run')
            guard_ok = True
        except Exception as exc:
            errors.append(str(exc))
        metadata = app / OUT_REL / 'feature-splashes/native-metadata.json'
        try:
            original_metadata = json.loads(metadata.read_text())
            raw = original_metadata['scenes'][0]['suite_frame_delivery_diagnostic']
            if len(json.dumps(raw).encode()) > 8 * 1024 * 1024:
                raise ValueError('Raw diagnostic exceeded8MiB')
            if raw.get('app_source') != APP_SOURCE or raw.get('app_tree') != APP_TREE:
                raise ValueError('Raw diagnostic source mismatch')
            if raw.get('wrapper_sha256') != receipt['wrapper_sha256']:
                raise ValueError('Raw diagnostic compiled wrapper mismatch')
            if raw.get('controller_source') != receipt['controller_head'] or raw.get('compile_target') != WRAPPER_TARGET:
                raise ValueError('Raw diagnostic controller/target mismatch')
            if raw.get('max_frames') != 10000 or raw.get('max_events') != 64:
                raise ValueError('Raw diagnostic sampling limits differ')
            if raw.get('classification') != 'DIAGNOSTIC_ONLY' or raw.get('frames_truncated') or raw.get('events_truncated'):
                raise ValueError('Diagnostic missing or truncated')
            receipt['original_driver_metadata'] = {'path': str(metadata), 'sha256': sha(metadata),
                    'diagnostic_json_path': '$.scenes[0].suite_frame_delivery_diagnostic'}
            diagnostic_ok = True
        except Exception as exc:
            errors.append('Diagnostic unavailable/incomplete: ' + str(exc))
        receipt.update(original_native_exit_status=original_status,
                       post_source_guard_passed=guard_ok, diagnostic_complete=diagnostic_ok,
                       errors=errors, native_release_certification=False)
        write_json(output / 'controller-provenance.json', receipt)
    return final_status(original_status if original_status is not None else 1, guard_ok, diagnostic_ok)


def bundle(app, output):
    destination = output / 'upload'
    destination.mkdir(parents=True, exist_ok=True)
    candidates = []
    for root in (output, app / OUT_REL):
        if not root.exists():
            continue
        candidates.extend(p for p in root.rglob('*') if p.is_file() and destination not in p.parents
                          and p.suffix.lower() in ('.json', '.log', '.txt'))
    total = 0
    index = []
    for path in sorted(set(candidates)):
        size = path.stat().st_size
        if size > 10 * 1024 * 1024 or total + size > MAX_BUNDLE_BYTES:
            raise ValueError('Diagnostic upload size cap exceeded; original files retained on runner')
        relative = path.relative_to(output) if output in path.parents else Path('original-script-output') / path.relative_to(app / OUT_REL)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        total += size
        index.append({'path': str(relative), 'bytes': size, 'sha256': sha(path)})
    write_json(destination / 'diagnostic-upload-index.json', {'classification': 'DIAGNOSTIC_ONLY',
               'bytes': total, 'max_bytes': MAX_BUNDLE_BYTES, 'files': index})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('prepare', 'run', 'bundle'))
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--controller', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    app, controller, output = (p.resolve() for p in (args.app, args.controller, args.output))
    if output == app or app in output.parents:
        raise ValueError('Diagnostic controller output must stay outside the application checkout')
    if args.operation == 'prepare':
        prepare(app, controller, output)
    elif args.operation == 'run':
        return run_original(app, output)
    else:
        bundle(app, output)
    return 0


if __name__ == '__main__':
    sys.exit(main())
