from __future__ import annotations

import hashlib
import json
import sqlite3
import time
from contextlib import closing
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

PROFILE_VERSION = "bil-mobile-catalog-v1"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class CatalogProfile:
    profile_id: str
    market_code: str | None = None
    language_code: str | None = None
    minimum_quality_score: float = 75.0
    include_generic: bool = True
    include_branded: bool = True
    max_rows: int | None = None
    version: str = PROFILE_VERSION

    def validate(self) -> None:
        if not self.profile_id.strip():
            raise ValueError("profile_id must not be blank")
        if not 0 <= self.minimum_quality_score <= 100:
            raise ValueError("minimum_quality_score must be between 0 and 100")
        if self.max_rows is not None and self.max_rows <= 0:
            raise ValueError("max_rows must be positive")
        if not self.include_generic and not self.include_branded:
            raise ValueError("profile must include at least one food class")


DELIVERY_SCHEMA_SQL = """
PRAGMA foreign_keys = ON;
CREATE TABLE catalog_metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE food(
  bil_food_id TEXT PRIMARY KEY,
  food_kind TEXT NOT NULL,
  name_en TEXT,
  name_ar TEXT,
  normalized_name TEXT,
  quality_score REAL NOT NULL,
  market_code TEXT,
  updated_at TEXT NOT NULL
);
CREATE TABLE alias(
  alias_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bil_food_id TEXT NOT NULL REFERENCES food(bil_food_id) ON DELETE CASCADE,
  language TEXT NOT NULL,
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  name_type TEXT NOT NULL,
  UNIQUE(bil_food_id, language, normalized_name, name_type)
);
CREATE TABLE nutrient(
  bil_food_id TEXT NOT NULL REFERENCES food(bil_food_id) ON DELETE CASCADE,
  bil_nutrient_id TEXT NOT NULL,
  amount REAL NOT NULL,
  unit TEXT NOT NULL,
  basis TEXT NOT NULL,
  confidence REAL NOT NULL,
  PRIMARY KEY(bil_food_id, bil_nutrient_id, basis)
);
CREATE TABLE portion(
  portion_id INTEGER PRIMARY KEY,
  bil_food_id TEXT NOT NULL REFERENCES food(bil_food_id) ON DELETE CASCADE,
  amount REAL NOT NULL,
  unit_code TEXT NOT NULL,
  gram_weight REAL,
  description_en TEXT,
  description_ar TEXT,
  confidence REAL NOT NULL
);
CREATE TABLE barcode(
  normalized_gtin TEXT NOT NULL,
  bil_food_id TEXT NOT NULL REFERENCES food(bil_food_id) ON DELETE CASCADE,
  market_code TEXT,
  confidence REAL NOT NULL,
  PRIMARY KEY(normalized_gtin, bil_food_id)
);
CREATE INDEX idx_food_name ON food(normalized_name);
CREATE INDEX idx_food_quality ON food(quality_score DESC, bil_food_id);
CREATE INDEX idx_alias_name ON alias(normalized_name);
CREATE INDEX idx_barcode_gtin ON barcode(normalized_gtin);
CREATE VIRTUAL TABLE food_fts USING fts5(bil_food_id UNINDEXED,name_en,name_ar,aliases,tokenize='unicode61 remove_diacritics 2');
"""



def _sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest()

