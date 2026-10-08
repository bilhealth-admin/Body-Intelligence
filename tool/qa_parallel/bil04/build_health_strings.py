"""Rebuild source-backed BIL-04 localization inventories without Git/network."""
from __future__ import annotations
import argparse
import difflib
import hashlib
import json
import re
import subprocess
from pathlib import Path

BASE = "1744788e6bfbdffc3a168bbaf36b3abf3e2c698a"
OWNED = "lib/features/intelligence_center/app_commands/"
SHARED = "lib/features/intelligence_center/"
LITERAL_FILES = {
    "coach_health_copy.dart", "coach_health_flow.dart", "coach_health_parser.dart",
    "coach_health_tools.dart", "coach_activity_catalog.dart",
}
def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--validation", type=Path, required=True)
    parser.add_argument("--dart", type=Path, required=True)
    args = parser.parse_args()
    repo, validation = args.repository.resolve(), args.validation.resolve()
    output = repo / "docs/qa_parallel/bil04"
    output.mkdir(parents=True, exist_ok=True)
    logs = output / "query_validation"
    logs.mkdir(parents=True, exist_ok=True)
    files = []
    for source in sorted((repo / OWNED).glob("*.dart")):
        files.append({
            "path": str(source.relative_to(repo)), "sourcePath": str(source),
            "mode": "owned", "sourceSha256": digest(source.read_bytes()),
            "userCopyExpected": source.name in LITERAL_FILES,
            "addedRanges": [],
        })
    for source in sorted((validation / SHARED).rglob("*.dart")):
        relative = source.relative_to(validation)
        if str(relative).startswith(OWNED):
            continue
        base = repo / relative
        if not base.is_file():
            raise RuntimeError("Missing verified local BASE file: " + str(relative))
        before, after = base.read_bytes(), source.read_bytes()
        if before == after:
            continue
        a, b = before.decode().splitlines(keepends=True), after.decode().splitlines(keepends=True)
        offsets = [0]
        # Dart AST offsets count UTF-16 code units, not bytes or Python scalars.
        for line in b:
            offsets.append(offsets[-1] + len(line.encode("utf-16-le")) // 2)
        added = [
            [offsets[k], offsets[l]]
            for kind, i, j, k, l in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes()
            if kind in ("replace", "insert") and k != l
        ]
        files.append({
            "path": str(relative), "sourcePath": str(source),
            "mode": "shared_added", "sourceSha256": digest(after),
            "baseSha256": digest(before), "addedRanges": added,
            "userCopyExpected": "/presentation/" in str(relative),
        })
    manifest_path = logs / "health_strings_manifest.json"
    manifest = {
        "base": BASE, "baseMethod": "Preverified local BASE files; no Git or network",
        "files": files,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    raw_path = logs / "health_strings_ast.json"
    command = [
        str(args.dart),
        "--packages=" + str(validation / ".dart_tool/package_config.json"),
        str(repo / "tool/qa_parallel/bil04/extract_health_strings.dart"),
        str(manifest_path), str(raw_path),
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    (logs / "health_strings_extraction.txt").write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    raw = json.loads(raw_path.read_text())
    locale_path = repo / "lib/app/localization/bil_locale_rollout_manifest.dart"
    locale_source = locale_path.read_text().split("static const releaseTargets25 = <String>{", 1)[1].split("};", 1)[0]
    tags = re.findall(r"'([^']+)'", locale_source)
    if len(tags) != 25 or len(set(tags)) != 25 or not {"en", "ar"} <= set(tags):
        raise RuntimeError("Unexpected locale target manifest; review required")
    pending = {
        tag: {
            "status": "PENDING_HUMAN_TRANSLATION_AND_REVIEW",
            "translated": False,
            "runtimeFallbackIsNotTranslationEvidence": True,
        }
        for tag in tags if tag not in ("en", "ar")
    }
    # Deliberately keep review findings visible. Internal diagnostics are
    # classified here only if they match a known app-owned diagnostic string.
    known_diagnostics = set()
    for item in raw["unpairedLiteralAudit"]:
        if item["classification"] == "internal_diagnostic":
            known_diagnostics.add(item["template"])
    for item in raw["unpairedLiteralAudit"]:
        if item["classification"] == "REVIEW_UNPAIRED" and item["template"] in known_diagnostics:
            item["classification"] = "internal_diagnostic_comparison"
    review = [
        item for item in raw["unpairedLiteralAudit"]
        if item["classification"] == "REVIEW_UNPAIRED"
    ]
    metadata = {
        "schemaVersion": 1, "role": "BIL-04", "baseSha": BASE,
        "format": "Template inventory with per-occurrence exact Dart bindings; not runtime locale catalogs",
        "sourceMethod": "Dart analyzer AST; local BASE-to-overlay comparison restricts shared strings to new/changed spans",
        "runtimeSourceStatus": "EN_AR_AUTHORED_AND_EXTRACTED",
        "humanLinguisticAndRtlVisualReview": "PENDING",
        "productionTargetCount": 25, "otherLocalesPendingCount": 23,
        "otherLocales": pending,
        "localeManifest": str(locale_path.relative_to(repo)),
        "localeManifestSha256": digest(locale_path.read_bytes()),
        "placeholderConvention": "{p1}, {p2}, ... are positional within each template; source bindings retain nested expressions and locale-specific terms; do not evaluate code",
        "sourceFiles": [
            {key: value for key, value in item.items() if key not in ("sourcePath", "addedRanges")}
            for item in files
        ],
        "pairedTemplateCount": len(raw["pairs"]),
        "placeholderDiagnostics": raw["diagnostics"],
        "unpairedReviewRequired": review,
        "excludedLiteralClassificationCounts": {},
        "astAudit": "query_validation/health_strings_ast.json",
        "rebuildTool": "tool/qa_parallel/bil04/build_health_strings.py",
    }
    for item in raw["unpairedLiteralAudit"]:
        key = item["classification"]
        counts = metadata["excludedLiteralClassificationCounts"]
        counts[key] = counts.get(key, 0) + 1
    for locale in ("en", "ar"):
        entries = {}
        for pair in raw["pairs"]:
            entries[pair["id"]] = {
                "template": pair[locale], "kinds": pair["kinds"],
                "placeholderParity": pair["placeholderParity"],
                "sources": [source[locale] for source in pair["sources"]],
                "status": "AUTHORED_SOURCE_EXTRACTED",
            }
        (output / ("strings." + locale + ".json")).write_text(
            json.dumps({"metadata": {**metadata, "locale": locale}, "strings": entries},
                       ensure_ascii=False, indent=2) + "\n"
        )
    after_hashes = {
        item["path"]: digest(Path(item["sourcePath"]).read_bytes()) for item in files
    }
    unchanged = all(after_hashes[item["path"]] == item["sourceSha256"] for item in files)
    report = {
        "command": command, "exitCode": result.returncode,
        "templateCount": len(raw["pairs"]), "sharedPairedOccurrences": sum(
            1 for p in raw["pairs"] for s in p["sources"] if s["en"]["scope"] == "shared_added"
        ),
        "unpairedReviewRequiredCount": len(review),
        "placeholderDiagnosticCount": len(raw["diagnostics"]),
        "sourceUnchangedDuringExtraction": unchanged,
        "sourceBefore": {item["path"]: item["sourceSha256"] for item in files},
        "sourceAfter": after_hashes,
        "status": "PASS" if unchanged and not raw["diagnostics"] and not review else "REVIEW_REQUIRED",
    }
    (logs / "health_strings_extraction.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({key: value for key, value in report.items() if key not in ("command", "sourceBefore", "sourceAfter")}, indent=2))

if __name__ == "__main__":
    main()
