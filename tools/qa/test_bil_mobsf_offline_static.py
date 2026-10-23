import json
import unittest

from bil_mobsf_offline_static import (summarize, validate_producer, select_artifact,
                                     BRANCH, CANDIDATE_BRANCH, CODEQL_WORKFLOW_ID)


class MobSFReportTest(unittest.TestCase):
    def fixture(self):
        return {'package_name': 'com.bilhealth.bodyintelligencelog', 'version_code': '33',
                'manifest_analysis': {'manifest_findings': [{'rule': 'debug', 'severity': 'high',
                                      'description': 'private-synthetic-value'}]},
                'code_analysis': {'findings': {'example-rule': {'metadata': {'severity': 'warning'},
                                  'files': {'Example.java': 5}, 'code': 'private-synthetic-value'}}},
                'permissions': {'android.permission.CAMERA': {'description': 'private-synthetic-value'}},
                'secrets': ['private-synthetic-value']}

    def test_public_metadata_excludes_matched_values(self):
        result = summarize(self.fixture())
        self.assertNotIn('private-synthetic-value', json.dumps(result))
        self.assertFalse(result['internet_enabled_in_scanner'])
        self.assertEqual(result['manifest_findings'][0]['severity'], 'high')
        self.assertEqual(result['code_findings'][0]['affected_files_count'], 1)

    def test_wrong_package_or_build_cannot_be_certified(self):
        for changes in [{'package_name': 'other.app'}, {'version_code': '32'}]:
            with self.assertRaises(ValueError):
                summarize(self.fixture() | changes)

    def test_missing_core_sections_are_not_empty_clean_results(self):
        for key in ['manifest_analysis', 'code_analysis', 'permissions']:
            value = self.fixture()
            del value[key]
            with self.assertRaises(ValueError):
                summarize(value)


class MobSFProducerIdentityTest(unittest.TestCase):
    source = 'a' * 40

    def producer(self, **changes):
        return {'head_branch': CANDIDATE_BRANCH, 'status': 'completed',
                'workflow_id': CODEQL_WORKFLOW_ID, 'event': 'workflow_dispatch',
                'head_sha': self.source, 'run_attempt': 2, 'conclusion': 'success'} | changes

    def jobs(self, **changes):
        return [{'name': 'CodeQL (java-kotlin)', 'conclusion': 'success', 'steps': [
            {'name': name, 'conclusion': 'success'} for name in (
                'Build Android plugin sources for CodeQL',
                'Preserve the isolated Android debug APK for static inspection',
                'Upload Android CodeQL APK and build evidence')]} | changes]

    def artifact(self, **changes):
        return {'id': 42, 'name': f'bil-android-codeql-apk-{self.source}-2',
                'expired': False, 'size_in_bytes': 100,
                'workflow_run': {'id': 123, 'head_sha': self.source}} | changes

    def validate(self, producer=None, jobs=None, branch=CANDIDATE_BRANCH, sha=None):
        return validate_producer(self.producer() if producer is None else producer,
            self.jobs() if jobs is None else jobs, branch=branch, audit_sha=sha or self.source)

    def test_exact_candidate_source_attempt_and_successful_compiler_job_select_exact_apk(self):
        source, attempt, name = self.validate()
        self.assertEqual((source, attempt), (self.source, 2))
        artifact = select_artifact([self.artifact()], name=name, run_id='123', source=source)
        self.assertEqual(artifact['id'], 42)

    def test_candidate_never_promotes_failed_foreign_stale_or_in_progress_producers(self):
        for changes in ({'head_branch': BRANCH}, {'status': 'in_progress'},
                        {'workflow_id': 11}, {'event': 'pull_request'},
                        {'head_sha': 'b' * 40}, {'head_sha': 'invalid'},
                        {'conclusion': 'failure'}, {'run_attempt': 0},
                        {'run_attempt': True}, {'run_attempt': None}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.validate(self.producer(**changes))
        with self.assertRaises(ValueError):
            self.validate(branch='arbitrary/branch')

    def test_required_steps_must_all_succeed_in_the_same_exact_compiler_job(self):
        for jobs in (self.jobs(conclusion='failure'), self.jobs(name='other job'), []):
            with self.subTest(jobs=jobs), self.assertRaises(ValueError):
                self.validate(jobs=jobs)
        for index in range(3):
            jobs = self.jobs()
            jobs[0]['steps'][index]['conclusion'] = 'skipped'
            with self.assertRaises(ValueError):
                self.validate(jobs=jobs)
        jobs = self.jobs()
        steps = jobs[0]['steps']
        with self.assertRaises(ValueError):
            self.validate(jobs=[dict(jobs[0], steps=steps[:2]), dict(jobs[0], steps=steps[2:])])

    def test_legacy_failed_run_is_diagnostic_only_and_never_reuses_an_earlier_attempt(self):
        producer = self.producer(head_branch=BRANCH, conclusion='failure', run_attempt=1)
        jobs = self.jobs(conclusion='failure')
        jobs[0]['steps'][-1]['name'] = 'Upload Android API 33 native integration evidence'
        self.assertEqual(self.validate(producer, jobs, BRANCH)[2], f'bil-android33-native-integration-{self.source}')
        with self.assertRaises(ValueError):
            self.validate(producer | {'run_attempt': 2}, jobs, BRANCH)
        with self.assertRaises(ValueError):
            self.validate(producer, jobs, CANDIDATE_BRANCH)

    def test_artifact_selection_rejects_expiry_ambiguity_foreign_run_and_earlier_attempt(self):
        name = self.validate()[2]
        cases = [[], [self.artifact(), self.artifact(id=43)],
                 [self.artifact(expired=True)], [self.artifact(id=True)],
                 [self.artifact(size_in_bytes=0)], [self.artifact(size_in_bytes=1024**3+1)],
                 [self.artifact(name=f'bil-android-codeql-apk-{self.source}-1')],
                 [self.artifact(workflow_run={'id': 124, 'head_sha': self.source})],
                 [self.artifact(workflow_run={'id': 123, 'head_sha': 'b'*40})]]
        for artifacts in cases:
            with self.subTest(artifacts=artifacts), self.assertRaises(ValueError):
                select_artifact(artifacts, name=name, run_id='123', source=self.source)


if __name__ == '__main__':
    unittest.main()
