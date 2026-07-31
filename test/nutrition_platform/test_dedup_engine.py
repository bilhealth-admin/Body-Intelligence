from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from tool.nutrition_platform.canonical_model import CanonicalFoodStore, SourceLink
from tool.nutrition_platform.dedup_engine import (
    DeduplicationPolicy,
    FoodFingerprint,
    apply_auto_merge,
    install_dedup_schema,
    persist_decision,
    select_canonical_field,
)


class DedupEngineTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db = Path(self.temp.name) / "canonical.sqlite"
        self.store = CanonicalFoodStore(self.db)
        self.policy = DeduplicationPolicy()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def fp(self, food_id: str, source_id: int, **overrides):
        values = dict(
            bil_food_id=food_id,
            source_record_id=source_id,
            source_system="USDA_BRANDED",
            external_id=str(source_id),
            normalized_name_key="plain yogurt",
            normalized_brand_key="bil dairy",
            normalized_barcode="012345678905",
            barcode_status="valid",
            food_kind="branded",
            category_key="dairy",
            nutrient_profile={"energy": 60.0, "protein": 4.0, "carbohydrate": 5.0, "fat": 2.0},
            package_key="500g",
            quality_score=80.0,
        )
        values.update(overrides)
        return FoodFingerprint(**values)

    def create_pair(self):
        left = self.store.create_food("left yogurt", "branded", "Plain Yogurt")
        right = self.store.create_food("right yogurt", "branded", "Plain Yogurt")
        left_source = self.store.link_source(left, SourceLink("USDA_BRANDED", "v1", "100", "a" * 64))
        right_source = self.store.link_source(right, SourceLink("USDA_BRANDED", "v1", "200", "b" * 64))
        return left, right, left_source, right_source

    def test_same_valid_gtin_brand_package_and_profile_auto_merges(self):
        left, right, ls, rs = self.create_pair()
        decision = self.policy.evaluate(self.fp(left, ls, quality_score=91), self.fp(right, rs, quality_score=82))
        self.assertEqual("auto_merge", decision.disposition)
        self.assertEqual(left, decision.survivor_bil_food_id)

    def test_barcode_conflict_is_review_only_and_preserved(self):
        left, right, ls, rs = self.create_pair()
        decision = self.policy.evaluate(self.fp(left, ls), self.fp(right, rs, normalized_brand_key="other brand"))
        self.assertEqual("candidate_review", decision.disposition)
        self.assertIn("brand_conflict", decision.conflicts)
        self.assertIsNone(decision.survivor_bil_food_id)

    def test_fuzzy_or_same_name_alone_never_auto_merges(self):
        left, right, ls, rs = self.create_pair()
        decision = self.policy.evaluate(
            self.fp(left, ls, normalized_barcode=None, barcode_status="missing", normalized_brand_key=None),
            self.fp(right, rs, normalized_barcode=None, barcode_status="missing", normalized_brand_key="other"),
        )
        self.assertEqual("candidate_review", decision.disposition)

    def test_exact_generic_identity_with_compatible_profile_auto_merges(self):
        left = self.store.create_food("generic left", "generic", "Apple raw")
        right = self.store.create_food("generic right", "generic", "Apple raw")
        decision = self.policy.evaluate(
            self.fp(left, 1, food_kind="generic", normalized_barcode=None, barcode_status="missing", normalized_brand_key=None, category_key="fruit"),
            self.fp(right, 2, food_kind="generic", normalized_barcode=None, barcode_status="missing", normalized_brand_key=None, category_key="fruit"),
        )
        self.assertEqual("auto_merge", decision.disposition)

    def test_material_nutrient_disagreement_blocks_auto_merge(self):
        left, right, ls, rs = self.create_pair()
        decision = self.policy.evaluate(
            self.fp(left, ls),
            self.fp(right, rs, nutrient_profile={"energy": 400.0, "protein": 20.0, "carbohydrate": 40.0, "fat": 30.0}),
        )
        self.assertEqual("candidate_review", decision.disposition)
        self.assertIn("nutrient_profile_conflict", decision.conflicts)

    def test_persisted_decision_is_explainable_and_idempotent(self):
        left, right, ls, rs = self.create_pair()
        install_dedup_schema(self.db)
        decision = self.policy.evaluate(self.fp(left, ls), self.fp(right, rs))
        persist_decision(self.db, decision)
        persist_decision(self.db, decision)
        with closing(sqlite3.connect(self.db)) as conn:
            row = conn.execute("SELECT disposition,reasons_json,conflicts_json FROM duplicate_decision").fetchone()
            count = conn.execute("SELECT COUNT(*) FROM duplicate_decision").fetchone()[0]
        self.assertEqual(1, count)
        self.assertEqual("auto_merge", row[0])
        self.assertIn("same_valid_gtin", row[1])

    def test_auto_merge_preserves_retired_identity_and_lineage(self):
        left, right, ls, rs = self.create_pair()
        decision = self.policy.evaluate(self.fp(left, ls, quality_score=90), self.fp(right, rs, quality_score=70))
        apply_auto_merge(self.db, decision)
        with closing(sqlite3.connect(self.db)) as conn:
            retired = conn.execute("SELECT status,merged_into_bil_food_id FROM canonical_food WHERE bil_food_id=?", (right,)).fetchone()
            event_count = conn.execute("SELECT COUNT(*) FROM merge_event").fetchone()[0]
            source_count = conn.execute("SELECT COUNT(*) FROM source_record").fetchone()[0]
        self.assertEqual(("merged", left), retired)
        self.assertEqual(1, event_count)
        self.assertEqual(2, source_count)

    def test_canonical_field_selection_is_deterministic_and_audited(self):
        left, _, ls, rs = self.create_pair()
        install_dedup_schema(self.db)
        selected = select_canonical_field(self.db, bil_food_id=left, field_name="canonical_name_en", candidates=[(rs, "Yoghurt", 80.0), (ls, "Plain Yogurt", 91.0)])
        self.assertEqual((ls, "Plain Yogurt"), selected)
        with closing(sqlite3.connect(self.db)) as conn:
            row = conn.execute("SELECT selected_source_record_id,reason FROM canonical_field_selection").fetchone()
        self.assertEqual(ls, row[0])
        self.assertIn("highest_quality", row[1])

    def test_schema_does_not_create_mobile_or_search_tables(self):
        install_dedup_schema(self.db)
        with closing(sqlite3.connect(self.db)) as conn:
            tables = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertIn("duplicate_decision", tables)
        self.assertNotIn("mobile_food", tables)
        self.assertNotIn("food_fts", tables)


if __name__ == "__main__":
    unittest.main()
