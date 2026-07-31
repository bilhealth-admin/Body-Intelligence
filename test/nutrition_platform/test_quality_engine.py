from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from tool.nutrition_platform.canonical_model import CanonicalFoodStore, SourceLink
from tool.nutrition_platform.quality_engine import (
    NutritionQualityEngine,
    QualityInput,
    QualityPolicy,
    install_quality_schema,
    normalize_barcode,
    normalize_text,
    normalize_unit,
    persist_assessment,
)


class QualityEngineTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.db = Path(self.temp.name) / "canonical.sqlite"
        self.store = CanonicalFoodStore(self.db)
        self.engine = NutritionQualityEngine()

    def tearDown(self) -> None:
        self.temp.cleanup()


    def _assert_database_released(self) -> None:
        moved = self.db.with_name("canonical.released.sqlite")
        self.db.replace(moved)
        moved.replace(self.db)

    def _source(self, external_id: str = "1") -> int:
        food_id = self.store.create_food(f"generic|food|{external_id}", "generic", "Food")
        return self.store.link_source(food_id, SourceLink("USDA_FOUNDATION", "2026", external_id, "a" * 64))

    def test_text_unit_and_barcode_normalization_are_deterministic(self) -> None:
        self.assertEqual(normalize_text("  Whole\u00a0  Milk  "), "Whole Milk")
        self.assertEqual(normalize_unit(" Grams "), "g")
        self.assertEqual(normalize_barcode("4006-3813-3393-1"), ("4006381333931", "valid"))
        self.assertEqual(normalize_barcode("123"), ("123", "invalid_length"))

    def test_policy_is_versioned_and_weights_must_sum_to_one(self) -> None:
        QualityPolicy().validate()
        invalid = QualityPolicy(weights={"source_authority": 0.5})
        with self.assertRaises(ValueError):
            invalid.validate()

    def test_high_quality_record_is_mobile_candidate(self) -> None:
        assessment = self.engine.assess(QualityInput(
            source_record_id=1,
            source_system="USDA_FOUNDATION",
            name="Apple, raw",
            food_kind="generic",
            nutrient_values={"energy": 52, "protein": 0.3, "carbohydrate": 13.8, "fat": 0.2},
            portion_gram_weights=(100.0,),
            source_age_days=30,
            identity_evidence_count=2,
        ))
        self.assertEqual(assessment.validation_status, "accepted")
        self.assertEqual(assessment.delivery_eligibility, "mobile_candidate")
        self.assertGreaterEqual(assessment.overall_score, 72)

    def test_hard_rejects_are_explainable_and_do_not_delete_master_evidence(self) -> None:
        assessment = self.engine.assess(QualityInput(
            source_record_id=1,
            source_system="USDA_BRANDED",
            name="   ",
            barcode="123",
            nutrient_values={"energy": -1},
            identity_evidence_count=0,
        ))
        self.assertEqual(assessment.validation_status, "rejected")
        self.assertEqual(assessment.delivery_eligibility, "excluded")
        self.assertIn("missing_or_unusable_name", assessment.rejection_reasons)
        self.assertIn("invalid_nutrient_value", assessment.rejection_reasons)
        self.assertIn("missing_identity_evidence", assessment.rejection_reasons)

    def test_missing_barcode_is_not_a_hard_reject(self) -> None:
        assessment = self.engine.assess(QualityInput(
            source_record_id=1,
            source_system="USDA_SR_LEGACY",
            name="Rice, cooked",
            food_kind="generic",
            nutrient_values={"energy": 130, "protein": 2.7, "carbohydrate": 28.0, "fat": 0.3},
            portion_gram_weights=(158.0,),
        ))
        self.assertNotEqual(assessment.validation_status, "rejected")
        self.assertEqual(assessment.barcode_status, "missing")

    def test_assessment_persistence_keeps_policy_components_and_reasons(self) -> None:
        source_record_id = self._source()
        install_quality_schema(self.db)
        assessment = self.engine.assess(QualityInput(
            source_record_id=source_record_id,
            source_system="USDA_FOUNDATION",
            name="Water",
            food_kind="generic",
            nutrient_values={"energy": 0, "protein": 0, "carbohydrate": 0, "fat": 0},
            portion_gram_weights=(100.0,),
        ))
        persist_assessment(self.db, assessment)
        with closing(sqlite3.connect(self.db)) as conn:
            row = conn.execute("SELECT overall_score,components_json,policy_version FROM quality_assessment").fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row[2], QualityPolicy().version)
            self.assertIn("source_authority", json.loads(row[1]))
            self.assertEqual(conn.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            self.assertEqual(conn.execute("SELECT count(*) FROM source_record").fetchone()[0], 1)
        self._assert_database_released()

    def test_quality_schema_does_not_create_dedup_or_delivery_tables(self) -> None:
        install_quality_schema(self.db)
        with closing(sqlite3.connect(self.db)) as conn:
            tables = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        self.assertIn("quality_assessment", tables)
        self.assertNotIn("dedup_candidate", tables)
        self.assertNotIn("mobile_catalog", tables)
        self._assert_database_released()


if __name__ == "__main__":
    unittest.main()
