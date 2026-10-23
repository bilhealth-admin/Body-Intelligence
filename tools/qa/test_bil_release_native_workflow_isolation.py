"""Evaluate the real workflow's native-job conditions, without a YAML runtime."""
import ast
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/bil_codeql_security_extended.yml'


def job(name):
    source = WORKFLOW.read_text(encoding='utf-8').split('\njobs:\n', 1)[1]
    match = re.search(r'^  ' + re.escape(name) + r':\n(.*?)(?=^  [\w-]+:\n|\Z)', source, re.M | re.S)
    if not match:
        raise ValueError('Missing real workflow job')
    return match.group(1)


def native_selected(**inputs):
    condition = re.search(r'^    if:\s*(.*?)^    name:', job('android-native-only'), re.M | re.S).group(1)
    expression = condition.replace('>-', '').replace('${{', '').replace('}}', '')
    expression = re.sub(r'inputs\.([a-z_]+)', lambda match: repr(inputs.get(match[1], False)), expression)
    expression = re.sub(r'\btrue\b', 'True', expression).replace('&&', ' and ').replace('||', ' or ')
    expression = ' '.join(expression.split())

    def walk(node):
        if isinstance(node, ast.Expression): return walk(node.body)
        if isinstance(node, ast.Constant) and type(node.value) is bool: return node.value
        if isinstance(node, ast.BoolOp):
            values = [walk(value) for value in node.values]
            if isinstance(node.op, ast.And): return all(values)
            if isinstance(node.op, ast.Or): return any(values)
        if isinstance(node, ast.Compare) and len(node.ops) == len(node.comparators) == 1:
            left, right = walk(node.left), walk(node.comparators[0])
            if isinstance(node.ops[0], ast.Eq): return left == right
            if isinstance(node.ops[0], ast.NotEq): return left != right
        raise ValueError('Unsupported actual workflow condition')
    return walk(ast.parse(expression, mode='eval'))


class NativeWorkflowIsolationTest(unittest.TestCase):
    def test_default_full_scope_and_explicit_native_scope_keep_all_actual_journeys(self):
        self.assertTrue(native_selected())
        self.assertTrue(native_selected(android_native_only=True))
        native = job('android-native-only')
        self.assertIn('script: bash .github/scripts/bil_android33_native_integration.sh', native)
        self.assertIn('api-level: 33', native)
        self.assertNotIn('github/codeql-action/init', native)
        self.assertIn('bil_prepare_android_kvm.sh', native)

    def test_compiler_and_other_explicit_lanes_do_not_run_ui_under_tracing(self):
        for inputs in ({'android_only': True}, {'ios_only': True},
                       {'android_only': True, 'ios_only': True},
                       {'source_audit_only': True}, {'mobsf_only': True},
                       {'supabase_only': True}, {'ios_native_only': True}):
            with self.subTest(inputs=inputs):
                self.assertFalse(native_selected(**inputs))
        traced = job('analyze')
        self.assertIn('github/codeql-action/analyze', traced)
        self.assertIn('Build Android plugin sources for CodeQL', traced)
        self.assertNotIn('android-emulator-runner', traced)
        self.assertNotIn('script: bash .github/scripts/bil_android33_native_integration.sh', traced)

    def test_native_is_still_an_independent_mandatory_release_gate(self):
        manifest = json.loads((ROOT / 'tools/qa/revalidation_ci_plan.json').read_text(encoding='utf-8'))
        lane = next(row for row in manifest['workflows'] if row['lane_id'] == 'android_native')
        self.assertIn('Android API 33 native integration without CodeQL tracing', lane['required_jobs'])
        self.assertEqual(lane['inputs']['android_native_only'], 'true')

    def test_static_apk_evidence_is_bound_to_the_current_attempt_and_missing_capture_fails(self):
        traced = job('analyze')
        self.assertIn('name: bil-android-codeql-apk-${{ github.sha }}-${{ github.run_attempt }}', traced)
        upload = traced.split('- name: Upload Android CodeQL APK and build evidence', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn('if-no-files-found: error', upload)
        audit = job('offline-mobile-static-audit')
        self.assertIn('BIL_AUDIT_BRANCH: ${{ github.ref_name }}', audit)
        self.assertIn('--expected-branch "$BIL_AUDIT_BRANCH"', audit)
        self.assertNotIn('--expected-branch "${{', audit)


if __name__ == '__main__':
    unittest.main()
