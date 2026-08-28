"""Audit BIL's five-language contract and report hard-coded UI copy."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

LANGUAGES = ("ar", "en", "fr", "es", "tr")
MAP_START = re.compile(r"const _appLocale(?P<lang>Ar|En|Fr|Es|Tr) = \{")
KEY = re.compile(r"^\s*'(?P<key>[^']+)'\s*:")
TEXT_WIDGET = re.compile(r"\b(?:Text|Tooltip|SnackBar)\(\s*(?:const\s+)?(['\"])(.+?)\1")


def app_keys(path: Path) -> dict[str, set[str]]:
    result = {language: set() for language in LANGUAGES}
    active = None
    depth = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        if active is None:
            match = MAP_START.search(line)
            if match:
                active = match.group("lang").lower()
                depth = line.count("{") - line.count("}")
            continue
        depth += line.count("{") - line.count("}")
        match = KEY.match(line)
        if match:
            result[active].add(match.group("key"))
        if depth <= 0:
            active = None
    return result


def feature_key_gaps(path: Path) -> list[dict[str, object]]:
    source = path.read_text(encoding="utf-8")
    gaps = []
    for key, body in re.findall(r"'([^']+)'\s*:\s*\{(.*?)\n\s*\},", source, re.S):
        present = set(re.findall(r"^\s*'(ar|en|fr|es|tr)'\s*:", body, re.M))
        missing = sorted(set(LANGUAGES) - present)
        if missing:
            gaps.append({"key": key, "missing": missing})
    return gaps


def hard_coded_copy(lib: Path) -> list[dict[str, object]]:
    findings = []
    for path in lib.rglob("*.dart"):
        relative = path.relative_to(lib.parent).as_posix()
        if "/localization/" in f"/{relative}":
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = TEXT_WIDGET.search(line)
            if not match:
                continue
            value = match.group(2).strip()
            if value in {"", "-", "—", "BIL"} or value.startswith(("http", "assets/")):
                continue
            findings.append({"file": relative, "line": number, "text": value[:120]})
    return findings


def audit(project: Path) -> dict[str, object]:
    localization = project / "lib/app/localization"
    keys = app_keys(localization / "app_localizations_base_catalog.dart")
    reference = keys["en"]
    parity = {
        language: {
            "missing": sorted(reference - values),
            "extra": sorted(values - reference),
        }
        for language, values in keys.items()
    }
    return {
        "languages": list(LANGUAGES),
        "app_localization_key_count": {key: len(value) for key, value in keys.items()},
        "app_localization_parity": parity,
        "feature_string_gaps": feature_key_gaps(localization / "feature_strings.dart"),
        "hard_coded_ui_copy": hard_coded_copy(project / "lib"),
    }


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    report = audit(args.project.resolve())
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    parity_failed = any(
        value["missing"] or value["extra"]
        for value in report["app_localization_parity"].values()
    )
    if parity_failed or report["feature_string_gaps"]:
        raise SystemExit(1)
    if args.strict and report["hard_coded_ui_copy"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
