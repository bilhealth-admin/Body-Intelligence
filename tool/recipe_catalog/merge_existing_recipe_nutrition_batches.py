import argparse
import hashlib
import json
import math
import sys
from pathlib import Path


class MergeError(ValueError):
    pass


def load_object(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise MergeError(f"cannot_read_json:{path.name}:{error}") from error
    if not isinstance(value, dict) or not isinstance(value.get("records"), list):
        raise MergeError(f"invalid_batch_shape:{path.name}")
    return value


def nonempty_string(value):
    return isinstance(value, str) and bool(value.strip())


def validate_record(record):
    if not isinstance(record, dict):
        raise MergeError("record_not_object")
    canonical = record.get("canonicalId")
    fingerprint = record.get("contentFingerprint")
    if not nonempty_string(canonical):
        raise MergeError("missing_canonical_id")
    if not isinstance(fingerprint, str) or len(fingerprint) != 64 or any(c not in "0123456789abcdef" for c in fingerprint):
        raise MergeError(f"invalid_content_fingerprint:{canonical}")
    image = record.get("image")
    if not isinstance(image, dict) or not nonempty_string(image.get("assetPath")) or not nonempty_string(image.get("sha256")):
        raise MergeError(f"missing_image_identity:{canonical}")
    timing = record.get("timing")
    if not isinstance(timing, dict):
        raise MergeError(f"missing_timing:{canonical}")
    prep, cook, total = (timing.get(k) for k in ("prepMinutes", "cookMinutes", "totalMinutes"))
    if any(isinstance(v, bool) or not isinstance(v, int) or v < 0 for v in (prep, cook, total)) or prep + cook != total:
        raise MergeError(f"timing_sum_mismatch:{canonical}")
    ingredients = record.get("ingredients")
    if not isinstance(ingredients, list) or not ingredients:
        raise MergeError(f"missing_ingredients:{canonical}")
    for index, ingredient in enumerate(ingredients):
        if not isinstance(ingredient, dict) or not nonempty_string(ingredient.get("recordId")):
            raise MergeError(f"ingredient_record_id_missing:{canonical}:{index}")
        refs = ingredient.get("sourceRefs")
        if not isinstance(refs, list) or not refs or any(not nonempty_string(ref) for ref in refs):
            raise MergeError(f"ingredient_source_refs_missing:{canonical}:{index}")
    nutrition = record.get("nutrition")
    if not isinstance(nutrition, dict) or nutrition.get("status") != "calculated":
        raise MergeError(f"nutrition_not_calculated:{canonical}")
    per_serving = nutrition.get("perServing")
    if not isinstance(per_serving, dict) or not per_serving:
        raise MergeError(f"per_serving_missing:{canonical}")
    for nutrient, value in per_serving.items():
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            raise MergeError(f"per_serving_invalid:{canonical}:{nutrient}")


def _source_ids(ingredient):
    refs = ingredient.get("sourceRefs")
    if not isinstance(refs, list):
        return []
    result = []
    for ref in refs:
        value = ref if isinstance(ref, str) else ref.get("localRecordId") if isinstance(ref, dict) else None
        if nonempty_string(value):
            result.append(value)
    return result


def normalize_record(record, seed):
    """Merge a verified formulation onto its canonical seed shape."""
    value = json.loads(json.dumps(seed))
    canonical = seed["canonicalId"]
    fingerprint = record.get("contentFingerprint") or record.get("seedContentFingerprint")
    if fingerprint != seed.get("contentFingerprint"):
        raise MergeError(f"seed_content_fingerprint_mismatch:{canonical}")
    raw_ingredients = record.get("ingredients") or record.get("formulation")
    if not isinstance(raw_ingredients, list):
        raise MergeError(f"missing_ingredients:{canonical}")
    ingredients = []
    for index, item in enumerate(raw_ingredients):
        refs = _source_ids(item)
        record_id = item.get("recordId") or (refs[0] if refs else None)
        ingredients.append({
            "itemId": item.get("itemId") or item.get("ingredient"),
            "quantity": item.get("quantity") if item.get("quantity") is not None else item.get("grams"),
            "unit": item.get("unit") or "g",
            "grams": item.get("grams"),
            "recordId": record_id,
            "sourceRefs": refs,
        })
    nutrition = record.get("nutrition")
    if not isinstance(nutrition, dict):
        per = record.get("nutritionPerServing")
        nutrition = {
            "status": "calculated" if record.get("status") == "verified-calculation" else "pending",
            "servings": record.get("servings"),
            "sourceRefs": sorted({ref for item in ingredients for ref in item["sourceRefs"]}),
            "reviewedAt": None,
            "perServing": per,
        }
    value.update({
        "contentFingerprint": fingerprint,
        "serving": {"count": record.get("servings"), "size": 1, "unit": "serving"},
        "timing": record.get("timing"),
        "ingredients": ingredients,
        "nutrition": nutrition,
    })
    if isinstance(record.get("image"), dict):
        value["image"] = record["image"]
    return value


def merge(batch_a_path, batch_b_path, seeds_path):
    batch_a, batch_b, seeds = (load_object(path) for path in (batch_a_path, batch_b_path, seeds_path))
    if str(batch_a.get("batch", "")).upper() != "A" or str(batch_b.get("batch", "")).upper() != "B":
        raise MergeError("batch_labels_must_be_A_and_B")
    expected_order = [row.get("canonicalId") for row in seeds["records"]]
    if len(expected_order) != 18 or len(set(expected_order)) != 18 or any(not nonempty_string(value) for value in expected_order):
        raise MergeError("seed_contract_must_contain_exactly_18_ids")
    seed_by_id = {row["canonicalId"]: row for row in seeds["records"]}
    raw_records = [*batch_a["records"], *batch_b["records"]]
    records = []
    for record in raw_records:
        canonical = record.get("canonicalId") if isinstance(record, dict) else None
        if canonical not in seed_by_id:
            raise MergeError(f"unknown_canonical_id:{canonical}")
        records.append(normalize_record(record, seed_by_id[canonical]))
    if len(records) != 18:
        raise MergeError(f"merged_record_count_must_be_18:found={len(records)}")
    for record in records:
        validate_record(record)
    ids = [row["canonicalId"] for row in records]
    if len(set(ids)) != 18:
        raise MergeError("duplicate_canonical_id")
    if set(ids) != set(expected_order):
        raise MergeError(f"canonical_id_set_mismatch:missing={sorted(set(expected_order)-set(ids))}:extra={sorted(set(ids)-set(expected_order))}")
    for field, getter in (
        ("contentFingerprint", lambda row: row["contentFingerprint"]),
        ("image_sha256", lambda row: row["image"]["sha256"]),
        ("image_assetPath", lambda row: row["image"]["assetPath"].replace("\\", "/").lower()),
    ):
        values = [getter(row) for row in records]
        if len(set(values)) != len(values):
            raise MergeError(f"duplicate_{field}")
    by_id = {row["canonicalId"]: row for row in records}
    return {
        "schemaVersion": 1,
        "verification": {
            "recordCount": 18,
            "canonicalIdsExact": True,
            "ingredientEvidenceComplete": True,
            "timingSumsValid": True,
            "perServingFiniteNonnegative": True,
            "duplicateCanonicalContentImage": False,
            "sourceBatchSha256": {
                "A": hashlib.sha256(batch_a_path.read_bytes()).hexdigest(),
                "B": hashlib.sha256(batch_b_path.read_bytes()).hexdigest(),
            },
        },
        "records": [by_id[canonical] for canonical in expected_order],
    }


def main():
    parser = argparse.ArgumentParser(description="Fail-closed merge for the two existing-recipe nutrition batches")
    parser.add_argument("--directory", default="artifacts/meal_catalog")
    parser.add_argument("--output")
    args = parser.parse_args()
    directory = Path(args.directory)
    a = directory / "existing_recipe_nutrition_batch_a.json"
    b = directory / "existing_recipe_nutrition_batch_b.json"
    seeds = directory / "existing_recipe_canonical_seeds.json"
    missing = [path.name for path in (a, b) if not path.is_file()]
    if missing:
        print(f"PENDING: waiting for {', '.join(missing)}", file=sys.stderr)
        return 2
    output = Path(args.output) if args.output else directory / "existing_recipe_canonical_verified.json"
    try:
        merged = merge(a, b, seeds)
    except MergeError as error:
        print(f"REJECTED: {error}", file=sys.stderr)
        return 1
    output.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"VERIFIED: records=18 output={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
