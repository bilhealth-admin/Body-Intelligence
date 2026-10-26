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
import unittest
from types import SimpleNamespace

import bil39_internal_build_ci as gate

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
                 'version': '26.1', 'isAvailable': True},
                {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-25-0',
                 'version': '25.0', 'isAvailable': True}]}), encoding='utf-8')
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
                 'version': '26.1', 'isAvailable': True}]}), encoding='utf-8')
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
        self.assertIn('--use-application-binary "$APP" --target "$TARGET" --driver "$DRIVER"', self.script)
        self.assertIn('--summary-grace-seconds 60 --fail-on-launch-error', self.script)
        self.assertIn('flutter --verbose drive', self.script)
        self.assertIn('for pair in "$LABEL:$DEVICE"', self.script)
        self.assertNotIn('continue-on-error', self.script)
        old = ROOT / '.github/scripts/bil_ios37_native_integration.sh'
        self.assertEqual(hashlib.sha256(old.read_bytes()).hexdigest(),
            '68625566fd2fc38280ed3daec9851ec4d2539965a2a85d9a8d91cfddc07bc314')

    def test_two_distinct_workflow_runs_are_required_and_each_missing_failed_or_skipped_job_blocks(self):
        for label, title in [('iphone', 'iPhone'), ('ipad', 'iPad')]:
            workflow = f'bil39_{label}_native.yml'
            job_name = f'{title} native tests from exact BIL39 simulator bundles'
            self.assertEqual(gate.WORKFLOWS[workflow], {job_name})
            source = (ROOT / '.github/workflows' / workflow).read_text(encoding='utf-8')
            self.assertIn('branches: [bil39/integration-20261025]', source)
            self.assertIn('runs-on: macos-26', source)
            self.assertIn(f'BIL_NATIVE_DEVICE: {label}', source)
            self.assertIn(f'name: bil39-{label}-native-${{{{ github.sha }}}}', source)
            self.assertNotIn('matrix:', source)
            self.assertNotIn('continue-on-error', source)
            run = {'id': 123, 'head_sha': SHA, 'head_branch': gate.BRANCH, 'event': 'push',
                'status': 'completed', 'conclusion': 'success', 'path': '.github/workflows/' + workflow,
                'html_url': f'https://github.com/{gate.REPOSITORY}/actions/runs/123'}
            job = {'name': job_name, 'status': 'completed', 'conclusion': 'success', 'head_sha': SHA}
            self.assertEqual(gate.validate_run(run, [job], sha=SHA, workflow=workflow)['status'], 'PASS')
            for jobs in ([], [{**job, 'conclusion': 'skipped'}], [{**job, 'conclusion': 'failure'}],
                         [{**job, 'head_sha': 'b' * 40}]):
                with self.subTest(workflow=workflow, jobs=jobs):
                    with self.assertRaises(ValueError):
                        gate.validate_run(run, jobs, sha=SHA, workflow=workflow)

    def test_combined_job_is_disabled_for_bil39_but_existing_main_scope_is_preserved(self):
        source = (ROOT / '.github/workflows/bil_codeql_security_extended.yml').read_text(encoding='utf-8')
        job = source.split('\n  ios-native-integration:\n', 1)[1].split('\n    name:', 1)[0]
        expression = job.split('${{', 1)[1].rsplit('}}', 1)[0].strip()
        expression = expression.replace('&&', ' and ').replace('||', ' or ').replace('!=', '<>')
        expression = expression.replace('!', ' not ').replace('<>', '!=')
        expression = expression.replace('true', 'True')
        tree = ast.parse(' '.join(expression.split()), mode='eval')
        allowed = (ast.Expression, ast.BoolOp, ast.UnaryOp, ast.Compare, ast.Name,
            ast.Attribute, ast.Constant, ast.And, ast.Or, ast.Not, ast.Eq, ast.NotEq, ast.Load)
        self.assertTrue(all(isinstance(node, allowed) for node in ast.walk(tree)))
        flags = SimpleNamespace(**dict.fromkeys(['source_audit_only', 'mobsf_only', 'android_native_only',
            'ios_native_only', 'ios_only', 'android_only', 'supabase_only'], False))
        for branch, expected in [('bil39/integration-20261025', False), ('main', True)]:
            github = SimpleNamespace(event_name='push', ref='refs/heads/' + branch)
            self.assertEqual(eval(compile(tree, '<actual condition>', 'eval'),
                {'__builtins__': {}}, {'inputs': flags, 'github': github}), expected)


if __name__ == '__main__':
    unittest.main()
