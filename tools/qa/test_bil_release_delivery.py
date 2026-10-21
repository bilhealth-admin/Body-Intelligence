"""Adversarial release-gate fixtures; no remote, signing or upload operations."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import bil_release_delivery as delivery
import bil_release_revalidation_plan as planner

HEAD = 'a' * 40
DIGEST = 'b' * 64


def fixture():
    manifest = {'required_workflow_ids': [1], 'workflows': [{
        'lane_id': 'synthetic', 'workflow_id': 1, 'workflow': 'synthetic.yml',
        'required_jobs': ['Actual E2E'], 'inputs': {}, 'reason': 'Synthetic test'}],
        'manual_physical': [{'name': 'device', 'status': 'PENDING'}]}
    run = {'id': 12, 'workflow_id': 1, 'head_sha': HEAD, 'head_branch': delivery.BRANCH,
           'event': 'workflow_dispatch', 'created_at': '2026-10-21T00:00:00Z',
           'status': 'completed', 'conclusion': 'success'}
    return manifest, run


def reports():
    semgrep = dict(source_head=HEAD, result='CLEAN_SCAN', findings_count=0, findings=[],
                   errors_count=0, errors=[], scanned_paths_count=3)
    mobsf = dict(audit_source=HEAD, producer_source=HEAD, producer_conclusion='success',
                 result='STATIC_DEBUG_REPORT_PRESENT', internet_enabled_in_scanner=False,
                 manifest_findings=[], code_findings=[])
    analyses = [dict(commit_sha=HEAD, tool={'name': 'CodeQL'}, ref='refs/heads/' + delivery.BRANCH,
                     category='/language:' + lang, error='', warning='') for lang in delivery.LANGUAGES]
    return semgrep, mobsf, analyses, []


class DeliveryTest(unittest.TestCase):
    def api(self, run, job=None):
        def request(endpoint):
            if '/jobs?' in endpoint:
                return {'jobs': [job or {'name': 'Actual E2E', 'status': 'completed', 'conclusion': 'success'}]}
            return deepcopy(run)
        return request

    def test_complete_exact_ci_prerequisite_passes(self):
        manifest, run = fixture()
        self.assertEqual(len(delivery.validate_prerequisites(manifest, {'synthetic': 12}, HEAD, self.api(run))), 1)

    def test_wrong_source_workflow_branch_event_and_all_non_successes_rejected(self):
        manifest, run = fixture()
        for update in ({'head_sha': 'c' * 40}, {'workflow_id': 2}, {'head_branch': 'other'},
                       {'event': 'pull_request'}, {'status': 'queued'}, {'conclusion': 'failure'},
                       {'conclusion': 'cancelled'}, {'conclusion': 'timed_out'}, {'conclusion': 'neutral'}):
            with self.subTest(update=update), self.assertRaises((ValueError, planner.PlanValidationError)):
                delivery.validate_prerequisites(manifest, {'synthetic': 12}, HEAD, self.api(run | update))

    def test_missing_extra_boolean_and_duplicate_run_inventory_rejected(self):
        manifest, run = fixture()
        for values in ({}, {'synthetic': True}, {'synthetic': '12'}, {'synthetic': 0},
                       {'synthetic': 12, 'extra': 13}):
            with self.subTest(values=values), self.assertRaises(ValueError):
                delivery.validate_prerequisites(manifest, values, HEAD, self.api(run))

    def test_skipped_failed_missing_required_jobs_are_not_upload_authority(self):
        manifest, run = fixture()
        for job in ({'name': 'Actual E2E', 'status': 'completed', 'conclusion': 'skipped'},
                    {'name': 'Actual E2E', 'status': 'completed', 'conclusion': 'failure'},
                    {'name': 'Other', 'status': 'completed', 'conclusion': 'success'}):
            with self.subTest(job=job), self.assertRaises(planner.PlanValidationError):
                delivery.validate_prerequisites(manifest, {'synthetic': 12}, HEAD, self.api(run, job))

    def test_clean_scans_need_all_five_languages(self):
        self.assertEqual(delivery.security_reports(*reports(), HEAD)['status'], 'PASS')
        for index in range(5):
            values = list(reports()); values[2].pop(index)
            with self.subTest(index=index), self.assertRaises(ValueError):
                delivery.security_reports(*values, HEAD)

    def test_partial_scans_any_semgrep_finding_and_open_codeql_alert_block_signing(self):
        for update in ({'result': 'PARTIAL'}, {'source_head': 'c' * 40}, {'findings_count': 1},
                       {'errors': [{}]}, {'scanned_paths_count': 0}):
            values = list(reports()); values[0].update(update)
            with self.subTest(update=update), self.assertRaises(ValueError):
                delivery.security_reports(*values, HEAD)
        values = list(reports()); values[3].append({'state': 'open'})
        with self.assertRaises(ValueError):
            delivery.security_reports(*values, HEAD)

    def test_stale_apk_failed_producer_and_high_unknown_mobsf_findings_rejected(self):
        for update in ({'producer_source': 'c' * 40}, {'producer_conclusion': 'failure'},
                       {'internet_enabled_in_scanner': True}, {'code_findings': None},
                       {'manifest_findings': [{'severity': 'high'}]},
                       {'code_findings': [{'severity': 'warning'}]},
                       {'code_findings': [{'severity': 'unknown'}]}):
            values = list(reports()); values[1].update(update)
            with self.subTest(update=update), self.assertRaises(ValueError):
                delivery.security_reports(*values, HEAD)

    def test_codeql_analysis_errors_or_previous_commit_are_not_full_coverage(self):
        for update in ({'error': 'failed'}, {'warning': 'incomplete'}, {'commit_sha': 'c' * 40}):
            values = list(reports()); values[2][0].update(update)
            with self.subTest(update=update), self.assertRaises(ValueError):
                delivery.security_reports(*values, HEAD)

    def test_upload_acceptance_keeps_processing_and_device_unproved(self):
        receipt = dict(source_sha=HEAD, build_number='37', validate_outcome='success',
                       upload_outcome='success', status='UPLOAD_ACCEPTED', ipa_sha256=DIGEST)
        inventory = dict(ipa_sha256=DIGEST, status='FINAL_ARTIFACT_IDENTITY_PASS',
                         platform='ios', build='37', package='com.bilhealth.bodyintelligencelog')
        actual = delivery.validate_upload(receipt, inventory, HEAD, DIGEST, HEAD)
        self.assertFalse(actual['processing_verified'])
        self.assertFalse(actual['physical_device_verified'])
        for key in receipt:
            broken = dict(receipt); broken[key] = 'wrong'
            with self.subTest(key=key), self.assertRaises(ValueError):
                delivery.validate_upload(broken, inventory, HEAD, DIGEST, HEAD)
        with self.assertRaises(ValueError):
            delivery.validate_upload(receipt, inventory, HEAD, 'c' * 64, HEAD)

    def test_no_local_no_published_or_failed_ci_never_updates_release_variables(self):
        for state in ({}, {'local_pass': True}, {'all_ci_pass': True},
                      {'local_pass': True, 'all_ci_pass': True, 'published_head': 'c' * 40}):
            control = SimpleNamespace(state=state, head=HEAD, gh=Mock(), stable=Mock())
            with self.subTest(state=state), self.assertRaises(ValueError):
                delivery.deliver(control, [])
            control.gh.assert_not_called()

    def test_e2e_new_unassigned_entrypoint_is_not_silently_omitted(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root / 'integration_test').mkdir()
            (root / 'integration_test/new_test.dart').write_text('synthetic')
            manifest = {'workflows': [{'lane_id': 'native'}], 'e2e_coverage': {}}
            with self.assertRaises(planner.PlanValidationError):
                planner.e2e_inventory(root, manifest)
            manifest['e2e_coverage']['integration_test/new_test.dart'] = dict(
                mode='direct', lanes=['native'], reason='Actual native test')
            self.assertEqual(len(planner.e2e_inventory(root, manifest)), 1)

    def test_complete_repository_plan_has_no_unassigned_e2e(self):
        manifest = json.loads((delivery.ROOT / 'tools/qa/revalidation_ci_plan.json').read_text(encoding='utf8'))
        self.assertGreaterEqual(len(planner.e2e_inventory(delivery.ROOT, manifest)), 23)
        lanes = planner.validate_ci_manifest(manifest, required_workflow_ids=manifest['required_workflow_ids'])
        self.assertTrue(any(lane.get('depends_on') for lane in lanes))


if __name__ == '__main__':
    unittest.main()
