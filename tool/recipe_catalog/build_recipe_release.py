#!/usr/bin/env python3
"""Build the deterministic, metadata-only BIL recipe release.

The source catalog and image corpus are read-only inputs. Generated Flutter
assets contain searchable metadata and 30 JSON shards, never recipe pixels or
machine-local paths.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
from pathlib import Path, PurePosixPath

from PIL import Image

COUNT = 1500
SHARD_SIZE = 50
SHARD_COUNT = 30
SHA = re.compile(r"^[0-9a-f]{64}$")
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
MOJIBAKE = ("\u00c3", "\u00c2", "\u00e2\u20ac", "\ufffd")
IMAGE_EXTENSIONS = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}
SUPPORTED_LOCALES = {
    "ar", "en", "fr", "es", "tr", "de", "it", "pt-BR", "pt-PT", "ur",
    "fa", "hi", "id", "ms", "ja", "ko", "zh-Hans", "zh-Hant", "ru",
    "bn", "vi", "th", "pl", "nl", "uk",
}

# Whole localized ingredient/step arrays may match English only after an
# explicit proper-name review. No current recipe needs such an exception.
EXACT_ENGLISH_COPY_ALLOWLIST: set[tuple[str, str, str]] = set()


def _pairs(items):
    value = {}
    for key, item in items:
        if key in value:
            raise ValueError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def load(path: Path):
    return json.loads(
        path.read_text("utf-8"),
        object_pairs_hook=_pairs,
        parse_constant=lambda value: (_ for _ in ()).throw(
            ValueError(f"non-finite JSON value: {value}")
        ),
    )


def canonical(value) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical(value) + b"\n")


def digest_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def digest_file(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
            size += len(block)
    return digest.hexdigest(), size


def artifact(path: Path, root: Path) -> dict:
    sha, size = digest_file(path)
    return {
        "path": path.relative_to(root).as_posix(),
        "size_bytes": size,
        "sha256": sha,
    }


def localized_strings(record: dict):
    for localization in record["localizations"].values():
        yield localization.get("title", "")
        yield from localization.get("ingredients", [])
        yield from localization.get("steps", [])


def has_mojibake(record: dict) -> bool:
    return any(marker in text for text in localized_strings(record) for marker in MOJIBAKE)


def validate_record(record: dict) -> None:
    expected_keys = {
        "canonicalId", "contentFingerprint", "origin", "primaryLocale",
        "region", "countryTags", "mealTypes", "allergens", "dietTags",
        "budgetTier", "serving", "timing", "ingredients", "method",
        "localizations", "nutrition", "image",
    }
    if set(record) != expected_keys:
        raise ValueError("recipe record fields are invalid")
    recipe_id = record.get("canonicalId")
    fingerprint = record.get("contentFingerprint")
    if not isinstance(recipe_id, str) or not SLUG.fullmatch(recipe_id):
        raise ValueError("invalid canonicalId")
    if not isinstance(fingerprint, str) or not SHA.fullmatch(fingerprint):
        raise ValueError(f"invalid fingerprint: {recipe_id}")
    locale = record.get("primaryLocale")
    if locale not in SUPPORTED_LOCALES or locale not in record.get("localizations", {}):
        raise ValueError(f"invalid primary locale: {recipe_id}")
    timing = record.get("timing", {})
    if timing.get("totalMinutes") != timing.get("prepMinutes") + timing.get("cookMinutes"):
        raise ValueError(f"invalid timing: {recipe_id}")
    method = record.get("method")
    if not isinstance(method, list) or [step.get("order") for step in method] != list(range(1, len(method) + 1)):
        raise ValueError(f"invalid method order: {recipe_id}")
    nutrition = record.get("nutrition", {})
    values = nutrition.get("perServing", {})
    if nutrition.get("status") != "calculated" or not nutrition.get("sourceRefs"):
        raise ValueError(f"nutrition is not source-backed calculated data: {recipe_id}")
    if not values or any(isinstance(value, bool) or not isinstance(value, (int, float)) or value < 0 for value in values.values()):
        raise ValueError(f"invalid nutrition values: {recipe_id}")
    if any(marker in text for text in localized_strings(record) for marker in MOJIBAKE):
        raise ValueError(f"residual mojibake: {recipe_id}")
    for code, localization in record["localizations"].items():
        if code not in SUPPORTED_LOCALES or not isinstance(localization, dict):
            raise ValueError(f"invalid localization: {recipe_id}")
        if not isinstance(localization.get("title"), str) or not localization["title"].strip():
            raise ValueError(f"empty localized title: {recipe_id}")
        if not isinstance(localization.get("ingredients"), list) or not all(isinstance(value, str) and value.strip() for value in localization["ingredients"]):
            raise ValueError(f"invalid localized ingredients: {recipe_id}")
        if not isinstance(localization.get("steps"), list) or len(localization["steps"]) != len(method) or not all(isinstance(value, str) and value.strip() for value in localization["steps"]):
            raise ValueError(f"invalid localized steps: {recipe_id}")
        if code != "en":
            english = record["localizations"].get("en")
            if not isinstance(english, dict):
                raise ValueError(f"missing English localization: {recipe_id}")
            for field in ("ingredients", "steps"):
                key = (recipe_id, code, field)
                if (
                    localization[field] == english[field]
                    and key not in EXACT_ENGLISH_COPY_ALLOWLIST
                ):
                    raise ValueError(
                        "exact English localization copy: "
                        f"{recipe_id}/{code}/{field}"
                    )


def ingredient_evidence_complete(record: dict) -> bool:
    for ingredient in record.get("ingredients", []):
        record_id = ingredient.get("recordId")
        refs = ingredient.get("sourceRefs")
        if not isinstance(record_id, str) or not isinstance(refs, list) or record_id not in refs:
            return False
    return True


def image_inventory(root: Path, ids: set[str]) -> tuple[dict[str, dict], list[dict]]:
    candidates: dict[str, list[Path]] = {}
    excluded: list[dict] = []
    files = sorted(
        (path for path in root.iterdir() if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS),
        key=lambda path: path.name.casefold(),
    )
    for path in files:
        normalized = path.stem.casefold().replace("_", "-")
        if normalized in ids:
            candidates.setdefault(normalized, []).append(path)
        else:
            sha, size = digest_file(path)
            excluded.append({"logical_source_id": path.name, "sha256": sha, "size_bytes": size, "reason": "no_canonical_id_match"})
    selected: dict[str, dict] = {}
    for recipe_id, paths in sorted(candidates.items()):
        if len(paths) != 1:
            raise ValueError(f"ambiguous image ownership: {recipe_id}: {[p.name for p in paths]}")
        path = paths[0]
        sha, size = digest_file(path)
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            width, height = image.size
        suffix = path.suffix.lower()
        selected[recipe_id] = {
            "status": "external_candidate",
            "object_path": f"recipes/v1/images/{recipe_id}{suffix}",
            "mime_type": IMAGE_EXTENSIONS[suffix],
            "size_bytes": size,
            "sha256": sha,
            "width": width,
            "height": height,
            "review_status": "review_evidence_unbound",
        }
    return selected, excluded


def verify_release(root: Path) -> None:
    manifest = load(root / "release-manifest.json")
    if manifest.get("schema_version") != 1 or manifest.get("record_count") != COUNT:
        raise ValueError("invalid release manifest header")
    descriptors = manifest.get("shards")
    if not isinstance(descriptors, list) or len(descriptors) != SHARD_COUNT:
        raise ValueError("invalid release shard descriptors")
    expected_ids: list[str] = []
    for ordinal, descriptor in enumerate(descriptors):
        relative = descriptor["path"].removeprefix("assets/catalogs/recipes/v1/")
        path = root / PurePosixPath(relative)
        sha, size = digest_file(path)
        if sha != descriptor["sha256"] or size != descriptor["size_bytes"]:
            raise ValueError(f"shard integrity mismatch: {ordinal}")
        shard = load(path)
        records = shard.get("records")
        if shard.get("schema_version") != 1 or shard.get("shard_index") != ordinal or not isinstance(records, list) or len(records) != SHARD_SIZE:
            raise ValueError(f"invalid shard: {ordinal}")
        shard_ids = [record["canonicalId"] for record in records]
        if descriptor["first_id"] != shard_ids[0] or descriptor["last_id"] != shard_ids[-1]:
            raise ValueError(f"shard boundary mismatch: {ordinal}")
        for record in records:
            validate_record(record)
        expected_ids.extend(shard_ids)
    if len(set(expected_ids)) != COUNT or expected_ids != sorted(expected_ids):
        raise ValueError("release IDs are not unique and ordered")
    index = load(root / "recipe-index.json")
    entries = index.get("entries")
    if not isinstance(entries, list) or [entry["canonical_id"] for entry in entries] != expected_ids:
        raise ValueError("index/shard membership mismatch")
    images = load(root / "recipe-images.json")
    image_entries = images.get("entries")
    if not isinstance(image_entries, list) or [entry["canonical_id"] for entry in image_entries] != expected_ids:
        raise ValueError("image/index membership mismatch")
    for key, filename in (
        ("index", "recipe-index.json"),
        ("image_manifest", "recipe-images.json"),
        ("provenance", "recipe-provenance.json"),
    ):
        sha, size = digest_file(root / filename)
        if sha != manifest[f"{key}_sha256"] or size != manifest[f"{key}_size_bytes"]:
            raise ValueError(f"{key} integrity mismatch")


def build(canonical_path: Path, clean_path: Path, image_root: Path, output: Path) -> None:
    source = load(canonical_path)
    clean = load(clean_path)
    records = source.get("records")
    clean_records = {record["canonicalId"]: record for record in clean.get("records", [])}
    if not isinstance(records, list) or len(records) != COUNT or len(clean_records) != 100:
        raise ValueError("unexpected source catalog counts")
    repaired = []
    repair_evidence = []
    for original in records:
        record = json.loads(json.dumps(original, ensure_ascii=False))
        if has_mojibake(record):
            clean_record = clean_records.get(record["canonicalId"])
            if clean_record is None or clean_record["contentFingerprint"] != record["contentFingerprint"]:
                raise ValueError(f"no fingerprint-bound clean source: {record['canonicalId']}")
            before = digest_bytes(canonical(record["localizations"]))
            record["localizations"] = clean_record["localizations"]
            repair_evidence.append({
                "canonical_id": record["canonicalId"],
                "content_fingerprint": record["contentFingerprint"],
                "before_localizations_sha256": before,
                "after_localizations_sha256": digest_bytes(canonical(record["localizations"])),
            })
        validate_record(record)
        repaired.append(record)
    repaired.sort(key=lambda record: record["canonicalId"])
    ids = [record["canonicalId"] for record in repaired]
    if len(set(ids)) != COUNT:
        raise ValueError("recipe IDs are not unique")
    images, excluded = image_inventory(image_root, set(ids))

    parent = output.parent.resolve()
    parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".recipe-release-", dir=parent))
    try:
        shard_descriptors = []
        index_entries = []
        for shard_index in range(SHARD_COUNT):
            shard_records = repaired[shard_index * SHARD_SIZE:(shard_index + 1) * SHARD_SIZE]
            shard_path = stage / "shards" / f"recipes-{shard_index:02d}.json"
            write_json(shard_path, {"schema_version": 1, "shard_index": shard_index, "records": shard_records})
            descriptor = artifact(shard_path, stage)
            descriptor.update({"ordinal": shard_index, "first_id": shard_records[0]["canonicalId"], "last_id": shard_records[-1]["canonicalId"], "count": SHARD_SIZE})
            shard_descriptors.append(descriptor)
            for ordinal, record in enumerate(shard_records):
                locale = record["primaryLocale"]
                localization = record["localizations"].get(locale) or next(iter(record["localizations"].values()))
                index_entries.append({
                    "canonical_id": record["canonicalId"],
                    "content_fingerprint": record["contentFingerprint"],
                    "shard": shard_index,
                    "ordinal": ordinal,
                    "primary_locale": locale,
                    "title": localization["title"],
                    "localized_titles": {
                        code: value["title"]
                        for code, value in sorted(record["localizations"].items())
                    },
                    "total_minutes": record["timing"]["totalMinutes"],
                    "meal_types": record["mealTypes"],
                    "diet_tags": record["dietTags"],
                    "allergens": record["allergens"],
                    "image_status": "external_candidate" if record["canonicalId"] in images else "placeholder",
                    "region": record["region"],
                    "cuisine_key": (
                        "turkey" if record["primaryLocale"] == "tr" and record["region"] != "global"
                        else record["countryTags"][0]
                    ),
                })
        index_path = stage / "recipe-index.json"
        write_json(index_path, {"schema_version": 1, "record_count": COUNT, "entries": index_entries})
        image_path = stage / "recipe-images.json"
        write_json(image_path, {
            "schema_version": 1,
            "record_count": COUNT,
            "external_candidate_count": len(images),
            "placeholder_count": COUNT - len(images),
            "entries": [
                {"canonical_id": recipe_id, **(images.get(recipe_id) or {"status": "placeholder", "seed": digest_bytes(recipe_id.encode())[:16]})}
                for recipe_id in ids
            ],
            "excluded_source_files": excluded,
        })
        provenance_path = stage / "recipe-provenance.json"
        canonical_sha, canonical_size = digest_file(canonical_path)
        clean_sha, clean_size = digest_file(clean_path)
        localization_mismatches = [
            {
                "canonical_id": record["canonicalId"],
                "locale": locale,
                "canonical_ingredient_count": len(record["ingredients"]),
                "localized_ingredient_count": len(localization["ingredients"]),
            }
            for record in repaired
            for locale, localization in record["localizations"].items()
            if len(localization["ingredients"]) != len(record["ingredients"])
        ]
        complete_ingredient_evidence = sum(
            ingredient_evidence_complete(record) for record in repaired
        )
        write_json(provenance_path, {
            "schema_version": 1,
            "source_inputs": [
                {"logical_name": "recipe_canonical_1500", "sha256": canonical_sha, "size_bytes": canonical_size},
                {"logical_name": "recipe_canonical_100_clean_localizations", "sha256": clean_sha, "size_bytes": clean_size},
            ],
            "localization_repairs": repair_evidence,
            "localization_ingredient_count_mismatches": localization_mismatches,
            "nutrition_claim": {
                "calculated_value_record_count": COUNT,
                "recipe_level_source_reference_count": COUNT,
                "ingredient_evidence_complete_record_count": complete_ingredient_evidence,
                "ingredient_evidence_incomplete_record_count": COUNT - complete_ingredient_evidence,
                "external_review_assertion": "owner_asserted_unbound",
                "professional_attestation_artifact": None,
            },
            "image_claim": {"external_candidates": len(images), "externally_available": 0},
        })
        manifest = {
            "schema_version": 1,
            "record_count": COUNT,
            "shard_size": SHARD_SIZE,
            "canonical_sha256": digest_bytes(canonical(repaired)),
            "canonical_size_bytes": len(canonical(repaired)),
            "index_path": "assets/catalogs/recipes/v1/recipe-index.json",
            "index_size_bytes": artifact(index_path, stage)["size_bytes"],
            "index_sha256": artifact(index_path, stage)["sha256"],
            "image_manifest_path": "assets/catalogs/recipes/v1/recipe-images.json",
            "image_manifest_size_bytes": artifact(image_path, stage)["size_bytes"],
            "image_manifest_sha256": artifact(image_path, stage)["sha256"],
            "provenance_path": "assets/catalogs/recipes/v1/recipe-provenance.json",
            "provenance_size_bytes": artifact(provenance_path, stage)["size_bytes"],
            "provenance_sha256": artifact(provenance_path, stage)["sha256"],
            "shards": [
                {**descriptor, "path": f"assets/catalogs/recipes/v1/{descriptor['path']}"}
                for descriptor in shard_descriptors
            ],
        }
        write_json(stage / "release-manifest.json", manifest)
        expected = {"release-manifest.json", "recipe-index.json", "recipe-images.json", "recipe-provenance.json"} | {f"shards/recipes-{i:02d}.json" for i in range(SHARD_COUNT)}
        actual = {path.relative_to(stage).as_posix() for path in stage.rglob("*") if path.is_file()}
        if actual != expected:
            raise ValueError("release file closure is invalid")
        verify_release(stage)
        backup = output.with_name(output.name + ".previous")
        if backup.exists():
            shutil.rmtree(backup)
        moved_previous = False
        if output.exists():
            os.replace(output, backup)
            moved_previous = True
        try:
            os.replace(stage, output)
        except BaseException:
            if moved_previous and backup.exists() and not output.exists():
                os.replace(backup, output)
            raise
        if backup.exists():
            shutil.rmtree(backup)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--canonical", type=Path, default=Path("artifacts/meal_catalog/recipe_canonical_1500.json"))
    parser.add_argument("--clean", type=Path, default=Path("artifacts/meal_catalog/recipe_canonical_100.json"))
    parser.add_argument("--image-root", type=Path, default=Path("assets/images/professional/recipes"))
    parser.add_argument("--output", type=Path, default=Path("assets/catalogs/recipes/v1"))
    args = parser.parse_args()
    build(args.canonical, args.clean, args.image_root, args.output)


if __name__ == "__main__":
    main()
