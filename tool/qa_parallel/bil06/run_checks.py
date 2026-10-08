#!/usr/bin/env python3
"""Reproduce BIL-06 checks on BASE plus the declared integration overlay.

Uses an already installed, isolated Flutter 3.44.6 / Dart 3.12.2 SDK. It never
downloads dependencies, changes the lockfile, publishes, or contacts a database.
Missing tools are recorded as NOT_RUN rather than converted into passing tests.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import time


BASE = "1744788e6bfbdffc3a168bbaf36b3abf3e2c698a"
BASE_TREE = "8f140791e1c2adcb21122ce64a65cb168bbe90d7"
EXISTING = [
    "lib/features/community/presentation/community_circles_page.dart",
    "lib/features/community/presentation/community_circle_detail_page.dart",
    "lib/features/community/presentation/community_circle_discovery_header.dart",
    "lib/features/community/presentation/community_circle_reference_body.dart",
    "lib/features/community/presentation/community_circle_owner_scope.dart",
    "lib/features/community/presentation/community_circle_copy.dart",
]
REGRESSION = [
    "test/features/community/community_circles_auth_session_test.dart",
    "test/features/community/community_circles_v1_contract_test.dart",
    "test/features/community/community_topic_circle_resilience_test.dart",
    "test/qa_next/community_circles_reference_capture_test.dart",
    "test/features/community/community_reference_navigation_test.dart",
]


def digest(root: Path) -> dict:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=root, check=True, stdout=subprocess.PIPE,
    )
    paths = sorted(set(result.stdout.decode().split("\0")) - {""})
    entries = []
    missing = []
    for name in paths:
        path = root / name
        if path.is_file():
            entries.append([name, hashlib.sha256(path.read_bytes()).hexdigest()])
        else:
            entries.append([name, "NOT_MATERIALIZED"])
            missing.append(name)
    value = hashlib.sha256(
        json.dumps(entries, ensure_ascii=False, separators=(",", ":")).encode()
    ).hexdigest()
    return {"sha256": value, "file_count": len(entries),
            "not_materialized_count": len(missing)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--dart", default="dart")
    parser.add_argument("--capture-dir", type=Path,
                        help="Optional external directory for genuine BASE circle Flutter captures")
    args = parser.parse_args()
    root = args.repo.resolve()
    output = args.output.resolve()
    if output == root or root in output.parents:
        parser.error("Evidence output must be outside the source tree.")
    output.mkdir(parents=True, exist_ok=True)
    process_env = os.environ.copy()
    capture_dir = args.capture_dir.resolve() if args.capture_dir else None
    if capture_dir is not None:
        if capture_dir == root or root in capture_dir.parents:
            parser.error("Capture output must be outside the source tree.")
        capture_dir.mkdir(parents=True, exist_ok=True)
        process_env["BIL_CIRCLES_CAPTURE_DIR"] = str(capture_dir)
    records = []
    environment = {
        "platform": platform.platform(), "python": platform.python_version(),
        "requested_flutter": "3.44.6", "requested_dart": "3.12.2",
        "flutter_executable": shutil.which(args.flutter),
        "dart_executable": shutil.which(args.dart),
        "network_restore_requested": False, "production_deployed": False,
        "circle_capture_dir": str(capture_dir) if capture_dir else None,
    }

    def run(name: str, command: list[str], *, blocked: str | None = None) -> dict:
        started = time.monotonic()
        before = digest(root)
        record = {"name": name, "command": command, "cwd": str(root),
                  "source_before": before, "environment": environment,
                  "log": f"{name}.log"}
        log_path = output / record["log"]
        log = None
        if blocked is not None or shutil.which(command[0]) is None:
            record.update(status="NOT_RUN", exit_code=None,
                          reason=blocked or f"Executable unavailable: {command[0]}")
            log = record["reason"] + "\n"
        else:
            try:
                # Write directly so a long-running test can be inspected while
                # it runs. Keep all diagnostics, including an interrupted run.
                with log_path.open("w", encoding="utf-8") as live_log:
                    result = subprocess.run(
                        command, cwd=root, text=True, stdout=live_log,
                        stderr=subprocess.STDOUT, check=False, env=process_env,
                    )
                record.update(status="PASS" if result.returncode == 0 else "FAIL",
                              exit_code=result.returncode)
            except OSError as error:
                log = f"{type(error).__name__}: {error}\n"
                record.update(status="NOT_RUN", exit_code=None, reason=log.strip())
        record["duration_seconds"] = round(time.monotonic() - started, 3)
        record["source_after"] = digest(root)
        record["source_unchanged"] = record["source_before"] == record["source_after"]
        if log is not None:
            log_path.write_text(log, encoding="utf-8")
        records.append(record)
        (output / "completed_runs.json").write_text(
            json.dumps(records, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"{name}: {record['status']} (exit {record['exit_code']})", flush=True)
        return record

    head = run("base_identity", ["git", "rev-parse", "HEAD", "HEAD^{tree}"])
    identity = (output / "base_identity.log").read_text().splitlines()
    if identity != [BASE, BASE_TREE]:
        head["status"] = "FAIL"
        head["reason"] = "Source is not based on the frozen BIL-06 commit/tree."

    flutter = run("flutter_version", [args.flutter, "--version", "--machine"])
    dart = run("dart_version", [args.dart, "--version"])
    version_failure = None
    if flutter["status"] != "PASS" or dart["status"] != "PASS":
        version_failure = "Pinned Flutter/Dart SDK is unavailable."
    else:
        try:
            info = json.loads((output / "flutter_version.log").read_text())
            dart_text = (output / "dart_version.log").read_text()
            if info.get("frameworkVersion") != "3.44.6" or "3.12.2" not in dart_text:
                version_failure = "Pinned Flutter 3.44.6 / Dart 3.12.2 required."
        except (ValueError, TypeError):
            version_failure = "Could not verify pinned SDK versions."
    if head["status"] != "PASS":
        version_failure = head["reason"]

    # Check the delivered code and its exact integration overlay. Validation
    # may read verified BASE assets through local leaf links; those files are
    # not changed or delivered by this role and are outside its patch scope.
    patch_paths = EXISTING + [
        "lib/features/community/circle_management", "test/parallel/bil06",
        "docs/qa_parallel/bil06", "tool/qa_parallel/bil06",
        "lib/features/community/presentation/community_hub_page.dart",
        "supabase/functions/_shared/account_deletion_storage.ts",
    ]
    run("diff_whitespace", ["git", "diff", "--check", BASE, "--", *patch_paths])
    dart_paths = EXISTING + [
        "lib/features/community/circle_management", "test/parallel/bil06",
    ]
    run("dart_format_check", [args.dart, "format", "--output=none",
                              "--set-exit-if-changed", *dart_paths],
        blocked=version_failure)
    run("flutter_analyze", [args.flutter, "analyze", "--no-pub"],
        blocked=version_failure)
    # Serial file execution limits compiler/engine memory in shared runners;
    # every selected test still executes with its unchanged timeout/assertions.
    run("bil06_focused", [args.flutter, "test", "--no-pub", "--concurrency=1", "--reporter",
                          "expanded", "test/parallel/bil06"],
        blocked=version_failure)
    # Run each complete BASE file in its own process. This releases compiler
    # and engine state between the heavier reference-capture fixtures on a
    # shared runner; the selected files, cases and assertions stay unchanged.
    for path in REGRESSION:
        name = "circles_regression_" + Path(path).stem.removesuffix("_test")
        run(name, [args.flutter, "test", "--no-pub", "--concurrency=1", "--reporter",
                   "expanded", path], blocked=version_failure)

    summary = {
        "role_id": "BIL-06", "base_sha": BASE, "base_tree": BASE_TREE,
        "source": digest(root), "environment": environment, "runs": records,
        "production_deployed": False, "unique_dart_tests_passed": None,
        "note": "Commands with overlapping tests are not summed. SQL is a separate run.",
    }
    (output / "verification.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    if any(r["status"] == "FAIL" or not r["source_unchanged"] for r in records):
        return 1
    if any(r["status"] == "NOT_RUN" for r in records):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
