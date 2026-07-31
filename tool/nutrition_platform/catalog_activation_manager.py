from __future__ import annotations

import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
from contextlib import closing
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class CatalogActivationError(RuntimeError):
    pass


@dataclass(frozen=True)
class CatalogManifest:
    catalog_id: str
    version: str
    schema_version: int
    sha256: str
    size_bytes: int
    created_at_utc: str

    @classmethod
    def from_path(cls, catalog_path: Path, *, catalog_id: str, version: str, schema_version: int) -> "CatalogManifest":
        return cls(
            catalog_id=catalog_id,
            version=version,
            schema_version=schema_version,
            sha256=_sha256_file(catalog_path),
            size_bytes=catalog_path.stat().st_size,
            created_at_utc=datetime.now(timezone.utc).isoformat(),
        )


class CatalogActivationManager:
    def __init__(self, root: str | Path, *, supported_schema_version: int = 1) -> None:
        self.root = Path(root)
        self.supported_schema_version = supported_schema_version
        self.catalogs_dir = self.root / "catalogs"
        self.registry_path = self.root / "catalog_registry.json"
        self.catalogs_dir.mkdir(parents=True, exist_ok=True)

    def activate(self, source_catalog: str | Path, manifest: CatalogManifest) -> Path:
        source = Path(source_catalog)
        self._validate_source(source, manifest)

        version_dir = self.catalogs_dir / manifest.catalog_id / manifest.version
        version_dir.mkdir(parents=True, exist_ok=True)
        final_catalog = version_dir / "catalog.sqlite"
        final_manifest = version_dir / "manifest.json"
        if final_catalog.exists():
            existing_hash = _sha256_file(final_catalog)
            if existing_hash != manifest.sha256:
                raise CatalogActivationError("Catalog version is immutable; an existing version has a different SHA-256")

        with tempfile.NamedTemporaryFile(delete=False, dir=version_dir, suffix=".tmp") as tmp:
            temp_catalog = Path(tmp.name)
        try:
            shutil.copyfile(source, temp_catalog)
            if _sha256_file(temp_catalog) != manifest.sha256:
                raise CatalogActivationError("Copied catalog hash mismatch")
            os.replace(temp_catalog, final_catalog)
        finally:
            temp_catalog.unlink(missing_ok=True)

        self._atomic_write_json(final_manifest, asdict(manifest))

        registry = self._load_registry()
        previous = registry.get("active")
        history = list(registry.get("history", []))
        if previous:
            history.append(previous)
        registry = {
            "active": self._registry_entry(manifest, final_catalog),
            "history": history,
            "updated_at_utc": datetime.now(timezone.utc).isoformat(),
        }
        self._atomic_write_json(self.registry_path, registry)
        return final_catalog.resolve()

    def rollback(self) -> Path:
        registry = self._load_registry()
        history = list(registry.get("history", []))
        if not history:
            raise CatalogActivationError("No previous catalog available for rollback")
        target = history.pop()
        target_path = Path(target["path"])
        if not target_path.is_file():
            raise CatalogActivationError("Rollback catalog file is missing")
        self._validate_registry_entry(target)
        current = registry.get("active")
        if current:
            history.append(current)
        new_registry = {
            "active": target,
            "history": history,
            "updated_at_utc": datetime.now(timezone.utc).isoformat(),
        }
        self._atomic_write_json(self.registry_path, new_registry)
        return target_path

    def active_catalog(self) -> Path | None:
        registry = self._load_registry()
        active = registry.get("active")
        if not active:
            return None
        self._validate_registry_entry(active)
        return Path(active["path"])

    def active_manifest(self) -> dict[str, Any] | None:
        registry = self._load_registry()
        active = registry.get("active")
        return dict(active) if active else None

    def _validate_source(self, source: Path, manifest: CatalogManifest) -> None:
        if not source.is_file():
            raise CatalogActivationError(f"Catalog not found: {source}")
        if manifest.schema_version != self.supported_schema_version:
            raise CatalogActivationError(
                f"Unsupported schema version {manifest.schema_version}; expected {self.supported_schema_version}"
            )
        if source.stat().st_size != manifest.size_bytes:
            raise CatalogActivationError("Catalog size mismatch")
        if _sha256_file(source) != manifest.sha256:
            raise CatalogActivationError("Catalog SHA-256 mismatch")
        _validate_sqlite(source)

    def _validate_registry_entry(self, entry: dict[str, Any]) -> None:
        path = Path(entry["path"])
        if not path.is_file():
            raise CatalogActivationError("Registered catalog is missing")
        if _sha256_file(path) != entry["sha256"]:
            raise CatalogActivationError("Registered catalog hash mismatch")
        _validate_sqlite(path)

    def _registry_entry(self, manifest: CatalogManifest, path: Path) -> dict[str, Any]:
        return {**asdict(manifest), "path": str(path.resolve())}

    def _load_registry(self) -> dict[str, Any]:
        if not self.registry_path.exists():
            return {"active": None, "history": []}
        try:
            return json.loads(self.registry_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise CatalogActivationError("Catalog registry is unreadable") from exc

    @staticmethod
    def _atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, temp_name = tempfile.mkstemp(prefix=path.name, suffix=".tmp", dir=path.parent)
        temp_path = Path(temp_name)
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
                json.dump(payload, handle, ensure_ascii=False, sort_keys=True, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temp_path, path)
        finally:
            temp_path.unlink(missing_ok=True)


def _sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _validate_sqlite(path: Path) -> None:
    try:
        with closing(sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)) as connection:
            result = connection.execute("PRAGMA integrity_check").fetchone()
            if result is None or result[0] != "ok":
                raise CatalogActivationError("SQLite integrity_check failed")
            tables = {
                row[0]
                for row in connection.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'"
                ).fetchall()
            }
            required = {"catalog_metadata", "food", "alias", "nutrient", "portion", "barcode"}
            missing = sorted(required - tables)
            if missing:
                raise CatalogActivationError(f"Required catalog tables missing: {', '.join(missing)}")
    except sqlite3.Error as exc:
        raise CatalogActivationError("Catalog is not a valid SQLite database") from exc
