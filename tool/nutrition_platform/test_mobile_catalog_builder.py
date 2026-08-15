from __future__ import annotations

import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from .mobile_catalog_builder import CatalogProfile, build_mobile_catalog


class MobileCatalogBuilderLocaleTest(unittest.TestCase):
    def test_locale_pack_contains_only_localized_foods(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            master = root / "master.sqlite"
            output = root / "arabic.sqlite"
            with closing(sqlite3.connect(master)) as database:
                database.executescript(
                    """
                    CREATE TABLE canonical_food(
                      bil_food_id TEXT PRIMARY KEY, food_kind TEXT NOT NULL,
                      canonical_name_en TEXT, canonical_name_ar TEXT,
                      status TEXT NOT NULL, updated_at TEXT NOT NULL
                    );
                    CREATE TABLE source_record(
                      source_record_id INTEGER PRIMARY KEY, bil_food_id TEXT,
                      record_status TEXT NOT NULL
                    );
                    CREATE TABLE quality_assessment(
                      source_record_id INTEGER PRIMARY KEY, overall_score REAL,
                      validation_status TEXT, delivery_eligibility TEXT
                    );
                    CREATE TABLE food_name(
                      bil_food_id TEXT, language TEXT, name TEXT,
                      normalized_name TEXT, name_type TEXT
                    );
                    CREATE TABLE barcode_claim(
                      bil_food_id TEXT, market_code TEXT,
                      normalized_gtin TEXT, confidence REAL,
                      claim_status TEXT
                    );
                    INSERT INTO canonical_food VALUES
                      ('localized','generic','Bananas, raw','موز طازج','active','now'),
                      ('english-only','generic','Apple, raw',NULL,'active','now');
                    INSERT INTO source_record VALUES
                      (1,'localized','active'),(2,'english-only','active');
                    INSERT INTO quality_assessment VALUES
                      (1,90,'accepted','mobile_candidate'),
                      (2,90,'accepted','mobile_candidate');
                    INSERT INTO food_name VALUES
                      ('localized','ar','موز','موز','alias');
                    """
                )
                database.commit()

            result = build_mobile_catalog(
                master,
                output,
                CatalogProfile(profile_id="arabic-seed", language_code="ar"),
            )

            self.assertEqual(result["rows"], 1)
            with closing(sqlite3.connect(output)) as catalog:
                self.assertEqual(
                    catalog.execute("SELECT bil_food_id FROM food").fetchall(),
                    [("localized",)],
                )

    def test_locale_pack_does_not_require_optional_barcode_table(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            master = root / "master.sqlite"
            output = root / "arabic.sqlite"
            with closing(sqlite3.connect(master)) as database:
                database.executescript(
                    """
                    CREATE TABLE canonical_food(
                      bil_food_id TEXT PRIMARY KEY, food_kind TEXT NOT NULL,
                      canonical_name_en TEXT, canonical_name_ar TEXT,
                      status TEXT NOT NULL, updated_at TEXT NOT NULL
                    );
                    CREATE TABLE source_record(
                      source_record_id INTEGER PRIMARY KEY, bil_food_id TEXT,
                      record_status TEXT NOT NULL
                    );
                    CREATE TABLE quality_assessment(
                      source_record_id INTEGER PRIMARY KEY, overall_score REAL,
                      validation_status TEXT, delivery_eligibility TEXT
                    );
                    INSERT INTO canonical_food VALUES
                      ('localized','generic','Bananas, raw','موز طازج','active','now');
                    INSERT INTO source_record VALUES (1,'localized','active');
                    INSERT INTO quality_assessment VALUES
                      (1,90,'accepted','mobile_candidate');
                    """
                )
                database.commit()

            result = build_mobile_catalog(
                master,
                output,
                CatalogProfile(profile_id="arabic-seed", language_code="ar"),
            )

            self.assertEqual(result["rows"], 1)
            with closing(sqlite3.connect(output)) as catalog:
                self.assertEqual(
                    catalog.execute("SELECT bil_food_id FROM food").fetchall(),
                    [("localized",)],
                )


if __name__ == "__main__":
    unittest.main()
