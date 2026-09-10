"""Record a code-only audit command without confusing a started gate with a pass.

The caller must review commands for scope; this is not a command sandbox. Logs
stay in ignored build/diagnostics, and a result is written even for timeouts.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import time


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "build/diagnostics/prebuild_code_audit_20260910"


def run_gate(name: str, command: list[str], *, cwd: Path = ROOT,
             timeout: float = 3600) -> int:
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", name):
        raise ValueError("Gate name must be a simple identifier")
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    prefix = EVIDENCE / f"{name}_{stamp}"
    result = {
        "name": name, "command": command, "cwd": str(cwd),
        "started_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "status": "NOT RUN", "log": str(prefix.with_suffix(".log")),
    }
    started = time.monotonic()
    process = None
    exit_code = 1
    try:
        with prefix.with_suffix(".log").open("wb") as log:
            process = subprocess.Popen(command, cwd=cwd, stdout=log,
                                       stderr=subprocess.STDOUT)
            print(f"START {name} pid={process.pid} log={result['log']}", flush=True)
            exit_code = process.wait(timeout=timeout)
            result["status"] = "PASS" if exit_code == 0 else "FAIL"
    except subprocess.TimeoutExpired:
        result["status"] = "FAIL"
        result["reason"] = f"Command exceeded {timeout} seconds"
        exit_code = 124
        if process is not None:
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               capture_output=True, check=False)
            else:
                process.kill()
            process.wait()
    except OSError as error:
        result["reason"] = f"Could not execute command: {error}"
    finally:
        result["exit_code"] = exit_code
        result["duration_seconds"] = round(time.monotonic() - started, 3)
        result["finished_at"] = dt.datetime.now(dt.timezone.utc).isoformat()
        prefix.with_suffix(".json").write_text(
            json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result), flush=True)
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name")
    parser.add_argument("--cwd", type=Path, default=ROOT)
    parser.add_argument("--timeout", type=float, default=3600)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("A command is required after --")
    return run_gate(args.name, command, cwd=args.cwd, timeout=args.timeout)


if __name__ == "__main__":
    raise SystemExit(main())
