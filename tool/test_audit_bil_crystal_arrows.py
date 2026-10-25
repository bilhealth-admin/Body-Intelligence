"""Synthetic, read-only regression fixtures for Crystal asset occurrence scanning."""
from __future__ import annotations

import csv
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from tool import audit_bil_crystal_arrows as audit


class DirectionalAssetInventoryTest(unittest.TestCase):
    def test_flutter_and_native_directional_asset_names_and_refs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def write(path: str, payload: bytes) -> None:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(payload)

            write("assets/icons/arrow_back.png", b"\x89PNG\x00\xff\xff")
            write("assets/icons/chevron_left.svg", b'<svg xmlns="http://www.w3.org/2000/svg"/>')
            write("assets/icons/meal_photo.png", b"\x89PNG\x00\xff")
            write("ios/Runner/Assets.xcassets/BackArrow.imageset/arrow_next.png", b"\x89PNG\x00\xff")
            write("android/app/src/main/res/drawable-xhdpi/ic_arrow_right.webp", b"RIFF\xff\x00")
            write(
                "lib/features/test_menu.dart",
                b"final icon = Image.asset('assets/icons/arrow_back.png');\n"
                b"final nav = BackButton();\n",
            )
            write(
                audit.PROTECTED_COMMERCE_PATH,
                b"final preservedArrow = Icon(Icons.arrow_forward_rounded);\n",
            )

            output = root / "inventory.csv"
            with patch.object(sys, "argv", [
                "audit_bil_crystal_arrows.py", "--root", str(root),
                "--output", str(output),
            ]), redirect_stdout(io.StringIO()):
                self.assertEqual(audit.main(), 0)

            with output.open(encoding="utf-8-sig", newline="") as stream:
                rows = list(csv.DictReader(stream))

            files = {row["file"] for row in rows}
            for expected in (
                "assets/icons/arrow_back.png",
                "assets/icons/chevron_left.svg",
                "ios/Runner/Assets.xcassets/BackArrow.imageset/arrow_next.png",
                "android/app/src/main/res/drawable-xhdpi/ic_arrow_right.webp",
            ):
                self.assertIn(expected, files)
                hits = [
                    row for row in rows
                    if row["file"] == expected and row["candidate_types"] == "ASSET_FILENAME"
                ]
                self.assertEqual(len(hits), 1)
                self.assertEqual(hits[0]["line"], "0")
                self.assertEqual(hits[0]["verified_crystal_state"], "UNVERIFIED")
                self.assertEqual(hits[0]["manual_review_required"], "YES")

            self.assertNotIn("assets/icons/meal_photo.png", files)
            dart = [row for row in rows if row["file"] == "lib/features/test_menu.dart"]
            kinds = ";".join(row["candidate_types"] for row in dart)
            self.assertIn("ASSET_REFERENCE", kinds)
            self.assertIn("AUTO_NAV_WIDGET", kinds)
            commerce = [
                row for row in rows if row["file"] == audit.PROTECTED_COMMERCE_PATH
            ]
            self.assertEqual(len(commerce), 1)
            self.assertEqual(commerce[0]["protected_payment_file"], "YES")
            self.assertEqual(commerce[0]["verified_crystal_state"], "UNVERIFIED")


if __name__ == "__main__":
    unittest.main()
