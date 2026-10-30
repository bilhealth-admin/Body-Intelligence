"""Isolated diagnostic ownership/cleanup controls, not actual macOS evidence."""
import json
import re
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from bil40_ipad_history_diagnostic import Diagnostic, select_device, valid_owned_uuid

UUID = '11111111-1111-4111-8111-111111111111'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'


class DiagnosticTest(unittest.TestCase):
    def test_selector_retains_ipad_and_latest_available_ios_without_phone_fallback(self):
        runtimes = {'runtimes': [
            {'isAvailable': True, 'identifier': RUNTIME, 'version': '26.5'},
            {'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-1', 'version': '26.1'}]}
        devices = {'devicetypes': [{'name': 'iPad Pro 13-inch (M4)', 'identifier': 'ipad-M4'},
                                  {'name': 'iPhone 16 Pro', 'identifier': 'iphone'}]}
        self.assertEqual(select_device(runtimes, devices), (RUNTIME, 'ipad-M4'))
        with self.assertRaises(ValueError):
            select_device(runtimes, {'devicetypes': [devices['devicetypes'][1]]})
        for invalid in ('', '../other', UUID + '\n' + UUID, 'g' * 36):
            self.assertFalse(valid_owned_uuid(invalid))
        self.assertTrue(valid_owned_uuid(UUID))

    def run_fixture(self, *, fail=None, created=UUID, collect_failure=False, cleanup_failure=False):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        runner = Diagnostic(root, root / 'evidence')
        calls = []
        def stage(label, seconds, command):
            calls.append((label, seconds, command))
            if label == fail or (cleanup_failure and label == 'delete'):
                raise RuntimeError('original-' + label)
            return {
                'source-head': 'a' * 40, 'source-tree': 'b' * 40,
                'runtimes': json.dumps({'runtimes': [{'isAvailable': True, 'identifier': RUNTIME, 'version': '26.5'}]}),
                'device-types': json.dumps({'devicetypes': [{'name': 'iPad Pro 13-inch (M4)', 'identifier': 'ipad-M4'}]}),
                'create': created,
            }.get(label, '')
        runner.stage = stage
        def collect():
            if collect_failure:
                raise ValueError('collection failed')
        runner.collect = collect
        with patch.dict('os.environ', {}, clear=False):
            code = runner.run()
        return runner, calls, code

    def test_exact_eight_coach_cases_one_drive_and_owned_cleanup(self):
        runner, calls, code = self.run_fixture()
        self.assertEqual(code, 0)
        self.assertEqual(runner.receipt['coach_cases'], 8)
        config = next(c for label, _, c in calls if label == 'feature-config')
        self.assertIn('--dart-define=BIL_QA_NATIVE_COACH_ONLY=true', config)
        self.assertFalse(any('BIL_QA_NATIVE_SCENE' in part for part in config))
        self.assertIn('--dart-define=BIL_USE_SUPABASE=false', config)
        self.assertIn('--dart-define=BIL_PAYMENTS_ENABLED=false', config)
        self.assertEqual(sum(label == 'drive' for label, _, _ in calls), 1)
        self.assertEqual([(label, seconds, command[-1]) for label, seconds, command in calls[-2:]],
                         [('shutdown', 30, UUID), ('delete', 30, UUID)])
        self.assertNotIn('system-crypto', [label for label, _, _ in calls])

    def test_invalid_uuid_stops_before_build_and_never_cleans_unknown_device(self):
        runner, calls, code = self.run_fixture(created='../bad')
        self.assertEqual(code, 1)
        self.assertIsNone(runner.device)
        self.assertFalse(any(label in ('feature-build', 'delete', 'shutdown') for label, _, _ in calls))

    def test_setup_failure_still_deletes_only_its_created_simulator(self):
        runner, calls, code = self.run_fixture(fail='native-preflight')
        self.assertEqual(code, 1)
        self.assertEqual(calls[-1], ('delete', 30, ['xcrun', 'simctl', 'delete', UUID]))
        self.assertFalse(any(label == 'drive' for label, _, _ in calls))

    def test_drive_failure_preserved_when_collection_and_cleanup_also_fail(self):
        runner, calls, code = self.run_fixture(fail='drive', collect_failure=True, cleanup_failure=True)
        self.assertEqual(code, 1)
        self.assertEqual(runner.receipt['error'], 'original-drive')
        self.assertEqual(runner.receipt['collection_error_type'], 'ValueError')
        self.assertEqual(runner.receipt['cleanup_errors'], [{'stage': 'delete', 'error_type': 'RuntimeError'}])
        self.assertFalse(runner.receipt['completed'])
        self.assertEqual(sum(label == 'drive' for label, _, _ in calls), 1)

    def test_cleanup_failure_cannot_be_a_clean_diagnostic_pass(self):
        runner, _, code = self.run_fixture(cleanup_failure=True)
        self.assertEqual(code, 1)
        self.assertTrue(runner.receipt['cleanup_errors'])
        self.assertEqual(runner.receipt['scope'], 'DIAGNOSTIC_ONLY_NOT_RELEASE_ACCEPTANCE')


