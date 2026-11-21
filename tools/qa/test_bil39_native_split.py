"""Independent native orchestration; host fixtures are not iOS runtime proof."""
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import shlex
import tempfile
import textwrap
import unittest
from types import SimpleNamespace
from unittest import mock

import bil39_internal_build_ci as gate
import bil_native_source_evidence as native
from bil_native_source_evidence import validate_native_workflow_contract, native_job_name

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / '.github/scripts/bil39_ios_native_integration.sh'
SHA = 'a' * 40


class NativeSplitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = SCRIPT.read_text(encoding='utf-8')
        cls.bash = (str(Path('C:/Program Files/Git/bin/bash.exe')) if os.name == 'nt'
                    else '/bin/bash' if sys.platform == 'darwin' else shutil.which('bash'))
        if not cls.bash:
            raise RuntimeError('Real Bash is required to verify native orchestration')

    def emitted_provenance(self, device, future_pin=False):
        workflow = (ROOT / '.github/workflows/bil39_ios_native_reusable.yml').read_text(encoding='utf-8')
        code = textwrap.dedent(workflow.split("<<'PY_NATIVE_SOURCE_PROVENANCE'\n", 1)[1]
            .split('\n          PY_NATIVE_SOURCE_PROVENANCE', 1)[0])
        ast.parse(code)
        extra = '.github/scripts/future-native-registry-pin.py'
        required = list(native.native_source_paths(device)) + ([extra] if future_pin else [])
        with tempfile.TemporaryDirectory(prefix='bil39-actual-provenance-') as folder:
            target = Path(folder)
            for name in native.native_source_paths(device):
                output = target / name
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes((ROOT / name).read_bytes())
            helper = target / 'tools/qa/bil_native_source_evidence.py'
            helper.parent.mkdir(parents=True, exist_ok=True)
            helper.write_bytes((ROOT / 'tools/qa/bil_native_source_evidence.py').read_bytes())
            if future_pin:
                (target / extra).write_text('future required native source pin\n', encoding='utf-8')
            with mock.patch.object(native, 'native_source_paths', return_value=required):
                expected = native.native_source_pins(target, device)
            wrapper = '''import subprocess,sys
from pathlib import Path
def source_git(args, **kwargs):
    if args == ['git','rev-parse','HEAD']: return '@SHA@\\n'
    if args == ['git','rev-parse','HEAD^{tree}']: return '@TREE@\\n'
    raise AssertionError('Unexpected Git operation in provenance-only fixture')
subprocess.check_output = source_git
def refuse_process(*args, **kwargs):
    raise AssertionError('No native or other command may run in the provenance fixture')
subprocess.Popen = refuse_process
'''.replace('@SHA@', SHA).replace('@TREE@', 'b' * 40)
            if future_pin:
                wrapper += '''sys.path.insert(0, str(Path('tools/qa').resolve()))
import bil_native_source_evidence as registry
original_paths = registry.native_source_paths
registry.native_source_paths = lambda device: original_paths(device) + [@EXTRA@]
'''.replace('@EXTRA@', repr(extra))
            wrapper += 'exec(compile(' + repr(code) + ", '<actual-native-provenance>', 'exec'))\n"
            result = subprocess.run([sys.executable, '-B', '-c', wrapper], cwd=target,
                env={**os.environ, 'BIL_NATIVE_DEVICE': device, 'GITHUB_SHA': SHA,
                    'GITHUB_REPOSITORY': gate.REPOSITORY,
                    'GITHUB_WORKFLOW_REF': gate.REPOSITORY + '/.github/workflows/bil39_' + device + '_native.yml@refs/heads/' + gate.BRANCH,
                    'GITHUB_REF': 'refs/heads/' + gate.BRANCH,
                    'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1'},
                capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            receipt = json.loads((target / 'artifacts/qa' / ('bil39-native-' + device)
                / 'controller-provenance.json').read_text(encoding='utf-8'))
            return receipt, expected

    def test_actual_provenance_emitter_records_current_and_future_registry(self):
        for device in ('iphone', 'ipad'):
            for future in (False, True):
                with self.subTest(device=device, future_pin=future):
                    receipt, expected = self.emitted_provenance(device, future)
                    actual = receipt['source_scope_hashes']
                    self.assertIn('.github/scripts/bil_ios_os_readiness.py', expected)
                    self.assertEqual(set(actual), set(expected),
                        f'Actual emitter recorded {len(actual)} pins; consumer requires {len(expected)}; missing {sorted(set(expected)-set(actual))}')
                    self.assertEqual(actual, expected)
                    self.assertEqual(receipt['application_source_sha'], SHA)
                    self.assertEqual(receipt['application_source_tree'], 'b' * 40)
                    self.assertEqual(receipt['device'], device)
                    self.assertEqual(receipt['run_attempt'], '1')
                    self.assertFalse(receipt['signed_artifact_acceptance'])
                    self.assertFalse(receipt['physical_device_acceptance'])

    def test_single_device_script_parses_and_refuses_ambiguous_device_before_any_mutation(self):
        result = subprocess.run([self.bash, '-n', str(SCRIPT)], capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        for value in ('', 'both', 'iphone ipad', '../ipad'):
            with self.subTest(value=value):
                result = subprocess.run([self.bash, str(SCRIPT)], capture_output=True,
                    env={**os.environ, 'BIL_NATIVE_DEVICE': value}, timeout=10)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn(b'Exactly one explicit native device', result.stderr)

    def select(self, label, types):
        code = self.script.split("<<'PY_DEVICE'\n", 1)[1].split('\nPY_DEVICE', 1)[0]
        with tempfile.TemporaryDirectory(prefix='bil39-native-selector-') as folder:
            target = Path(folder)
            (target / 'runtimes.json').write_text(json.dumps({'runtimes': [
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-1',
                 'version': '26.1', 'isAvailable': True,
                 'supportedDeviceTypes': [{'identifier': row['identifier']} for row in types]},
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-25-0',
                 'version': '25.0', 'isAvailable': True,
                 'supportedDeviceTypes': [{'identifier': row['identifier']} for row in types]}]}), encoding='utf-8')
            (target / 'device-types.json').write_text(json.dumps({'devicetypes': types}), encoding='utf-8')
            return subprocess.run([sys.executable, '-c', code, folder, label],
                                  capture_output=True, text=True, timeout=10)

    def test_actual_selector_needs_only_its_own_family_and_never_substitutes_other_device(self):
        for label, name in [('iphone', 'iPhone 16 Pro'), ('ipad', 'iPad Pro 13-inch (M4)')]:
            with self.subTest(label=label):
                types = [{'name': name, 'identifier': f'qa-{label}-type'}]
                result = self.select(label, types)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(),
                    f'com.apple.CoreSimulator.SimRuntime.iOS-26-1 qa-{label}-type')
                other = 'ipad' if label == 'iphone' else 'iphone'
                self.assertNotEqual(self.select(other, types).returncode, 0)

    def test_duo_first_actual_metadata_order_selects_only_exact_compatible_runtime(self):
        code = self.script.split("<<'PY_DEVICE'\n", 1)[1].split('\nPY_DEVICE', 1)[0]
        with tempfile.TemporaryDirectory(prefix='bil39-duo-first-') as folder:
            target = Path(folder)
            # Observed stock order: both 27.2, but Duo supports only iPhone Duo.
            runtimes = {'runtimes': [
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4',
                 'version': '27.2', 'isAvailable': True,
                 'supportedDeviceTypes': [{'identifier': 'qa-duo'}]},
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-2',
                 'version': '27.2', 'isAvailable': True,
                 'supportedDeviceTypes': [{'identifier': 'qa-iphone'}, {'identifier': 'qa-ipad'}]}]}
            (target / 'runtimes.json').write_text(json.dumps(runtimes), encoding='utf8')
            (target / 'device-types.json').write_text(json.dumps({'devicetypes': [
                {'name': 'iPhone 16 Pro', 'identifier': 'qa-iphone'},
                {'name': 'iPad Pro 13-inch (M4)', 'identifier': 'qa-ipad'}]}), encoding='utf8')
            for label in ('iphone', 'ipad'):
                result = subprocess.run([sys.executable, '-c', code, folder, label],
                    capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(),
                    f'com.apple.CoreSimulator.SimRuntime.iOS-27-2 qa-{label}')

    def test_quoted_selector_runs_through_the_actual_shell_and_preserves_python_literals(self):
        # Execute the complete shell/Python boundary, not just extracted Python.
        # macOS CI uses its /bin/bash (3.2); Windows runs the same boundary on Git Bash.
        code = self.script.split('python3 - "$OUT" "$LABEL" >', 1)[1]
        code = 'python3 - "$OUT" "$LABEL" >' + code.split('\nstage "create-$LABEL"', 1)[0]
        python = Path(sys.executable).as_posix()
        if os.name == 'nt':
            python = '/' + python[0].lower() + python[2:]
        code = code.replace('python3 - ', shlex.quote(python) + ' - ', 1)
        with tempfile.TemporaryDirectory(prefix='bil39 full shell selector ') as folder:
            target = Path(folder)
            (target / 'runtimes.json').write_text(json.dumps({'runtimes': [
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-1',
                 'version': '26.1', 'isAvailable': True,
                 'supportedDeviceTypes': [{'identifier': 'qa-iphone'},
                                          {'identifier': 'qa-ipad'}]}]}), encoding='utf-8')
            (target / 'device-types.json').write_text(json.dumps({'devicetypes': [
                {'name': 'iPhone 16 Pro', 'identifier': 'qa-iphone'},
                {'name': 'iPad Pro 13-inch (M4)', 'identifier': 'qa-ipad'}]}), encoding='utf-8')
            shell_code = code
            read_code = ''
            if os.name == 'nt':
                # Git Bash's fork of a native child is unavailable on this
                # Windows host (dofork 0xC0000142). exec still runs the real
                # quoted heredoc and native Python, then a second owned Bash
                # verifies the unchanged read boundary. macOS runs it whole.
                shell_code, read_code = code.rsplit('\nread -r ', 1)
                shell_code = 'exec ' + shell_code + '\n'
                read_code = 'read -r ' + read_code + '\n'
            for label in ('iphone', 'ipad'):
                result = subprocess.run([self.bash, '-e', '-o', 'pipefail'],
                    input=shell_code + ('' if os.name == 'nt' else
                        '\nprintf "%s|%s\\n" "$RUNTIME" "$DEVICE_TYPE"\n'),
                    env={**os.environ, 'OUT': str(target), 'LABEL': label},
                    text=True, capture_output=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                if os.name == 'nt':
                    result = subprocess.run([self.bash, '-e', '-o', 'pipefail'],
                        input=read_code + '\nprintf "%s|%s\\n" "$RUNTIME" "$DEVICE_TYPE"\n',
                        env={**os.environ, 'OUT': str(target)},
                        text=True, capture_output=True, timeout=10)
                    self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(),
                    f'com.apple.CoreSimulator.SimRuntime.iOS-26-1|qa-{label}')
            (target / 'runtimes.json').write_text('{"runtimes": []}', encoding='utf-8')
            result = subprocess.run([self.bash, '-e', '-o', 'pipefail'], input=shell_code,
                env={**os.environ, 'OUT': str(target), 'LABEL': 'ipad'},
                text=True, capture_output=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('No available iOS Simulator runtime', result.stderr)

    def test_all_native_scopes_and_exact_binary_remain_mandatory_per_device(self):
        assignment = self.script.split('KINDS=(', 1)[1].split(')', 1)[0]
        result = subprocess.run([self.bash], input='set -eu\nKINDS=(' + assignment +
            ')\nprintf "%s\\n" "${KINDS[@]}"\n', capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['system-crypto', 'native-settings', 'feature-splashes'])
        self.assertNotIn('BIL_NATIVE_TARGET', self.script)
        self.assertNotIn('IPAD_UDID', self.script)
        self.assertNotIn('IPHONE_UDID', self.script)
        self.assertIn('--build-number 39', self.script)
        self.assertIn('python3 .github/scripts/bil39_simulator_vm_attach.py --qa-simulator-only', self.script)
        self.assertIn('--target "$TARGET" --driver "$DRIVER" --label "$LABEL-$KIND-drive"', self.script)
        self.assertIn('--device "$DEVICE"', self.script)
        self.assertIn('for pair in "$LABEL:$DEVICE"', self.script)
        self.assertNotIn('continue-on-error', self.script)
        old = ROOT / '.github/scripts/bil_ios37_native_integration.sh'
        self.assertEqual(hashlib.sha256(old.read_bytes()).hexdigest(),
            '68625566fd2fc38280ed3daec9851ec4d2539965a2a85d9a8d91cfddc07bc314')

    def test_actual_shell_hands_all_three_scopes_and_exact_receipts_to_transport(self):
        selection = 'case "$KIND" in' + self.script.split('case "$KIND" in', 1)[1].split('\n  esac', 1)[0] + '\n  esac\n'
        command = self.script.split('    BIL_NATIVE_CAPTURE_DEVICE_ID=', 1)[1].split('    collect_app_files', 1)[0]
        command = '    BIL_NATIVE_CAPTURE_DEVICE_ID=' + command
        python = Path(sys.executable).as_posix()
        if os.name == 'nt':
            python = '/' + python[0].lower() + python[2:]
        with tempfile.TemporaryDirectory(prefix='bil39-scope-argv-') as folder:
            root = Path(folder)
            recorder = root / 'record.py'
            recorder.write_text('import json,os,sys;print(json.dumps({"argv":sys.argv[1:],"device":os.environ.get("BIL_NATIVE_CAPTURE_DEVICE_ID")}))', encoding='utf-8')
            shell = selection + command.replace('python3 .github/scripts/bil39_simulator_vm_attach.py',
                'exec ' + shlex.quote(python) + ' ' + shlex.quote(recorder.as_posix()), 1)
            device = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
            for kind, target in [('system-crypto', 'integration_test/system_crypto_bridge_integration_test.dart'),
                                 ('native-settings', 'integration_test/native_settings_polish_test.dart'),
                                 ('feature-splashes', 'integration_test/native_feature_splashes_test.dart')]:
                with self.subTest(kind=kind):
                    result = subprocess.run([self.bash, '-e', '-o', 'pipefail'], input=shell,
                        text=True, capture_output=True, timeout=10, env={**os.environ,
                            'KIND':kind, 'LABEL':'iphone', 'DEVICE':device, 'APP':root.as_posix()+'/Runner.app',
                            'GITHUB_WORKSPACE':root.as_posix(), 'OUT':'artifacts/native', 'CRYPTO_DRIVER':'crypto-driver.dart'})
                    self.assertEqual(result.returncode, 0, result.stderr)
                    record = json.loads(result.stdout)
                    args = record['argv']
                    self.assertEqual(record['device'], device)
                    self.assertEqual(args[args.index('--device')+1], device)
                    self.assertEqual(args[args.index('--app')+1].replace(chr(92), '/'), root.as_posix()+'/Runner.app')
                    expected_driver = ('crypto-driver.dart' if kind == 'system-crypto' else 'test_driver/native_settings_capture_driver.dart' if kind == 'native-settings' else 'test_driver/native_feature_splashes_driver.dart')
                    self.assertEqual(args[args.index('--driver')+1], expected_driver)
                    self.assertEqual(args[args.index('--target')+1], target)
                    self.assertEqual(args[args.index('--label')+1], 'iphone-'+kind+'-drive')
                    self.assertTrue(args[args.index('--log')+1].replace(chr(92), '/').endswith('/artifacts/native/iphone-'+kind+'.log'))
                    self.assertTrue(args[args.index('--receipt')+1].replace(chr(92), '/').endswith('/artifacts/native/iphone-'+kind+'-drive-result.json'))
                    self.assertIn('--qa-simulator-only', args)

    def test_two_distinct_workflow_runs_are_required_and_each_missing_failed_or_skipped_job_blocks(self):
        for label in ('iphone', 'ipad'):
            workflow = f'bil39_{label}_native.yml'
            job_name = native_job_name(label)
            proof = validate_native_workflow_contract(ROOT, label, 'codex/bil43-android35-verified-20261108')
            self.assertEqual(proof['job_name'], job_name)
            self.assertEqual(gate.WORKFLOWS[workflow], {job_name})
            run = {'id':123, 'head_sha':SHA, 'head_branch':gate.BRANCH, 'event':'push',
                'status':'completed', 'conclusion':'success', 'path':'.github/workflows/'+workflow,
                'html_url':f'https://github.com/{gate.REPOSITORY}/actions/runs/123'}
            job = {'name':job_name,'status':'completed','conclusion':'success','head_sha':SHA}
            self.assertEqual(gate.validate_run(run,[job],sha=SHA,workflow=workflow)['status'],'PASS')
            for jobs in ([],[{**job,'conclusion':'skipped'}],[{**job,'conclusion':'failure'}],
                    [{**job,'head_sha':'b'*40}]):
                with self.subTest(workflow=workflow,jobs=jobs),self.assertRaises(ValueError):
                    gate.validate_run(run,jobs,sha=SHA,workflow=workflow)

    def test_combined_job_is_disabled_for_bil39_but_existing_main_scope_is_preserved(self):
        security = (ROOT/'.github/workflows/bil_codeql_security_extended.yml').read_text()
        self.assertNotIn('\n  ios-native-integration:\n', security)
        for branch in ('bil39/integration-20261025','codex/bil40-device-fixes-20261028',
                'codex/bil41-android33-release-20261106','codex/bil43-android35-verified-20261108','main'):
            for device in ('iphone','ipad'):
                self.assertEqual(validate_native_workflow_contract(ROOT,device,branch)['device'],device)
        for device in ('iphone','ipad'):
            caller=(ROOT/f'.github/workflows/bil39_{device}_native.yml').read_text()
            self.assertIn('  pull_request:\n    branches: [main, integration/bil-qa-media-policy-20261011]',caller)


if __name__ == '__main__':
    unittest.main()
