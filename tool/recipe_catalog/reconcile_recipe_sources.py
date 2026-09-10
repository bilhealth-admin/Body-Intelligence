"""Reproducible source reconciliation, never substring-based food selection.

Dry-run by default. --recover-from preserves the original 34 formulations as
an auditable input. --apply requires a hash-matching backup of the current assets.
No SQLite, image, thumbnail, saved-user-recipe or unrelated asset is modified.
"""
import argparse
import copy
import hashlib
import json
import math
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RELEASE = ROOT / "assets/catalogs/recipes/v1"
EVIDENCE = Path(__file__).with_name("recovered_recipe_formulations_20260910.json")
REVISION = "bil-source-reconciled-20260910-v1"
COLUMNS = {
    "kcal": "energy_kcal", "proteinG": "protein_g",
    "carbohydrateG": "carbs_g", "fatG": "fat_g", "fiberG": "fiber_g",
    "sugarG": "sugars_g", "sodiumMg": "sodium_mg", "potassiumMg": "potassium_mg",
}
CORE = {"kcal", "proteinG", "carbohydrateG", "fatG"}

# Explicit BIL formulation choices, not claims about every food of that name.
# Source state is retained in each ingredient and disclosed to the user.
# Existing, compatible records are kept; original missing mappings come from
# the fingerprint/quantity-bound recovered formulation, not this table.
CORRECTIONS = {
    ("artichoke", 169236): 169205,       # globe artichoke, not Jerusalem tuber
    ("beef", 172012): 171206,            # raw chuck for stew, not bologna
    ("beef", 174032): 171203,            # cooked beef pieces, not a patty
    ("black beans", 168064): 173735,     # beans, not restaurant rice + beans
    ("bread", 172673): 174924,           # white bread, not egg bread
    ("chicken breast", 174608): 171477,  # breast meat, not processed chicken roll
    ("corn", 169698): 169998,            # sweet corn, not cornstarch
    ("egg", 171258): 171287,             # whole raw egg, not eggnog
    ("green beans", 172273): 169141,     # cooked green beans, not baby food
    ("ground beef", 167657): 171796,     # raw 85/15 beef, not a restaurant taco
    ("kidney beans", 169885): 175194,    # beans, not drained bean liquid
    ("lemon", 167749): 167746,           # flesh, not peel
    ("lemon", 167747): 167746,           # whole edible lemon, not juice
    ("milk", 174980): 171265,            # whole 3.25% milk, not crackers
    ("mint", 167982): 173475,            # fresh spearmint, not candy
    ("olive oil", 171443): 171413,       # oil, not reduced-fat mayonnaise
    ("pie crust", 167521): 172814,       # standard unbaked pastry, not chocolate
    ("potato", 168446): 170026,          # whole raw potato, not flour
    ("red beans", 168065): 175194,       # red kidney beans, not rice + beans
    ("rice", 173161): 169756,            # raw long-grain rice, not crackers
    ("sweet potato", 169305): 168482,    # raw sweet potato, not canned mash
    ("tomato", 170461): 170457,          # raw tomato, not powder
    ("turkey breast", 172941): 171496,   # breast meat, not packaged slices
    ("walnuts", 170593): 170187,         # plain walnuts, not sugar-glazed nuts
    ("wheat", 172686): 169719,           # wheat grain, not bread
    ("whole-wheat-pasta", 168934): 168910,  # whole wheat, not protein-fortified
    ("yogurt", 167722): 171284,          # plain dairy yogurt, not tofu yogurt
}


