from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

SUPPORTED_ACCESS = {"free", "plus", "pro", "coach", "clinic", "enterprise"}
REQUIRED_USDA_TABLES = {"foods", "food_fts", "portions", "search_alias"}
REQUIRED_MOBILE_TABLES = {
    "food",
    "food_fts",
    "alias",
    "nutrient",
    "portion",
    "barcode",
}


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest()


def validate_sqlite(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(path)
    with closing(
        sqlite3.connect(f"file:{path.resolve()}?mode=ro", uri=True)
    ) as database:
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise ValueError(f"SQLite integrity failed for {path}: {integrity}")
        tables = {
            row[0]
            for row in database.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
            )
        }
    if REQUIRED_USDA_TABLES.issubset(tables):
        return "usda-core-v1"
    if REQUIRED_MOBILE_TABLES.issubset(tables):
        return "bil-mobile-catalog-v1"
    raise ValueError(f"Unsupported catalog schema: {path}")


def load_config(path: Path) -> dict[str, object]:
    # Windows PowerShell 5.1 writes UTF-8 files with a BOM. ``utf-8-sig``
    # accepts that output while remaining fully compatible with BOM-less UTF-8.
    decoded = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(decoded, dict) or not isinstance(decoded.get("packs"), list):
        raise ValueError("Config must contain a packs array")
    return decoded


def publish(config_path: Path, output_path: Path) -> dict[str, object]:
    config = load_config(config_path)
    base_url = str(config.get("base_url", "")).rstrip("/")
    if not base_url.startswith("https://"):
        raise ValueError("base_url must use HTTPS")

    packs: list[dict[str, object]] = []
    seen_ids: set[str] = set()
    for raw in config["packs"]:
        if not isinstance(raw, dict):
            raise ValueError("Every pack must be an object")
        pack_id = str(raw["id"]).strip()
        version = str(raw["version"]).strip()
        title = str(raw["title"]).strip()
        access = str(raw.get("access", "pro")).strip().lower()
        source = (config_path.parent / str(raw["file"])).resolve()
        compression = raw.get("compression")
        database_source = (
            config_path.parent / str(raw.get("database_file") or raw["file"])
        ).resolve()
        if not pack_id or not version or not title:
            raise ValueError("Pack id, version, and title cannot be blank")
        if pack_id in seen_ids:
            raise ValueError(f"Duplicate pack id: {pack_id}")
        if access not in SUPPORTED_ACCESS:
            raise ValueError(f"Unsupported access level: {access}")
        seen_ids.add(pack_id)
        schema = validate_sqlite(database_source)
        remote_name = str(raw.get("remote_name") or source.name)
        pack = {
            "id": pack_id,
            "version": version,
            "title": title,
            "download_url": f"{base_url}/{quote(remote_name)}",
            "sha256": sha256_file(source),
            "size_bytes": source.stat().st_size,
            "access": access,
            "locale_codes": list(raw.get("locale_codes", [])),
            "country_codes": list(raw.get("country_codes", [])),
            "schema": schema,
        }
        if compression is not None:
            if compression != "gzip":
                raise ValueError(f"Unsupported compression: {compression}")
            pack.update(
                {
                    "compression": compression,
                    "installed_size_bytes": database_source.stat().st_size,
                    "database_sha256": sha256_file(database_source),
                }
            )
        packs.append(pack)

    manifest = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "packs": packs,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = output_path.with_suffix(output_path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(output_path)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate BIL SQLite catalogs and emit a hash-verified download manifest."
    )
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    manifest = publish(args.config, args.output)
    print(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
