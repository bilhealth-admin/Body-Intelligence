"""Validate manifests for licensed BIL recipe and workout packs."""

import argparse
import hashlib
import json
from pathlib import Path

TYPES = {"recipes", "workouts", "sleep", "fasting"}
ACCESS = {"free", "plus", "pro", "coach", "clinic", "enterprise"}
LOCALES = {"ar", "en", "fr", "es", "tr", "all"}


def text(value, field):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Missing text field: {field}")
    return value.strip()


def https(value, field):
    value = text(value, field)
    if not value.startswith("https://"):
        raise ValueError(f"{field} must use HTTPS")
    return value


def validate_payload(path):
    data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if data.get("schema_version") != 1 or data.get("type") not in TYPES:
        raise ValueError("Unsupported pack schema or type")
    if not isinstance(data.get("version"), int) or data["version"] < 1:
        raise ValueError("version must be a positive integer")
    text(data.get("pack_id"), "pack_id")
    items = data.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError("items must be a non-empty list")
    seen = set()
    for index, item in enumerate(items):
        item_id = text(item.get("id"), f"items[{index}].id")
        if item_id in seen:
            raise ValueError(f"Duplicate item id: {item_id}")
        seen.add(item_id)
        text(item.get("title"), f"items[{index}].title")
        if item.get("locale", "en") not in LOCALES:
            raise ValueError(f"Unsupported locale in item {item_id}")
        text(item.get("rights_holder"), f"items[{index}].rights_holder")
        text(item.get("license"), f"items[{index}].license")
        https(item.get("image_url"), f"items[{index}].image_url")
        if data["type"] == "workouts":
            https(item.get("video_url"), f"items[{index}].video_url")
            if not isinstance(item.get("duration_minutes"), int):
                raise ValueError(f"items[{index}].duration_minutes required")
        if data["type"] == "recipes" and not item.get("ingredients"):
            raise ValueError(f"items[{index}].ingredients required")
    return data


def publish(config_path, output_path):
    config = json.loads(Path(config_path).read_text(encoding="utf-8-sig"))
    base_url = https(config.get("base_url"), "base_url").rstrip("/")
    packs = []
    for entry in config.get("packs", []):
        source = Path(text(entry.get("file"), "file"))
        payload = validate_payload(source)
        access = entry.get("minimum_access", "free")
        if access not in ACCESS:
            raise ValueError(f"Unsupported access: {access}")
        raw = source.read_bytes()
        remote_name = entry.get("remote_name", source.name)
        packs.append({
            "id": payload["pack_id"], "version": payload["version"],
            "type": payload["type"], "title": text(entry.get("title"), "title"),
            "description": str(entry.get("description", "")),
            "locale": entry.get("locale", "en"),
            "download_url": f"{base_url}/{remote_name}",
            "size_bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "item_count": len(payload["items"]), "minimum_access": access,
        })
    if not packs:
        raise ValueError("packs must be a non-empty list")
    manifest = {"schema_version": 1, "packs": packs}
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    print(json.dumps(publish(args.config, args.output), ensure_ascii=False, indent=2))
