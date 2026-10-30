#!/usr/bin/env python3
"""Isolated Coach-only iPad diagnostic, never a release-certification gate."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from bil_native_bounded_command import run_bounded

BASE = '978758a25d892be15bda26387e3970bb1f2a9ae0'
TARGET = 'integration_test/native_feature_splashes_test.dart'
DRIVER = 'test_driver/native_feature_splashes_driver.dart'
BUNDLE = 'com.bilhealth.bodyintelligencelog'
OUTPUT = Path('artifacts/qa/bil40-ipad-history-diagnostic')


def select_device(runtimes, device_types):
    ios = [item for item in runtimes['runtimes'] if item.get('isAvailable') and
           item['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
    if not ios:
        raise ValueError('No available iOS Simulator runtime')
    runtime = max(ios, key=lambda item: tuple(map(int, re.findall(r'\d+', item['version']))))
    preferred = ['iPad Pro 13-inch (M4)', 'iPad Pro (13-inch) (M4)',
                 'iPad Pro (12.9-inch) (6th generation)']
    tablets = [item for item in device_types['devicetypes'] if item['name'].startswith('iPad')]
    if not tablets:
        raise ValueError('Requested iPad device type is unavailable')
    device = next((item for name in preferred for item in tablets if item['name'] == name), tablets[-1])
    return runtime['identifier'], device['identifier']


def valid_owned_uuid(value):
    return re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', value) is not None


class Diagnostic:
    def __init__(self, workspace, output=OUTPUT):
        self.workspace, self.output = Path(workspace).resolve(), Path(output).resolve()
        self.output.relative_to(self.workspace)
        self.output.mkdir(parents=True, exist_ok=True)
        self.device = None
        self.boot_attempted = False
        self.receipt = {'scope': 'DIAGNOSTIC_ONLY_NOT_RELEASE_ACCEPTANCE',
                        'base_source': BASE, 'completed': False, 'retry_count': 0,
                        'coach_cases': 8, 'scene_filter': None,
                        'sequence_limit': 'Original eight Coach cases retained; the four earlier six-entry cases are absent. A diagnostic pass cannot establish the old failure cause.',
                        'cleanup_errors': []}

    def stage(self, label, seconds, command):
        code = run_bounded(command, label='history-' + label,
                           log_path=self.output / (label + '.log'),
                           receipt_path=self.output / (label + '-result.json'),
                           timeout_seconds=seconds)
        if code:
            raise RuntimeError('Diagnostic stage failed: ' + label)
        return (self.output / (label + '.log')).read_text(encoding='utf-8')

    def collect(self):
        if self.device is None or not self.boot_attempted:
            return
        container = Path(self.stage('app-container', 30,
            ['xcrun', 'simctl', 'get_app_container', self.device, BUNDLE, 'data']).strip())
        expected = Path.home() / 'Library/Developer/CoreSimulator/Devices' / self.device / 'data/Containers/Data/Application'
        container.resolve().relative_to(expected.resolve())
        # Synthetic QA metadata/PNGs only. No database, Keychain or Health data.
        for name in ('feature-splashes-native', 'platform-polish'):
            source = container / 'Documents' / name
            if source.is_dir():
                self.stage('copy-' + name, 60,
                    ['cp', '-R', str(source), str(self.output / ('device-' + name))])

    def run(self):
        primary = None
        try:
            head = self.stage('source-head', 30, ['git', 'rev-parse', 'HEAD']).strip()
            tree = self.stage('source-tree', 30, ['git', 'rev-parse', 'HEAD^{tree}']).strip()
            if re.fullmatch(r'[0-9a-f]{40}', head) is None or re.fullmatch(r'[0-9a-f]{40}', tree) is None:
                raise ValueError('Exact source metadata missing')
            self.stage('source-base', 30, ['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'])
            self.receipt.update(source_head=head, source_tree=tree)
            os.environ.update(BIL_QA_SOURCE_HEAD=head, BIL_QA_SOURCE_FINGERPRINT=tree)
            self.stage('xcode-version', 120, ['xcodebuild', '-version'])
            runtime, device_type = select_device(
                json.loads(self.stage('runtimes', 120, ['xcrun', 'simctl', 'list', 'runtimes', 'available', '-j'])),
                json.loads(self.stage('device-types', 120, ['xcrun', 'simctl', 'list', 'devicetypes', '-j'])))
            self.receipt.update(runtime=runtime, device_type=device_type)
            created = self.stage('create', 120, ['xcrun', 'simctl', 'create',
                'BIL40-history-' + os.environ.get('GITHUB_RUN_ID', 'local'), device_type, runtime]).strip()
            if not valid_owned_uuid(created):
                raise ValueError('Invalid created simulator UUID; no cleanup target accepted')
            self.device = created
            self.receipt['owned_device'] = created
            self.stage('native-preflight', 900, [sys.executable,
                '.github/scripts/bil_ios_native_preflight.py', '--workspace', str(self.workspace),
                '--output', str(self.output)])
            defines = ['--dart-define=' + item for item in (
                'BIL_ENVIRONMENT=testing', 'BIL_USE_SUPABASE=false', 'BIL_PAYMENTS_ENABLED=false',
                'BIL_ADS_ENABLED=false', 'BIL_QA_IOS_SIMULATOR=true',
                'BIL_QA_NATIVE_COACH_ONLY=true', 'BIL_QA_DEVICE_NAME=github-bil40-history-ipad',
                'BIL_QA_SOURCE_HEAD=' + head, 'BIL_QA_SOURCE_FINGERPRINT=' + tree)]
            self.stage('feature-config', 900, ['flutter', '--verbose', 'build', 'ios', '--config-only',
                '--simulator', '--debug', '--no-codesign', '--no-pub', '--build-number', '39',
                '--target', TARGET, *defines])
            app = self.workspace / 'build/ios/Debug-iphonesimulator/Runner.app'
            # Existing strict simulator-only local ad-hoc identity; no certificate or provisioning.
            self.stage('feature-build', 1800, [sys.executable,
                '.github/scripts/bil_ios_simulator_adhoc_sign.py', '--qa-simulator-only',
                '--build-number', '39', '--workspace', str(self.workspace), '--app', str(app),
                '--output', str(self.output / 'simulator-signature.json'), '--target', TARGET,
                '--source-head', head, '--source-tree', tree, '--device', self.device])
            self.boot_attempted = True
            self.stage('boot', 120, ['xcrun', 'simctl', 'boot', self.device])
            self.stage('bootstatus', 180, ['xcrun', 'simctl', 'bootstatus', self.device, '-b'])
            self.stage('appearance', 120, ['xcrun', 'simctl', 'ui', self.device, 'appearance', 'light'])
            os.environ.update(BIL_NATIVE_CAPTURE_DEVICE_ID=self.device,
                BIL_FEATURE_NATIVE_OUTPUT=str(self.output / 'host-feature-splashes'))
            self.stage('drive', 1500, [sys.executable, '.github/scripts/bil39_simulator_vm_attach.py',
                '--qa-simulator-only', '--device', self.device, '--app', str(app),
                '--output', str(self.output / 'transport'), '--target', TARGET, '--driver', DRIVER,
                '--label', 'ipad-history-diagnostic-drive', '--log', str(self.output / 'native.log'),
                '--receipt', str(self.output / 'native-drive-result.json')])
            self.receipt['completed'] = True
        except Exception as error:
            primary = error
            self.receipt['error_type'] = type(error).__name__
            self.receipt['error'] = str(error)
        finally:
            if self.device is not None:
                try:
                    self.collect()
                except Exception as error:
                    self.receipt['collection_error_type'] = type(error).__name__
                    if primary is None:
                        primary = error
                commands = ([('shutdown', ['xcrun', 'simctl', 'shutdown', self.device])]
                            if self.boot_attempted else [])
                commands.append(('delete', ['xcrun', 'simctl', 'delete', self.device]))
                for label, command in commands:
                    try:
                        self.stage(label, 30, command)
                    except Exception as error:
                        self.receipt['cleanup_errors'].append({'stage': label, 'error_type': type(error).__name__})
                        if primary is None:
                            primary = error
            self.receipt['exit_code'] = 1 if primary else 0
            (self.output / 'diagnostic-result.json').write_text(json.dumps(self.receipt, indent=2) + '\n', encoding='utf-8')
        return self.receipt['exit_code']


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This isolated diagnostic requires the actual macOS runner')
    return Diagnostic(Path.cwd()).run()


if __name__ == '__main__':
    raise SystemExit(main())
