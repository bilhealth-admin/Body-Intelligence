from __future__ import annotations

import json
import sqlite3
from contextlib import closing
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Mapping, Sequence

from .canonical_model import CanonicalFoodStore

POLICY_VERSION = "bil-food-dedup-v1"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class FoodFingerprint:
    bil_food_id: str
    source_record_id: int
    source_system: str
    external_id: str
    normalized_name_key: str | None
    normalized_brand_key: str | None
    normalized_barcode: str | None
    barcode_status: str
    food_kind: str
    category_key: str | None
    nutrient_profile: Mapping[str, float | None]
    package_key: str | None = None
    market_code: str | None = None
    quality_score: float = 0.0


@dataclass(frozen=True)
class DuplicateDecision:
    left_bil_food_id: str
    right_bil_food_id: str
    policy_version: str
    disposition: str
    confidence: float
    reasons: tuple[str, ...]
    conflicts: tuple[str, ...]
    survivor_bil_food_id: str | None
    decided_at: str

    def to_json(self) -> str:
        return json.dumps(asdict(self), sort_keys=True)


class DeduplicationPolicy:
    version = POLICY_VERSION
    nutrient_relative_tolerance = 0.15
    minimum_profile_overlap = 3

    def evaluate(self, left: FoodFingerprint, right: FoodFingerprint) -> DuplicateDecision:
        if left.bil_food_id == right.bil_food_id:
            raise ValueError("deduplication requires distinct BIL food identities")

        reasons: list[str] = []
        conflicts: list[str] = []

        same_source_record = (
            left.source_system == right.source_system
            and left.external_id == right.external_id
        )
        if same_source_record:
            reasons.append("same_stable_external_record")

        valid_same_barcode = (
            left.barcode_status == "valid"
            and right.barcode_status == "valid"
            and left.normalized_barcode is not None
            and left.normalized_barcode == right.normalized_barcode
        )
        same_brand = bool(left.normalized_brand_key) and left.normalized_brand_key == right.normalized_brand_key
        compatible_package = self._compatible_package(left.package_key, right.package_key)
        compatible_kind = left.food_kind == right.food_kind
        compatible_profile, profile_reasons = self._compatible_nutrients(left.nutrient_profile, right.nutrient_profile)
        reasons.extend(profile_reasons)

        if valid_same_barcode:
            reasons.append("same_valid_gtin")
            if not same_brand:
                conflicts.append("brand_conflict")
            if not compatible_package:
                conflicts.append("package_conflict")
            if not compatible_profile:
                conflicts.append("nutrient_profile_conflict")
            if left.market_code and right.market_code and left.market_code != right.market_code:
                conflicts.append("market_conflict")

        exact_generic_identity = (
            left.food_kind == "generic"
            and right.food_kind == "generic"
            and bool(left.normalized_name_key)
            and left.normalized_name_key == right.normalized_name_key
            and left.category_key == right.category_key
            and compatible_profile
        )
        if exact_generic_identity:
            reasons.append("exact_generic_identity")

        if same_source_record:
            disposition = "auto_merge"
            confidence = 1.0
        elif valid_same_barcode and same_brand and compatible_package and compatible_profile and not conflicts:
            disposition = "auto_merge"
            confidence = 0.98
        elif exact_generic_identity:
            disposition = "auto_merge"
            confidence = 0.96
        elif valid_same_barcode or (
            left.normalized_name_key
            and left.normalized_name_key == right.normalized_name_key
        ):
            disposition = "candidate_review"
            confidence = 0.72 if valid_same_barcode else 0.58
            if not reasons:
                reasons.append("name_similarity_only")
        else:
            disposition = "distinct"
            confidence = 0.99
            reasons.append("insufficient_duplicate_evidence")

        survivor = None
        if disposition == "auto_merge":
            survivor = self._select_survivor(left, right)

        return DuplicateDecision(
            left_bil_food_id=left.bil_food_id,
            right_bil_food_id=right.bil_food_id,
            policy_version=self.version,
            disposition=disposition,
            confidence=confidence,
            reasons=tuple(dict.fromkeys(reasons)),
            conflicts=tuple(dict.fromkeys(conflicts)),
            survivor_bil_food_id=survivor,
            decided_at=utc_now(),
        )

    @staticmethod
    def _compatible_package(left: str | None, right: str | None) -> bool:
        if left is None or right is None:
            return True
        return left == right

    def _compatible_nutrients(
        self,
        left: Mapping[str, float | None],
        right: Mapping[str, float | None],
    ) -> tuple[bool, list[str]]:
        comparable = []
        for key in sorted(set(left) & set(right)):
            a, b = left[key], right[key]
            if a is None or b is None:
                continue
            denominator = max(abs(float(a)), abs(float(b)), 1.0)
            comparable.append(abs(float(a) - float(b)) / denominator <= self.nutrient_relative_tolerance)
        if len(comparable) < self.minimum_profile_overlap:
            return True, ["insufficient_nutrient_overlap"]
        return all(comparable), ["compatible_nutrient_profile" if all(comparable) else "material_nutrient_disagreement"]

    @staticmethod
    def _select_survivor(left: FoodFingerprint, right: FoodFingerprint) -> str:
        if left.quality_score != right.quality_score:
            return left.bil_food_id if left.quality_score > right.quality_score else right.bil_food_id
        return min(left.bil_food_id, right.bil_food_id)


