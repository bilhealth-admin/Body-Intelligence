"""Execute the real BIL39 IPA identity guard using synthetic fixture bytes."""
from pathlib import Path
import unittest
import test_bil_candidate_promotion_receipt as fixtures

WORKFLOW = 'bil39_internal_testflight.yml'


class Bil39SignedWorkflowTest(unittest.TestCase):
    def test_exact_build39_binary_passes_the_actual_guard(self):
        result, identity = fixtures.PromotionReceiptTest().exercise(
            '39', workflow=WORKFLOW, receipt_build=39)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(39, identity['build'])
        self.assertEqual(fixtures.HEAD, identity['source_sha'])

    def test_38_binary_cannot_be_renamed_to_39(self):
        result, identity = fixtures.PromotionReceiptTest().exercise(
            '38', workflow=WORKFLOW, receipt_build=39)
        self.assertNotEqual(0, result.returncode)
        self.assertIsNone(identity)

    def test_signature_keys_follow_exact_ci_gate_and_no_38_waiver_is_inherited(self):
        source = (Path(fixtures.ROOT) / '.github/workflows' / WORKFLOW).read_text()
        self.assertLess(source.index('bil39_internal_build_ci.py'),
                        source.index('secrets.APPLE_TEAM_ID'))
        self.assertIn('branches: [bil39/internal-testflight-20261025]', source)
        self.assertTrue('internal_testflight_existing_evidence' not in source,
                        'The iOS38 prior-evidence waiver must never enter BIL39')
        self.assertTrue('NOT_RERUN_OWNER_APPROVED' not in source,
                        'BIL39 needs current exact-SHA native cryptography evidence')
        self.assertIn('--dart-define=BIL_MOBILE_INTEGRITY_REQUIRED=true', source)
        self.assertIn('--dart-define=BIL_PAYMENTS_ENABLED=true', source)
        self.assertIn("const previous=await matching('38');", source)
        self.assertTrue('find delivery' not in source,
                        'The unified job must promote its own IPA, not another run download')
        self.assertNotIn('reviewSubmissions', source)
        self.assertNotIn('appStoreVersions', source)


if __name__ == '__main__':
    unittest.main()
