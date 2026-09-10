import contextlib
import io
import json
import unittest

import reconcile_recipe_sources as repair


class RecipeSourceReconciliationTest(unittest.TestCase):
    def test_release_is_reproducible_without_rewriting_any_asset(self):
        with contextlib.redirect_stdout(io.StringIO()):
            result = repair.reconcile()
        self.assertEqual(result["records"], 1500)
        self.assertEqual(result["changed_asset_files"], 0)
        self.assertEqual(result["rebound_ingredients"], 0)

    def test_hashes_and_canonical_aggregate_match_every_shard(self):
        manifest = repair.read(repair.RELEASE / "release-manifest.json")
        records = []
        for shard in manifest["shards"]:
            data = (repair.ROOT / shard["path"]).read_bytes()
            self.assertEqual(repair.digest(data), shard["sha256"])
            self.assertEqual(len(data), shard["size_bytes"])
            records.extend(json.loads(data)["records"])
        self.assertEqual(repair.digest(repair.encode(records)), manifest["canonical_sha256"])
        self.assertEqual(len(repair.encode(records)), manifest["canonical_size_bytes"])
        for key in ("index", "image_manifest", "provenance"):
            data = (repair.ROOT / manifest[f"{key}_path"]).read_bytes()
            self.assertEqual(repair.digest(data), manifest[f"{key}_sha256"])
            self.assertEqual(len(data), manifest[f"{key}_size_bytes"])
        # Data correction must not reauthor image identity or thumbnail delivery.
        self.assertEqual(manifest["index_sha256"], "6c9f4773f6221f5468c28e02d3897271009e6e36c3f0d9dd6bdca2fe66628638")
        self.assertEqual(manifest["image_manifest_sha256"], "e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3")

    def test_optional_unknown_is_not_zero_or_an_underreported_subtotal(self):
        a = {"grams": 100, "nutrientsPer100g": {key: 10 for key in repair.COLUMNS}}
        b = {"grams": 200, "nutrientsPer100g": {key: 20 for key in repair.COLUMNS}}
        b["nutrientsPer100g"]["sugarG"] = None
        result = repair.calculate([a, b], 2)
        self.assertEqual(result["kcal"], 25)
        self.assertIsNone(result["sugarG"])

    def test_missing_core_and_invalid_divisor_are_rejected(self):
        a = {"grams": 100, "nutrientsPer100g": {key: 10 for key in repair.COLUMNS}}
        for servings in (0, -1, float("nan"), True):
            with self.assertRaises(ValueError):
                repair.calculate([a], servings)
        a["nutrientsPer100g"]["proteinG"] = None
        with self.assertRaises(ValueError):
            repair.calculate([a], 2)

    def test_source_state_does_not_treat_uncooked_as_cooked(self):
        self.assertEqual(repair.source_state("Quinoa, uncooked"), "raw")
        self.assertEqual(repair.source_state("Chicken, cooked, roasted"), "cooked")
        self.assertEqual(repair.source_state("Pasta, dry"), "dry")
        self.assertEqual(repair.source_state("Pie crust, unbaked"), "unbaked")
        self.assertEqual(repair.source_state("Yogurt, plain, whole milk"), "as-sold")


if __name__ == "__main__":
    unittest.main()
