#!/usr/bin/env python3
"""Run one local verification command with immutable-input evidence.

No network, SDK, or repository configuration is changed by this runner.
The invoked command is responsible for its own local-only behavior.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time
from datetime import datetime, timezone


def snapshot(root: Path, inputs: list[str]) -> dict:
    files: dict[str, str] = {}
    for item in inputs:
        target = root / item
        if not target.exists():
            raise FileNotFoundError(f"Missing verification input: {item}")
        candidates = target.rglob("*") if target.is_dir() else [target]
        for path in candidates:
            if not path.is_file() or any(
                part in {"__pycache__", ".dart_tool", "build", ".git"}
                for part in path.relative_to(root).parts
            ):
                continue
            files[path.relative_to(root).as_posix()] = hashlib.sha256(
                path.read_bytes()
            ).hexdigest()
    ordered = dict(sorted(files.items()))
    canonical = json.dumps(ordered, sort_keys=True, separators=(",", ":"))
    return {
        "algorithm": "sha256(compact sorted JSON {relative_path: file_sha256})",
        "digest": hashlib.sha256(canonical.encode()).hexdigest(),
        "file_count": len(ordered),
        "files": ordered,
    }


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--input", action="append", dest="inputs", required=True)
    parser.add_argument("--context", default="Local synthetic verification")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("Provide a command after --")
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", args.name):
        parser.error("Use a plain evidence name")
    root = args.root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = snapshot(root, args.inputs)
    write_json(output / f"{args.name}.sources_before.json", before)
    started = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    log_path = output / f"{args.name}.log"
    launch_error = None
    with log_path.open("w") as log:
        try:
            result = subprocess.run(
                command, cwd=root, stdout=log, stderr=subprocess.STDOUT,
                check=False, text=True,
            )
            code = result.returncode
        except OSError as error:
            launch_error = str(error)
            log.write(launch_error + "\n")
            code = 127
    elapsed = time.monotonic() - tick
    after = snapshot(root, args.inputs)
    write_json(output / f"{args.name}.sources_after.json", after)
    log_text = log_path.read_text(errors="replace")
    test_match = re.search(r"\+(\d+)(?:[^\n]*)All tests passed!", log_text)
    metadata = {
        "name": args.name,
        "status": "NOT_RUN" if launch_error else "PASS" if code == 0 else "FAIL",
        "exit_code": code,
        "command": command,
        "cwd": str(root),
        "context": args.context,
        "started_at_utc": started,
        "ended_at_utc": datetime.now(timezone.utc).isoformat(),
        "duration_seconds": round(elapsed, 3),
        "environment": {
            "platform": platform.platform(),
            "python": platform.python_version(),
            "uid": os.getuid(),
            "flutter_required": "3.44.6",
            "dart_required": "3.12.2",
            "runtime_version_evidence": "tests/runtime/flutter-version.log and dart-version.log",
        },
        "input_paths": args.inputs,
        "source_digest_before": before["digest"],
        "source_digest_after": after["digest"],
        "source_unchanged": before["digest"] == after["digest"],
        "source_manifest_before": f"{args.name}.sources_before.json",
        "source_manifest_after": f"{args.name}.sources_after.json",
        "test_count_if_flutter_expanded_success": int(test_match[1]) if test_match else None,
        "log": log_path.name,
        "log_sha256": hashlib.sha256(log_path.read_bytes()).hexdigest(),
        "launch_error": launch_error,
    }
    write_json(output / f"{args.name}.json", metadata)
    print(json.dumps({key: metadata[key] for key in (
        "name", "status", "exit_code", "duration_seconds", "source_unchanged",
        "test_count_if_flutter_expanded_success", "source_digest_after",
    )}))
    return code


if __name__ == "__main__":
    sys.exit(main())
