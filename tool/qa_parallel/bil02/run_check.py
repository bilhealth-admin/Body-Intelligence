#!/usr/bin/env python3
"""Run an unchanged check and retain its command, source identity and full log."""

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import time
from pathlib import Path

BASE = "1744788e6bfbdffc3a168bbaf36b3abf3e2c698a"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a command is required")
    root = Path.cwd()
    def git(*items):
        return subprocess.check_output(["git", *items], cwd=root).decode().strip()
    changed = set(git("diff", "--name-only", BASE).splitlines())
    changed.update(git("ls-files", "--others", "--exclude-standard").splitlines())
    source = []
    for name in sorted(changed):
        path = root / name
        if path.suffix not in {".dart", ".py", ".yaml", ".lock"}:
            continue
        source.append({
            "path": name,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()
            if path.is_file() else None,
        })
    identity = {"base_sha": BASE, "changes": source}
    digest = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
    args.evidence.mkdir(parents=True, exist_ok=True)
    result = {
        "id": args.id,
        "command": command,
        "cwd": str(root),
        "head": git("rev-parse", "HEAD"),
        "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "environment": {key: os.environ.get(key) for key in [
            "PUB_CACHE", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "CI",
            "FLUTTER_SUPPRESS_ANALYTICS", "DART_SUPPRESS_ANALYTICS",
        ]},
        "source": identity,
        "tested_source_digest": digest,
        "log": args.id + ".log",
    }
    started = time.monotonic()
    with (args.evidence / result["log"]).open("wb") as log:
        try:
            completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
            result["exit_code"] = completed.returncode
            result["status"] = "PASS" if completed.returncode == 0 else "FAIL"
        except OSError as error:
            result.update(exit_code=None, status="NOT_RUN", reason=str(error))
    result["duration_seconds"] = round(time.monotonic() - started, 3)
    result["log_sha256"] = hashlib.sha256(
        (args.evidence / result["log"]).read_bytes()
    ).hexdigest()
    (args.evidence / (args.id + ".json")).write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    print(json.dumps({key: result[key] for key in [
        "id", "status", "exit_code", "duration_seconds", "tested_source_digest", "log",
    ]}))
    return result["exit_code"] or (0 if result["status"] == "PASS" else 1)


if __name__ == "__main__":
    raise SystemExit(main())
