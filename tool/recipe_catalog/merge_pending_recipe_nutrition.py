"""Fail-closed nutrition merge for the canonical 100-recipe catalog."""
import argparse
import json
import math
import sys
from pathlib import Path


def fail(message):
    raise ValueError(message)


def load(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot_read:{path.name}:{error}")
    if not isinstance(value, dict) or not isinstance(value.get("records"), list):
        fail(f"invalid_shape:{path.name}")
    return value


def finite_nonnegative_map(value, canonical):
    if not isinstance(value, dict) or not value:
        fail(f"missing_per_serving:{canonical}")
    for key, number in value.items():
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or number < 0:
            fail(f"invalid_per_serving:{canonical}:{key}")


def normalized_patch(record):
    canonical = record.get("canonicalId")
    if not isinstance(canonical, str) or not canonical:
        fail("missing_canonical_id")
    nutrition = record.get("nutrition")
    if not isinstance(nutrition, dict):
        raw_status = record.get("status")
        ingredient_refs = []
        for ingredient in record.get("formulation", []):
            for ref in ingredient.get("sourceRefs", []):
                value = ref if isinstance(ref, str) else ref.get("localRecordId") if isinstance(ref, dict) else None
                if isinstance(value, str) and value:
                    ingredient_refs.append(value)
        nutrition = {
            "status": "calculated" if raw_status == "verified-calculation" else raw_status,
            "servings": record.get("servings"),
            "sourceRefs": sorted(set(record.get("sourceRefs") or ingredient_refs)),
            "reviewedAt": record.get("reviewedAt"),
            "perServing": record.get("nutritionPerServing") or record.get("perServing"),
        }
    if nutrition.get("status") != "calculated":
        fail(f"nutrition_not_calculated:{canonical}")
    refs = nutrition.get("sourceRefs")
    if not isinstance(refs, list) or not refs or any(not isinstance(ref, str) or not ref for ref in refs):
        fail(f"missing_source_refs:{canonical}")
    finite_nonnegative_map(nutrition.get("perServing"), canonical)
    return canonical, nutrition


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default="artifacts/meal_catalog")
    args = parser.parse_args()
    directory = Path(args.directory)
    source_path = directory / "recipe_canonical_100.json"
    paths = [directory / "recipe_nutrition_pending_a.json", directory / "recipe_nutrition_pending_b.json"]
    missing = [path.name for path in paths if not path.is_file()]
    if missing:
        print("PENDING: " + ",".join(missing))
        return 2
    try:
        source = load(source_path)
        batches = [load(path) for path in paths]
        records = source["records"]
        if len(records) != 100:
            fail(f"source_count_not_100:{len(records)}")
        ids = [record.get("canonicalId") for record in records]
        if len(set(ids)) != 100:
            fail("source_duplicate_ids")
        expected = {record["canonicalId"] for record in records if record.get("nutrition", {}).get("status") != "calculated"}
        patches = {}
        for batch in batches:
            for record in batch["records"]:
                canonical, nutrition = normalized_patch(record)
                if canonical in patches:
                    fail(f"duplicate_patch_id:{canonical}")
                patches[canonical] = nutrition
        if set(patches) != expected:
            fail(f"pending_id_set_mismatch:expected={len(expected)}:found={len(patches)}:missing={sorted(expected-set(patches))}:extra={sorted(set(patches)-expected)}")
        for record in records:
            if record["canonicalId"] in patches:
                record["nutrition"] = patches[record["canonicalId"]]
        if len(records) != 100 or len({r["canonicalId"] for r in records}) != 100:
            fail("final_identity_drift")
        locales = {locale: sum(r.get("primaryLocale") == locale for r in records) for locale in ("ar", "en", "fr", "es", "tr")}
        if any(count != 20 for count in locales.values()):
            fail(f"final_locale_distribution_drift:{locales}")
        calculated = sum(r.get("nutrition", {}).get("status") == "calculated" for r in records)
        pending = 100 - calculated
        output = {**source, "verification": {"recordCount": 100, "localeCounts": locales,
            "calculated": calculated, "pending": pending, "pendingBatchesMerged": [path.name for path in paths]}, "records": records}
        target = directory / "recipe_canonical_100_verified.json"
        target.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS records=100 calculated={calculated} pending={pending} output={target}")
        return 0
    except ValueError as error:
        print(f"FAIL {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
