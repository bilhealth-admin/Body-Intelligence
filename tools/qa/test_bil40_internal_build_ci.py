"""Fail-closed pre-signing receipts, synthetic only; no actual CI claimed."""
import copy
from pathlib import Path
import re
import unittest
import bil40_internal_build_ci as gate

SHA = 'a' * 40
WORKFLOW = 'verify.yml'


class InternalBuildGateTest(unittest.TestCase):
    def test_every_required_workflow_runs_on_the_final_integration_sha(self):
        workflow_root = Path(__file__).resolve().parents[2] / '.github/workflows'
        for workflow in gate.WORKFLOWS:
            with self.subTest(workflow=workflow):
                source = (workflow_root / workflow).read_text(encoding='utf-8')
                push = re.search(r'^  push:\n(.*?)(?=^  [A-Za-z_]|^\S)',
                                 source, re.MULTILINE | re.DOTALL)
                self.assertIsNotNone(push, 'A dispatch cannot replace exact-SHA push evidence')
                self.assertIn(gate.BRANCH, push.group(1))
                self.assertNotRegex(push.group(1), r'(?m)^    paths(?:-ignore)?:',
                                    'Path filters can omit a required final-SHA workflow')

    def setUp(self):
        self.run = {'id': 123, 'head_sha': SHA, 'head_branch': gate.BRANCH,
                    'event': 'push', 'status': 'completed', 'conclusion': 'success',
                    'path': '.github/workflows/' + WORKFLOW,
                    'html_url': f'https://github.com/{gate.REPOSITORY}/actions/runs/123'}
        self.jobs = [{'name': name, 'head_sha': SHA, 'status': 'completed',
                      'conclusion': 'success'} for name in gate.WORKFLOWS[WORKFLOW]]

    def check(self):
        return gate.validate_run(self.run, self.jobs, sha=SHA, workflow=WORKFLOW)

    def test_complete_synthetic_receipt_is_passable(self):
        self.assertEqual('PASS', self.check()['status'])

    def test_old_sha_branch_workflow_or_nonfinal_run_cannot_be_reused(self):
        for field, value in [('head_sha', 'b'*40), ('head_branch', 'main'),
                             ('path', '.github/workflows/other.yml'), ('event', 'pull_request'),
                             ('status', 'in_progress'), ('conclusion', 'failure'),
                             ('html_url', 'https://github.com/attacker/other/actions/runs/123')]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.run); self.run[field] = value
                with self.assertRaises(ValueError): self.check()
                self.run = original

    def test_missing_shard_blocks_signing(self):
        self.jobs = [job for job in self.jobs if job['name'] != 'flutter-tests (shard 7 of 8)']
        with self.assertRaises(ValueError): self.check()

    def test_skipped_required_job_is_not_success(self):
        self.jobs[0]['conclusion'] = 'skipped'
        with self.assertRaises(ValueError): self.check()

    def test_job_from_different_sha_is_rejected(self):
        self.jobs[0]['head_sha'] = 'b'*40
        with self.assertRaises(ValueError): self.check()

    def test_extra_failed_job_blocks_overall_success_claim(self):
        self.jobs.append({'name': 'unexpected-job', 'conclusion': 'timed_out'})
        with self.assertRaises(ValueError): self.check()


if __name__ == '__main__':
    unittest.main()
