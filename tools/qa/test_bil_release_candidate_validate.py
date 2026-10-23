"""Fault injection for the feature-only validation controller."""
from contextlib import ExitStack, redirect_stdout, redirect_stderr
from io import StringIO
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import bil_release_candidate_validate as validate


class ControllerGuards(unittest.TestCase):
    def exercise(self, fail=None, change_source=False, branch=None):
        with tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
            root = Path(directory)
            calls = []
            def git(*args):
                if args == ('branch', '--show-current'):
                    return branch or validate.BRANCH
                if args == ('rev-parse', 'HEAD'):
                    return validate.SOURCE_BASE
                return 'lib/feature.dart'
            def launch(command, **_):
                calls.append(command)
                is_root = '--reporter=json' in command
                is_source_audit = 'tool/epic14_release_audit.dart' in command
                is_producer_guard = 'test_bil_mobsf*.py' in command
                is_sync_guard = 'tools/qa/bil_manual_sync_evidence.py' in command
                is_failed = fail == ('root-suite' if is_root else 'full-analysis' if 'analyze' in command else 'source-audit-epic14' if is_source_audit else 'offline-apk-producer-guards' if is_producer_guard else 'manual-sync-live-proof' if is_sync_guard else '')
                output = ['{"type":"testDone","hidden":false,"result":"success","skipped":false}\n', '{"type":"done","success":' + ('false' if is_failed else 'true') + '}\n']
                return Mock(stdout=iter(output), wait=Mock(return_value=1 if is_failed else 0))
            stack.enter_context(patch.object(validate, 'ROOT', root))
            stack.enter_context(patch.object(validate.owner, 'git', side_effect=git))
            stack.enter_context(patch.object(validate.owner, 'resources', return_value={'ram_available_bytes':8*1024**3, 'disk_free_bytes':10*1024**3}))
            snap = Mock(return_value={'source':'stable'})
            if change_source:
                snap.side_effect = [{'source':'stable'}, {'source':'stable'}, {'source':'edited'}]
            stack.enter_context(patch.object(validate, 'snapshot', snap))
            stack.enter_context(patch.object(validate.subprocess, 'run'))
            stack.enter_context(patch.object(validate.subprocess, 'Popen', side_effect=launch))
            stack.enter_context(patch.object(validate.shutil, 'which', return_value='deno'))
            stack.enter_context(patch.object(validate.sys, 'argv', ['script','--expect-head',validate.SOURCE_BASE,'--flutter','fake-flutter','--manual-sync-proof',str(root / 'synthetic-proof.json'),'--reported-account-proof',str(root / 'synthetic-account-proof.json'),'--run']))
            stack.enter_context(redirect_stdout(StringIO()))
            stack.enter_context(redirect_stderr(StringIO()))
            if branch:
                with self.assertRaisesRegex(RuntimeError, 'independent branch'):
                    validate.main()
                self.assertEqual(calls, [])
                return
            code = validate.main()
            state = json.loads(next(root.glob('build/release-ios38-android33/frozen-*/status.json')).read_text(encoding='utf8'))
            return code, state, calls

    def test_other_branch_cannot_run(self):
        self.exercise(branch='integration/bil-qa-media-policy-20261011')

    def test_sync_proof_failure_prevents_all_other_final_stages(self):
        code, state, calls = self.exercise(fail='manual-sync-live-proof')
        self.assertEqual(code, 1)
        self.assertEqual(state['stages'][-1]['name'], 'manual-sync-live-proof')
        self.assertEqual(len(calls), 1)
        self.assertFalse(state['release_ready'])

    def test_analysis_failure_never_starts_root_or_reports_success(self):
        code, state, calls = self.exercise(fail='full-analysis')
        self.assertEqual(code, 1)
        self.assertEqual(state['status'], 'failed')
        self.assertFalse(any('--reporter=json' in command for command in calls))
        self.assertFalse(state['release_ready'])

    def test_failed_root_cannot_be_counted_as_pass(self):
        code, state, _ = self.exercise(fail='root-suite')
        self.assertEqual(code, 1)
        self.assertEqual(state['stages'][-1]['status'], 'fail')
        self.assertFalse(state['release_ready'])

    def test_failed_actual_source_audit_blocks_analysis_and_root(self):
        code, state, calls = self.exercise(fail='source-audit-epic14')
        self.assertEqual(code, 1)
        self.assertEqual(state['stages'][-1]['name'], 'source-audit-epic14')
        self.assertEqual(state['stages'][-1]['status'], 'fail')
        self.assertFalse(any('analyze' in command or '--reporter=json' in command for command in calls))
        self.assertFalse(state['release_ready'])

    def test_all_noninteractive_source_audits_execute_before_root(self):
        code, _, calls = self.exercise()
        self.assertEqual(code, 0)
        audits = [command[1] for command in calls
                  if len(command) == 2 and command[1].startswith('tool/epic')]
        self.assertEqual(audits, [
            'tool/epic11_localization_audit.dart',
            'tool/epic12_security_audit.dart',
            'tool/epic13_commerce_audit.dart',
            'tool/epic14_release_audit.dart',
            'tool/epic16_release_audit.dart',
        ])

    def test_static_apk_identity_guard_failure_cannot_continue_to_analysis_or_root(self):
        code, state, calls = self.exercise(fail='offline-apk-producer-guards')
        self.assertEqual(code, 1)
        self.assertEqual(state['stages'][-1]['name'], 'offline-apk-producer-guards')
        self.assertFalse(any('analyze' in command or '--reporter=json' in command for command in calls))
        self.assertFalse(state['release_ready'])

    def test_source_mutation_invalidates_successful_exit(self):
        code, state, calls = self.exercise(change_source=True)
        self.assertEqual(code, 1)
        self.assertIn('Frozen source changed', state['error'])
        self.assertEqual(len(calls), 1)

    def test_local_success_is_explicitly_not_release_approval(self):
        code, state, calls = self.exercise()
        self.assertEqual(code, 0)
        self.assertEqual(state['status'], 'local_validation_passed')
        self.assertFalse(state['release_ready'])
        root = calls[-1]
        self.assertIn('--concurrency=2', root)
        self.assertFalse(any('shard' in arg or 'no-assert' in arg for arg in root))


if __name__ == '__main__':
    unittest.main()
