"""Publish scanner metadata without matched source, credentials or messages."""

import datetime
import hashlib
import json
import pathlib
import subprocess
import sys


def sanitize(payload):
    if not isinstance(payload, dict) or not isinstance(payload.get("version"), str):
        raise ValueError("Semgrep did not produce a versioned JSON result")
    findings = payload.get("results")
    errors = payload.get("errors")
    if not isinstance(findings, list) or not isinstance(errors, list):
        raise ValueError("Semgrep result arrays are missing")
    rows = []
    for finding in findings:
        rows.append({
            "rule": finding["check_id"],
            "path": finding["path"],
            "line": finding["start"]["line"],
            "severity": finding.get("extra", {}).get("severity"),
        })
    return {
        "scanner_version": payload["version"],
        "result": "PARTIAL" if errors else "FINDINGS_REVIEW" if rows else "CLEAN_SCAN",
        "findings_count": len(rows),
        "findings": rows,
        "errors_count": len(errors),
        "errors": [{"type": error.get("type"), "level": error.get("level"),
                    "code": error.get("code"), "path": error.get("path"),
                    "rule_id": error.get("rule_id")} for error in errors],
        "scanned_paths_count": len(payload.get("paths", {}).get("scanned", [])),
        "scope": "Semgrep CE supported source languages; not a Dart, device or release-artifact scan",
        "source_uploaded": False,
        "metrics_enabled": False,
    }


def main():
    raw = pathlib.Path(sys.argv[1]).read_bytes()
    result = sanitize(json.loads(raw))
    result["raw_report_sha256"] = hashlib.sha256(raw).hexdigest()
    result["source_head"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], text=True
    ).strip()
    result["recorded_at_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    target = pathlib.Path(sys.argv[2])
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((json.dumps(result, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print(json.dumps({key: result[key] for key in
                      ("result", "scanner_version", "findings_count", "errors_count", "scanned_paths_count")}))
    return 1 if any(error.get("level") == "error" for error in result["errors"]) else 0


if __name__ == "__main__":
    sys.exit(main())
