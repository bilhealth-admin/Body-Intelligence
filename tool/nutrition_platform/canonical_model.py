from __future__ import annotations

import hashlib
import sqlite3
import uuid
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

BIL_FOOD_NAMESPACE = uuid.UUID("8f7df640-d61a-5a3e-a4cf-8f95eb8b451e")
SCHEMA_VERSION = 1


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def stable_bil_food_id(identity_key: str) -> str:
    """Return a stable BIL-owned UUID independent from any external source id."""
    normalized = " ".join(identity_key.strip().casefold().split())
    if not normalized:
        raise ValueError("identity_key must not be blank")
    return str(uuid.uuid5(BIL_FOOD_NAMESPACE, normalized))


@dataclass(frozen=True)
class SourceLink:
    source_system: str
    source_version: str
    external_id: str
    payload_hash: str

    def validate(self) -> None:
        for value, name in ((self.source_system, "source_system"), (self.source_version, "source_version"), (self.external_id, "external_id"), (self.payload_hash, "payload_hash")):
            if not value.strip():
                raise ValueError(f"{name} must not be blank")


SCHEMA_SQL = r"""
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS schema_metadata (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS canonical_food (
  bil_food_id TEXT PRIMARY KEY,
  food_kind TEXT NOT NULL CHECK(food_kind IN ('generic','branded','recipe','prepared','ingredient','supplement','unknown')),
  canonical_name_en TEXT,
  canonical_name_ar TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','deprecated','quarantined','merged')),
  merged_into_bil_food_id TEXT REFERENCES canonical_food(bil_food_id),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CHECK(merged_into_bil_food_id IS NULL OR merged_into_bil_food_id <> bil_food_id)
);
CREATE TABLE IF NOT EXISTS source_record (
  source_record_id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_system TEXT NOT NULL,
  source_version TEXT NOT NULL,
  external_id TEXT NOT NULL,
  bil_food_id TEXT REFERENCES canonical_food(bil_food_id),
  source_payload_hash TEXT NOT NULL,
  source_modified_at TEXT,
  imported_at TEXT NOT NULL,
  record_status TEXT NOT NULL DEFAULT 'active',
  UNIQUE(source_system, source_version, external_id)
);
CREATE INDEX IF NOT EXISTS idx_source_record_food ON source_record(bil_food_id);
CREATE TABLE IF NOT EXISTS food_name (
  food_name_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  language TEXT NOT NULL,
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  name_type TEXT NOT NULL,
  source_record_id INTEGER REFERENCES source_record(source_record_id),
  confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1)
);
CREATE TABLE IF NOT EXISTS brand (
  brand_id INTEGER PRIMARY KEY AUTOINCREMENT,
  display_name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  owner_name TEXT
);
CREATE TABLE IF NOT EXISTS barcode_claim (
  barcode_claim_id INTEGER PRIMARY KEY AUTOINCREMENT,
  normalized_gtin TEXT NOT NULL,
  bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  source_record_id INTEGER REFERENCES source_record(source_record_id),
  claim_status TEXT NOT NULL CHECK(claim_status IN ('active','conflicting','retired','invalid')),
  confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
  market_code TEXT,
  effective_from TEXT,
  effective_to TEXT
);
CREATE INDEX IF NOT EXISTS idx_barcode_claim_gtin ON barcode_claim(normalized_gtin);
CREATE TABLE IF NOT EXISTS nutrient_definition (
  bil_nutrient_id TEXT PRIMARY KEY,
  canonical_name TEXT NOT NULL,
  unit TEXT NOT NULL,
  nutrient_group TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS nutrient_source_mapping (
  source_system TEXT NOT NULL,
  external_nutrient_id TEXT NOT NULL,
  bil_nutrient_id TEXT NOT NULL REFERENCES nutrient_definition(bil_nutrient_id),
  PRIMARY KEY(source_system, external_nutrient_id)
);
CREATE TABLE IF NOT EXISTS nutrient_evidence (
  nutrient_evidence_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  bil_nutrient_id TEXT NOT NULL REFERENCES nutrient_definition(bil_nutrient_id),
  amount REAL NOT NULL,
  basis TEXT NOT NULL CHECK(basis IN ('per_100g','per_100ml','per_serving','calculated')),
  source_record_id INTEGER NOT NULL REFERENCES source_record(source_record_id),
  derivation_method TEXT NOT NULL,
  confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
  is_explicit_zero INTEGER NOT NULL DEFAULT 0 CHECK(is_explicit_zero IN (0,1)),
  measured_at TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS portion (
  portion_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  amount REAL NOT NULL CHECK(amount > 0),
  unit_code TEXT NOT NULL,
  gram_weight REAL CHECK(gram_weight > 0),
  description_en TEXT,
  description_ar TEXT,
  source_record_id INTEGER REFERENCES source_record(source_record_id),
  confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1)
);
CREATE TABLE IF NOT EXISTS merge_event (
  merge_event_id INTEGER PRIMARY KEY AUTOINCREMENT,
  retired_bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  survivor_bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  reason TEXT NOT NULL,
  evidence_json TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  created_at TEXT NOT NULL,
  CHECK(retired_bil_food_id <> survivor_bil_food_id)
);
"""


