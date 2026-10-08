#!/usr/bin/env python3
"""Run an unchanged validation command and record its exact local source state.

This recorder adds no skips, filters, tolerances, or retries. Run it from the
validation checkout, passing the actual Flutter/Dart command after ``--``.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time


def source_snapshot(root):
    paths = []
    for directory in ("lib", "test", "tool"):
        paths.extend(
            p for p in (root / directory).rglob("*")
            if p.is_file() and p.suffix in (".dart", ".py", ".sh", ".yaml", ".json")
        )
    paths.extend(
        root / name
        for name in ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "l10n.yaml")
        if (root / name).is_file()
    )
    entries = {
        p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(set(paths))
    }
    canonical = json.dumps(entries, sort_keys=True, separators=(",", ":"))
    return entries, hashlib.sha256(canonical.encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("An actual validation command is required after --")
    root = Path.cwd().resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    log_path = args.output / (args.name + ".txt")
    report_path = args.output / (args.name + ".json")
    source_path = args.output / (args.name + ".sources.json")
    before, before_digest = source_snapshot(root)
    start = dt.datetime.now(dt.timezone.utc).isoformat()
    clock_start = time.monotonic()
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, errors="replace", env=os.environ.copy(),
        )
        for line in process.stdout:
            log.write(line)
            log.flush()
        exit_code = process.wait()
    after, after_digest = source_snapshot(root)
    output = log_path.read_text(encoding="utf-8")
    counts = re.findall(r"\+(\d+)(?:[^\n]*)All tests passed!", output)
    source_path.write_text(json.dumps(before, ensure_ascii=False, indent=2) + "\n")
    report = {
        "name": args.name,
        "command_argv": command,
        "cwd": str(root),
        "started_at_utc": start,
        "ended_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "duration_seconds": round(time.monotonic() - clock_start, 3),
        "environment": {
            "platform": platform.platform(),
            "python": platform.python_version(),
            "TZ": os.environ.get("TZ", "system UTC"),
            "TAR_OPTIONS": os.environ.get("TAR_OPTIONS"),
            "runtime_requirement": "Flutter 3.44.6 / Dart 3.12.2, unchanged pubspec.lock",
            "live_providers": False,
            "test_data": "synthetic, local host",
        },
        "exit_code": exit_code,
        "result": "PASS" if exit_code == 0 else "FAIL",
        "passed_test_count": int(counts[-1]) if counts else None,
        "source_digest_algorithm": "SHA256 of sorted compact JSON path-to-SHA256 map",
        "source_scope": "lib/test/tool .dart/.py/.sh/.yaml/.json and four root build configuration files",
        "source_digest_before": before_digest,
        "source_digest_after": after_digest,
        "source_stable": before == after,
        "source_file_count": len(before),
        "source_manifest": source_path.name,
        "changed_during_run": sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p)),
        "log": log_path.name,
        "log_sha256": hashlib.sha256(log_path.read_bytes()).hexdigest(),
        "skips_or_exclusions_added_by_recorder": False,
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("name", "result", "exit_code", "passed_test_count", "source_stable", "source_digest_before")}, indent=2))
    print("Evidence:", report_path)
    return exit_code if before == after else (exit_code or 3)


if __name__ == "__main__":
    sys.exit(main())