DEDUP_SCHEMA_SQL = """
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS duplicate_decision (
  duplicate_decision_id INTEGER PRIMARY KEY AUTOINCREMENT,
  left_bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  right_bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  disposition TEXT NOT NULL CHECK(disposition IN ('auto_merge','candidate_review','distinct')),
  confidence REAL NOT NULL CHECK(confidence >= 0 AND confidence <= 1),
  reasons_json TEXT NOT NULL,
  conflicts_json TEXT NOT NULL,
  survivor_bil_food_id TEXT REFERENCES canonical_food(bil_food_id),
  policy_version TEXT NOT NULL,
  decided_at TEXT NOT NULL,
  UNIQUE(left_bil_food_id, right_bil_food_id, policy_version),
  CHECK(left_bil_food_id <> right_bil_food_id)
);
CREATE INDEX IF NOT EXISTS idx_duplicate_disposition ON duplicate_decision(disposition, confidence);
CREATE TABLE IF NOT EXISTS canonical_field_selection (
  selection_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bil_food_id TEXT NOT NULL REFERENCES canonical_food(bil_food_id),
  field_name TEXT NOT NULL,
  selected_source_record_id INTEGER NOT NULL REFERENCES source_record(source_record_id),
  selected_value_json TEXT NOT NULL,
  reason TEXT NOT NULL,
  policy_version TEXT NOT NULL,
  selected_at TEXT NOT NULL,
  UNIQUE(bil_food_id, field_name, policy_version)
);
"""


def install_dedup_schema(database_path: Path) -> None:
    with closing(sqlite3.connect(database_path)) as conn:
        conn.executescript(DEDUP_SCHEMA_SQL)
        conn.commit()


def persist_decision(database_path: Path, decision: DuplicateDecision) -> None:
    pair = sorted((decision.left_bil_food_id, decision.right_bil_food_id))
    with closing(sqlite3.connect(database_path)) as conn:
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute(
            """INSERT OR REPLACE INTO duplicate_decision(
               left_bil_food_id,right_bil_food_id,disposition,confidence,reasons_json,
               conflicts_json,survivor_bil_food_id,policy_version,decided_at)
               VALUES(?,?,?,?,?,?,?,?,?)""",
            (
                pair[0], pair[1], decision.disposition, decision.confidence,
                json.dumps(decision.reasons), json.dumps(decision.conflicts),
                decision.survivor_bil_food_id, decision.policy_version, decision.decided_at,
            ),
        )
        conn.commit()


def apply_auto_merge(
    database_path: Path,
    decision: DuplicateDecision,
    *,
    reason_prefix: str = "deduplication",
) -> None:
    if decision.disposition != "auto_merge" or decision.survivor_bil_food_id is None:
        raise ValueError("only an auto_merge decision may be applied")
    retired = (
        decision.right_bil_food_id
        if decision.survivor_bil_food_id == decision.left_bil_food_id
        else decision.left_bil_food_id
    )
    CanonicalFoodStore(database_path).merge_foods(
        retired,
        decision.survivor_bil_food_id,
        f"{reason_prefix}:{','.join(decision.reasons)}",
        decision.to_json(),
        decision.policy_version,
    )


def select_canonical_field(
    database_path: Path,
    *,
    bil_food_id: str,
    field_name: str,
    candidates: Sequence[tuple[int, object, float]],
    policy_version: str = POLICY_VERSION,
) -> tuple[int, object]:
    if not candidates:
        raise ValueError("canonical field selection requires candidates")
    selected = sorted(candidates, key=lambda item: (-item[2], item[0]))[0]
    with closing(sqlite3.connect(database_path)) as conn:
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute(
            """INSERT OR REPLACE INTO canonical_field_selection(
               bil_food_id,field_name,selected_source_record_id,selected_value_json,reason,policy_version,selected_at)
               VALUES(?,?,?,?,?,?,?)""",
            (
                bil_food_id, field_name, selected[0], json.dumps(selected[1], ensure_ascii=False),
                "highest_quality_then_lowest_source_record_id", policy_version, utc_now(),
            ),
        )
        conn.commit()
    return selected[0], selected[1]
