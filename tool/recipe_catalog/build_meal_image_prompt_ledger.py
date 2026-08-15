"""Append the 82 canonical image prompts without changing existing row values."""
import csv
import hashlib
import io
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "artifacts" / "meal_catalog" / "recipe_canonical_100_verified.json"
LEDGER = ROOT / "artifacts" / "meal_catalog" / "meal_image_prompt_ledger.csv"
NEW_FIELDS = ("filename", "prompt_sha256")


def main():
    original = LEDGER.read_text(encoding="utf-8-sig")
    old_reader = csv.DictReader(io.StringIO(original))
    old_fields = tuple(old_reader.fieldnames or ())
    old_rows = list(old_reader)
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["records"]
    records = [record for record in catalog if record["image"]["status"] in ("planned", "pending")]
    if len(records) != 82:
        raise SystemExit(f"REJECTED expected 82 image-pending records, found {len(records)}")
    if any(row.get("canonical_id") in {r["canonicalId"] for r in records} for row in old_rows):
        raise SystemExit("REJECTED ledger already contains one of the 82 canonical IDs")
    appended = []
    for record in records:
        locale = record["primaryLocale"]
        localized = record["localizations"][locale]
        ingredients = ", ".join(
            f"{ingredient['quantity']:g} {ingredient['unit']} {ingredient['itemId']}"
            for ingredient in record["ingredients"]
        )
        serving = record["serving"]
        method = " ".join(localized["steps"])
        prompt = (
            f"Square premium editorial food photograph of {localized['title']}, an authentic {record['region']} dish. "
            f"Show one plausible {serving['size']:g} {serving['unit']} portion from a {serving['count']:g}-serving recipe, "
            f"faithfully reflecting these measured ingredients: {ingredients}. "
            f"The visible preparation and plating must agree with this method: {method} "
            "Authentic regional tableware and restrained culturally appropriate styling; appetizing natural texture; "
            "soft directional daylight; refined contemporary editorial composition; true-to-life color; 1:1 square crop. "
            "No text, letters, numbers, label, logo, trademark, watermark, packaging, people, hands, faces, "
            "impossible garnish, duplicated food, or unrelated ingredients."
        )
        digest = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
        appended.append({
            "prompt_id": record["image"]["promptId"], "canonical_id": record["canonicalId"],
            "status": "planned", "use_case": "premium-editorial-regional-recipe", "aspect_ratio": "1:1",
            "prompt_template": prompt,
            "review_requirements": "Human verifies dish identity, measured ingredient visibility, portion plausibility, cultural fit, no people/brand/text/artifacts, then records final asset SHA-256.",
            "filename": f"{record['canonicalId']}.png", "prompt_sha256": digest,
        })
    for label, values in (
        ("canonical_id", [row["canonical_id"] for row in appended]),
        ("prompt_id", [row["prompt_id"] for row in appended]),
        ("filename", [row["filename"] for row in appended]),
        ("prompt_sha256", [row["prompt_sha256"] for row in appended]),
    ):
        if any(not value for value in values) or len(values) != len(set(values)):
            raise SystemExit(f"REJECTED duplicate or empty {label}")
    fields = [*old_fields, *(field for field in NEW_FIELDS if field not in old_fields)]
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows([{field: row.get(field, "") for field in fields} for row in old_rows])
    writer.writerows([{field: row.get(field, "") for field in fields} for row in appended])
    LEDGER.write_text(output.getvalue(), encoding="utf-8")
    # Prove every pre-existing field value survived unchanged.
    reread = list(csv.DictReader(io.StringIO(LEDGER.read_text(encoding="utf-8"))))
    for before, after in zip(old_rows, reread):
        if any(before.get(field, "") != after.get(field, "") for field in old_fields):
            raise SystemExit("REJECTED existing ledger row changed")
    print(f"PASS appended=82 unique_ids=82 unique_prompts=82 total_rows={len(reread)}")


if __name__ == "__main__":
    main()
