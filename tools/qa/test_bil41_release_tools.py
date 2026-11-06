"""Behavioral, offline release-tool negatives; not actual CI/upload evidence."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import bil39_full_suite_artifacts as artifact
import bil41_internal_build_ci as gate
import bil41_internal_signing_manifest as manifest

SHA = 'a' * 40
ROOT = Path(__file__).resolve().parents[2]


def valid_cloud():
    return {'status': 'RECORDED_DEPLOYED_SOURCE_PARITY_PASS', 'source_commit': gate.CLOUD_SOURCE,
            'deployed_version': 134, 'runtime_file_count': 15, 'new_model_requests': 0,
            'receipt_sha256': 'b' * 64, 'live_model_health': 'NOT_TESTED_BY_THIS_GATE'}


def receipt(platform='ios'):
    return {'status': 'INTERNAL_BUILD_PREREQUISITES_PASS', 'source_sha': SHA,
            'source_branch': gate.BRANCH, 'platform': platform, 'build': gate.BUILDS[platform],
            'cloud_source_parity': valid_cloud(), 'app_store_submission_approved': False,
            'public_release_approved': False,
            'physical_device_acceptance': 'PENDING_INSTALLATION_OF_NEW_ARTIFACT',
            'signed_artifact_identity': 'MUST_PASS_AFTER_BUILD',
            'ci': [{'workflow': name, 'source_sha': SHA, 'source_branch': gate.BRANCH,
                    'status': 'PASS', 'run_id': index,
                    'url': f'https://github.com/{gate.REPOSITORY}/actions/runs/{index}',
                    'required_jobs': sorted(jobs)}
                   for index, (name, jobs) in enumerate(gate.WORKFLOWS.items(), 1)]}


class ExactSource41GateTest(unittest.TestCase):
    def setUp(self):
        self.workflow = 'verify.yml'
        self.run = {'id': 123, 'head_sha': SHA, 'head_branch': gate.BRANCH,
                    'event': 'push', 'status': 'completed', 'conclusion': 'success',
                    'path': '.github/workflows/' + self.workflow,
                    'html_url': f'https://github.com/{gate.REPOSITORY}/actions/runs/123'}
        self.jobs = [{'name': name, 'head_sha': SHA, 'status': 'completed',
                      'conclusion': 'success'} for name in gate.WORKFLOWS[self.workflow]]

    def check(self):
        return gate.validate_run(self.run, self.jobs, sha=SHA, workflow=self.workflow)

    def test_exact_completed_run_preserves_sha_branch_and_coverage(self):
        row = self.check()
        self.assertEqual(row['source_sha'], SHA)
        self.assertEqual(row['source_branch'], gate.BRANCH)
        self.assertEqual(set(row['required_jobs']), gate.WORKFLOWS[self.workflow])

    def test_old_wrong_branch_sha_dispatch_foreign_or_nonfinal_runs_fail(self):
        for field, value in [('head_sha', 'b'*40), ('head_branch', 'main'),
                             ('head_branch', gate.PROMOTION_BRANCH), ('event', 'workflow_dispatch'),
                             ('conclusion', 'failure'), ('status', 'in_progress'), ('id', True),
                             ('path', '.github/workflows/other.yml'),
                             ('html_url', f'https://github.com/{gate.REPOSITORY}/actions/runs/123/foreign')]:
            with self.subTest(field=field, value=value):
                prior = dict(self.run)
                self.run[field] = value
                with self.assertRaises(ValueError):
                    self.check()
                self.run = prior

    def test_missing_duplicate_skipped_failed_and_wrong_sha_jobs_block(self):
        prior = copy.deepcopy(self.jobs)
        for mutation in ('missing', 'duplicate', 'skipped', 'failed', 'sha'):
            self.jobs = copy.deepcopy(prior)
            if mutation == 'missing':
                self.jobs.pop()
            elif mutation == 'duplicate':
                self.jobs.append(dict(self.jobs[0]))
            elif mutation in ('skipped', 'failed'):
                self.jobs[0]['conclusion'] = mutation
            else:
                self.jobs[0]['head_sha'] = 'b' * 40
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.check()

    def test_additional_unfinished_or_failed_job_cannot_be_hidden(self):
        for status, conclusion in [('completed', 'failure'), ('in_progress', 'skipped')]:
            with self.subTest(status=status):
                self.jobs.append({'name': 'additional', 'status': status, 'conclusion': conclusion})
                with self.assertRaises(ValueError):
                    self.check()
                self.jobs.pop()


class RecordedCloudParityTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory(prefix='bil41-parity-')
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        self.record = json.loads((ROOT / gate.CLOUD_RECEIPT).read_bytes())
        self.data = {}
        for row in self.record['files'] + self.record['deployed_configuration']:
            data = (ROOT / row['path']).read_bytes()
            path = self.root / row['path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            self.data[row['path']] = data

    def check(self):
        return gate.cloud_parity(self.root, self.record, source_bytes=self.data.__getitem__)

    def test_all_runtime_and_configuration_bytes_match_separate_cloud_source(self):
        result = self.check()
        self.assertEqual(result['source_commit'], gate.CLOUD_SOURCE)
        self.assertEqual(result['runtime_file_count'], 15)
        self.assertEqual(result['live_model_health'], 'NOT_TESTED_BY_THIS_GATE')

    def test_changed_bytes_or_other_git_source_are_rejected(self):
        path = self.root / self.record['files'][0]['path']
        original = path.read_bytes()
        path.write_bytes(original + b'changed')
        with self.assertRaises(ValueError):
            self.check()
        path.write_bytes(original)
        self.data[self.record['files'][0]['path']] += b'other commit'
        with self.assertRaises(ValueError):
            self.check()

    def test_missing_duplicate_escaping_and_size_tampering_are_rejected(self):
        original = copy.deepcopy(self.record)
        for mutation in ('missing', 'duplicate', 'escape', 'backslash', 'size', 'configuration'):
            self.record = copy.deepcopy(original)
            if mutation == 'missing':
                self.record['files'].pop()
            elif mutation == 'duplicate':
                self.record['files'][1] = self.record['files'][0]
            elif mutation == 'escape':
                self.record['files'][0]['path'] = 'supabase/functions/../../../secret'
            elif mutation == 'backslash':
                self.record['files'][0]['path'] = 'supabase/functions/ai-coach\\index.ts'
            elif mutation == 'size':
                self.record['files'][0]['bytes'] += 1
            else:
                self.record['deployed_configuration'] = []
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.check()

    def test_invented_model_success_writes_wrong_version_or_app_sha_rejected(self):
        for field, value in [('source_commit', SHA), ('version', 133), ('read_only', False),
                             ('cloud_writes', 1), ('new_model_requests', 1),
                             ('all_candidate_and_cloud_source_bytes_match', False),
                             ('verified_at_utc', '2026-11-06T00:21:11')]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.record)
                self.record[field] = value
                with self.assertRaises(ValueError):
                    self.check()
                self.record = original


class PreSigning41OrchestrationTest(unittest.TestCase):
    def execute(self, folder, platform, *, fail_latest=False, dirty=False):
        output = folder / (platform + '.json')
        workflows = list(gate.WORKFLOWS)
        calls = []

        def git(command, **options):
            if command[1:] == ['rev-parse', 'HEAD']:
                return SHA
            if command[1] == 'status':
                return ' M source.dart' if dirty else ''
            if command[1] == 'hash-object':
                return gate.PROTECTED[command[2]]
            if command[1] == 'show':
                return (ROOT / command[2].split(':', 1)[1]).read_bytes()
            raise AssertionError('Unexpected local command')

        def api(path):
            calls.append(path)
            if path.startswith('/git/ref/heads/'):
                branch = path.removeprefix('/git/ref/heads/')
                return {'object': {'sha': {'work/ios38-safe-fixes-20261025': gate.BASE,
                        'codex/bil40-device-fixes-20261028': gate.SIGNED40,
                        gate.BRANCH: SHA}[branch]}}
            workflow = path.split('/')[3]
            index = workflows.index(workflow) + 1
            run = {'id': index, 'head_sha': SHA, 'head_branch': gate.BRANCH,
                   'event': 'push', 'status': 'completed', 'conclusion': 'success',
                   'path': '.github/workflows/' + workflow,
                   'html_url': f'https://github.com/{gate.REPOSITORY}/actions/runs/{index}'}
            if fail_latest and workflow == workflows[0]:
                return {'workflow_runs': [run, dict(run, id=99, conclusion='failure')]}
            return {'workflow_runs': [run]}

        def jobs(index):
            if index == 99:
                index = 1  # The latest failed attempt still has its own fetched job list.
            return [{'name': name, 'head_sha': SHA, 'status': 'completed', 'conclusion': 'success'}
                    for name in gate.WORKFLOWS[workflows[index - 1]]]

        with patch('sys.argv', ['gate', '--sha', SHA, '--branch', gate.BRANCH,
                   '--platform', platform, '--output', str(output)]), \
                patch.object(gate.Path, 'cwd', return_value=ROOT), \
                patch.object(gate.subprocess, 'check_output', side_effect=git), \
                patch.object(gate.subprocess, 'run') as ancestry, \
                patch.object(gate, 'api', side_effect=api), \
                patch.object(gate, 'all_jobs', side_effect=jobs):
            if dirty or fail_latest:
                with self.assertRaises(ValueError):
                    gate.main()
                self.assertFalse(output.exists(), 'Failure must not create a passing receipt')
                if dirty:
                    self.assertEqual(calls, [], 'Dirty sources fail before GitHub reads')
            else:
                gate.main()
                record = json.loads(output.read_bytes())
                self.assertEqual(record['build'], gate.BUILDS[platform])
                self.assertEqual(record['source_sha'], SHA)
                self.assertEqual(len(record['ci']), 10)
                self.assertEqual(len({row['run_id'] for row in record['ci']}), 10)
                self.assertEqual(record['cloud_source_parity']['source_commit'], gate.CLOUD_SOURCE)
                self.assertFalse(record['app_store_submission_approved'])
                self.assertEqual(len(calls), 13)
                ancestry.assert_called_once()

    def test_actual_gate_main_builds_each_platform_receipt_from_ten_exact_run_fixtures(self):
        with tempfile.TemporaryDirectory(prefix='bil41-gate-main-') as directory:
            for platform in gate.BUILDS:
                self.execute(Path(directory), platform)

    def test_old_success_cannot_mask_a_new_failed_attempt_and_dirty_source_is_blocked(self):
        with tempfile.TemporaryDirectory(prefix='bil41-gate-negative-') as directory:
            self.execute(Path(directory), 'ios', fail_latest=True)
            self.execute(Path(directory), 'android', dirty=True)


class Internal41ManifestTest(unittest.TestCase):
    def test_each_platform_uses_own_build_and_pending_acceptance(self):
        for platform, number in gate.BUILDS.items():
            text = manifest.render(receipt(platform), source=SHA, workflow_sha=SHA, platform=platform)
            self.assertIn(f'RELEASE_BUILD_NUMBER: {number}', text)
            self.assertIn('PHYSICAL_ARTIFACT_ACCEPTANCE: PENDING_INSTALLATION', text)
            self.assertIn('APP_STORE_SUBMISSION_APPROVED: NO', text)
            self.assertIn('LIVE_MODEL_HEALTH: NOT_TESTED_BY_THIS_GATE', text)

    def test_wrong_platform_build_source_and_premature_approval_fail(self):
        for field, value in [('platform', 'android'), ('build', 40), ('build', True),
                             ('source_sha', 'b'*40), ('source_branch', gate.PROMOTION_BRANCH),
                             ('public_release_approved', True), ('app_store_submission_approved', True),
                             ('physical_device_acceptance', 'PASS')]:
            with self.subTest(field=field):
                record = receipt()
                record[field] = value
                with self.assertRaises(ValueError):
                    manifest.render(record, source=SHA, workflow_sha=SHA, platform='ios')
        with self.assertRaises(ValueError):
            manifest.render(receipt(), source=SHA, workflow_sha='b'*40, platform='ios')

    def test_all_distinct_runs_and_required_jobs_are_mandatory(self):
        for mutation in ('missing', 'duplicate', 'job', 'sha', 'branch'):
            record = receipt()
            if mutation == 'missing':
                record['ci'].pop()
            elif mutation == 'duplicate':
                record['ci'][1] = copy.deepcopy(record['ci'][0])
            elif mutation == 'job':
                record['ci'][0]['required_jobs'].pop()
            elif mutation == 'sha':
                record['ci'][0]['source_sha'] = 'b'*40
            else:
                record['ci'][0]['source_branch'] = 'main'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                manifest.render(record, source=SHA, workflow_sha=SHA, platform='ios')

    def test_cloud_parity_cannot_be_replaced_with_full_app_sha_or_model_health(self):
        for field, value in [('source_commit', SHA), ('runtime_file_count', 14),
                             ('deployed_version', 133), ('live_model_health', 'PASS')]:
            record = receipt()
            record['cloud_source_parity'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                manifest.render(record, source=SHA, workflow_sha=SHA, platform='ios')

    def test_cli_writes_new_runner_private_manifest_and_environment_exports(self):
        for platform in gate.BUILDS:
            with self.subTest(platform=platform), tempfile.TemporaryDirectory(prefix='bil41-manifest-') as directory:
                folder = Path(directory)
                raw = folder / 'ci.json'
                raw.write_text(json.dumps(receipt(platform)))
                output, env = folder / 'acceptance.md', folder / 'env'
                prior = Path.cwd()
                try:
                    os.chdir(folder)
                    with patch('sys.argv', ['manifest', '--receipt', str(raw), '--platform', platform,
                               '--output', str(output)]), patch.dict(os.environ, {
                               'GITHUB_SHA': SHA, 'RUNNER_TEMP': str(folder), 'GITHUB_ENV': str(env)}), \
                            patch.object(manifest.subprocess, 'check_output', return_value=SHA):
                        manifest.main()
                    digest = hashlib.sha256(output.read_bytes()).hexdigest()
                    exports = env.read_text()
                    self.assertIn('BIL_RELEASE_MANIFEST_PATH=' + str(output.resolve()), exports)
                    self.assertIn('BIL_AUDITED_FREEZE_MANIFEST_SHA256=' + digest, exports)
                    with patch('sys.argv', ['manifest', '--receipt', str(raw), '--platform', platform,
                               '--output', str(output)]), patch.dict(os.environ, {
                               'GITHUB_SHA': SHA, 'RUNNER_TEMP': str(folder), 'GITHUB_ENV': str(env)}), \
                            patch.object(manifest.subprocess, 'check_output', return_value=SHA), \
                            self.assertRaises(ValueError):
                        manifest.main()
                finally:
                    os.chdir(prior)


class FullSuite41CollectorTest(unittest.TestCase):
    def test_all_eight_real_archives_require_the_exact_41_run_and_branch(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            for name in sorted(artifact.MEMBERS):
                archive.writestr(name, '{"fixture": true}')
        payload = data.getvalue()
        rows = [{'id': 100+i, 'name': f'bil39-full-shard-{i}-{SHA}',
                 'created_at': '2026-11-06T01:00:00Z', 'expired': False,
                 'size_in_bytes': len(payload), 'digest': 'sha256:' + hashlib.sha256(payload).hexdigest(),
                 'workflow_run': {'head_sha': SHA, 'id': 123, 'head_branch': gate.BRANCH}}
                for i in range(8)]
        run = {'id': 123, 'head_sha': SHA, 'head_branch': gate.BRANCH,
               'event': 'push', 'path': '.github/workflows/verify.yml'}

        def download(command, *, stdout, check, timeout):
            self.assertTrue(check)
            self.assertEqual(timeout, 60)
            self.assertRegex(command[-1], r'/actions/artifacts/10[0-7]/zip$')
            stdout.write(payload)

        with tempfile.TemporaryDirectory(prefix='bil41-shards-') as directory:
            output = Path(directory) / 'complete'
            with patch('sys.argv', ['collector', '--sha', SHA, '--run-id', '123',
                       '--branch', gate.BRANCH, '--total', '8', '--output', str(output)]), \
                    patch.object(artifact, 'api', side_effect=lambda path: run if path == '/actions/runs/123'
                                 else {'artifacts': rows}), patch.object(artifact.subprocess, 'run', download):
                artifact.main()
            self.assertEqual(len(list(output.rglob('receipt.json'))), 8)
            self.assertFalse(json.loads((output / 'artifact-selection.json').read_bytes())['prior_artifacts_deleted'])
        rows[0]['workflow_run']['head_branch'] = artifact.BRANCH
        with self.assertRaises(ValueError):
            artifact.select(rows, sha=SHA, run_id=123, total=8, branch=gate.BRANCH)


class Internal41WorkflowBoundaryTest(unittest.TestCase):
    def test_promotion_does_not_race_final_qa_and_retains_security_identity_gates(self):
        text = (ROOT / '.github/workflows/bil41_internal_testflight.yml').read_text()
        push = re.search(r'^  push:\n(.*?)(?=^\S)', text, re.M | re.S).group(1)
        self.assertIn(gate.PROMOTION_BRANCH, push)
        self.assertNotIn(gate.BRANCH, push)
        self.assertNotIn('workflow_dispatch:', text)
        gate_at = text.index('python3 tools/qa/bil41_internal_build_ci.py')
        self.assertLess(gate_at, text.index('secrets.APPLE_TEAM_ID'))
        for marker in ('--platform ios', "BUILD_NUMBER: '41'", '--build 41',
                       'SIGNED_IPA_CODESIGN_GATE=PASS', 'SIGNED_IPA_FORBIDDEN_CRYPTO_MARKERS=0',
                       'NATIVE_CRYPTO_RUNTIME_GATE=PASS', '--platform=ios',
                       'BIL_MOBILE_INTEGRITY_REQUIRED', "write(ready?'testflight-ready'",
                       'BIL_AUDITED_FREEZE_MANIFEST_SHA256',
                       'BIL_TESTED_SOURCE_SHA', 'APP_STORE_CONNECT_PRIVATE_KEY_BASE64'):
            if marker == 'BIL_AUDITED_FREEZE_MANIFEST_SHA256':
                # Exported from the executed shared manifest helper, not a stale env override.
                self.assertIn(marker, (ROOT / 'tools/qa/bil41_internal_signing_manifest.py').read_text())
            else:
                self.assertIn(marker, text)
        self.assertNotIn('BIL41_VERIFIED_CLOUD_SOURCE_SHA', text)
        self.assertNotIn('fitness BLE,StoreKit sandbox', text)
        self.assertNotIn('submit_for_review', text)
        self.assertNotIn('BIL_RELEASE_MANIFEST_PATH:', text)


if __name__ == '__main__':
    unittest.main()