def encode(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value >= 0


def recover(directory):
    records, inputs = [], []
    for name in ("recipe_nutrition_pending_a.json", "recipe_nutrition_pending_b.json"):
        path = directory / name
        source = read(path)
        inputs.append({"file": name, "sha256": digest(path.read_bytes())})
        for record in source["records"]:
            require(record["status"] in ("verified-calculation", "calculated"), "Uncalculated recovery input")
            require(not record.get("blockedReasons") and not record.get("blockedIngredientIds"), "Blocked recovery input")
            records.append({
                "canonicalId": record["canonicalId"], "servings": record["servings"],
                "ingredients": [{key: item[key] for key in
                    ("itemId", "grams", "recordId", "sourceDescription")}
                    for item in record["formulation"]],
            })
    require(len(records) == 34 and len({r["canonicalId"] for r in records}) == 34, "Expected exactly 34 recovered formulations")
    value = {"schema_version": 1, "source_inputs": inputs,
             "records": sorted(records, key=lambda r: r["canonicalId"])}
    data = encode(value)
    if EVIDENCE.exists():
        require(EVIDENCE.read_bytes() == data, "Refusing to overwrite different recovery evidence")
    else:
        EVIDENCE.write_bytes(data)


def source_state(description):
    text = description.lower()
    if "uncooked" in text or ", raw" in text:
        return "raw"
    if "cooked" in text or "roasted" in text or ", boiled" in text:
        return "cooked"
    if ", dry" in text or ", dried" in text:
        return "dry"
    if "unbaked" in text or "ready-to-bake" in text:
        return "unbaked"
    return "as-sold"


def calculate(ingredients, servings):
    require(finite(servings) and servings > 0, "Invalid servings")
    result = {}
    for nutrient in COLUMNS:
        values = [item["nutrientsPer100g"][nutrient] for item in ingredients]
        if any(value is None for value in values):
            require(nutrient not in CORE, f"Missing core nutrient {nutrient}")
            result[nutrient] = None  # Not zero, and not a subtotal presented as a total.
        else:
            require(all(finite(v) for v in values), f"Invalid {nutrient}")
            result[nutrient] = round(sum(v * i["grams"] / 100 for v, i in zip(values, ingredients)) / servings, 6)
    return result


def reconcile(*, apply=False, backup=None):
    manifest_path = RELEASE / "release-manifest.json"
    manifest = read(manifest_path)
    evidence = read(EVIDENCE)
    patches = {r["canonicalId"]: r for r in evidence["records"]}
    db_path = ROOT / "assets/catalogs/bil_food_core.sqlite"
    connection = sqlite3.connect(db_path.as_uri() + "?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    foods, changes, records, outputs = {}, [], [], {}
    try:
        for descriptor in manifest["shards"]:
            path = ROOT / descriptor["path"]
            before = path.read_bytes()
            require(len(before) == descriptor["size_bytes"] and digest(before) == descriptor["sha256"], f"Source integrity: {path.name}")
            shard = json.loads(before)
            for record in shard["records"]:
                original = copy.deepcopy(record)
                recipe_id = record["canonicalId"]
                patch = patches.get(recipe_id)
                if patch:
                    # Old batches sometimes used a different divisor than the
                    # displayed serving count. Recover only identity/grams and
                    # calculate anew using the current displayed serving count.
                    require(len(patch["ingredients"]) == len(record["ingredients"]), f"Ingredient count drift: {recipe_id}")
                for index, ingredient in enumerate(record["ingredients"]):
                    old_id = ingredient.get("recordId")
                    if patch:
                        bound = patch["ingredients"][index]
                        require(bound["itemId"] == ingredient["itemId"] and bound["grams"] == ingredient["grams"], f"Formulation drift: {recipe_id}:{index}")
                        ingredient["recordId"] = bound["recordId"]
                    source_id = ingredient.get("recordId")
                    require(isinstance(source_id, str) and source_id.startswith("usda:"), f"Missing source: {recipe_id}:{index}")
                    fdc_id = int(source_id.split(":")[1])
                    fdc_id = CORRECTIONS.get((ingredient["itemId"], fdc_id), fdc_id)
                    if fdc_id not in foods:
                        rows = connection.execute("SELECT * FROM foods WHERE fdc_id = ?", (fdc_id,)).fetchall()
                        require(len(rows) == 1, f"Missing/duplicate USDA row: {fdc_id}")
                        foods[fdc_id] = dict(rows[0])
                    food = foods[fdc_id]
                    grams = ingredient["grams"]
                    require(finite(grams) and grams > 0, f"Invalid grams: {recipe_id}:{index}")
                    # The source formulation is weighed in grams, never a volume
                    # silently interpreted as mass. Keep every original amount.
                    ingredient.update({
                        "recordId": f"usda:{fdc_id}", "sourceRefs": [f"usda:{fdc_id}"],
                        "sourceDescription": food["description"],
                        "sourcePreparation": source_state(food["description"]),
                        "quantity": grams, "unit": "g",
                        "nutrientsPer100g": {k: food[v] for k, v in COLUMNS.items()},
                    })
                    if old_id != ingredient["recordId"]:
                        changes.append({"recipe": recipe_id, "item": ingredient["itemId"],
                                        "from": old_id, "to": ingredient["recordId"]})
                per_serving = calculate(record["ingredients"], record["serving"]["count"])
                record["nutrition"] = {
                    "status": "calculated", "reviewedAt": None,
                    "servings": record["serving"]["count"],
                    "sourceRefs": sorted({i["recordId"] for i in record["ingredients"]}),
                    "perServing": per_serving, "calculationRevision": REVISION,
                    "missingNutrients": [k for k, v in per_serving.items() if v is None],
                }
                # Fingerprint identifies recipe concept/imagery. Source revision
                # and file hashes identify this corrected nutritional snapshot.
                for key in set(original) - {"ingredients", "nutrition"}:
                    require(original[key] == record[key], f"Unrelated content drift: {recipe_id}:{key}")
                records.append(record)
            data = encode(shard)
            outputs[path] = data
            descriptor.update(size_bytes=len(data), sha256=digest(data))
    finally:
        connection.close()
    require(len(records) == 1500 and len({r["canonicalId"] for r in records}) == 1500, "Catalog identity drift")
    require(set(patches) <= {r["canonicalId"] for r in records}, "Unused recovery evidence")
    canonical = encode(records)
    manifest.update(canonical_sha256=digest(canonical), canonical_size_bytes=len(canonical))
    provenance_path = RELEASE / "recipe-provenance.json"
    provenance = read(provenance_path)
    provenance["nutrition_claim"].update(
        ingredient_evidence_complete_record_count=1500,
        ingredient_evidence_incomplete_record_count=0,
    )
    provenance["source_reconciliation"] = {
        "revision": REVISION, "recovered_formulation_count": len(patches),
        "formulation_evidence_sha256": digest(EVIDENCE.read_bytes()),
        "food_database_sha256": digest(db_path.read_bytes()),
        "food_snapshot_sha256": digest(encode(foods)),
        "formula": "sum(per100g * grams / 100) / servings",
        "weighing_basis": "Each ingredient's declared sourcePreparation and sourceDescription",
        "missing_optional_policy": "null; never zero or a partial sum",
        "core_nutrients_calculated_record_count": len(records),
        "optional_unknowns": [{"recipe": r["canonicalId"], "nutrients": r["nutrition"]["missingNutrients"]}
                              for r in records if r["nutrition"]["missingNutrients"]],
    }
    outputs[provenance_path] = encode(provenance)
    manifest.update(provenance_size_bytes=len(outputs[provenance_path]), provenance_sha256=digest(outputs[provenance_path]))
    outputs[manifest_path] = encode(manifest)
    changed = {path: data for path, data in outputs.items() if path.read_bytes() != data}
    if apply and changed:
        require(backup is not None, "--apply needs --backup")
        for path in changed:
            saved = backup / path.relative_to(ROOT)
            require(saved.is_file() and saved.read_bytes() == path.read_bytes(), f"Backup must match current asset: {path.name}")
        # All validation/calculation completes before any asset is written.
        for path, data in changed.items():
            path.write_bytes(data)
    report = {"mode": "apply" if apply else "dry-run", "records": len(records),
              "changed_asset_files": len(changed), "rebound_ingredients": len(changes),
              "rebound_recipes": len({c["recipe"] for c in changes}),
              "distinct_source_foods": len(foods),
              "optional_unknowns": provenance["source_reconciliation"]["optional_unknowns"],
              "changes": changes}
    print(json.dumps({**{k: v for k, v in report.items() if k not in ("changes", "optional_unknowns")},
                      "optional_unknown_record_count": len(report["optional_unknowns"]),
                      "optional_unknown_nutrients": sorted({n for r in report["optional_unknowns"] for n in r["nutrients"]})}, indent=2))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recover-from", type=Path)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--backup", type=Path)
    args = parser.parse_args()
    if args.recover_from:
        recover(args.recover_from)
    reconcile(apply=args.apply, backup=args.backup)


if __name__ == "__main__":
    main()
