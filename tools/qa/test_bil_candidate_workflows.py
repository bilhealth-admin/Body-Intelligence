"""Candidate workflows keep manual, exact-source and native-security boundaries."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FILES = ('.github/workflows/bil_ios_signed_release.yml',
         '.github/workflows/bil_android_release_candidate.yml')


class CandidateWorkflowTest(unittest.TestCase):
    def test_workflows_never_sign_on_push_or_upload_to_a_store(self):
        for name in FILES:
            text = (ROOT / name).read_text(encoding='utf-8')
            with self.subTest(name=name):
                self.assertIn('  workflow_dispatch:', text)
                self.assertNotRegex(text, re.compile(r'^  (push|pull_request|workflow_run|schedule):', re.M))
                self.assertNotIn('--upload-app', text)
                self.assertNotIn('upload_to_testflight:', text)
                self.assertNotIn('r0adkll/upload-google-play', text)
                self.assertNotIn('39797161745', text)
                self.assertNotIn('937aea673c2e9c0bec15ef988131d58f96bf5afe', text)

    def test_all_signing_inputs_follow_the_exact_ci_and_manifest_guard(self):
        for name in FILES:
            text = (ROOT / name).read_text(encoding='utf-8')
            with self.subTest(name=name):
                self.assertIn('ref: ${{ inputs.expected_source_sha }}', text)
                gate = text.index('bil_candidate_release.py --verify-ci')
                self.assertLess(gate, text.index('${{ secrets.'))
                self.assertIn('QA_RUN_IDS: ${{ inputs.qa_run_ids }}', text)
                self.assertIn('echo "BIL_AUDITED_FREEZE_MANIFEST_SHA256=', text)
                self.assertNotIn('BIL_AUDITED_FREEZE_docs', text)
                self.assertIn('fetch-depth: 0', text)
                self.assertIn('persist-credentials: false', text)
                for ref in re.findall(r'uses:\s*([^\s]+)', text):
                    self.assertRegex(ref, r'@[0-9a-f]{40}$')

    def test_native_crypto_has_no_optional_input_or_waiver(self):
        for name in FILES:
            text = (ROOT / name).read_text(encoding='utf-8')
            with self.subTest(name=name):
                self.assertNotIn('run_native_crypto_checks', text)
                self.assertNotIn('NOT_RUN_OWNER_WAIVED', text)
                self.assertIn('id: native_crypto_runtime_gate', text)
                self.assertIn('steps.native_crypto_runtime_gate.outcome', text)
                self.assertIn('test "$NATIVE_CRYPTO_OUTCOME" = success', text)

    def test_build_numbers_and_source_are_explicit_and_ios_upload_keys_are_absent(self):
        ios = (ROOT / FILES[0]).read_text(encoding='utf-8')
        android = (ROOT / FILES[1]).read_text(encoding='utf-8')
        self.assertIn("BUILD_NUMBER: '38'", ios)
        self.assertIn("'build':38", ios)
        self.assertIn("BUILD_NUMBER: '33'", android)
        self.assertNotIn('secrets.APP_STORE_CONNECT', ios)
        for text in (ios, android):
            self.assertIn('--build-number "$BUILD_NUMBER"', text)
            self.assertIn('BIL_SOURCE_COMMIT: ${{ github.sha }}', text)

    def test_candidate_manifest_identity_and_acceptance_are_checked(self):
        import bil_candidate_release as candidate
        for platform, name in candidate.MANIFESTS.items():
            with self.subTest(platform=platform):
                text = (ROOT / name).read_text(encoding='utf-8')
                self.assertIn(f'`RELEASE_BUILD_NUMBER: {candidate.TARGETS[platform]}`', text)
                if '`CANDIDATE_FROZEN_OR_ACCEPTED: NO`' in text:
                    with self.assertRaises(ValueError):
                        candidate.validate_manifest(text, platform)
                else:
                    candidate.validate_manifest(text, platform)

    def test_testflight_requires_manual_exact_artifact_and_prior_ci(self):
        text = (ROOT / '.github/workflows/bil_ios_upload_existing_testflight.yml').read_text(encoding='utf8')
        self.assertIn('  workflow_dispatch:', text)
        self.assertNotRegex(text, re.compile(r'^  (push|pull_request|workflow_run|schedule):', re.M))
        self.assertLess(text.index('bil_candidate_release.py --verify-ci'), text.index('${{ secrets.'))
        for witness in ("run['head_sha']==source", "artifact['workflow_run']['id']==int(run_id)",
                        "digest==os.environ['BIL_IPA_SHA256']", "info['CFBundleVersion']=='38'",
                        "test \"$GITHUB_RUN_ATTEMPT\" = '1'", "matching('38')", "matching('37')",
                        '--validate-app', '--upload-app', "processingState!=='VALID'"):
            self.assertIn(witness, text)
        self.assertNotIn('flutter build', text)
        self.assertNotIn('39815453479', text)
        self.assertNotIn('39797161745', text)


if __name__ == '__main__':
    unittest.main()
