from __future__ import annotations

import json
import gzip
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

try:
    from .catalog_pack_publisher import publish
except ImportError:
    from catalog_pack_publisher import publish


class CatalogPackPublisherTest(unittest.TestCase):
    def test_publishes_verified_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / "catalog.sqlite"
            with closing(sqlite3.connect(catalog)) as database:
                for table in ("food", "alias", "nutrient", "portion", "barcode"):
                    database.execute(f"CREATE TABLE {table}(id TEXT)")
                database.execute("CREATE VIRTUAL TABLE food_fts USING fts5(value)")
                database.commit()
            config = root / "packs.json"
            config.write_text(
                json.dumps(
                    {
                        "base_url": "https://downloads.example.test/catalogs",
                        "packs": [
                            {
                                "id": "regional",
                                "version": "1",
                                "title": "Regional",
                                "file": "catalog.sqlite",
                                "access": "pro",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            manifest = publish(config, root / "manifest.json")
            pack = manifest["packs"][0]
            self.assertEqual(pack["id"], "regional")
            self.assertEqual(pack["schema"], "bil-mobile-catalog-v1")
            self.assertEqual(len(pack["sha256"]), 64)
            self.assertEqual(pack["size_bytes"], catalog.stat().st_size)

    def test_rejects_non_https_download_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "packs.json"
            config.write_text(
                json.dumps({"base_url": "http://unsafe.test", "packs": []}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "HTTPS"):
                publish(config, root / "manifest.json")

    def test_accepts_utf8_bom_from_windows_powershell(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "packs.json"
            config.write_text(
                json.dumps(
                    {
                        "base_url": "https://downloads.example.test/catalogs",
                        "packs": [],
                    }
                ),
                encoding="utf-8-sig",
            )

            manifest = publish(config, root / "manifest.json")

            self.assertEqual(manifest["packs"], [])

    def test_publishes_compressed_catalog_with_both_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / "catalog.sqlite"
            with closing(sqlite3.connect(catalog)) as database:
                for table in ("food", "alias", "nutrient", "portion", "barcode"):
                    database.execute(f"CREATE TABLE {table}(id TEXT)")
                database.execute("CREATE VIRTUAL TABLE food_fts USING fts5(value)")
                database.commit()
            archive = root / "catalog.sqlite.gz"
            with catalog.open("rb") as source, gzip.open(archive, "wb") as target:
                target.write(source.read())
            config = root / "packs.json"
            config.write_text(
                json.dumps(
                    {
                        "base_url": "https://downloads.example.test/catalogs",
                        "packs": [
                            {
                                "id": "compressed",
                                "version": "1",
                                "title": "Compressed",
                                "file": archive.name,
                                "database_file": catalog.name,
                                "remote_name": archive.name,
                                "compression": "gzip",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )

            manifest = publish(config, root / "manifest.json")
            pack = manifest["packs"][0]

            self.assertEqual(pack["compression"], "gzip")
            self.assertEqual(pack["size_bytes"], archive.stat().st_size)
            self.assertEqual(pack["installed_size_bytes"], catalog.stat().st_size)
            self.assertEqual(len(pack["database_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