def _table_exists(conn: sqlite3.Connection, name: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone() is not None


def _eligible_rows(conn: sqlite3.Connection, profile: CatalogProfile):
    required = ("canonical_food", "source_record", "quality_assessment")
    missing = [name for name in required if not _table_exists(conn, name)]
    if missing:
        raise ValueError(f"master database missing required tables: {', '.join(missing)}")

    kinds: list[str] = []
    if profile.include_generic:
        kinds.extend(["generic", "ingredient", "prepared", "recipe"])
    if profile.include_branded:
        kinds.extend(["branded", "supplement"])

    placeholders = ",".join("?" for _ in kinds)
    sql = f"""
        SELECT cf.bil_food_id,
               cf.food_kind,
               cf.canonical_name_en,
               cf.canonical_name_ar,
               MAX(qa.overall_score) AS quality_score,
               MAX(COALESCE(bc.market_code, '')) AS market_code,
               cf.updated_at
        FROM canonical_food cf
        JOIN source_record sr
          ON sr.bil_food_id = cf.bil_food_id
         AND sr.record_status = 'active'
        JOIN quality_assessment qa
          ON qa.source_record_id = sr.source_record_id
         AND qa.validation_status = 'accepted'
         AND qa.delivery_eligibility = 'mobile_candidate'
        LEFT JOIN barcode_claim bc
          ON bc.bil_food_id = cf.bil_food_id
         AND bc.claim_status = 'active'
        WHERE cf.status = 'active'
          AND cf.food_kind IN ({placeholders})
          AND qa.overall_score >= ?
    """
    params: list[object] = list(kinds) + [profile.minimum_quality_score]
    if profile.market_code:
        sql += " AND (bc.market_code IS NULL OR bc.market_code='' OR bc.market_code=?)"
        params.append(profile.market_code)
    sql += " GROUP BY cf.bil_food_id ORDER BY quality_score DESC, cf.bil_food_id ASC"
    if profile.max_rows is not None:
        sql += " LIMIT ?"
        params.append(profile.max_rows)
    return conn.execute(sql, params)


def build_mobile_catalog(master_path: Path, output_path: Path, profile: CatalogProfile) -> dict[str, object]:
    profile.validate()
    if master_path.resolve() == output_path.resolve():
        raise ValueError("output catalog must be separate from master database")
    if not master_path.is_file():
        raise FileNotFoundError(master_path)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = output_path.with_suffix(output_path.suffix + ".tmp")
    temp_path.unlink(missing_ok=True)
    started = time.perf_counter()

    try:
        with closing(sqlite3.connect(master_path)) as master, closing(sqlite3.connect(temp_path)) as out:
            master.row_factory = sqlite3.Row
            master.execute("PRAGMA query_only=ON")
            out.executescript(DELIVERY_SCHEMA_SQL)
            rows = _eligible_rows(master, profile)
            row_count = 0

            for row in rows:
                row_count += 1
                bil_food_id = row["bil_food_id"]
                normalized_row = None
                if _table_exists(master, "source_normalization"):
                    normalized_row = master.execute(
                        """
                        SELECT sn.normalized_name
                        FROM source_normalization sn
                        JOIN source_record sr ON sr.source_record_id = sn.source_record_id
                        WHERE sr.bil_food_id = ?
                        ORDER BY sn.source_record_id
                        LIMIT 1
                        """,
                        (bil_food_id,),
                    ).fetchone()

                out.execute(
                    "INSERT INTO food VALUES(?,?,?,?,?,?,?,?)",
                    (
                        bil_food_id,
                        row["food_kind"],
                        row["canonical_name_en"],
                        row["canonical_name_ar"],
                        normalized_row[0] if normalized_row else None,
                        float(row["quality_score"]),
                        row["market_code"] or None,
                        row["updated_at"],
                    ),
                )

                if _table_exists(master, "food_name"):
                    for alias in master.execute(
                        "SELECT language,name,normalized_name,name_type FROM food_name WHERE bil_food_id=?",
                        (bil_food_id,),
                    ):
                        out.execute(
                            "INSERT OR IGNORE INTO alias(bil_food_id,language,name,normalized_name,name_type) VALUES(?,?,?,?,?)",
                            (bil_food_id, *alias),
                        )

                if _table_exists(master, "nutrient_evidence"):
                    for nutrient in master.execute(
                        """
                        SELECT ranked.bil_nutrient_id, ranked.amount, ranked.unit, ranked.basis, ranked.confidence
                        FROM (
                          SELECT ne.bil_nutrient_id, ne.amount, nd.unit, ne.basis, ne.confidence,
                                 ROW_NUMBER() OVER (PARTITION BY ne.bil_nutrient_id, ne.basis ORDER BY ne.confidence DESC, ne.nutrient_evidence_id DESC) AS rn
                          FROM nutrient_evidence ne
                          JOIN nutrient_definition nd ON nd.bil_nutrient_id = ne.bil_nutrient_id
                          WHERE ne.bil_food_id = ?
                        ) ranked
                        WHERE ranked.rn = 1
                        """,
                        (bil_food_id,),
                    ):
                        out.execute(
                            "INSERT OR REPLACE INTO nutrient VALUES(?,?,?,?,?,?)",
                            (bil_food_id, *nutrient),
                        )

                if _table_exists(master, "portion"):
                    for portion in master.execute(
                        "SELECT portion_id,amount,unit_code,gram_weight,description_en,description_ar,confidence FROM portion WHERE bil_food_id=?",
                        (bil_food_id,),
                    ):
                        out.execute(
                            "INSERT INTO portion VALUES(?,?,?,?,?,?,?,?)",
                            (portion[0], bil_food_id, *portion[1:]),
                        )

                if _table_exists(master, "barcode_claim"):
                    for barcode in master.execute(
                        "SELECT normalized_gtin,market_code,confidence FROM barcode_claim WHERE bil_food_id=? AND claim_status='active'",
                        (bil_food_id,),
                    ):
                        out.execute(
                            "INSERT OR IGNORE INTO barcode VALUES(?,?,?,?)",
                            (barcode[0], bil_food_id, barcode[1], barcode[2]),
                        )

                alias_text = " ".join(str(value) for (value,) in out.execute("SELECT name FROM alias WHERE bil_food_id=? ORDER BY alias_id", (bil_food_id,)))
                out.execute("INSERT INTO food_fts(bil_food_id,name_en,name_ar,aliases) VALUES(?,?,?,?)", (bil_food_id, row["canonical_name_en"] or "", row["canonical_name_ar"] or "", alias_text))

            metadata = {
                "profile": asdict(profile),
                "built_at": utc_now(),
                "source_master_sha256": _sha256_file(master_path),
                "row_count": row_count,
            }
            for key, value in metadata.items():
                out.execute(
                    "INSERT INTO catalog_metadata VALUES(?,?)",
                    (key, value if isinstance(value, str) else json.dumps(value, sort_keys=True)),
                )
            out.commit()
            integrity = out.execute("PRAGMA integrity_check").fetchone()[0]
            if integrity != "ok":
                raise RuntimeError(f"catalog integrity check failed: {integrity}")

        temp_path.replace(output_path)
    except Exception:
        temp_path.unlink(missing_ok=True)
        raise

    elapsed = time.perf_counter() - started
    return {
        "profile_id": profile.profile_id,
        "rows": row_count,
        "elapsed_seconds": round(elapsed, 3),
        "size_bytes": output_path.stat().st_size,
        "sha256": _sha256_file(output_path),
        "integrity": "ok",
    }
