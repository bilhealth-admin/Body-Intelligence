#!/usr/bin/env python3
"""Bound one owned native QA command, keeping its raw log and honest result.

Flutter 3.44.6 drive creates its --timeout timer only through the optional
--screenshot registration. These runners require an OS bound independently
of that SDK path, including a stalled driver after a native test summary.
"""

import argparse
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import sys
import threading
import time


ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
COUNTER = re.compile(r"\b\d{1,2}:\d{2}(?:\.\d+)? \+\d+(?: -\d+)?: (.+)")
SUMMARY = re.compile(r"^(All tests passed|Some tests failed)[.!]\s*$")


def positive_seconds(value):
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise argparse.ArgumentTypeError("timeout must be finite and positive")
    return result


def _stop_windows_owned_tree(process, grace):
    """Bound every cleanup attempt; only a Popen handle/owned group is used.

    taskkill success is a command result, not proof that every descendant was
    reaped. In particular, an exited parent and an inherited pipe do not give
    us an authoritative descendant inventory.
    """
    result = {"platform": "nt", "parent_pid": process.pid,
              "parent_reaped": False, "descendants_reaped": None,
              "tree_kill_succeeded": None, "actions": [], "errors": []}
    wait_budget = max(.1, min(float(grace), 5))

    def error(action, failure):
        # TimeoutExpired.__str__ includes argv; never log it or a possible token.
        result["errors"].append({"action": action, "type": type(failure).__name__})

    def reaped():
        try:
            code = process.poll()
            if code is not None:
                result["parent_reaped"] = True
                result["parent_returncode"] = code
                return True
        except Exception as failure:
            error("poll", failure)
        return False

    def wait(action):
        try:
            code = process.wait(timeout=wait_budget)
            result["parent_reaped"] = True
            result["parent_returncode"] = code
            return True
        except Exception as failure:
            error(action, failure)
            return reaped()

    if reaped():
        return result
    killer = None
    try:
        result["actions"].append("taskkill_owned_tree")
        # run(timeout=...) performs its own communicate/wait during exception
        # cleanup. Use a pipe-free Popen without a context manager so even a
        # slow/failing helper kill cannot introduce an unbounded implicit wait.
        killer = subprocess.Popen(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        result["taskkill_helper_pid"] = killer.pid
        code = killer.wait(timeout=max(wait_budget, 1))
        result["tree_kill_succeeded"] = code == 0
        result["taskkill_returncode"] = code
    except Exception as failure:
        error("taskkill_owned_tree", failure)
    finally:
        if killer is not None:
            try:
                if killer.poll() is None:
                    try:
                        killer.kill()
                    except Exception as failure:
                        error("kill_taskkill_helper_handle", failure)
                    try:
                        killer.wait(timeout=min(wait_budget, 1))
                    except Exception as failure:
                        error("wait_taskkill_helper", failure)
                result["taskkill_helper_reaped"] = killer.poll() is not None
            except Exception as failure:
                result["taskkill_helper_reaped"] = False
                error("poll_taskkill_helper", failure)
    if reaped():
        return result
    # CREATE_NEW_PROCESS_GROUP is set by run_bounded. Never signal a caller's
    # arbitrary group, and do not use image-name or broad PID discovery kills.
    if getattr(process, "_bil_owned_process_group", False) is True:
        try:
            result["actions"].append("ctrl_break_owned_group")
            process.send_signal(signal.CTRL_BREAK_EVENT)
        except Exception as failure:
            error("ctrl_break_owned_group", failure)
        if wait("wait_after_ctrl_break"):
            return result
    try:
        result["actions"].append("kill_owned_parent_handle")
        # Windows Popen.kill uses its retained process handle, not a new PID
        # lookup. It cannot establish that grandchildren have terminated.
        process.kill()
    except Exception as failure:
        error("kill_owned_parent_handle", failure)
    wait("wait_after_parent_kill")
    return result


def _stop_owned_tree(process, grace):
    """Only the child/session created by this invocation may be terminated."""
    if os.name == "posix":
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            pass
        # A child may retain the pipe after its immediate parent has exited.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    else:
        return _stop_windows_owned_tree(process, grace)
    try:
        process.wait(timeout=max(grace, 1))
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def run_bounded(command, *, label, log_path, receipt_path, timeout_seconds,
                running_timeout_seconds=None, summary_grace_seconds=60,
                kill_grace_seconds=5):
    log_path, receipt_path = Path(log_path), Path(receipt_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    receipt_path.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    deadline = started + timeout_seconds
    phase, reason = "bootstrap", "process_exit"
    first_test_at = terminal_at = None
    native_summary, native_failed = None, False
    interrupted = []
    previous_signals = {}
    process = None
    raw_returncode = None
    timed_out = False
    supervisor_error = None
    cleanup_attempted = False
    cleanup = None
    output_hash = hashlib.sha256()
    output_bytes = 0
    chunks = queue.Queue()
    reader = None
    eof = False
    output_drain_limited = False
    for sig in (signal.SIGTERM, signal.SIGINT):
        previous_signals[sig] = signal.signal(
            sig, lambda received, _frame: interrupted.append(received),
        )

    def cleanup_once():
        nonlocal cleanup_attempted, cleanup
        if cleanup_attempted or process is None:
            return
        cleanup_attempted = True
        try:
            cleanup = _stop_owned_tree(process, kill_grace_seconds)
        except Exception as error:
            # Cleanup must not replace the original timeout/failure or prevent
            # the receipt, even if a platform/helper has another failure.
            cleanup = {"parent_pid": process.pid, "parent_reaped": False,
                       "descendants_reaped": None,
                       "errors": [{"action": "stop_owned_tree",
                                   "type": type(error).__name__}]}

    def consume(raw, stream):
        nonlocal deadline, phase, first_test_at, terminal_at
        nonlocal native_summary, native_failed, output_bytes
        stream.write(raw)
        stream.flush()
        output_hash.update(raw)
        output_bytes += len(raw)
        sys.stdout.buffer.write(raw)
        sys.stdout.buffer.flush()
        text = ANSI.sub("", raw.decode("utf-8", errors="replace")).strip()
        match = COUNTER.search(text)
        if match is None or match.group(1).lower().startswith("loading "):
            return
        now = time.monotonic()
        if first_test_at is None:
            first_test_at = now
            phase = "native_tests"
            if running_timeout_seconds is not None:
                deadline = now + running_timeout_seconds
        if SUMMARY.fullmatch(match.group(1)):
            native_failed = native_failed or "Some tests failed" in match.group(1)
            if terminal_at is None:
                terminal_at = now
                native_summary = match.group(0)
                phase = "result_delivery"
                deadline = min(deadline, now + summary_grace_seconds)

    try:
        options = {"start_new_session": True} if os.name == "posix" else {
            "creationflags": subprocess.CREATE_NEW_PROCESS_GROUP,
        }
        print(f"BIL_NATIVE_STAGE {label}: starting (OS deadline enabled)", flush=True)
        process = subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **options,
        )
        process._bil_owned_process_group = os.name != "posix"

        def read_output():
            try:
                for raw in iter(process.stdout.readline, b""):
                    chunks.put(raw)
            finally:
                chunks.put(None)

        reader = threading.Thread(target=read_output, daemon=True)
        reader.start()
        last_heartbeat = started
        with log_path.open("wb") as stream:
            while not (eof and process.poll() is not None):
                try:
                    raw = chunks.get(timeout=.1)
                    if raw is None:
                        eof = True
                    else:
                        consume(raw, stream)
                except queue.Empty:
                    pass
                now = time.monotonic()
                if now - last_heartbeat >= 30:
                    print(f"BIL_NATIVE_STAGE {label}: {phase}, "
                          f"elapsed={int(now-started)}s", flush=True)
                    last_heartbeat = now
                if interrupted or now >= deadline:
                    timed_out = not interrupted
                    reason = "interrupted" if interrupted else {
                        "bootstrap": "bootstrap_timeout",
                        "native_tests": "native_test_timeout",
                        "result_delivery": "result_delivery_timeout",
                    }[phase]
                    cleanup_once()
                    reader.join(timeout=1)
                    # An unreaped child may keep emitting; draining that queue
                    # must not undo the OS bound or prevent the receipt either.
                    drain_deadline = time.monotonic() + .5
                    for _ in range(1024):
                        if time.monotonic() >= drain_deadline:
                            output_drain_limited = True
                            break
                        try:
                            raw = chunks.get_nowait()
                        except queue.Empty:
                            break
                        if raw is not None:
                            consume(raw, stream)
                        else:
                            eof = True
                    else:
                        output_drain_limited = True
                    break
            raw_returncode = process.poll() if cleanup_attempted else process.wait(timeout=5)
    except Exception as error:
        supervisor_error = type(error).__name__
        if not (timed_out or interrupted):
            reason = f"supervisor_error:{supervisor_error}"
    finally:
        if process is not None:
            try:
                if process.poll() is None:
                    cleanup_once()
                observed = process.poll()
                if observed is not None:
                    raw_returncode = observed
            except Exception as error:
                supervisor_error = supervisor_error or type(error).__name__
        for sig, handler in previous_signals.items():
            try:
                signal.signal(sig, handler)
            except Exception as error:
                supervisor_error = supervisor_error or type(error).__name__

    exit_code = (
        128 + interrupted[0] if interrupted else
        124 if timed_out else
        127 if raw_returncode is None else
        raw_returncode if raw_returncode != 0 else
        2 if supervisor_error is not None else
        1 if native_failed else 0
    )
    if raw_returncode == 0 and native_failed and not timed_out:
        reason = "native_failure_summary_with_zero_process_exit"
    receipt = {
        "label": label,
        "started_at_utc": dt.datetime.fromtimestamp(
            time.time() - (time.monotonic() - started), dt.timezone.utc,
        ).isoformat(),
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "bootstrap_timeout_seconds": timeout_seconds,
        "native_test_timeout_seconds": running_timeout_seconds,
        "summary_grace_seconds": summary_grace_seconds,
        "first_test_after_seconds": None if first_test_at is None else round(first_test_at-started, 3),
        "terminal_summary_after_seconds": None if terminal_at is None else round(terminal_at-started, 3),
        "native_summary": native_summary,
        "native_failure_summary_seen": native_failed,
        "timed_out": timed_out,
        "reason": reason,
        "raw_returncode": raw_returncode,
        "supervisor_error": supervisor_error,
        "cleanup_attempted": cleanup_attempted,
        "cleanup": cleanup,
        "effective_returncode": exit_code,
        "output_bytes": output_bytes,
        "output_sha256": output_hash.hexdigest(),
        "output_complete": eof and not output_drain_limited,
        "output_drain_limited": output_drain_limited,
        "success_basis": "process exit 0 and no native failure summary; never inferred from a log alone",
    }
    receipt_path.write_bytes((json.dumps(receipt, indent=2) + "\n").encode("utf-8"))
    print(f"BIL_NATIVE_STAGE {label}: {reason}, exit={exit_code}", flush=True)
    return exit_code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--timeout-seconds", type=positive_seconds, required=True)
    parser.add_argument("--running-timeout-seconds", type=positive_seconds)
    parser.add_argument("--summary-grace-seconds", type=positive_seconds, default=60)
    parser.add_argument("--kill-grace-seconds", type=positive_seconds, default=5)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or re.fullmatch(r"[A-Za-z0-9_.-]{1,100}", args.label) is None:
        parser.error("a safe stage label and an explicit command are required")
    return run_bounded(
        command, label=args.label, log_path=args.log, receipt_path=args.receipt,
        timeout_seconds=args.timeout_seconds,
        running_timeout_seconds=args.running_timeout_seconds,
        summary_grace_seconds=args.summary_grace_seconds,
        kill_grace_seconds=args.kill_grace_seconds,
    )


if __name__ == "__main__":
    raise SystemExit(main())
