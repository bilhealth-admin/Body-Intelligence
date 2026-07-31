from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool" / "nutrition_platform"))

from canonical_model import CanonicalFoodStore, SourceLink
from mobile_catalog_builder import CatalogProfile, build_mobile_catalog
from quality_engine import install_quality_schema


class MobileCatalogBuilderTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.master = self.root / "master.sqlite"
        self.output = self.root / "mobile.sqlite"
        store = CanonicalFoodStore(self.master)
        self.food_id = store.create_food("apple", "generic", "Apple", "تفاح")
        source_id = store.link_source(
            self.food_id,
            SourceLink("USDA_FOUNDATION", "2026", "1", "hash"),
        )
        install_quality_schema(self.master)
        with closing(sqlite3.connect(self.master)) as conn:
            conn.execute(
                "INSERT INTO quality_assessment VALUES(?,95,'{}','accepted','mobile_candidate','[]','bil-food-quality-v1','now')",
                (source_id,),
            )
            conn.execute(
                "INSERT INTO source_normalization VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    source_id,
                    "Apple",
                    "apple",
                    None,
                    None,
                    None,
                    "missing",
                    "[]",
                    "bil-food-quality-v1",
                    "now",
                ),
            )
            conn.execute(
                "INSERT INTO food_name(bil_food_id,language,name,normalized_name,name_type,source_record_id,confidence) VALUES(?,?,?,?,?,?,?)",
                (self.food_id, "en", "Apple", "apple", "canonical", source_id, 1.0),
            )
            conn.commit()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_builds_separate_compact_catalog(self) -> None:
        result = build_mobile_catalog(self.master, self.output, CatalogProfile("core"))
        self.assertEqual(1, result["rows"])
        with closing(sqlite3.connect(self.output)) as conn:
            self.assertEqual(self.food_id, conn.execute("SELECT bil_food_id FROM food").fetchone()[0])
            self.assertIsNone(conn.execute("SELECT name FROM sqlite_master WHERE name='source_record'").fetchone())

    def test_threshold_excludes_low_quality(self) -> None:
        with closing(sqlite3.connect(self.master)) as conn:
            conn.execute("UPDATE quality_assessment SET overall_score=40")
            conn.commit()
        result = build_mobile_catalog(self.master, self.output, CatalogProfile("core"))
        self.assertEqual(0, result["rows"])

    def test_rejects_same_master_and_output(self) -> None:
        with self.assertRaises(ValueError):
            build_mobile_catalog(self.master, self.master, CatalogProfile("core"))

    def test_profile_validation(self) -> None:
        with self.assertRaises(ValueError):
            CatalogProfile("").validate()
        with self.assertRaises(ValueError):
            CatalogProfile("x", minimum_quality_score=101).validate()

    def test_build_selection_is_deterministic(self) -> None:
        first = build_mobile_catalog(self.master, self.output, CatalogProfile("core"))
        second = build_mobile_catalog(self.master, self.output, CatalogProfile("core"))
        self.assertEqual(first["rows"], second["rows"])

    def test_runtime_indexes_exist_without_build_evidence(self) -> None:
        build_mobile_catalog(self.master, self.output, CatalogProfile("core"))
        with closing(sqlite3.connect(self.output)) as conn:
            index_names = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='index'")}
            self.assertIn("idx_food_name", index_names)
            table_names = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            self.assertNotIn("duplicate_decision", table_names)
            self.assertNotIn("quality_assessment", table_names)


if __name__ == "__main__":
    unittest.main()
