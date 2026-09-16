"""Analyze, then run host tests in ten serial, fail-between-batch gates.

No resume, name filters, golden updates, or silent file exclusions. Device
integration tests are inventoried separately and are never claimed as run.
Batch 1 also runs every local Deno, PostgreSQL and release-helper test.
Each invocation starts fresh at analysis and batch 1. Logs stay under build/.
The process needs no agent, watcher, network deployment, or automatic repair.
"""
from __future__ import annotations

import argparse
import codecs
from contextlib import contextmanager
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]


def write_json(path: Path, value: object) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


@contextmanager
def exclusive_run(path: Path):
    """OS-owned lock: a crashed runner cannot leave a permanently stale lock."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as lock:
        if path.stat().st_size == 0:
            lock.write(b"0")
            lock.flush()
        lock.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            raise RuntimeError("Another full-validation run already owns this tree") from error
        try:
            yield
        finally:
            lock.seek(0)
            if os.name == "nt":
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def groups(files: list[str]) -> list[list[str]]:
    # Exercise commerce/access regressions first, without excluding any file.
    key = lambda name: (not any(part in name for part in (
        "/commerce/", "subscription", "entitlement", "trial", "store_",
        "access_policy", "recipe_detail_entitlement", "workout_video_access",
    )), name)
    ordered = sorted(files, key=key)
    return [ordered[len(ordered) * n // 10:len(ordered) * (n + 1) // 10]
            for n in range(10)]


def command_parts(base: list[str], files: list[str]) -> list[list[str]]:
    # Windows CreateProcess limit is 32767 UTF-16 characters, even without cmd.
    parts: list[list[str]] = []
    current = list(base)
    for name in files:
        if name == "test/performance_budget_test.dart":
            if len(current) > len(base):
                parts.append(current)
                current = list(base)
            parts.append([*base, name])
            continue
        candidate = [*current, name]
        if len(subprocess.list2cmdline(candidate)) > 24000:
            parts.append(current)
            current = [*base, name]
        else:
            current = candidate
    if len(current) > len(base):
        parts.append(current)
    return parts


def stop_child(process: subprocess.Popen) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       capture_output=True, check=False)
    else:
        process.terminate()
    process.wait(timeout=30)


def show_live_log(path: Path, finished: threading.Event) -> None:
    """Mirror child output into the invoking terminal while preserving its log."""
    decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
    with path.open("rb") as log:
        while True:
            chunk = log.read(65536)
            if chunk:
                sys.stdout.write(decoder.decode(chunk))
                sys.stdout.flush()
            elif finished.is_set():
                sys.stdout.write(decoder.decode(b"", final=True))
                sys.stdout.flush()
                return
            else:
                finished.wait(0.1)


def run(command: list[str], path: Path, timeout: int) -> dict:
    result = {"command": command, "status": "NOT RUN", "log": str(path)}
    started = time.monotonic()
    process = None
    finished = threading.Event()
    display = None
    try:
        with path.open("wb") as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log,
                                       stderr=subprocess.STDOUT)
            result.update(status="RUNNING", pid=process.pid)
            write_json(path.with_suffix(".json"), result)
            print(f"START {path.stem} pid={process.pid}", flush=True)
            display = threading.Thread(target=show_live_log, args=(path, finished),
                                       daemon=True)
            display.start()
            result["exit_code"] = process.wait(timeout=timeout)
            result["status"] = "PASS" if result["exit_code"] == 0 else "FAIL"
    except subprocess.TimeoutExpired:
        if process is not None:
            stop_child(process)
        result.update(status="FAIL", exit_code=124, reason="timeout")
    except KeyboardInterrupt:
        if process is not None:
            stop_child(process)
        result.update(status="INTERRUPTED", exit_code=130)
        raise
    except OSError as error:
        result.update(status="FAIL", exit_code=1, reason=str(error))
    finally:
        finished.set()
        if display is not None:
            display.join()
        result["seconds"] = round(time.monotonic() - started, 3)
        write_json(path.with_suffix(".json"), result)
        print(f"{result['status']} {path.stem}: exit={result.get('exit_code')} "
              f"in {result['seconds']}s", flush=True)
    return result


def auxiliary_commands(deno: str, node: str) -> list[tuple[str, list[str]]]:
    deno_tests = sorted(p.relative_to(ROOT).as_posix()
                        for p in (ROOT / "supabase/functions").rglob("*_test.ts"))
    sql_tests = sorted(p.relative_to(ROOT).as_posix()
                       for p in (ROOT / "supabase/tests").glob("*_test.mjs"))
    release_tests = sorted(p.relative_to(ROOT).as_posix()
                           for p in (ROOT / "tool/release").glob("*.mjs")
                           if p.name.endswith(("_test.mjs", ".test.mjs")))
    if not deno_tests or not sql_tests or not release_tests:
        raise RuntimeError("Auxiliary test discovery unexpectedly returned an empty suite")
    return [
        ("release_python", [sys.executable, "-m", "unittest", "discover", "-s",
                            "tool/release", "-p", "test_*.py", "-v"]),
        ("backend_deno", [deno, "test", "--no-prompt", "--allow-env",
                          "--allow-read=supabase", "--config=supabase/functions/deno.json",
                          "--lock=supabase/functions/deno.lock", "--frozen", *deno_tests]),
        ("postgres_local", [node, "--test", "--test-concurrency=1", *sql_tests]),
        ("release_node", [node, "--test", "--test-concurrency=1", *release_tests]),
    ]


def pipeline(evidence: Path, command: list[str], batches: list[list[str]],
             timeout: int, auxiliary: list[tuple[str, list[str]]]) -> int:
    """Run all parts of a group, then stop on failure; never resume mid-suite."""
    summary = {"runner_pid": os.getpid(), "analysis": None,
               "batches": [], "status": "RUNNING", "current": "analysis"}

    def publish() -> None:
        summary["updated_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        write_json(evidence / "summary.json", summary)
        write_json(evidence.parent / "latest_full_validation.json", {
            "evidence": str(evidence), "runner_pid": os.getpid(),
            "status": summary["status"], "current": summary["current"],
            "updated_at": summary["updated_at"],
        })

    publish()
    try:
        summary["analysis"] = run([*command, "analyze", "--no-pub"],
                                  evidence / "analysis.log", timeout)
        if summary["analysis"]["status"] != "PASS":
            summary["status"] = "STOPPED_AT_ANALYSIS"
            return 1
        base = [*command, "test", "--no-pub", "--concurrency", "1", "--reporter", "expanded",
                "--dart-define=BIL_CAPTURE_COMMUNITY_REVIEW=false",
                "--dart-define=BIL_CAPTURE_HEALTH_REVIEW=false"]
        for index, batch in enumerate(batches, 1):
            print(f"BATCH {index}/{len(batches)} START: {len(batch)} Flutter files", flush=True)
            parts = [
                *(auxiliary if index == 1 else []),
                *[(f"flutter_{part_no:02d}", part)
                  for part_no, part in enumerate(command_parts(base, batch), 1)],
            ]
            group = {"batch": index, "files": batch, "results": [], "status": "RUNNING"}
            summary["batches"].append(group)
            # No --fail-fast: finish every test command in the failed group.
            for label, part in parts:
                summary["current"] = f"batch_{index:02d}_{label}"
                publish()
                group["results"].append(run(
                    part, evidence / f"batch_{index:02d}_{label}.log", timeout))
                publish()
            passed = all(result["status"] == "PASS" for result in group["results"])
            group["status"] = "PASS" if passed else "FAIL"
            print(f"BATCH {index}/{len(batches)} {group['status']} (all command results):", flush=True)
            for (label, _), result in zip(parts, group["results"]):
                print(f"  {label}: {result['status']}", flush=True)
            summary["status"] = "RUNNING" if passed else f"STOPPED_AT_BATCH_{index}"
            publish()
            if not passed:
                print(f"STOPPED_AFTER_FAILED_BATCH={index}; later batches NOT RUN", flush=True)
                return 1
        summary["status"] = "HOST_SUITE_PASS"
        summary["current"] = "complete"
        return 0
    except KeyboardInterrupt:
        summary["status"] = "INTERRUPTED"
        return 130
    except Exception as error:
        summary.update(status="RUNNER_ERROR", reason=str(error))
        return 1
    finally:
        publish()
        print(f"VALIDATION_STATUS={summary['status']}", flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-root", type=Path, required=True)
    parser.add_argument("--deno-executable", default=shutil.which("deno"))
    parser.add_argument("--node-executable", default=shutil.which("node"))
    parser.add_argument("--list-only", action="store_true")
    parser.add_argument("--timeout", type=int, default=3600)
    args = parser.parse_args(argv)
    dart = args.flutter_root / "bin/cache/dart-sdk/bin" / (
        "dart.exe" if os.name == "nt" else "dart")
    snapshot = args.flutter_root / "bin/cache/flutter_tools.snapshot"
    if not dart.is_file() or not snapshot.is_file():
        parser.error("A populated Flutter SDK is required")
    for name in ("deno_executable", "node_executable"):
        value = getattr(args, name)
        if not value or not Path(value).is_file():
            parser.error(f"A local {name} is required; no tests may be silently omitted")
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    files = sorted(p.relative_to(ROOT).as_posix()
                   for p in (ROOT / "test").rglob("*_test.dart"))
    if len(files) < 10:
        parser.error("Expected at least ten test files")
    batches = groups(files)
    auxiliary = auxiliary_commands(args.deno_executable, args.node_executable)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    evidence = ROOT / "build/diagnostics" / ("full_validation_" + stamp)
    evidence.mkdir(parents=True, exist_ok=False)
    plan = {
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                        text=True).strip(),
        "git_status": subprocess.check_output(["git", "status", "--short"],
                                              cwd=ROOT, text=True),
        "test_file_count": len(files), "batches": batches,
        "auxiliary_batch_1": dict(auxiliary),
        "auxiliary_sha256": {
            p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted({
                *(ROOT / "supabase/functions").rglob("*_test.ts"),
                *(ROOT / "supabase/tests").glob("*_test.mjs"),
                *(ROOT / "tool/release").glob("test_*.py"),
                *(ROOT / "tool/release").glob("*_test.mjs"),
                *(ROOT / "tool/release").glob("*.test.mjs"),
            })
        },
        "test_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                        for name in files},
        "device_integration_NOT_RUN": sorted(p.relative_to(ROOT).as_posix()
                                              for p in (ROOT / "integration_test").rglob("*_test.dart")),
        "note": "Host tests only. Built-in skips are reported in logs, not passes. No device/store test, build, deployment or auto-repair. Stop only after all commands in a failed group finish.",
    }
    write_json(evidence / "plan.json", plan)
    print(f"EVIDENCE={evidence}; FILES={len(files)}; BATCHES=10", flush=True)
    if args.list_only:
        return 0
    try:
        with exclusive_run(evidence.parent / "full_validation.lock"):
            return pipeline(evidence, [str(dart), str(snapshot)], batches,
                            args.timeout, auxiliary)
    except RuntimeError as error:
        print(str(error), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
