from __future__ import annotations

import csv
from contextlib import closing
import json
import sqlite3
import tempfile
import unittest
import zipfile
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tool.nutrition_platform.usda_importer import (  # noqa: E402
    StagingDatabase,
    detect_dataset,
    inspect_archives,
    run_import,
)


class UsdaImporterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()


    def _assert_database_released(self, database: Path) -> None:
        moved = database.with_suffix(".released.sqlite")
        database.replace(moved)
        moved.replace(database)

    def _archive(self, name: str, member: str, rows: list[dict[str, str]]) -> Path:
        path = self.root / name
        csv_path = self.root / "source.csv"
        with csv_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(csv_path, member)
        return path

    def test_inspection_reads_headers_directly_from_zip(self) -> None:
        archive = self._archive(
            "FoodData_Central_foundation_food_csv_test.zip",
            "foundation/food.csv",
            [{"fdc_id": "1", "description": "Apple"}],
        )
        report = inspect_archives([archive])
        member = report["datasets"]["foundation"]["members"][0]
        self.assertEqual(member["columns"], ["fdc_id", "description"])
        self.assertEqual(member["stage"], "foods")

    def test_interrupt_then_resume_does_not_duplicate_rows(self) -> None:
        rows = [{"fdc_id": str(i), "description": f"Food {i}"} for i in range(1, 11)]
        archive = self._archive(
            "FoodData_Central_foundation_food_csv_test.zip",
            "foundation/food.csv",
            rows,
        )
        database = self.root / "staging.sqlite"
        report = self.root / "report.json"

        first = run_import([archive], database, report, batch_size=2, stop_after_rows=5)
        self.assertEqual(first["status"], "interrupted")

        second = run_import([archive], database, report, batch_size=2)
        self.assertEqual(second["status"], "completed")

        # sqlite3.Connection's context manager commits/rolls back but does
        # not close the connection. Use closing() so Windows releases the
        # database handle before the immediate rename assertion below.
        with closing(sqlite3.connect(database)) as conn:
            count = conn.execute("SELECT COUNT(*) FROM raw_record").fetchone()[0]
            distinct_count = conn.execute(
                "SELECT COUNT(DISTINCT source_row_number) FROM raw_record"
            ).fetchone()[0]
            checkpoint = conn.execute(
                "SELECT status,last_row_number FROM import_checkpoint"
            ).fetchone()
        self.assertEqual(count, 10)
        self.assertEqual(distinct_count, 10)
        self.assertEqual(checkpoint, ("completed", 10))
        self._assert_database_released(database)

    def test_completed_rerun_is_idempotent(self) -> None:
        archive = self._archive(
            "FoodData_Central_sr_legacy_food_csv_test.zip",
            "legacy/food.csv",
            [{"fdc_id": "1", "description": "Food"}],
        )
        database = self.root / "staging.sqlite"
        report = self.root / "report.json"
        run_import([archive], database, report, batch_size=1)
        run_import([archive], database, report, batch_size=1)
        with closing(sqlite3.connect(database)) as conn:
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM raw_record").fetchone()[0], 1)
        self._assert_database_released(database)

    def test_changed_source_is_rejected_after_progress(self) -> None:
        first = self._archive(
            "FoodData_Central_branded_food_csv_a.zip",
            "branded/food.csv",
            [{"fdc_id": "1", "description": "A"}],
        )
        database = self.root / "staging.sqlite"
        report = self.root / "report.json"
        run_import([first], database, report, batch_size=1)

        second = self._archive(
            "FoodData_Central_branded_food_csv_b.zip",
            "branded/food.csv",
            [{"fdc_id": "2", "description": "B"}],
        )
        with self.assertRaises(RuntimeError):
            run_import([second], database, report, batch_size=1)
        self._assert_database_released(database)

    def test_integrity_report_is_clean(self) -> None:
        database = self.root / "staging.sqlite"
        db = StagingDatabase(database)
        result = db.verify_integrity()
        db.close()
        self.assertEqual(result["integrity_check"], "ok")
        self.assertEqual(result["foreign_key_violations"], 0)


if __name__ == "__main__":
    unittest.main()
