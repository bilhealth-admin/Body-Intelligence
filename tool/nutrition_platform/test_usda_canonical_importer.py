from __future__ import annotations

import csv
import io
import json
import sqlite3
import tempfile
import unittest
import zipfile
from contextlib import closing
from pathlib import Path

from tool.nutrition_platform.usda_canonical_importer import Importer, file_hash


def csv_bytes(fieldnames: list[str], values: list[dict[str, str]]) -> bytes:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(values)
    return output.getvalue().encode("utf-8")


class UsdaCanonicalImporterTest(unittest.TestCase):
    def test_streams_minimal_foundation_archive_and_resumes(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as temporary:
            root = Path(temporary)
            archive_path = root / "FoodData_Central_foundation_food_csv_test.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("food.csv", csv_bytes(
                    ["fdc_id", "data_type", "description", "food_category_id", "publication_date"],
                    [{"fdc_id": "123", "data_type": "Foundation", "description": "Test apple", "food_category_id": "1", "publication_date": "2026-04-30"}],
                ))
                archive.writestr("nutrient.csv", csv_bytes(
                    ["id", "name", "unit_name", "nutrient_nbr", "rank"],
                    [{"id": "1003", "name": "Protein", "unit_name": "g", "nutrient_nbr": "203", "rank": "600"}],
                ))
                archive.writestr("food_nutrient.csv", csv_bytes(
                    ["id", "fdc_id", "nutrient_id", "amount", "data_points", "derivation_id", "min", "max", "median", "footnote", "min_year_acquired"],
                    [{"id": "1", "fdc_id": "123", "nutrient_id": "1003", "amount": "0.3", "data_points": "1", "derivation_id": "1", "min": "", "max": "", "median": "", "footnote": "", "min_year_acquired": "2026"}],
                ))
                archive.writestr("food_portion.csv", csv_bytes(
                    ["id", "fdc_id", "seq_num", "amount", "measure_unit_id", "portion_description", "modifier", "gram_weight", "data_points", "footnote", "min_year_acquired"],
                    [{"id": "1", "fdc_id": "123", "seq_num": "1", "amount": "1", "measure_unit_id": "999", "portion_description": "one apple", "modifier": "", "gram_weight": "182", "data_points": "1", "footnote": "", "min_year_acquired": "2026"}],
                ))

            database = root / "master.sqlite"
            importer = Importer(database, batch_size=1)
            try:
                importer.import_archive(archive_path, "foundation", "test-release")
                importer.import_archive(archive_path, "foundation", "test-release")
            finally:
                importer.close()

            with closing(sqlite3.connect(database)) as conn:
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM canonical_food").fetchone()[0], 1)
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM source_record").fetchone()[0], 1)
                self.assertEqual(conn.execute("SELECT amount FROM nutrient_evidence").fetchone()[0], 0.3)
                self.assertEqual(conn.execute("SELECT gram_weight FROM portion").fetchone()[0], 182)
                self.assertEqual(conn.execute("SELECT COUNT(*) FROM food_name").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
