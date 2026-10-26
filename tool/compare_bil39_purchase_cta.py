"""Compare immutable checkout evidence with zero pixel tolerance.

The full frames intentionally also contain a non-payment 'view all features'
chevron. Its new resting crystal was visually reviewed on 25 October 2026.
Only that glyph's 12px surrounding decoration may differ; all other pixels,
including the whole payment CTA, its halo, and all geometry must be identical.
No baseline generation, masking of the CTA, or percentage tolerance is used.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops

NAMES = {f"{state}_{theme}_{direction}" for state in ("rest", "pressed", "cancelled")
         for theme in ("light", "dark") for direction in ("ltr", "rtl")}


def compare_frame(candidate, baseline, geometry, baseline_geometry):
    if geometry != baseline_geometry:
        raise ValueError("Checkout or feature-chevron geometry changed")
    candidate = candidate.convert("RGBA")
    baseline = baseline.convert("RGBA")
    if candidate.size != baseline.size or list(candidate.size) != geometry["capture_size"]:
        raise ValueError("Capture size changed")
    width, height = candidate.size
    left, top, right, bottom = geometry["cta_bounds"]
    if not (0 <= left < right <= width and 0 <= top < bottom <= height):
        raise ValueError("Invalid checkout bounds")
    halo = (max(0, int(left) - 20), max(0, int(top) - 20),
            min(width, int(right) + 20), min(height, int(bottom) + 20))
    arrow = geometry["feature_arrow_bounds"]
    if len(arrow) != 4 or not (0 < arrow[2] - arrow[0] <= 24 and 0 < arrow[3] - arrow[1] <= 24):
        raise ValueError("Invalid separate feature-chevron bounds")
    allowed = (max(0, int(arrow[0]) - 12), max(0, int(arrow[1]) - 12),
               min(width, int(arrow[2] + .999) + 12), min(height, int(arrow[3] + .999) + 12))
    if max(halo[0], allowed[0]) < min(halo[2], allowed[2]) and max(halo[1], allowed[1]) < min(halo[3], allowed[3]):
        raise ValueError("Feature-chevron exception overlaps checkout protection")
    diff = ImageChops.difference(candidate, baseline)
    # Compare every RGBA channel, including alpha. RGB conversion alone would
    # accidentally omit an alpha-only mutation.
    def changed(image):
        return any(channel.getbbox() is not None for channel in image.split())
    if changed(diff.crop(halo)):
        raise ValueError("Protected checkout or surrounding halo pixels changed")
    remainder = diff.copy()
    remainder.paste((0, 0, 0, 0), allowed)
    if changed(remainder):
        raise ValueError("Unreviewed full-page pixels changed outside feature chevron")
    return {"checkout_and_halo_pixels": "EXACT", "geometry": "EXACT",
            "separate_feature_chevron_decoration_bounds": list(allowed)}


def compare_directories(candidate: Path, baseline: Path):
    for folder in (candidate, baseline):
        if {file.stem for file in folder.glob('*.png')} != NAMES:
            raise ValueError(f"Expected exactly twelve named frames: {folder}")
    rows = []
    for name in sorted(NAMES):
        paths = [folder / f"{name}.png" for folder in (candidate, baseline)]
        geometry = [json.loads(file.with_suffix('.geometry.json').read_text()) for file in paths]
        with Image.open(paths[0]) as current, Image.open(paths[1]) as original:
            result = compare_frame(current, original, *geometry)
        rows.append({"frame": name, **result,
                     "candidate_sha256": hashlib.sha256(paths[0].read_bytes()).hexdigest(),
                     "baseline_sha256": hashlib.sha256(paths[1].read_bytes()).hexdigest()})
    return {"status": "PASS", "frames": rows, "pixel_error_tolerance": 0,
            "scope": "Synthetic widget render; not a native StoreKit purchase"}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    receipt = compare_directories(args.candidate, args.baseline)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2) + '\n')
    print('PASS: twelve exact checkout surfaces, halos and geometry; only reviewed separate chevron decoration differs')
