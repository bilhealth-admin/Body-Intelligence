import importlib.util
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "score_benchmark", Path(__file__).with_name("score_benchmark.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ScoreBenchmarkTest(unittest.TestCase):
    def test_order_and_preparation_words_do_not_change_identity(self):
        self.assertTrue(MODULE.identity_match(
            "Lentil and vegetable stew", "vegetable lentil stew"))
        self.assertTrue(MODULE.identity_match(
            "Pan-fried white fish fillet", "fish fillet"))

    def test_minor_bowl_detail_matches_but_missing_ingredient_does_not(self):
        self.assertTrue(MODULE.identity_match("Shrimp Bowl", "shrimp rice bowl"))
        self.assertFalse(MODULE.identity_match("Tabbouleh", "quinoa tabbouleh"))
        self.assertFalse(MODULE.identity_match("Grain Bowl", "salmon grain bowl"))

    def test_specific_single_food_can_match_a_descriptive_variant(self):
        self.assertTrue(MODULE.identity_match("cooked zucchini slices", "zucchini"))
        self.assertFalse(MODULE.identity_match("vegetable soup", "soup"))

    def test_non_food_empty_prediction_is_correct(self):
        row = MODULE.score_case(
            {"id": "non-food", "category": "non_food", "truth": []},
            {"components": [], "latency_ms": 10, "cost_usd": 0},
        )
        self.assertEqual(row["exact_case_accuracy"], 1)
        self.assertEqual(row["hallucination_rate"], 0)

    def test_component_matching_amount_and_hallucination(self):
        row = MODULE.score_case(
            {"id": "meal", "category": "composite", "truth": [
                {"id": "rice", "aliases": ["أرز"], "amount_g": 200}]},
            {"components": [
                {"name": "أرز", "amount_g": 220},
                {"name": "hummus", "amount_g": 20}],
             "latency_ms": 10, "cost_usd": 0.1},
        )
        self.assertEqual(row["component_recall"], 1)
        self.assertEqual(row["component_precision"], 0.5)
        self.assertAlmostEqual(row["amount_mape"], 0.1)
        self.assertEqual(row["hallucination_count"], 1)

    def test_request_token_telemetry_is_preserved(self):
        row = MODULE.score_case(
            {"id": "meal", "category": "composite", "truth": []},
            {
                "components": [],
                "latency_ms": 10,
                "cost_usd": 0.1,
                "input_tokens": 321,
                "output_tokens": 45,
            },
        )
        self.assertEqual(row["input_tokens"], 321)
        self.assertEqual(row["output_tokens"], 45)

    def test_identity_and_visible_components_are_scored_separately(self):
        row = MODULE.score_case(
            {"id": "separated", "category": "meal", "truth": [],
             "dish_identity_truth": [{"id": "kabsa", "aliases": []}],
             "visible_component_truth": [
                 {"id": "chicken", "aliases": []}, {"id": "rice", "aliases": []}]},
            {"components": [], "dish_identities": [], "visible_components": [
                {"name": "chicken", "aliases": []}, {"name": "rice", "aliases": []}]},
        )
        self.assertEqual(row["identity_component_recall"], 0)
        self.assertEqual(row["identity_hallucination_rate"], 0)
        self.assertEqual(row["visible_component_f1"], 1)


if __name__ == "__main__":
    unittest.main()
