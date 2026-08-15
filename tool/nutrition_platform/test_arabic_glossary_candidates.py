import unittest

from tool.nutrition_platform.arabic_glossary_candidates import _relevance_score


class ArabicGlossaryCandidatesTest(unittest.TestCase):
    def test_prefers_whole_food_over_composite_food(self):
        whole = _relevance_score("Banana", "Bananas, raw")
        composite = _relevance_score("Banana", "Snacks, banana chips")

        self.assertGreater(whole, composite)

    def test_rejects_unrelated_partial_words(self):
        self.assertEqual(_relevance_score("Egg", "Eggplant, raw"), -10_000)
        self.assertEqual(
            _relevance_score("Chickpeas", "Vitamin C, Broccoli, raw"), -10_000
        )
        self.assertEqual(
            _relevance_score("Dates", "Vitamin D, Haddock, raw"), -10_000
        )


if __name__ == "__main__":
    unittest.main()
