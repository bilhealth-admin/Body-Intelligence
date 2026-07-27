from __future__ import annotations

import json
import math
import re
import sqlite3
import unicodedata
from contextlib import closing
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping, Sequence

POLICY_VERSION = "bil-food-quality-v1"

_UNIT_ALIASES = {
    "g": "g", "gram": "g", "grams": "g", "غ": "g", "جرام": "g",
    "kg": "kg", "kilogram": "kg", "kilograms": "kg", "كغ": "kg", "كجم": "kg",
    "mg": "mg", "milligram": "mg", "milligrams": "mg", "ملغ": "mg",
    "ug": "ug", "µg": "ug", "mcg": "ug", "microgram": "ug",
    "ml": "ml", "milliliter": "ml", "milliliters": "ml", "مل": "ml",
    "l": "l", "liter": "l", "liters": "l", "ل": "l",
    "kcal": "kcal", "calorie": "kcal", "calories": "kcal",
    "kj": "kJ", "kilojoule": "kJ", "kilojoules": "kJ",
}

_KEY_NUTRIENTS = ("energy", "protein", "carbohydrate", "fat")
_SOURCE_AUTHORITY = {
    "USDA_FOUNDATION": 100.0,
    "USDA_SR_LEGACY": 92.0,
    "USDA_BRANDED": 78.0,
    "COMMUNITY_VERIFIED": 68.0,
    "USER_ENTERED": 45.0,
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def normalize_text(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = unicodedata.normalize("NFKC", value)
    normalized = re.sub(r"[\u0000-\u001f\u007f]", " ", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized or None


def normalize_key(value: str | None) -> str | None:
    text = normalize_text(value)
    if text is None:
        return None
    text = text.casefold()
    text = re.sub(r"[^\w\u0600-\u06ff]+", " ", text, flags=re.UNICODE)
    text = re.sub(r"\s+", " ", text).strip()
    return text or None


def normalize_unit(value: str | None) -> str | None:
    key = normalize_key(value)
    if key is None:
        return None
    return _UNIT_ALIASES.get(key)


def _gtin_checksum_is_valid(digits: str) -> bool:
    body, expected = digits[:-1], int(digits[-1])
    total = 0
    for index, char in enumerate(reversed(body), start=1):
        total += int(char) * (3 if index % 2 == 1 else 1)
    return (10 - (total % 10)) % 10 == expected


def normalize_barcode(value: str | None) -> tuple[str | None, str]:
    text = normalize_text(value)
    if text is None:
        return None, "missing"
    digits = re.sub(r"\D", "", text)
    if len(digits) not in {8, 12, 13, 14}:
        return digits or None, "invalid_length"
    return digits, "valid" if _gtin_checksum_is_valid(digits) else "invalid_checksum"


@dataclass(frozen=True)
class QualityPolicy:
    version: str = POLICY_VERSION
    accepted_threshold: float = 72.0
    quarantine_threshold: float = 45.0
    weights: Mapping[str, float] = field(default_factory=lambda: {
        "source_authority": 0.18,
        "identity_completeness": 0.18,
        "nutrient_completeness": 0.22,
        "portion_quality": 0.10,
        "barcode_validity": 0.08,
        "recency": 0.08,
        "internal_consistency": 0.11,
        "conflict_resilience": 0.05,
    })

    def validate(self) -> None:
        if not self.version.strip():
            raise ValueError("policy version must not be blank")
        if not math.isclose(sum(self.weights.values()), 1.0, rel_tol=0, abs_tol=1e-9):
            raise ValueError("quality weights must sum to 1.0")
        if not (0 <= self.quarantine_threshold <= self.accepted_threshold <= 100):
            raise ValueError("quality thresholds are invalid")


@dataclass(frozen=True)
class QualityInput:
    source_record_id: int
    source_system: str
    name: str | None
    brand: str | None = None
    barcode: str | None = None
    food_kind: str = "unknown"
    nutrient_values: Mapping[str, float | None] = field(default_factory=dict)
    portion_gram_weights: Sequence[float] = field(default_factory=tuple)
    source_age_days: int | None = None
    conflict_count: int = 0
    identity_evidence_count: int = 1


@dataclass(frozen=True)
class QualityAssessment:
    source_record_id: int
    policy_version: str
    normalized_name: str | None
    normalized_name_key: str | None
    normalized_brand: str | None
    normalized_brand_key: str | None
    normalized_barcode: str | None
    barcode_status: str
    normalized_unit_examples: Mapping[str, str | None]
    components: Mapping[str, float]
    overall_score: float
    validation_status: str
    delivery_eligibility: str
    rejection_reasons: tuple[str, ...]
    warnings: tuple[str, ...]
    assessed_at: str

    def to_json(self) -> str:
        return json.dumps(asdict(self), ensure_ascii=False, sort_keys=True)


class NutritionQualityEngine:
    def __init__(self, policy: QualityPolicy | None = None):
        self.policy = policy or QualityPolicy()
        self.policy.validate()

    def assess(self, item: QualityInput) -> QualityAssessment:
        if item.source_record_id <= 0:
            raise ValueError("source_record_id must be positive")

        normalized_name = normalize_text(item.name)
        normalized_brand = normalize_text(item.brand)
        normalized_barcode, barcode_status = normalize_barcode(item.barcode)
        rejection_reasons: list[str] = []
        warnings: list[str] = []

        if normalized_name is None:
            rejection_reasons.append("missing_or_unusable_name")

        impossible_nutrients = [
            key for key, value in item.nutrient_values.items()
            if value is not None and (not math.isfinite(float(value)) or float(value) < 0)
        ]
        if impossible_nutrients:
            rejection_reasons.append("invalid_nutrient_value")

        present_key_nutrients = sum(
            1 for key in _KEY_NUTRIENTS
            if item.nutrient_values.get(key) is not None
        )
        if present_key_nutrients == 0:
            rejection_reasons.append("all_key_macronutrients_missing")

        if item.identity_evidence_count <= 0:
            rejection_reasons.append("missing_identity_evidence")

        if item.barcode is not None and barcode_status != "valid":
            warnings.append(f"barcode_{barcode_status}")
            if item.identity_evidence_count == 1 and normalized_name is None:
                rejection_reasons.append("invalid_barcode_as_sole_identity_evidence")

        invalid_portions = [value for value in item.portion_gram_weights if not math.isfinite(value) or value <= 0]
        if invalid_portions:
            rejection_reasons.append("invalid_portion_weight")

        source_authority = _SOURCE_AUTHORITY.get(item.source_system.upper(), 55.0)
        identity_completeness = min(100.0, 35.0 * bool(normalized_name) + 20.0 * bool(normalized_brand) + 20.0 * (item.food_kind != "unknown") + 25.0 * min(item.identity_evidence_count, 2) / 2)
        nutrient_completeness = present_key_nutrients / len(_KEY_NUTRIENTS) * 100.0
        portion_quality = 100.0 if item.portion_gram_weights and not invalid_portions else (45.0 if not item.portion_gram_weights else 0.0)
        barcode_validity = {"valid": 100.0, "missing": 55.0, "invalid_length": 10.0, "invalid_checksum": 15.0}[barcode_status]
        if item.source_age_days is None:
            recency = 60.0
        elif item.source_age_days <= 365:
            recency = 100.0
        elif item.source_age_days <= 3 * 365:
            recency = 80.0
        elif item.source_age_days <= 7 * 365:
            recency = 60.0
        else:
            recency = 35.0
        internal_consistency = 0.0 if impossible_nutrients or invalid_portions else 100.0
        conflict_resilience = max(0.0, 100.0 - min(item.conflict_count, 5) * 20.0)

        components = {
            "source_authority": source_authority,
            "identity_completeness": identity_completeness,
            "nutrient_completeness": nutrient_completeness,
            "portion_quality": portion_quality,
            "barcode_validity": barcode_validity,
            "recency": recency,
            "internal_consistency": internal_consistency,
            "conflict_resilience": conflict_resilience,
        }
        overall_score = round(sum(components[name] * weight for name, weight in self.policy.weights.items()), 2)

        if rejection_reasons:
            validation_status = "rejected"
            delivery_eligibility = "excluded"
        elif overall_score >= self.policy.accepted_threshold:
            validation_status = "accepted"
            delivery_eligibility = "mobile_candidate"
        elif overall_score >= self.policy.quarantine_threshold:
            validation_status = "quarantined"
            delivery_eligibility = "master_only"
        else:
            validation_status = "rejected"
            delivery_eligibility = "excluded"
            rejection_reasons.append("quality_score_below_quarantine_threshold")

        return QualityAssessment(
            source_record_id=item.source_record_id,
            policy_version=self.policy.version,
            normalized_name=normalized_name,
            normalized_name_key=normalize_key(normalized_name),
            normalized_brand=normalized_brand,
            normalized_brand_key=normalize_key(normalized_brand),
            normalized_barcode=normalized_barcode,
            barcode_status=barcode_status,
            normalized_unit_examples={key: normalize_unit(key) for key in ("g", "kg", "mg", "ml", "kcal")},
            components={key: round(value, 2) for key, value in components.items()},
            overall_score=overall_score,
            validation_status=validation_status,
            delivery_eligibility=delivery_eligibility,
            rejection_reasons=tuple(dict.fromkeys(rejection_reasons)),
            warnings=tuple(dict.fromkeys(warnings)),
            assessed_at=utc_now(),
        )


QUALITY_SCHEMA_SQL = """
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS quality_policy (
  policy_version TEXT PRIMARY KEY,
  policy_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS source_normalization (
  source_record_id INTEGER PRIMARY KEY REFERENCES source_record(source_record_id),
  normalized_name TEXT,
  normalized_name_key TEXT,
  normalized_brand TEXT,
  normalized_brand_key TEXT,
  normalized_barcode TEXT,
  barcode_status TEXT NOT NULL,
  warnings_json TEXT NOT NULL,
  policy_version TEXT NOT NULL REFERENCES quality_policy(policy_version),
  normalized_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS quality_assessment (
  source_record_id INTEGER PRIMARY KEY REFERENCES source_record(source_record_id),
  overall_score REAL NOT NULL CHECK(overall_score >= 0 AND overall_score <= 100),
  components_json TEXT NOT NULL,
  validation_status TEXT NOT NULL CHECK(validation_status IN ('accepted','quarantined','rejected')),
  delivery_eligibility TEXT NOT NULL CHECK(delivery_eligibility IN ('mobile_candidate','master_only','excluded')),
  rejection_reasons_json TEXT NOT NULL,
  policy_version TEXT NOT NULL REFERENCES quality_policy(policy_version),
  assessed_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_quality_status ON quality_assessment(validation_status, delivery_eligibility);
"""


def install_quality_schema(database_path: Path, policy: QualityPolicy | None = None) -> None:
    selected = policy or QualityPolicy()
    selected.validate()
    with closing(sqlite3.connect(database_path)) as conn:
        conn.executescript(QUALITY_SCHEMA_SQL)
        conn.execute(
            "INSERT OR REPLACE INTO quality_policy(policy_version,policy_json,created_at) VALUES(?,?,?)",
            (selected.version, json.dumps(asdict(selected), sort_keys=True), utc_now()),
        )
        conn.commit()


def persist_assessment(database_path: Path, assessment: QualityAssessment) -> None:
    with closing(sqlite3.connect(database_path)) as conn:
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute(
            """INSERT OR REPLACE INTO source_normalization(
               source_record_id,normalized_name,normalized_name_key,normalized_brand,normalized_brand_key,
               normalized_barcode,barcode_status,warnings_json,policy_version,normalized_at)
               VALUES(?,?,?,?,?,?,?,?,?,?)""",
            (
                assessment.source_record_id,
                assessment.normalized_name,
                assessment.normalized_name_key,
                assessment.normalized_brand,
                assessment.normalized_brand_key,
                assessment.normalized_barcode,
                assessment.barcode_status,
                json.dumps(assessment.warnings),
                assessment.policy_version,
                assessment.assessed_at,
            ),
        )
        conn.execute(
            """INSERT OR REPLACE INTO quality_assessment(
               source_record_id,overall_score,components_json,validation_status,delivery_eligibility,
               rejection_reasons_json,policy_version,assessed_at)
               VALUES(?,?,?,?,?,?,?,?)""",
            (
                assessment.source_record_id,
                assessment.overall_score,
                json.dumps(assessment.components, sort_keys=True),
                assessment.validation_status,
                assessment.delivery_eligibility,
                json.dumps(assessment.rejection_reasons),
                assessment.policy_version,
                assessment.assessed_at,
            ),
        )
        conn.commit()
