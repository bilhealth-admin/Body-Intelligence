#!/usr/bin/env python3
"""Focused checks for the Android launch-frame blank-screen guard."""

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_android_startup_frame import (
    frame_is_blank,
    has_interactive_app_content,
    inspect_frame,
    startup_is_ready,
)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def _rgb_png(
    width: int,
    height: int,
    marked: bool,
    *,
    mark_height_fraction: float = 1 / 3,
) -> bytes:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            in_mark = (
                marked
                and width // 3 <= x < 2 * width // 3
                and height // 2
                <= y
                < height // 2 + int(height * mark_height_fraction)
            )
            rows.extend(
                (200 + x % 56, 200 + y % 56, 255)
                if in_mark
                else (8, 119, 249)
            )
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(rows))
        + _chunk(b"IEND", b"")
    )


class VerifyAndroidStartupFrameTest(unittest.TestCase):
    def test_solid_launch_color_has_no_proven_flutter_frame(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "blank.png"
            capture.write_bytes(_rgb_png(96, 128, marked=False))
            result = inspect_frame(capture)
        self.assertEqual(result["viewport_unique_rgb_colors"], 1)
        self.assertTrue(frame_is_blank(result))

    def test_visible_app_mark_proves_nonblank_viewport(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "visible.png"
            capture.write_bytes(_rgb_png(96, 128, marked=True))
            result = inspect_frame(capture)
        self.assertGreaterEqual(result["viewport_unique_rgb_colors"], 2)
        self.assertFalse(frame_is_blank(result))

    def test_colorful_splash_without_controls_is_not_ready(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "splash.png"
            tree = Path(directory) / "splash.xml"
            capture.write_bytes(
                _rgb_png(96, 128, marked=True, mark_height_fraction=0.06)
            )
            tree.write_text(
                '<hierarchy><node package="com.bilhealth.bodyintelligencelog" '
                'class="android.view.View" content-desc="BIL" '
                'clickable="false" enabled="true" /></hierarchy>',
                encoding="utf-8",
            )
            result = inspect_frame(capture)
            is_blank = frame_is_blank(result)
            has_content = has_interactive_app_content(tree)
            is_ready = startup_is_ready(result, tree)
        self.assertTrue(is_blank)
        self.assertFalse(has_content)
        self.assertFalse(is_ready)

    def test_enabled_app_button_proves_accessible_content(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "welcome.png"
            tree = Path(directory) / "welcome.xml"
            capture.write_bytes(_rgb_png(96, 128, marked=True))
            tree.write_text(
                '<hierarchy><node package="com.bilhealth.bodyintelligencelog" '
                'class="android.widget.Button" content-desc="Sign in" '
                'clickable="true" enabled="true" /></hierarchy>',
                encoding="utf-8",
            )
            result = inspect_frame(capture)
            self.assertTrue(has_interactive_app_content(tree))
            self.assertTrue(startup_is_ready(result, tree))

    def test_disabled_or_foreign_button_does_not_prove_app_content(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tree = Path(directory) / "not-ready.xml"
            tree.write_text(
                '<hierarchy>'
                '<node package="com.bilhealth.bodyintelligencelog" '
                'class="android.widget.Button" content-desc="Continue" '
                'clickable="true" enabled="false" />'
                '<node package="com.android.launcher" '
                'class="android.widget.Button" content-desc="Open" '
                'clickable="true" enabled="true" />'
                '</hierarchy>',
                encoding="utf-8",
            )
            has_content = has_interactive_app_content(tree)
        self.assertFalse(has_content)


if __name__ == "__main__":
    unittest.main()
