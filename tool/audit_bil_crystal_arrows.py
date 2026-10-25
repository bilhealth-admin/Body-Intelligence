#!/usr/bin/env python3
"""Read-only candidate scanner for the BIL39 persistent-crystal arrow audit.

This tool deliberately reports candidates, not verified arrows. Review every
row manually and annotate the final inventory before claiming complete coverage.
"""
from __future__ import annotations

import argparse
import csv
import re
from collections import Counter
from pathlib import Path

SOURCE_DIRS = ("lib", "ios", "android", "macos", "windows", "linux", "test", "integration_test", "assets")
EXTENSIONS = {".dart", ".swift", ".kt", ".java", ".m", ".mm", ".xml", ".storyboard", ".xib"}
ASSET_EXTENSIONS = {".svg", ".png", ".webp", ".jpg", ".jpeg", ".gif", ".pdf", ".json", ".avif"}
ASSET_NAME_PATTERN = re.compile(
    r"(?:arrow|chevron|caret|back|forward|expand|collapse|next|previous|dropdown|disclosure)",
    re.IGNORECASE,
)
SKIP_DIRS = {
    ".dart_tool", ".git", "build", "DerivedData", "Pods", "Carthage",
    "node_modules", ".gradle", "Flutter", "GeneratedPluginRegistrant",
}
PATTERNS = (
    ("DART_ICON", re.compile(
        r"\b(?:Icons|CupertinoIcons)\.(?:[A-Za-z0-9_]*(?:arrow|chevron|keyboard_arrow|navigate|expand|unfold|first_page|last_page|double_arrow|reply|refresh|undo|redo|forward|back)[A-Za-z0-9_]*)",
        re.IGNORECASE,
    )),
    ("AUTO_NAV_WIDGET", re.compile(
        r"\b(?:BackButton(?:Icon)?|ExpansionTile|DropdownButton(?:FormField)?|DropdownMenu|CalendarDatePicker|showDatePicker|CupertinoNavigationBarBackButton|NavigationRail|PageView|CarouselSlider)\b"
    )),
    ("SF_SYMBOL", re.compile(
        r"(?:systemName\s*:\s*|Image\s*\(\s*systemName\s*:\s*)[\"'](?:arrow|chevron|caret|return|arrowshape|line\.3\.horizontal)[^\"']*[\"']",
        re.IGNORECASE,
    )),
    ("ASSET_REFERENCE", re.compile(
        r"\b(?:assets?/|(?:\.\./)*assets?/)[\w./-]*(?:arrow|chevron|caret|back|forward|expand|collapse|next|previous)[\w./-]*",
        re.IGNORECASE,
    )),
    ("ANDROID_RESOURCE", re.compile(
        r"(?:R\.drawable\.|@drawable/)[A-Za-z0-9_]*(?:arrow|chevron|back|forward|expand|collapse|next|previous)[A-Za-z0-9_]*",
        re.IGNORECASE,
    )),
    ("XML_ASSET_OR_LABEL", re.compile(
        r"(?:name|src|contentDescription|accessibilityLabel)=[\"'][^\"']*(?:arrow|chevron|back|forward|expand|collapse|next|previous)[^\"']*[\"']",
        re.IGNORECASE,
    )),
)
PROTECTED_COMMERCE_PATH = "lib/features/commerce/presentation/bil_dynamic_store_components.dart"


def language_for(path: Path) -> str:
    return {
        ".dart": "dart", ".swift": "swift", ".kt": "kotlin", ".java": "java",
        ".m": "objective-c", ".mm": "objective-c++", ".xml": "xml",
        ".storyboard": "storyboard", ".xib": "xib",
    }.get(path.suffix.lower(), "unknown")


def directional_asset(path: Path, root: Path) -> bool:
    """Find named Flutter/iOS/Android assets without decoding binary media."""
    parts = tuple(part.lower() for part in path.relative_to(root).parts)
    in_assets = (
        parts[0] == "assets"
        or any(
            part.endswith(".xcassets") or part.startswith(("drawable", "mipmap"))
            for part in parts[:-1]
        )
    )
    return (
        in_assets
        and path.suffix.lower() in ASSET_EXTENSIONS
        and ASSET_NAME_PATTERN.search(path.stem) is not None
    )


def source_files(root: Path):
    for directory in SOURCE_DIRS:
        base = root / directory
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() not in EXTENSIONS and not directional_asset(path, root):
                continue
            relative_parts = path.relative_to(root).parts
            if any(part in SKIP_DIRS for part in relative_parts):
                continue
            yield path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("build/bil39_crystal_arrow_candidates.csv"))
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.exists():
        parser.error("root directory does not exist: " + str(root))

    output = args.output if args.output.is_absolute() else root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    counts: Counter[str] = Counter()
    scanned_files = 0
    rows = []

    for path in source_files(root):
        scanned_files += 1
        relative = path.relative_to(root).as_posix()
        protected_file = relative == PROTECTED_COMMERCE_PATH
        if directional_asset(path, root):
            counts["ASSET_FILENAME"] += 1
            rows.append({
                "file": relative,
                "line": 0,
                "language": "asset",
                "candidate_types": "ASSET_FILENAME",
                "source_excerpt": path.name,
                "protected_payment_file": "NO",
                "manual_review_required": "YES",
                "verified_crystal_state": "UNVERIFIED",
                "click_back_and_rtl_ltr_proof": "UNVERIFIED",
            })
            # This is a source-name candidate only, never visual/runtime proof.
            # Do not try to decode PNG/WebP/SVG/asset-catalog bytes as text.
            if path.suffix.lower() not in EXTENSIONS:
                continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for line_number, line in enumerate(lines, start=1):
            kinds = [name for name, pattern in PATTERNS if pattern.search(line)]
            if not kinds:
                continue
            counts.update(kinds)
            excerpt = " ".join(line.strip().split())
            if len(excerpt) > 220:
                excerpt = excerpt[:217] + "..."
            rows.append({
                "file": relative,
                "line": line_number,
                "language": language_for(path),
                "candidate_types": ";".join(kinds),
                "source_excerpt": excerpt,
                "protected_payment_file": "YES" if protected_file else "NO",
                "manual_review_required": "YES",
                "verified_crystal_state": "UNVERIFIED",
                "click_back_and_rtl_ltr_proof": "UNVERIFIED",
            })

    rows.sort(key=lambda row: (row["file"], int(row["line"])))
    fields = [
        "file", "line", "language", "candidate_types", "source_excerpt",
        "protected_payment_file", "manual_review_required",
        "verified_crystal_state", "click_back_and_rtl_ltr_proof",
    ]
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    print("Root: " + str(root))
    print("Source files scanned: " + str(scanned_files))
    print("Candidate occurrences: " + str(len(rows)))
    for kind, count in sorted(counts.items()):
        print(kind + ": " + str(count))
    print("CSV: " + str(output))
    print("Status: candidates only; manual review and runtime tests are still required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
