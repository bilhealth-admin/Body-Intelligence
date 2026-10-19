#!/usr/bin/env python3
"""Retry an iOS build only for the confirmed transient sqlite3 GitHub DNS error."""

from __future__ import annotations

import os
import subprocess
import sys
import time


MAX_ATTEMPTS = 3
SQLITE_FAILURE = "Building assets for package:sqlite3 failed."
GITHUB_DNS_FAILURE = "Failed host lookup: 'github.com'"


def _retry_delay() -> int:
    raw = os.environ.get("BIL_SQLITE_NATIVE_ASSET_RETRY_DELAY_SECONDS", "15")
    if not raw.isascii() or not raw.isdecimal():
        raise ValueError("BIL_SQLITE_NATIVE_ASSET_RETRY_DELAY_SECONDS must be an integer from 0 to 60.")
    seconds = int(raw)
    if seconds > 60:
        raise ValueError("BIL_SQLITE_NATIVE_ASSET_RETRY_DELAY_SECONDS must be an integer from 0 to 60.")
    return seconds


def _run_once(command: list[str]) -> tuple[int, bool, bool]:
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
    except OSError as error:
        print(f"Could not start iOS build command: {error}", file=sys.stderr)
        return 127, False, False

    saw_sqlite_failure = False
    saw_github_dns_failure = False
    assert process.stdout is not None
    try:
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            saw_sqlite_failure |= SQLITE_FAILURE in line
            saw_github_dns_failure |= GITHUB_DNS_FAILURE in line
        return process.wait(), saw_sqlite_failure, saw_github_dns_failure
    except KeyboardInterrupt:
        process.terminate()
        process.wait()
        raise
    finally:
        process.stdout.close()


def main(argv: list[str]) -> int:
    if argv and argv[0] == "--":
        argv = argv[1:]
    if not argv:
        print(f"Usage: {sys.argv[0]} -- command [arguments...]", file=sys.stderr)
        return 64

    try:
        delay = _retry_delay()
    except ValueError as error:
        print(error, file=sys.stderr)
        return 64

    for attempt in range(1, MAX_ATTEMPTS + 1):
        print(f"Running iOS build command (attempt {attempt}/{MAX_ATTEMPTS}).", flush=True)
        status, saw_sqlite_failure, saw_github_dns_failure = _run_once(argv)
        if status == 0:
            return 0
        if attempt == MAX_ATTEMPTS or not (saw_sqlite_failure and saw_github_dns_failure):
            return status if status >= 0 else 128 - status

        next_attempt = attempt + 1
        print(
            "Transient sqlite3 GitHub DNS lookup failed; "
            f"retrying after {delay}s ({next_attempt}/{MAX_ATTEMPTS}).",
            file=sys.stderr,
            flush=True,
        )
        time.sleep(delay)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
