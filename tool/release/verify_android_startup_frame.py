#!/usr/bin/env python3
"""Require a visible Android app frame with accessible interactive content."""

from __future__ import annotations

import struct
import sys
import zlib
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree

APP_PACKAGE = "com.bilhealth.bodyintelligencelog"
MIN_FOREGROUND_PIXEL_SHARE = 0.05


def _paeth(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    diagonal_distance = abs(estimate - up_left)
    if left_distance <= up_distance and left_distance <= diagonal_distance:
        return left
    if up_distance <= diagonal_distance:
        return up
    return up_left


def inspect_frame(path: Path) -> dict[str, int | float]:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("capture is not a PNG image")

    offset = 8
    compressed = bytearray()
    width = height = bit_depth = color_type = interlace = 0
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break

    if width <= 0 or height <= 0 or bit_depth != 8 or color_type not in (2, 6):
        raise ValueError("capture must be a non-empty 8-bit RGB/RGBA PNG")
    if interlace != 0:
        raise ValueError("interlaced PNG captures are unsupported")

    bytes_per_pixel = 3 if color_type == 2 else 4
    stride = width * bytes_per_pixel
    raw = zlib.decompress(compressed)
    previous = bytearray(stride)
    colors: Counter[tuple[int, int, int]] = Counter()
    sample_count = 0
    # Ignore Android's status/navigation bars; evaluate only the actual app
    # viewport so system icons cannot make an empty launch window look valid.
    x_start, x_end = width // 10, width - width // 10
    y_start, y_end = height * 15 // 100, height * 85 // 100
    position = 0
    for y in range(height):
        filter_type = raw[position]
        position += 1
        scanline = bytearray(raw[position : position + stride])
        position += stride
        if filter_type > 4:
            raise ValueError(f"unsupported PNG filter {filter_type}")
        for index in range(stride):
            left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            up = previous[index]
            up_left = (
                previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            )
            if filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = up
            elif filter_type == 3:
                predictor = (left + up) // 2
            elif filter_type == 4:
                predictor = _paeth(left, up, up_left)
            else:
                predictor = 0
            scanline[index] = (scanline[index] + predictor) & 0xFF

        if y_start <= y < y_end and y % 4 == 0:
            for x in range(x_start + (x_start % 4), x_end, 4):
                pixel = x * bytes_per_pixel
                colors[tuple(scanline[pixel : pixel + 3])] += 1
                sample_count += 1
        previous = scanline

    if not colors or sample_count == 0:
        raise ValueError("capture contains no app viewport pixels")
    dominant_share = max(colors.values()) / sample_count
    return {
        "width": width,
        "height": height,
        "viewport_unique_rgb_colors": len(colors),
        "viewport_dominant_color_share": dominant_share,
        "viewport_foreground_pixel_share": 1.0 - dominant_share,
    }


def frame_is_blank(result: dict[str, int | float]) -> bool:
    return (
        result["viewport_unique_rgb_colors"] < 6
        or result["viewport_foreground_pixel_share"] < MIN_FOREGROUND_PIXEL_SHARE
    )


def has_interactive_app_content(path: Path) -> bool:
    """Reject Android splash/transition trees without an app control."""
    try:
        root = ElementTree.parse(path).getroot()
    except (OSError, ElementTree.ParseError):
        return False

    for node in root.iter("node"):
        if node.get("package") != APP_PACKAGE:
            continue
        if node.get("class") != "android.widget.Button":
            continue
        if node.get("enabled") != "true" or node.get("clickable") != "true":
            continue
        if node.get("content-desc", "").strip() or node.get("text", "").strip():
            return True
    return False


def startup_is_ready(
    frame_result: dict[str, int | float], accessibility_tree: Path
) -> bool:
    return not frame_is_blank(frame_result) and has_interactive_app_content(
        accessibility_tree
    )


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: verify_android_startup_frame.py <screenshot.png> <accessibility-tree.xml>",
            file=sys.stderr,
        )
        return 2
    try:
        result = inspect_frame(Path(sys.argv[1]))
    except (OSError, ValueError, zlib.error) as error:
        print(f"invalid startup capture: {error}", file=sys.stderr)
        return 2
    for name, value in result.items():
        print(f"{name}={value}")
    if frame_is_blank(result):
        print(
            "Android app viewport has too little foreground detail to prove "
            "the startup screen is visible.",
            file=sys.stderr,
        )
        return 1
    if not has_interactive_app_content(Path(sys.argv[2])):
        print(
            "Android accessibility tree has no enabled, clickable app button; "
            "the capture may still be the native splash or transition frame.",
            file=sys.stderr,
        )
        return 1
    print("accessible_interactive_app_content=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
