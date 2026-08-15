import csv
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from tool.nutrition_platform.arabic_catalog_enricher import enrich


class ArabicCatalogEnricherTest(unittest.TestCase):
    def test_writes_canonical_name_and_search_aliases(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "master.sqlite"
            output = root / "arabic.sqlite"
            glossary = root / "glossary.csv"
            with closing(sqlite3.connect(source)) as connection:
                with connection:
                    connection.executescript(
                        """
                        CREATE TABLE canonical_food(
                          bil_food_id TEXT PRIMARY KEY,
                          canonical_name_en TEXT,
                          canonical_name_ar TEXT
                        );
                        CREATE TABLE food_name(
                          food_name_id INTEGER PRIMARY KEY AUTOINCREMENT,
                          bil_food_id TEXT NOT NULL,
                          language TEXT NOT NULL,
                          name TEXT NOT NULL,
                          normalized_name TEXT NOT NULL,
                          name_type TEXT NOT NULL,
                          source_record_id INTEGER,
                          confidence REAL NOT NULL
                        );
                        INSERT INTO canonical_food
                        VALUES('food-1','Brown rice',NULL);
                        """
                    )
            with glossary.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(
                    ["bil_food_id", "english_name", "arabic_name", "aliases", "confidence"]
                )
                writer.writerow(["", "Brown rice", "أرز بني", "رز بني|أرز أسمر", "1"])

            result = enrich(source, output, glossary)

            self.assertEqual(result["foods_localized"], 1)
            with closing(sqlite3.connect(output)) as connection:
                self.assertEqual(
                    connection.execute(
                        "SELECT canonical_name_ar FROM canonical_food"
                    ).fetchone()[0],
                    "أرز بني",
                )
                self.assertEqual(
                    connection.execute(
                        "SELECT COUNT(*) FROM food_name WHERE language='ar'"
                    ).fetchone()[0],
                    3,
                )


if __name__ == "__main__":
    unittest.main()
