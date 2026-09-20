#!/usr/bin/env python3
"""Run every local release-validation suite from one live command.

The Flutter command is the authoritative unique test-case run.  Portable
replays the release-safe subset with its own timeout/batching contract; those
cases are reported as overlap and are not added to TOTAL_UNIQUE_TESTS.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LOG_ROOT = Path(".codex") / "validation-logs"


def _run_live(name: str, command: list[str], log_name: str) -> tuple[int, str]:
    print(f"\n=== {name} ===", flush=True)
    log_path = ROOT / LOG_ROOT / log_name
    log_path.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    with log_path.open("w", encoding="utf-8", errors="replace") as log:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        assert process.stdout is not None
        for line in process.stdout:
            print(line, end="", flush=True)
            log.write(line)
            lines.append(line)
        code = process.wait()
    print(f"=== {name} EXIT={code} LOG={log_path} ===", flush=True)
    return code, "".join(lines)


def _flutter_count(output: str) -> tuple[int, int, int]:
    passed = failed = skipped = 0
    for line in output.splitlines():
        match = re.search(r"\+(\d+)(?:\s+~(\d+))?(?:\s+-([0-9]+))?", line)
        if match:
            passed = int(match.group(1))
            skipped = int(match.group(2) or 0)
            failed = int(match.group(3) or 0)
    return passed, failed, skipped


def _deno_count(output: str) -> tuple[int, int, int]:
    passed = failed = skipped = 0
    for line in output.splitlines():
        match = re.search(
            r"(?:([0-9]+) passed|passed:\s*([0-9]+)).*?"
            r"(?:([0-9]+) failed|failed:\s*([0-9]+))?",
            line,
            re.IGNORECASE,
        )
        if match:
            passed = max(passed, int(match.group(1) or match.group(2) or 0))
            failed = max(failed, int(match.group(3) or match.group(4) or 0))
        skipped_match = re.search(r"(?:skipped|ignored):\s*([0-9]+)", line, re.I)
        if skipped_match:
            skipped = max(skipped, int(skipped_match.group(1)))
    return passed, failed, skipped


def main() -> int:
    results: list[tuple[str, int, int, int, int, str]] = []
    flutter_code, flutter_output = _run_live(
        "FULL FLUTTER",
        ["flutter.bat", "test", "--no-pub", "--concurrency=4", "test"],
        "master-flutter.log",
    )
    fp, ff, fs = _flutter_count(flutter_output)
    results.append(("Flutter", flutter_code, fp, ff, fs, "authoritative unique cases"))

    portable_code, portable_output = _run_live(
        "PORTABLE RELEASE (887 scheduled files)",
        [sys.executable, "tool/release/run_portable_release_tests.py"],
        "master-portable.log",
    )
    scheduled = 0
    executed = 0
    for line in portable_output.splitlines():
        marker = re.search(r"PORTABLE_RELEASE_SCHEDULED_TEST_FILES=(\d+)", line)
        if marker:
            scheduled = int(marker.group(1))
        marker = re.search(r"PORTABLE_RELEASE_EXECUTED_TEST_FILES=(\d+)", line)
        if marker:
            executed = int(marker.group(1))
    results.append(("Portable", portable_code, 0, 0 if portable_code == 0 else 1, 0, f"{executed or scheduled} files; overlap={executed or scheduled}"))

    ai_files = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "supabase/functions/ai-coach").glob("*_test.ts"))
    ai_code, ai_output = _run_live(
        "DENO AI COACH",
        ["deno", "test", "--allow-env", "--allow-net", "--allow-read", *ai_files],
        "master-deno-ai.log",
    )
    ap, af, ass = _deno_count(ai_output)
    results.append(("Deno AI", ai_code, ap, af, ass, "not counted twice"))

    store_dir = ROOT / "supabase/functions/verify-store-purchase"
    store_files = sorted(str(p.relative_to(ROOT)) for p in store_dir.glob("*_test.ts"))
    store_code, store_output = _run_live(
        "DENO STORE",
        ["deno", "test", "--allow-env", "--allow-net", "--allow-read", *store_files],
        "master-deno-store.log",
    )
    sp, sf, sss = _deno_count(store_output)
    results.append(("Deno Store", store_code, sp, sf, sss, "not counted twice"))

    type_files = sorted(
        str(p.relative_to(ROOT))
        for base in (ROOT / "supabase/functions/ai-coach", store_dir)
        for p in base.glob("*.ts")
    )
    type_code, _ = _run_live(
        "DENO TYPE CHECK",
        ["deno", "check", "--config", "supabase/functions/deno.json", *type_files],
        "master-deno-typecheck.log",
    )
    results.append(("Deno type-check", type_code, 0, 0 if type_code == 0 else 1, 0, "compile gate"))

    print("\n=== MASTER SUMMARY ===", flush=True)
    print("SUITE | PASSED | FAILED | SKIPPED | OVERLAP", flush=True)
    for name, code, passed, failed, skipped, note in results:
        overlap = note if name in {"Portable", "Deno AI", "Deno Store"} else "0"
        print(f"{name} | {passed} | {failed} | {skipped} | {overlap}", flush=True)
    total_passed = fp + ap + sp
    total_failed = ff + (0 if portable_code == 0 else 1) + af + sf + (0 if type_code == 0 else 1)
    total_skipped = fs + ass + sss
    print(f"TOTAL_UNIQUE_TESTS={total_passed + total_failed + total_skipped}", flush=True)
    print(f"TOTAL_PASSED={total_passed}", flush=True)
    print(f"TOTAL_FAILED={total_failed}", flush=True)
    print(f"TOTAL_SKIPPED={total_skipped}", flush=True)
    return 0 if total_failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