class ActualGitCheckoutTest(unittest.TestCase):
    def git(self, root, *arguments, check=True):
        result = subprocess.run(['git', '-c', 'user.name=BIL QA',
            '-c', 'user.email=bil-qa@example.invalid', *arguments], cwd=root,
            text=True, capture_output=True, timeout=15)
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def graph(self, root):
        origin = root / 'origin'
        origin.mkdir()
        self.git(origin, 'init', '--initial-branch=main')
        base = None
        for index in range(3):
            (origin / 'synthetic.txt').write_text(str(index), encoding='utf-8')
            self.git(origin, 'add', 'synthetic.txt')
            self.git(origin, 'commit', '-m', 'synthetic-' + str(index))
            if index == 0:
                base = self.git(origin, 'rev-parse', 'HEAD').stdout.strip()
        head = self.git(origin, 'rev-parse', 'HEAD').stdout.strip()
        self.git(origin, 'checkout', '--orphan', 'unrelated')
        (origin / 'synthetic.txt').write_text('independent root', encoding='utf-8')
        self.git(origin, 'add', 'synthetic.txt')
        self.git(origin, 'commit', '-m', 'unrelated-root')
        unrelated = self.git(origin, 'rev-parse', 'HEAD').stdout.strip()
        self.git(origin, 'checkout', 'main')
        return origin, base, head, unrelated

    def test_actual_depth_one_lacks_base_and_full_ancestry_keeps_unrelated_base_rejected(self):
        with tempfile.TemporaryDirectory(prefix='bil-history-git-control-') as folder:
            root = Path(folder)
            origin, base, head, unrelated = self.graph(root)
            shallow = root / 'shallow'
            self.git(root, 'clone', '--depth', '1', origin.as_uri(), str(shallow))
            self.assertEqual(self.git(shallow, 'rev-parse', '--is-shallow-repository').stdout.strip(), 'true')
            self.assertEqual(self.git(shallow, 'merge-base', '--is-ancestor', base, 'HEAD', check=False).returncode, 128)
            full = root / 'full'
            self.git(root, 'clone', origin.as_uri(), str(full))
            self.assertEqual(self.git(full, 'rev-parse', 'HEAD').stdout.strip(), head)
            self.assertEqual(self.git(full, 'merge-base', '--is-ancestor', base, 'HEAD', check=False).returncode, 0)
            self.git(full, 'cat-file', '-e', unrelated + '^{commit}')
            self.assertEqual(self.git(full, 'merge-base', '--is-ancestor', unrelated, 'HEAD', check=False).returncode, 1)

    def test_actual_git_clone_using_workflow_checkout_depth_can_verify_original_base(self):
        workflow = Path(__file__).resolve().parents[1] / 'workflows/bil40_ipad_history_diagnostic.yml'
        text = workflow.read_text(encoding='utf-8')
        checkout = text.split('- name: Check out exact diagnostic source', 1)[1].split('- name:', 1)[0]
        match = re.search(r'^\s+fetch-depth:\s*(\d+)\s*$', checkout, re.MULTILINE)
        # actions/checkout defaults to one commit; depth0 means full ancestry.
        depth = int(match.group(1)) if match else 1
        with tempfile.TemporaryDirectory(prefix='bil-history-workflow-git-') as folder:
            root = Path(folder)
            origin, base, head, _ = self.graph(root)
            clone = root / 'checkout'
            options = ['--depth', str(depth)] if depth else []
            self.git(root, 'clone', *options, origin.as_uri(), str(clone))
            self.assertEqual(self.git(clone, 'rev-parse', 'HEAD').stdout.strip(), head)
            result = self.git(clone, 'merge-base', '--is-ancestor', base, 'HEAD', check=False)
            self.assertEqual(result.returncode, 0,
                'Workflow checkout must retain the original base even after multiple diagnostic commits: ' + result.stderr)


if __name__ == '__main__':
    unittest.main()
