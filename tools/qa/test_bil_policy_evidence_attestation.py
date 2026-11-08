"""Offline actual native ZIP fixtures for the policy evidence consumer."""
from copy import deepcopy
import io
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest import mock
import urllib.error

import bil_policy_evidence_attestation as policy
from test_bil_native_source_evidence import Fixture, ROOT, SHA, TREE


BRANCH = 'integration/bil-qa-media-policy-20261011'


class PolicyFixture:
    def __init__(self, folder):
        self.folder = Path(folder)
        self.archive_dir = self.folder / 'downloaded'
        self.archive_dir.mkdir()
        self.output = self.folder / 'attestation.json'
        self.api_calls, self.downloads = [], []
        self.responses, self.archives = {}, {}
        self.record = {'schema': policy.SCHEMA, 'tested_source_sha': SHA,
            'tested_source_branch': BRANCH, 'required_runs': {}}
        for index, (role, (workflow, event, names)) in enumerate(policy.SPECS.items()):
            run_id = index + 2001
            run = {'id': run_id, 'run_attempt': 1, 'head_sha': SHA, 'head_branch': BRANCH,
                'repository': {'id': 42, 'full_name': policy.native.REPOSITORY},
                'path': '.github/workflows/' + workflow, 'event': event,
                'status': 'completed', 'conclusion': 'success',
                'html_url': f'https://github.com/{policy.native.REPOSITORY}/actions/runs/{run_id}'}
            attempt = {**run, 'run_started_at': '2026-11-08T00:00:00Z',
                'updated_at': '2026-11-08T00:02:00Z'}
            jobs = [{'id': run_id * 100 + number, 'run_id': run_id, 'run_attempt': 1,
                'head_sha': SHA, 'name': name, 'status': 'completed', 'conclusion': 'success'}
                for number, name in enumerate(sorted(names), 1)]
            row = {'run_id': run_id, 'run_attempt': 1}
            if role in ('iphone_native', 'ipad_native'):
                device = role.removesuffix('_native')
                fixture = Fixture(self.folder, device)
                fixture.run, fixture.attempt, fixture.jobs = run, attempt, jobs
                fixture.meta['workflow_run'].update(id=run_id, head_branch=BRANCH)
                fixture.meta['name'] = f'bil-native-{device}-{SHA}-r{run_id}-a1'
                fixture.edit('controller-provenance.json', lambda value: value.update(
                    run_id=str(run_id), caller_ref='refs/heads/' + BRANCH,
                    caller_workflow_ref=policy.native.REPOSITORY + '/' + run['path'] + '@refs/heads/' + BRANCH))
                fixture.write()
                row['artifact_id'] = fixture.meta['id']
                self.responses[f'/actions/artifacts/{fixture.meta["id"]}'] = fixture.meta
                self.archives[fixture.meta['id']] = fixture.path.read_bytes()
            self.record['required_runs'][role] = row
            self.responses[f'/actions/runs/{run_id}'] = run
            self.responses[f'/actions/runs/{run_id}/attempts/1'] = attempt
            self.responses[f'/actions/runs/{run_id}/attempts/1/jobs?per_page=100&page=1'] = {
                'total_count': len(jobs), 'jobs': jobs}

    def api(self, path):
        self.api_calls.append(path)
        return deepcopy(self.responses[path])

    def download(self, artifact, destination):
        self.downloads.append(artifact)
        Path(destination).write_bytes(self.archives[artifact])

    def verify(self):
        return policy.write_verified_evidence(self.output, self.record, root=ROOT,
            source_sha=SHA, source_tree=TREE, branch=BRANCH, api=self.api,
            download=self.download, archive_dir=self.archive_dir)


class PolicyNativePairTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='bil-policy-evidence-test-')
        self.addCleanup(self.temp.cleanup)
        self.fixture = PolicyFixture(self.temp.name)

    def test_actual_consumer_requires_both_complete_native_archives_before_writing_success(self):
        result = self.fixture.verify()
        self.assertEqual(result['native_pair']['status'], 'BOTH_EXACT_SOURCE_NATIVE_TARGETS_PASS')
        self.assertEqual(len(result['verified_runs']), 6)
        self.assertEqual(len(self.fixture.downloads), 2)
        self.assertTrue(self.fixture.output.is_file())
        self.assertFalse(result['signed_build_or_store_acceptance_proven'])
        self.assertTrue(all(row['xctest']['passedTests'] == 8
            for row in result['native_pair']['native_results']))

    def test_missing_one_native_zip_never_writes_attestation_or_continues(self):
        missing = self.fixture.record['required_runs']['ipad_native']['artifact_id']
        del self.fixture.archives[missing]
        with mock.patch.object(policy.native, 'require_native_pair', wraps=policy.native.require_native_pair) as pair:
            with self.assertRaises(KeyError):
                self.fixture.verify()
            pair.assert_not_called()
        self.assertFalse(self.fixture.output.exists())

    def test_foreign_native_sha_fails_before_any_download_or_attestation(self):
        run = self.fixture.record['required_runs']['ipad_native']['run_id']
        self.fixture.responses[f'/actions/runs/{run}']['head_sha'] = 'f' * 40
        with self.assertRaisesRegex(ValueError, 'workflow identity'):
            self.fixture.verify()
        self.assertEqual(self.fixture.downloads, [])
        self.assertFalse(self.fixture.output.exists())

    def test_old_combined_role_or_missing_device_is_not_a_native_pair(self):
        self.fixture.record['required_runs']['native_android_ios'] = self.fixture.record['required_runs'].pop('ipad_native')
        with self.assertRaisesRegex(ValueError, 'both separate native runs'):
            self.fixture.verify()
        self.assertEqual(self.fixture.api_calls, [])
        self.assertFalse(self.fixture.output.exists())

    def test_foreign_job_attempt_is_rejected_from_the_attempt_specific_inventory(self):
        run = self.fixture.record['required_runs']['iphone_native']['run_id']
        path = f'/actions/runs/{run}/attempts/1/jobs?per_page=100&page=1'
        self.fixture.responses[path]['jobs'][0]['run_attempt'] = 2
        with self.assertRaisesRegex(ValueError, 'current-attempt jobs'):
            self.fixture.verify()
        self.assertEqual(self.fixture.downloads, [])
        self.assertFalse(self.fixture.output.exists())

    def test_a_previous_success_file_cannot_survive_as_current_proof(self):
        self.fixture.output.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'previous attestation'):
            self.fixture.verify()
        self.assertEqual(self.fixture.api_calls, [])

    def test_workflow_calls_the_behavioral_consumer_and_keeps_certification_blocked(self):
        workflow = (ROOT / '.github/workflows/bil_apple_google_policy_gate.yml').read_text(encoding='utf-8')
        block = workflow.split('  evidence-attestation:', 1)[1]
        self.assertIn('python3 tools/qa/bil_policy_evidence_attestation.py', block)
        self.assertIn('test_bil_policy_evidence_attestation.py', block)
        self.assertIn('if: inputs.certify_release', block)
        self.assertIn('exit 2', block)
        self.assertNotIn('native_android_ios', block)


class _Response(io.BytesIO):
    status = 200
    headers = {}


class DocumentationIdentityTests(unittest.TestCase):
    def test_real_git_documentation_parent_is_required_and_dirty_source_fails_closed(self):
        with tempfile.TemporaryDirectory(prefix='bil-policy-git-fixture-') as folder:
            root = Path(folder)
            def git(*arguments):
                return subprocess.check_output(['git', '-c', 'user.name=BIL synthetic fixture',
                    '-c', 'user.email=fixture@invalid.test', '-c', 'commit.gpgsign=false',
                    '-c', 'core.hooksPath=' + str(root / 'no-hooks'), '-c', 'core.autocrlf=false',
                    *arguments], cwd=root,
                    text=True, stderr=subprocess.DEVNULL).strip()
            git('init', '-b', BRANCH)
            implementation = root / 'implementation.txt'
            implementation.write_text('synthetic source\n')
            git('add', '.')
            git('commit', '-m', 'synthetic tested source')
            source = git('rev-parse', 'HEAD')
            doc = root / 'docs/qa_next/fixture.md'
            doc.parent.mkdir(parents=True)
            doc.write_text('synthetic documentation\n')
            git('add', '.')
            git('commit', '-m', 'synthetic documentation only')
            environment = {'GITHUB_REF_NAME': BRANCH, 'GITHUB_REPOSITORY': policy.native.REPOSITORY,
                'GITHUB_SHA': git('rev-parse', 'HEAD')}
            record = {'tested_source_sha': source}
            identity = policy.documentation_source(root, record, environment)
            self.assertEqual(identity['source'], source)
            self.assertEqual(identity['changed'], ['docs/qa_next/fixture.md'])
            implementation.write_text('uncommitted synthetic implementation change\n')
            with self.assertRaisesRegex(ValueError, 'clean immutable checkout'):
                policy.documentation_source(root, record, environment)


class PolicyArtifactDownloadTests(unittest.TestCase):
    def test_signed_storage_redirect_receives_no_github_authorization(self):
        requests = []
        class Opener:
            def open(self, request, timeout):
                requests.append(request)
                if len(requests) == 1:
                    raise urllib.error.HTTPError(request.full_url, 302, 'Found',
                        {'Location': 'https://example.blob.core.windows.net/signed-fixture.zip?sig=synthetic'}, None)
                return _Response(b'synthetic-zip')
        client = policy.GitHubEvidenceClient('synthetic-read-token', opener=Opener())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'native.zip'
            client.download(201, path)
            self.assertEqual(path.read_bytes(), b'synthetic-zip')
        self.assertEqual(requests[0].get_header('Authorization'), 'Bearer synthetic-read-token')
        self.assertIsNone(requests[1].get_header('Authorization'))

    def test_download_enforces_actual_size_even_without_a_length_header(self):
        opener = mock.Mock()
        opener.open.return_value = _Response(b'oversized')
        client = policy.GitHubEvidenceClient('synthetic-read-token', opener=opener)
        with tempfile.TemporaryDirectory() as folder, mock.patch.object(policy.native, 'MAX_ARCHIVE', 1):
            with self.assertRaisesRegex(ValueError, 'download bound'):
                client.download(201, Path(folder) / 'native.zip')


if __name__ == '__main__':
    unittest.main()
