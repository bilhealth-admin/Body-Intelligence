"""Evaluate release push selection without CI, credentials or native devices."""
import ast
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

from bil40_internal_build_ci import WORKFLOWS

ROOT = Path(__file__).resolve().parents[2]
RELEASE_BRANCH = 'codex/bil41-android33-release-20261106'
PROMOTION_BRANCH = 'codex/bil41-internal-testflight-20261106'


def push_branches(source):
    match = re.search(r'^  push:\n(.*?)(?=^  [A-Za-z_]|^\S)', source, re.M | re.S)
    if match is None:
        raise ValueError('A required lane needs exact-source push evidence')
    block = match.group(1)
    if re.search(r'^    (?:paths(?:-ignore)?|branches-ignore):', block, re.M):
        raise ValueError('A required lane cannot omit a release push by path')
    inline = re.search(r'^    branches: \[([^\]\n]+)\]$', block, re.M)
    if inline:
        branches = [value.strip() for value in inline.group(1).split(',')]
    else:
        listed = re.fullmatch(r'    branches:\n((?:      - [^\n]+\n)+)', block)
        if listed is None:
            raise ValueError('Unknown push selector requires review')
        branches = re.findall(r'^      - ([^\n]+)$', listed.group(1), re.M)
    if len(branches) != len(set(branches)) or any(
            not re.fullmatch(r'[A-Za-z0-9_./-]+', value) for value in branches):
        raise ValueError('Push branches must be unique explicit identities')
    return set(branches)


def selected_job(source, job, *, branch, event='push', **options):
    block = re.search(r'^  ' + re.escape(job) + r':\n(.*?)(?=^  [\w-]+:\n|\Z)',
                      source.split('\njobs:\n', 1)[1], re.M | re.S).group(1)
    condition = re.search(r'^    if:\s*(.*?)^    name:', block, re.M | re.S).group(1)
    expression = condition.replace('>-', '').replace('${{', '').replace('}}', '')
    expression = expression.replace('&&', ' and ').replace('||', ' or ').replace('!=', '<>')
    expression = expression.replace('!', ' not ').replace('<>', '!=')
    expression = re.sub(r'\btrue\b', 'True', expression)
    tree = ast.parse(' '.join(expression.split()), mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.UnaryOp, ast.Compare, ast.Name,
               ast.Attribute, ast.Constant, ast.And, ast.Or, ast.Not, ast.Eq,
               ast.NotEq, ast.Load)
    if not all(isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError('Unknown job condition requires review')
    flags = dict.fromkeys(('source_audit_only', 'mobsf_only', 'android_native_only',
                          'ios_native_only', 'ios_only', 'android_only',
                          'supabase_only'), False)
    flags.update(options)
    return eval(compile(tree, '<actual workflow condition>', 'eval'),
                {'__builtins__': {}},
                {'inputs': SimpleNamespace(**flags),
                 'github': SimpleNamespace(event_name=event, ref='refs/heads/' + branch)})


class Release41CiTriggersTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = {name: (ROOT / '.github/workflows' / name).read_text(encoding='utf-8')
                       for name in WORKFLOWS}
        cls.security = cls.sources['bil_codeql_security_extended.yml']

    def test_all_ten_release_push_lanes_run_without_path_omissions(self):
        self.assertEqual(len(self.sources), 10)
        for name, source in self.sources.items():
            with self.subTest(workflow=name):
                branches = push_branches(source)
                self.assertIn(RELEASE_BRANCH, branches)
                self.assertIn('bil39/integration-20261025', branches)
                self.assertIn('codex/bil40-device-fixes-20261028', branches)

    def test_same_sha_promotion_does_not_repeat_the_ten_qa_runs(self):
        for name, source in self.sources.items():
            with self.subTest(workflow=name):
                self.assertNotIn(PROMOTION_BRANCH, push_branches(source))

    def test_required_semgrep_is_selected_on_the_real_release_push(self):
        self.assertTrue(selected_job(self.security, 'isolated-source-audit',
                                     branch=RELEASE_BRANCH))
        self.assertFalse(selected_job(self.security, 'isolated-source-audit',
                                      branch=PROMOTION_BRANCH))

    def test_release_keeps_iphone_and_ipad_in_independent_runs(self):
        self.assertFalse(selected_job(self.security, 'ios-native-integration',
                                      branch=RELEASE_BRANCH))
        for device in ('iphone', 'ipad'):
            source = self.sources[f'bil39_{device}_native.yml']
            jobs = source.split('\njobs:\n', 1)[1]
            self.assertEqual(re.findall(r'^  ([\w-]+):$', jobs, re.M), ['native'])
            self.assertNotRegex(jobs, r'(?m)^    if:')
            self.assertNotIn('matrix:', jobs)
            self.assertIn(f'BIL_NATIVE_DEVICE: {device}', jobs)

    def test_existing_native_scopes_and_manual_audit_keep_their_selection(self):
        for branch in ('bil39/integration-20261025', 'codex/bil40-device-fixes-20261028'):
            with self.subTest(branch=branch):
                self.assertTrue(selected_job(self.security, 'isolated-source-audit', branch=branch))
                self.assertFalse(selected_job(self.security, 'ios-native-integration', branch=branch))
        self.assertTrue(selected_job(self.security, 'ios-native-integration', branch='main'))
        self.assertTrue(selected_job(self.security, 'isolated-source-audit',
                                     branch='audit-fixture', event='workflow_dispatch',
                                     source_audit_only=True))
        self.assertFalse(selected_job(self.security, 'ios-native-integration',
                                      branch='audit-fixture', event='workflow_dispatch',
                                      source_audit_only=True))

    def test_unreviewed_path_and_wildcard_selectors_are_rejected(self):
        source = self.sources['verify.yml']
        with self.assertRaises(ValueError):
            push_branches(source.replace('  push:\n', '  push:\n    paths: [lib/**]\n', 1))
        with self.assertRaises(ValueError):
            push_branches(source.replace(RELEASE_BRANCH, 'codex/**', 1))


if __name__ == '__main__':
    unittest.main()
