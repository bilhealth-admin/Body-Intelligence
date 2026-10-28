"""Synthetic negative receipt tests, not actual release evidence."""
import copy
import unittest
import bil40_internal_signing_manifest as manifest

SHA = 'a'*40


class Internal40ManifestTest(unittest.TestCase):
    def setUp(self):
        self.receipt = {
            'status': 'INTERNAL_BUILD_PREREQUISITES_PASS', 'source_sha': SHA,
            'build': 40, 'app_store_submission_approved': False,
            'public_release_approved': False,
            'physical_device_acceptance': 'PENDING_INSTALLATION_OF_NEW_IPA',
            'signed_artifact_identity': 'MUST_PASS_AFTER_BUILD',
            'ci': [{'workflow': name, 'source_sha': SHA, 'status': 'PASS',
                    'run_id': i, 'url': f'https://github.com/{manifest.REPOSITORY}/actions/runs/{i}',
                    'required_jobs': sorted(jobs)}
                   for i, (name, jobs) in enumerate(manifest.WORKFLOWS.items(), 1)],
        }

    def render(self):
        return manifest.render(self.receipt, source=SHA, workflow_sha=SHA)

    def test_complete_internal_receipt(self):
        result = self.render()
        self.assertIn('RELEASE_BUILD_NUMBER: 40', result)
        self.assertIn('PHYSICAL_BUILD40_ACCEPTANCE: PENDING_INSTALLATION', result)
        self.assertIn('APP_STORE_SUBMISSION_APPROVED: NO', result)

    def test_wrong_scope_sha_build_or_approval_rejected(self):
        for field, value in [('source_sha', 'b'*40), ('build', 39), ('build', True),
                             ('public_release_approved', True), ('app_store_submission_approved', True),
                             ('physical_device_acceptance', 'PASS')]:
            with self.subTest(field=field, value=value):
                original = copy.deepcopy(self.receipt)
                self.receipt[field] = value
                with self.assertRaises(ValueError): self.render()
                self.receipt = original

    def test_old_or_foreign_missing_failed_job_evidence_rejected(self):
        for field, value in [('source_sha', 'b'*40), ('status', 'FAILED'), ('run_id', 0),
                             ('url', 'https://github.com/attacker/repo/actions/runs/1'),
                             ('required_jobs', [])]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.receipt)
                self.receipt['ci'][0][field] = value
                with self.assertRaises(ValueError): self.render()
                self.receipt = original

    def test_missing_workflow_and_duplicate_run_rejected(self):
        original = copy.deepcopy(self.receipt)
        self.receipt['ci'].pop()
        with self.assertRaises(ValueError): self.render()
        self.receipt = original
        self.receipt['ci'][1]['run_id'] = 1
        self.receipt['ci'][1]['url'] = self.receipt['ci'][0]['url']
        with self.assertRaises(ValueError): self.render()

    def test_orchestration_must_match_source(self):
        with self.assertRaises(ValueError):
            manifest.render(self.receipt, source=SHA, workflow_sha='b'*40)


if __name__ == '__main__':
    unittest.main()
