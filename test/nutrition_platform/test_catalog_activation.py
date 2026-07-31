from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from tool.nutrition_platform.catalog_activation_manager import (
    CatalogActivationError,
    CatalogActivationManager,
    CatalogManifest,
)


class CatalogActivationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _catalog(self, name: str, *, marker: str = "one") -> Path:
        path = self.root / name
        with closing(sqlite3.connect(path)) as conn:
            conn.execute("CREATE TABLE catalog_metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            conn.execute("CREATE TABLE food(bil_food_id TEXT PRIMARY KEY, name_en TEXT)")
            conn.execute("CREATE TABLE alias(alias_id INTEGER PRIMARY KEY, bil_food_id TEXT, name TEXT)")
            conn.execute("CREATE TABLE nutrient(bil_food_id TEXT, bil_nutrient_id TEXT, amount REAL)")
            conn.execute("CREATE TABLE portion(portion_id INTEGER PRIMARY KEY, bil_food_id TEXT)")
            conn.execute("CREATE TABLE barcode(normalized_gtin TEXT, bil_food_id TEXT)")
            conn.execute("INSERT INTO catalog_metadata VALUES('marker', ?)", (marker,))
            conn.execute("INSERT INTO food VALUES('bil:1', 'Apple')")
            conn.commit()
        return path

    def _manifest(self, path: Path, version: str, schema: int = 1) -> CatalogManifest:
        return CatalogManifest.from_path(path, catalog_id="core", version=version, schema_version=schema)

    def test_activation_requires_valid_integrity_and_schema(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime")
        catalog = self._catalog("valid.sqlite")
        active = manager.activate(catalog, self._manifest(catalog, "1.0.0"))
        self.assertTrue(active.is_file())
        self.assertEqual(active, manager.active_catalog())

    def test_corrupted_catalog_is_rejected_without_replacing_active(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime")
        first = self._catalog("first.sqlite")
        manager.activate(first, self._manifest(first, "1.0.0"))
        corrupted = self.root / "broken.sqlite"
        corrupted.write_bytes(b"not sqlite")
        bad_manifest = CatalogManifest.from_path(corrupted, catalog_id="core", version="2.0.0", schema_version=1)
        with self.assertRaises(CatalogActivationError):
            manager.activate(corrupted, bad_manifest)
        self.assertEqual(manager.active_manifest()["version"], "1.0.0")

    def test_schema_mismatch_is_rejected(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime", supported_schema_version=1)
        catalog = self._catalog("schema.sqlite")
        with self.assertRaises(CatalogActivationError):
            manager.activate(catalog, self._manifest(catalog, "1.0.0", schema=2))

    def test_activation_is_atomic_and_registry_is_valid_json(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime")
        catalog = self._catalog("atomic.sqlite")
        manager.activate(catalog, self._manifest(catalog, "1.0.0"))
        registry = json.loads(manager.registry_path.read_text(encoding="utf-8"))
        self.assertEqual(registry["active"]["version"], "1.0.0")
        self.assertFalse(any(manager.root.rglob("*.tmp")))

    def test_rollback_restores_previous_catalog(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime")
        first = self._catalog("first.sqlite", marker="one")
        second = self._catalog("second.sqlite", marker="two")
        manager.activate(first, self._manifest(first, "1.0.0"))
        manager.activate(second, self._manifest(second, "2.0.0"))
        rolled_back = manager.rollback()
        self.assertEqual(manager.active_manifest()["version"], "1.0.0")
        self.assertEqual(rolled_back, manager.active_catalog())

    def test_tampered_active_catalog_is_rejected_on_read(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime")
        catalog = self._catalog("tamper.sqlite")
        active = manager.activate(catalog, self._manifest(catalog, "1.0.0"))
        active.write_bytes(active.read_bytes() + b"tamper")
        with self.assertRaises(CatalogActivationError):
            manager.active_catalog()

    def test_no_history_rollback_fails(self) -> None:
        manager = CatalogActivationManager(self.root / "runtime")
        with self.assertRaises(CatalogActivationError):
            manager.rollback()


if __name__ == "__main__":
    unittest.main()