def create_canonical_database(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(path)) as conn:
        conn.executescript(SCHEMA_SQL)
        conn.execute("INSERT OR REPLACE INTO schema_metadata(key,value) VALUES('schema_version',?)", (str(SCHEMA_VERSION),))
        conn.commit()


class CanonicalFoodStore:
    def __init__(self, path: Path):
        create_canonical_database(path)
        self.path = path

    def create_food(self, identity_key: str, food_kind: str, canonical_name_en: str | None = None, canonical_name_ar: str | None = None) -> str:
        bil_food_id = stable_bil_food_id(identity_key)
        now = utc_now()
        with closing(sqlite3.connect(self.path)) as conn:
            conn.execute("PRAGMA foreign_keys=ON")
            conn.execute(
                """INSERT INTO canonical_food(bil_food_id,food_kind,canonical_name_en,canonical_name_ar,created_at,updated_at)
                   VALUES(?,?,?,?,?,?) ON CONFLICT(bil_food_id) DO UPDATE SET
                   canonical_name_en=COALESCE(excluded.canonical_name_en,canonical_food.canonical_name_en),
                   canonical_name_ar=COALESCE(excluded.canonical_name_ar,canonical_food.canonical_name_ar),
                   updated_at=excluded.updated_at""",
                (bil_food_id, food_kind, canonical_name_en, canonical_name_ar, now, now),
            )
            conn.commit()
        return bil_food_id

    def link_source(self, bil_food_id: str, link: SourceLink) -> int:
        link.validate()
        with closing(sqlite3.connect(self.path)) as conn:
            conn.execute("PRAGMA foreign_keys=ON")
            conn.execute(
                """INSERT INTO source_record(source_system,source_version,external_id,bil_food_id,source_payload_hash,imported_at)
                   VALUES(?,?,?,?,?,?) ON CONFLICT(source_system,source_version,external_id) DO UPDATE SET
                   bil_food_id=excluded.bil_food_id, source_payload_hash=excluded.source_payload_hash, imported_at=excluded.imported_at""",
                (link.source_system, link.source_version, link.external_id, bil_food_id, link.payload_hash, utc_now()),
            )
            row = conn.execute("SELECT source_record_id FROM source_record WHERE source_system=? AND source_version=? AND external_id=?", (link.source_system, link.source_version, link.external_id)).fetchone()
            conn.commit()
            return int(row[0])

    def merge_foods(self, retired_id: str, survivor_id: str, reason: str, evidence_json: str, policy_version: str) -> None:
        if retired_id == survivor_id:
            raise ValueError("cannot merge a food into itself")
        with closing(sqlite3.connect(self.path)) as conn:
            conn.execute("PRAGMA foreign_keys=ON")
            conn.execute("UPDATE canonical_food SET status='merged', merged_into_bil_food_id=?, updated_at=? WHERE bil_food_id=?", (survivor_id, utc_now(), retired_id))
            conn.execute("INSERT INTO merge_event(retired_bil_food_id,survivor_bil_food_id,reason,evidence_json,policy_version,created_at) VALUES(?,?,?,?,?,?)", (retired_id, survivor_id, reason, evidence_json, policy_version, utc_now()))
            conn.commit()


def schema_sha256() -> str:
    return hashlib.sha256(SCHEMA_SQL.encode('utf-8')).hexdigest()
