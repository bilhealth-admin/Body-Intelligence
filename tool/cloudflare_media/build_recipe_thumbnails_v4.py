#!/usr/bin/env python3
"""Build the release-pinned, additive recipe thumbnail v4 catalog.

The source v1 manifest remains authoritative and unchanged. Generated WebP
objects are content addressed, live outside the repository by default, and are
safe to upload without replacing any v1 object.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

from PIL import Image, ImageOps, __version__ as pillow_version, features


SOURCE_MANIFEST_SHA256 = (
    "e1568e8df82503d9dbf856f425e0d7f2f43c2c17033879b196642b0d9ab166f3"
)
CANONICAL_ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DIGEST_RE = re.compile(r"^[0-9a-f]{64}$")
MAX_EDGE = 512
QUALITY = 78
METHOD = 6
EXPECTED_RECORD_COUNT = 1500
EXPECTED_PILLOW_VERSION = "12.3.0"
EXPECTED_LIBWEBP_VERSION = "1.6.0"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    actual = set(value)
    if actual != expected:
        raise ValueError(
            f"{label} keys differ: missing={sorted(expected - actual)} "
            f"extra={sorted(actual - expected)}"
        )


def source_path_for(entry: dict[str, Any], source_dir: Path) -> Path:
    filename = Path(entry["object_path"]).name
    exact = source_dir / filename
    if exact.is_file():
        return exact
    legacy = source_dir / filename.replace("-", "_")
    if legacy.is_file():
        return legacy
    raise FileNotFoundError(f"missing source image for {entry['canonical_id']}: {filename}")


def build_one(args: tuple[dict[str, Any], str, str]) -> dict[str, Any]:
    entry, source_dir_raw, output_dir_raw = args
    source_dir = Path(source_dir_raw)
    output_dir = Path(output_dir_raw)
    canonical_id = entry["canonical_id"]
    source_path = source_path_for(entry, source_dir)
    source_size = source_path.stat().st_size
    source_sha = sha256_file(source_path)
    if source_size != entry["size_bytes"] or source_sha != entry["sha256"]:
        raise ValueError(f"source integrity mismatch: {canonical_id}")

    with Image.open(source_path) as opened:
        image = ImageOps.exif_transpose(opened)
        image.load()
        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGBA" if "transparency" in image.info else "RGB")
        width, height = image.size
        scale = min(1.0, MAX_EDGE / max(width, height))
        target = (max(1, round(width * scale)), max(1, round(height * scale)))
        if target != image.size:
            image = image.resize(target, Image.Resampling.LANCZOS)
        # Metadata is intentionally omitted. exact=True makes libwebp use the
        # requested preset without hidden parameter changes across entries.
        temp_path = output_dir / f".{canonical_id}.{os.getpid()}.webp"
        image.save(
            temp_path,
            format="WEBP",
            quality=QUALITY,
            method=METHOD,
            exact=True,
            exif=b"",
            xmp=b"",
            icc_profile=None,
        )

    thumb_sha = sha256_file(temp_path)
    if not DIGEST_RE.fullmatch(thumb_sha):
        temp_path.unlink(missing_ok=True)
        raise ValueError(f"invalid generated digest: {canonical_id}")
    final_name = f"{canonical_id}-{thumb_sha}.webp"
    final_path = output_dir / final_name
    if final_path.exists():
        if sha256_file(final_path) != thumb_sha:
            temp_path.unlink(missing_ok=True)
            raise ValueError(f"existing generated object differs: {final_name}")
        temp_path.unlink()
    else:
        temp_path.replace(final_path)

    with Image.open(final_path) as verified:
        if verified.format != "WEBP":
            raise ValueError(f"generated object is not WebP: {canonical_id}")
        generated_width, generated_height = verified.size
        verified.verify()
    if generated_width > MAX_EDGE or generated_height > MAX_EDGE:
        raise ValueError(f"generated dimensions exceed contract: {canonical_id}")

    size_bytes = final_path.stat().st_size
    if size_bytes <= 0:
        raise ValueError(f"empty generated object: {canonical_id}")
    object_path = f"recipes/v4/thumbnails/512/{final_name}"
    return {
        "canonical_id": canonical_id,
        "delivery_path": f"/v4/recipes/thumbnails/{canonical_id}/{thumb_sha}.webp",
        "height": generated_height,
        "mime_type": "image/webp",
        "object_path": object_path,
        "sha256": thumb_sha,
        "size_bytes": size_bytes,
        "source_sha256": source_sha,
        "width": generated_width,
    }


def validate_source_manifest(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, dict):
        raise ValueError("source manifest must be an object")
    exact_keys(
        raw,
        {
            "entries",
            "excluded_source_files",
            "external_candidate_count",
            "placeholder_count",
            "record_count",
            "schema_version",
        },
        "source manifest",
    )
    entries = raw.get("entries")
    if (
        raw.get("schema_version") != 1
        or raw.get("record_count") != EXPECTED_RECORD_COUNT
        or raw.get("external_candidate_count") != EXPECTED_RECORD_COUNT
        or raw.get("placeholder_count") != 0
        or not isinstance(entries, list)
        or len(entries) != EXPECTED_RECORD_COUNT
    ):
        raise ValueError("source manifest release pin is invalid")
    ids: set[str] = set()
    digests: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ValueError(f"source entry {index} must be an object")
        exact_keys(
            entry,
            {
                "canonical_id",
                "height",
                "mime_type",
                "object_path",
                "review_status",
                "sha256",
                "size_bytes",
                "status",
                "width",
            },
            f"source entry {index}",
        )
        canonical_id = entry.get("canonical_id")
        sha256 = entry.get("sha256")
        if (
            not isinstance(canonical_id, str)
            or not CANONICAL_ID_RE.fullmatch(canonical_id)
            or canonical_id in ids
            or not isinstance(sha256, str)
            or not DIGEST_RE.fullmatch(sha256)
            or sha256 in digests
        ):
            raise ValueError(f"source entry identity is invalid: {index}")
        ids.add(canonical_id)
        digests.add(sha256)
    return entries


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-manifest",
        type=Path,
        default=repo_root / "assets/catalogs/recipes/v1/recipe-images.json",
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=repo_root / "assets/images/professional/recipes",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=repo_root / ".tmp/recipe-thumbnails-v4",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=repo_root / "assets/catalogs/recipes/v1/recipe-thumbnails-v4.json",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=max(1, min(8, os.cpu_count() or 1)),
    )
    args = parser.parse_args()

    if not features.check("webp"):
        raise RuntimeError("Pillow was built without WebP support")
    if (
        pillow_version != EXPECTED_PILLOW_VERSION
        or features.version("webp") != EXPECTED_LIBWEBP_VERSION
    ):
        raise RuntimeError(
            "thumbnail encoder is not release-pinned: "
            f"Pillow={pillow_version} libwebp={features.version('webp')}"
        )
    source_manifest = args.source_manifest.resolve()
    if sha256_file(source_manifest) != SOURCE_MANIFEST_SHA256:
        raise ValueError("source manifest SHA-256 does not match the pinned release")
    with source_manifest.open("r", encoding="utf-8") as stream:
        entries = validate_source_manifest(json.load(stream))

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    work = [(entry, str(args.source_dir.resolve()), str(output_dir)) for entry in entries]
    results: list[dict[str, Any]] = []
    with concurrent.futures.ProcessPoolExecutor(max_workers=args.workers) as executor:
        for completed, result in enumerate(executor.map(build_one, work), start=1):
            results.append(result)
            if completed % 100 == 0 or completed == EXPECTED_RECORD_COUNT:
                print(f"generated {completed}/{EXPECTED_RECORD_COUNT}", flush=True)

    results.sort(key=lambda entry: entry["canonical_id"])
    ids = {entry["canonical_id"] for entry in results}
    keys = {entry["object_path"] for entry in results}
    # Different source photographs can converge to the same lossy WebP bytes.
    # Identity remains one-to-one because the canonical id is part of each key.
    if not (len(results) == len(ids) == len(keys) == EXPECTED_RECORD_COUNT):
        raise ValueError("generated allowlist is not one-to-one")
    total_size = sum(entry["size_bytes"] for entry in results)
    manifest = {
        "entries": results,
        "record_count": EXPECTED_RECORD_COUNT,
        "schema_version": 4,
        "source_image_manifest_sha256": SOURCE_MANIFEST_SHA256,
        "total_size_bytes": total_size,
        "transformation": {
            "codec": "libwebp",
            "fit": "contain-no-upscale",
            "max_height": MAX_EDGE,
            "max_width": MAX_EDGE,
            "method": METHOD,
            "quality": QUALITY,
            "resampling": "lanczos",
            "version": 1,
        },
    }
    manifest_path = args.manifest.resolve()
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(
        manifest,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ) + "\n"
    manifest_path.write_text(encoded, encoding="utf-8", newline="\n")
    print(
        json.dumps(
            {
                "manifest": str(manifest_path),
                "manifest_sha256": sha256_file(manifest_path),
                "output_dir": str(output_dir),
                "record_count": len(results),
                "total_size_bytes": total_size,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"thumbnail build failed: {error}", file=sys.stderr)
        raise
