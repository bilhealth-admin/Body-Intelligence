import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location("merge_batches", Path(__file__).with_name("merge_existing_recipe_nutrition_batches.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def record(index):
    return {
        "canonicalId": f"recipe-{index}",
        "contentFingerprint": f"{index:064x}",
        "image": {"assetPath": f"assets/recipe-{index}.jpg", "sha256": f"{index+100:064x}"},
        "timing": {"prepMinutes": 5, "cookMinutes": 10, "totalMinutes": 15},
        "ingredients": [{"ingredient": "food", "recordId": f"usda:{index}", "sourceRefs": [f"USDA-FDC:{index}"]}],
        "nutrition": {"status": "calculated", "perServing": {"kcal": 100.0 + index, "proteinG": 2.0}},
    }


class MergeExistingRecipeNutritionBatchesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.a = self.root / "a.json"
        self.b = self.root / "b.json"
        self.seeds = self.root / "seeds.json"
        self.records = [record(i) for i in range(1, 19)]
        self.write()

    def tearDown(self):
        self.temp.cleanup()

    def write(self):
        self.a.write_text(json.dumps({"batch": "A", "records": self.records[:9]}), encoding="utf-8")
        self.b.write_text(json.dumps({"batch": "B", "records": self.records[9:]}), encoding="utf-8")
        self.seeds.write_text(
            json.dumps({
                "records": [
                    {
                        "canonicalId": row["canonicalId"],
                        "contentFingerprint": row["contentFingerprint"],
                    }
                    for row in self.records
                ]
            }),
            encoding="utf-8",
        )

    def test_merges_exact_18_in_seed_order(self):
        result = MODULE.merge(self.a, self.b, self.seeds)
        self.assertEqual(result["verification"]["recordCount"], 18)
        self.assertEqual(result["records"][0]["canonicalId"], "recipe-1")

    def test_rejects_duplicate_content_or_image_identity(self):
        self.records[1]["contentFingerprint"] = self.records[0]["contentFingerprint"]
        self.write()
        with self.assertRaisesRegex(MODULE.MergeError, "duplicate_contentFingerprint"):
            MODULE.merge(self.a, self.b, self.seeds)

    def test_rejects_missing_ingredient_evidence_and_bad_timing(self):
        del self.records[0]["ingredients"][0]["sourceRefs"]
        self.records[1]["timing"]["totalMinutes"] = 99
        self.write()
        with self.assertRaises(MODULE.MergeError):
            MODULE.merge(self.a, self.b, self.seeds)

    def test_rejects_record_that_does_not_match_its_seed_fingerprint(self):
        self.write()
        seed_document = json.loads(self.seeds.read_text(encoding="utf-8"))
        seed_document["records"][0]["contentFingerprint"] = f"{999:064x}"
        self.seeds.write_text(json.dumps(seed_document), encoding="utf-8")
        with self.assertRaisesRegex(MODULE.MergeError, "seed_content_fingerprint_mismatch:recipe-1"):
            MODULE.merge(self.a, self.b, self.seeds)


if __name__ == "__main__":
    unittest.main()
