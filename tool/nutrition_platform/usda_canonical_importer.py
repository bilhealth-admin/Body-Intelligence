from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import sqlite3
import zipfile
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from tool.nutrition_platform.canonical_model import (
    SCHEMA_SQL,
    stable_bil_food_id,
)
from tool.nutrition_platform.quality_engine import QUALITY_SCHEMA_SQL, QualityPolicy

VERSION = "bil-usda-canonical-v1"
DATASETS = {
    "foundation": ("USDA_FOUNDATION", "foundation_food"),
    "legacy": ("USDA_SR_LEGACY", "sr_legacy_food"),
    "branded": ("USDA_BRANDED", "branded_food"),
}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def member(archive: zipfile.ZipFile, basename: str) -> str | None:
    return next((name for name in archive.namelist() if name.rsplit("/", 1)[-1].lower() == basename), None)


def rows(archive: zipfile.ZipFile, basename: str):
    selected = member(archive, basename)
    if selected is None:
        return
    with archive.open(selected) as raw, io.TextIOWrapper(raw, encoding="utf-8-sig", newline="") as text:
        yield from csv.DictReader(text)


def clean(value: str | None) -> str | None:
    value = " ".join((value or "").replace("\x00", " ").split())
    return value or None


def number(value: str | None) -> float | None:
    try:
        parsed = float(value or "")
        return parsed if parsed >= 0 else None
    except ValueError:
        return None


def payload_hash(row: dict[str, str]) -> str:
    payload = json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


