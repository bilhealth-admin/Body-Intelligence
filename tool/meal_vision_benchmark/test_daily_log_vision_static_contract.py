import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ACTIONS = (ROOT / 'lib/features/daily_log/daily_log_page_actions.dart').read_text(encoding='utf-8')
REVIEW = (ROOT / 'lib/features/nutrition/presentation/meal_image_review_dialog.dart').read_text(encoding='utf-8')


class DailyLogVisionStaticContractTest(unittest.TestCase):
    def test_multi_item_review_and_authoritative_search_are_required(self):
        active = ACTIONS.split('Future<void> _analyzeMealImage() async {', 1)[1]
        active = active.split('/* Replaced single-candidate/first-match flow:', 1)[0]
        self.assertIn('showMealImageReviewDialog', active)
        self.assertIn('for (final selection in selections)', active)
        self.assertIn('foodRuntimeSearchAuthorityProvider', active)
        self.assertIn('showTrustedVisionFoodMatchDialog', active)
        self.assertNotIn('foods.first', active)

    def test_review_exposes_required_evidence_and_selection(self):
        for marker in ('CheckboxListTile', 'candidate.confidence', 'candidate.alternatives',
                       'candidate.uncertainty', 'candidate.warnings',
                       'TextEditingController', 'lowConfidence'):
            self.assertIn(marker, REVIEW)


if __name__ == '__main__':
    unittest.main()
