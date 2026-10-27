import copy
import unittest

from bil39_internal_build_ci import WORKFLOWS
from bil39_internal_signing_manifest import RUNS, SOURCE, render


class InternalSigningManifestTest(unittest.TestCase):
    def receipt(self):
        return {'status': 'INTERNAL_BUILD_PREREQUISITES_PASS', 'source_sha': SOURCE, 'build': 39,
                'app_store_submission_approved': False, 'public_release_approved': False,
                'physical_device_acceptance': 'PENDING_INSTALLATION_OF_NEW_IPA',
                'signed_artifact_identity': 'MUST_PASS_AFTER_BUILD',
                'ci': [{'workflow': workflow, 'run_id': run, 'source_sha': SOURCE, 'status': 'PASS',
                        'url': f'https://github.com/bilhealth-admin/Body-Intelligence/actions/runs/{run}',
                        'required_jobs': sorted(WORKFLOWS[workflow])} for workflow, run in RUNS.items()]}

    def result(self, receipt):
        return render(receipt, required_jobs=WORKFLOWS, workflow_sha='a' * 40)

    def test_real_complete_receipt_binds_source_and_keeps_acceptance_boundaries(self):
        value = self.result(self.receipt())
        self.assertIn('SOURCE_SHA: ' + SOURCE, value)
        self.assertIn('RELEASE_BUILD_NUMBER: 39\n', value)
        self.assertIn('PUBLIC_RELEASE_APPROVED: NO\n', value)
        self.assertIn('PHYSICAL_BUILD39_ACCEPTANCE: PENDING_INSTALLATION\n', value)
        self.assertEqual(value.count('(PASS, source ' + SOURCE + ')'), 10)

    def test_unaccepted_candidate_or_public_approval_is_rejected(self):
        for field, value in [('status', 'FAIL'), ('source_sha', 'b' * 40), ('build', 38),
                             ('build', True), ('public_release_approved', True),
                             ('app_store_submission_approved', True),
                             ('physical_device_acceptance', 'PASS'),
                             ('signed_artifact_identity', 'PASS')]:
            with self.subTest(field=field, value=value):
                receipt = self.receipt(); receipt[field] = value
                with self.assertRaises(ValueError): self.result(receipt)

    def test_missing_duplicate_unexpected_or_nonlist_workflows_are_rejected(self):
        original = self.receipt()
        for ci in [original['ci'][:-1], original['ci'] + [original['ci'][0]],
                   original['ci'][:-1] + [original['ci'][0]], None]:
            receipt = copy.deepcopy(original); receipt['ci'] = ci
            with self.subTest(ci_length=len(ci) if ci else 0):
                with self.assertRaises(ValueError): self.result(receipt)

    def test_each_workflow_identity_and_job_set_is_mandatory(self):
        for index in range(10):
            for field, value in [('source_sha', 'b' * 40), ('status', 'FAIL'),
                                 ('run_id', 1), ('url', 'https://example.invalid'),
                                 ('required_jobs', [])]:
                with self.subTest(workflow=index, field=field):
                    receipt = self.receipt(); receipt['ci'][index][field] = value
                    with self.assertRaises(ValueError): self.result(receipt)

    def test_duplicate_required_job_is_not_accepted_as_complete(self):
        receipt = self.receipt(); receipt['ci'][0]['required_jobs'].append(receipt['ci'][0]['required_jobs'][0])
        with self.assertRaises(ValueError): self.result(receipt)

    def test_unrecorded_or_invalid_orchestration_identity_is_rejected(self):
        with self.assertRaises(ValueError):
            render(self.receipt(), required_jobs=WORKFLOWS, workflow_sha='')


if __name__ == '__main__':
    unittest.main()