class Importer:
    def __init__(self, database: Path, batch_size: int) -> None:
        database.parent.mkdir(parents=True, exist_ok=True)
        self.database = database
        self.batch_size = batch_size
        self.conn = sqlite3.connect(database)
        self.conn.execute("PRAGMA foreign_keys=ON")
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute("PRAGMA synchronous=NORMAL")
        self.conn.executescript(SCHEMA_SQL)
        self.conn.executescript(QUALITY_SCHEMA_SQL)
        policy = QualityPolicy()
        self.conn.execute(
            "INSERT OR REPLACE INTO quality_policy VALUES(?,?,?)",
            (policy.version, json.dumps(policy.__dict__, default=dict, sort_keys=True), now()),
        )
        self.conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS usda_import_state(
              dataset TEXT NOT NULL, member TEXT NOT NULL, source_sha256 TEXT NOT NULL,
              last_row INTEGER NOT NULL DEFAULT 0, completed INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL, PRIMARY KEY(dataset,member)
            );
            CREATE INDEX IF NOT EXISTS idx_source_external
              ON source_record(source_system,external_id);
            CREATE UNIQUE INDEX IF NOT EXISTS idx_nutrient_evidence_source
              ON nutrient_evidence(source_record_id,bil_nutrient_id,basis);
            """
        )
        self.conn.commit()

    def close(self) -> None:
        try:
            self.conn.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchall()
        finally:
            self.conn.close()

    def checkpoint(self, dataset: str, name: str, digest: str) -> tuple[int, bool]:
        found = self.conn.execute(
            "SELECT source_sha256,last_row,completed FROM usda_import_state WHERE dataset=? AND member=?",
            (dataset, name),
        ).fetchone()
        if found and found[0] != digest:
            raise RuntimeError(f"source changed for {dataset}/{name}; use a new database")
        return (int(found[1]), bool(found[2])) if found else (0, False)

    def progress(self, dataset: str, name: str, digest: str, row: int, completed: bool = False) -> None:
        self.conn.execute(
            """INSERT INTO usda_import_state VALUES(?,?,?,?,?,?)
               ON CONFLICT(dataset,member) DO UPDATE SET
               last_row=excluded.last_row,completed=excluded.completed,updated_at=excluded.updated_at""",
            (dataset, name, digest, row, int(completed), now()),
        )
        self.conn.commit()

    def import_archive(self, path: Path, dataset: str, release: str) -> None:
        source_system, _ = DATASETS[dataset]
        digest = file_hash(path)
        with zipfile.ZipFile(path) as archive:
            self.import_foods(archive, dataset, source_system, release, digest)
            if dataset == "branded":
                self.import_branded(archive, dataset, source_system, digest)
            self.import_nutrient_definitions(archive, dataset, source_system, digest)
            self.import_nutrients(archive, dataset, source_system, digest)
            self.import_portions(archive, dataset, source_system, digest)
        self.assess(source_system)

    def each(self, archive, basename, dataset, digest):
        start, complete = self.checkpoint(dataset, basename, digest)
        if complete:
            return
        seen = start
        for index, row in enumerate(rows(archive, basename) or (), start=1):
            if index <= start:
                continue
            yield index, row
            seen = index
            if index % self.batch_size == 0:
                self.progress(dataset, basename, digest, index)
        self.progress(dataset, basename, digest, seen, True)

    def import_foods(self, archive, dataset, system, release, digest):
        timestamp = now()
        for index, row in self.each(archive, "food.csv", dataset, digest) or ():
            external = row.get("fdc_id", "").strip()
            name = clean(row.get("description"))
            if not external or not name:
                continue
            kind = "branded" if dataset == "branded" else "generic"
            bil_id = stable_bil_food_id(f"{system}:{external}")
            self.conn.execute(
                "INSERT OR IGNORE INTO canonical_food VALUES(?,?,?,?,?,?,?,?)",
                (bil_id, kind, name, None, "active", None, timestamp, timestamp),
            )
            self.conn.execute(
                """INSERT OR IGNORE INTO source_record(
                   source_system,source_version,external_id,bil_food_id,source_payload_hash,
                   source_modified_at,imported_at,record_status) VALUES(?,?,?,?,?,?,?, 'active')""",
                (system, release, external, bil_id, payload_hash(row), row.get("publication_date"), timestamp),
            )
            source_id = self.conn.execute(
                "SELECT source_record_id FROM source_record WHERE source_system=? AND source_version=? AND external_id=?",
                (system, release, external),
            ).fetchone()[0]
            self.conn.execute(
                "INSERT INTO food_name(bil_food_id,language,name,normalized_name,name_type,source_record_id,confidence) VALUES(?,?,?,?,?,?,?)",
                (bil_id, "en", name, name.casefold(), "source", source_id, 0.98),
            )
            if index % self.batch_size == 0:
                self.conn.commit()
        self.conn.commit()

    def import_branded(self, archive, dataset, system, digest):
        for index, row in self.each(archive, "branded_food.csv", dataset, digest) or ():
            external = row.get("fdc_id", "").strip()
            found = self.conn.execute(
                "SELECT source_record_id,bil_food_id FROM source_record WHERE source_system=? AND external_id=?",
                (system, external),
            ).fetchone()
            if not found:
                continue
            source_id, bil_id = found
            gtin = "".join(c for c in (row.get("gtin_upc") or "") if c.isdigit())
            if gtin:
                self.conn.execute(
                    "INSERT OR IGNORE INTO barcode_claim(normalized_gtin,bil_food_id,source_record_id,claim_status,confidence,market_code) VALUES(?,?,?,'active',0.96,?)",
                    (gtin, bil_id, source_id, clean(row.get("market_country"))),
                )
            serving = number(row.get("serving_size"))
            unit = clean(row.get("serving_size_unit"))
            if serving and unit:
                grams = serving if unit.casefold() in {"g", "gram", "grams"} else None
                self.conn.execute(
                    "INSERT INTO portion(bil_food_id,amount,unit_code,gram_weight,description_en,source_record_id,confidence) VALUES(?,?,?,?,?,?,?)",
                    (bil_id, serving, unit, grams, clean(row.get("household_serving_fulltext")), source_id, 0.9),
                )
            if index % self.batch_size == 0:
                self.conn.commit()
        self.conn.commit()

    def import_nutrient_definitions(self, archive, dataset, system, digest):
        timestamp = now()
        for _, row in self.each(archive, "nutrient.csv", dataset, digest) or ():
            external = row.get("id", "").strip()
            name = clean(row.get("name"))
            unit = clean(row.get("unit_name"))
            if not external or not name or not unit:
                continue
            nutrient_id = f"usda:{external}"
            self.conn.execute("INSERT OR IGNORE INTO nutrient_definition VALUES(?,?,?,?,?)", (nutrient_id, name, unit, None, timestamp))
            self.conn.execute("INSERT OR IGNORE INTO nutrient_source_mapping VALUES(?,?,?)", (system, external, nutrient_id))
        self.conn.commit()

    def import_nutrients(self, archive, dataset, system, digest):
        timestamp = now()
        for index, row in self.each(archive, "food_nutrient.csv", dataset, digest) or ():
            external = row.get("fdc_id", "").strip()
            nutrient = row.get("nutrient_id", "").strip()
            amount = number(row.get("amount"))
            if not external or not nutrient or amount is None:
                continue
            found = self.conn.execute(
                "SELECT source_record_id,bil_food_id FROM source_record WHERE source_system=? AND external_id=?",
                (system, external),
            ).fetchone()
            if found:
                self.conn.execute(
                    "INSERT OR REPLACE INTO nutrient_evidence(bil_food_id,bil_nutrient_id,amount,basis,source_record_id,derivation_method,confidence,is_explicit_zero,created_at) VALUES(?,?,?,'per_100g',?,'USDA FoodData Central',?, ?,?)",
                    (found[1], f"usda:{nutrient}", amount, found[0], 0.98 if dataset != "branded" else 0.86, int(amount == 0), timestamp),
                )
            if index % self.batch_size == 0:
                self.conn.commit()
        self.conn.commit()

    def import_portions(self, archive, dataset, system, digest):
        for index, row in self.each(archive, "food_portion.csv", dataset, digest) or ():
            external = row.get("fdc_id", "").strip()
            amount = number(row.get("amount"))
            grams = number(row.get("gram_weight"))
            found = self.conn.execute(
                "SELECT source_record_id,bil_food_id FROM source_record WHERE source_system=? AND external_id=?",
                (system, external),
            ).fetchone()
            if found and amount and grams:
                self.conn.execute(
                    "INSERT INTO portion(bil_food_id,amount,unit_code,gram_weight,description_en,source_record_id,confidence) VALUES(?,?,?,?,?,?,0.96)",
                    (found[1], amount, row.get("measure_unit_id") or "portion", grams, clean(row.get("portion_description") or row.get("modifier")), found[0]),
                )
            if index % self.batch_size == 0:
                self.conn.commit()
        self.conn.commit()

    def assess(self, system: str):
        policy = QualityPolicy()
        timestamp = now()
        authority = {"USDA_FOUNDATION": 100, "USDA_SR_LEGACY": 92, "USDA_BRANDED": 78}[system]
        self.conn.execute(
            """INSERT OR REPLACE INTO source_normalization(
               source_record_id,normalized_name,normalized_name_key,normalized_brand,
               normalized_brand_key,normalized_barcode,barcode_status,warnings_json,
               policy_version,normalized_at)
               SELECT sr.source_record_id,cf.canonical_name_en,lower(cf.canonical_name_en),NULL,NULL,
                      MIN(bc.normalized_gtin),
                      CASE WHEN COUNT(bc.barcode_claim_id)>0 THEN 'valid' ELSE 'missing' END,
                      '[]',?,?
               FROM source_record sr
               JOIN canonical_food cf ON cf.bil_food_id=sr.bil_food_id
               LEFT JOIN barcode_claim bc ON bc.bil_food_id=sr.bil_food_id AND bc.claim_status='active'
               WHERE sr.source_system=?
               GROUP BY sr.source_record_id""",
            (policy.version, timestamp, system),
        )
        self.conn.execute(
            """WITH facts AS (
                 SELECT sr.source_record_id,
                        COUNT(DISTINCT ne.bil_nutrient_id) AS nutrient_count,
                        CASE WHEN COUNT(DISTINCT bc.barcode_claim_id)>0 THEN 100.0 ELSE 55.0 END AS barcode_score
                 FROM source_record sr
                 LEFT JOIN nutrient_evidence ne ON ne.bil_food_id=sr.bil_food_id
                 LEFT JOIN barcode_claim bc ON bc.bil_food_id=sr.bil_food_id AND bc.claim_status='active'
                 WHERE sr.source_system=?
                 GROUP BY sr.source_record_id
               ), scored AS (
                 SELECT source_record_id,nutrient_count,
                        MIN(100.0, ? * 0.18 + 45.9 + barcode_score * 0.08 +
                            MIN(100.0, nutrient_count * 12.5) * 0.22) AS score
                 FROM facts
               )
               INSERT OR REPLACE INTO quality_assessment(
                 source_record_id,overall_score,components_json,validation_status,
                 delivery_eligibility,rejection_reasons_json,policy_version,assessed_at)
               SELECT source_record_id,ROUND(score,2),'{}',
                      CASE WHEN nutrient_count>0 AND score>=? THEN 'accepted' ELSE 'quarantined' END,
                      CASE WHEN nutrient_count>0 AND score>=? THEN 'mobile_candidate' ELSE 'master_only' END,
                      CASE WHEN nutrient_count=0 THEN '[\"all_key_macronutrients_missing\"]' ELSE '[]' END,
                      ?,?
               FROM scored""",
            (system, authority, policy.accepted_threshold, policy.accepted_threshold, policy.version, timestamp),
        )
        self.conn.commit()


def main() -> int:
    parser = argparse.ArgumentParser(description="Stream USDA CSV archives into the BIL canonical database")
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--batch-size", type=int, default=5000)
    parser.add_argument(
        "--datasets",
        default="foundation,legacy,branded",
        help="Comma-separated datasets to import",
    )
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8-sig"))
    selected = {value.strip() for value in args.datasets.split(",") if value.strip()}
    unknown = selected.difference(DATASETS)
    if unknown:
        parser.error(f"unsupported datasets: {', '.join(sorted(unknown))}")
    importer = Importer(args.database, args.batch_size)
    try:
        for source in manifest["sources"]:
            dataset = source["dataset"]
            if dataset not in selected:
                continue
            archive = args.manifest.parent / source["file"]
            importer.import_archive(archive, dataset, source["release"])
        importer.conn.execute("INSERT OR REPLACE INTO schema_metadata VALUES('usda_importer_version',?)", (VERSION,))
        importer.conn.commit()
    finally:
        importer.close()
    print(f"Canonical USDA database ready: {args.database}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
