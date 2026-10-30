#!/usr/bin/env python3
"""Require a visible Android app frame with accessible interactive content."""

from __future__ import annotations

import argparse
import json
import re
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree

APP_PACKAGE = "com.bilhealth.bodyintelligencelog"
MIN_FOREGROUND_PIXEL_SHARE = 0.05
SYSTEM_UI_PACKAGE = "com.android.systemui"
BOOT_BROADCAST_IDLE_TIMEOUT = 120
BOOT_BROADCAST_IDLE_MARKER = "All broadcast queues are idle!"
WINDOW_FAILURE_CODES = {
    "EMULATOR_SYSTEM_UI_ANR": 20,
    "APP_ANR": 21,
    "EXTERNAL_APP_ANR": 22,
    "FOCUSED_WINDOW_UNAVAILABLE": 23,
}


def capture_failure_diagnostics(evidence: Path) -> None:
    """Bounded read-only capture; no signals, dialog action, root or restart."""
    evidence.mkdir(parents=True, exist_ok=True)
    receipt_path = evidence / "failure-diagnostics.json"
    if receipt_path.exists():
        return  # The prelaunch check and shell EXIT trap share one capture.
    commands = (
        ("last-anr", ["shell", "dumpsys", "activity", "lastanr"]),
        ("system-app-anr", ["shell", "dumpsys", "dropbox", "--print", "system_app_anr"]),
        ("events", ["logcat", "-b", "events", "-d", "-t", "500"]),
        ("cpu", ["shell", "dumpsys", "cpuinfo"]),
        ("threads", ["shell", "ps", "-A", "-T", "-o", "PID,TID,NAME"]),
    )
    rows = []
    limit = 512 * 1024
    for name, arguments in commands:
        command = ["adb", *arguments]
        row = {"command": command, "timeout_seconds": 8,
               "file": f"failure-diagnostic-{name}.txt", "return_code": None}
        with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
            try:
                result = subprocess.run(command, stdout=stdout, stderr=stderr,
                                        timeout=8, check=False)
                row["return_code"] = result.returncode
                row["status"] = "CAPTURED" if result.returncode == 0 else "NONZERO_EXIT"
            except subprocess.TimeoutExpired:
                row["status"] = "TIMEOUT"
            except OSError as error:
                row["status"] = "COMMAND_ERROR"
                row["error"] = str(error)[:1024]
            for stream, suffix, field in ((stdout, "", "stdout_truncated"),
                                           (stderr, ".errors.txt", "stderr_truncated")):
                stream.seek(0)
                data = stream.read(limit + 1)
                row[field] = len(data) > limit
                (evidence / (row["file"] + suffix)).write_bytes(data[:limit])
        rows.append(row)
    receipt_path.write_text(json.dumps({
        "scope": "Read-only failure diagnostics, not startup acceptance",
        "app_startup_proven": False, "commands": rows,
        "saved_byte_limit_per_stream": limit,
    }, indent=2) + "\n", encoding="utf-8")


def _paeth(left: int, up: int, up_left: int) -> int:
    estimate = left + up - up_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    diagonal_distance = abs(estimate - up_left)
    if left_distance <= up_distance and left_distance <= diagonal_distance:
        return left
    if up_distance <= diagonal_distance:
        return up
    return up_left


def inspect_frame(path: Path) -> dict[str, int | float]:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("capture is not a PNG image")

    offset = 8
    compressed = bytearray()
    width = height = bit_depth = color_type = interlace = 0
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        chunk = data[offset + 8 : offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk
            )
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break

    if width <= 0 or height <= 0 or bit_depth != 8 or color_type not in (2, 6):
        raise ValueError("capture must be a non-empty 8-bit RGB/RGBA PNG")
    if interlace != 0:
        raise ValueError("interlaced PNG captures are unsupported")

    bytes_per_pixel = 3 if color_type == 2 else 4
    stride = width * bytes_per_pixel
    raw = zlib.decompress(compressed)
    previous = bytearray(stride)
    colors: Counter[tuple[int, int, int]] = Counter()
    sample_count = 0
    # Ignore Android's status/navigation bars; evaluate only the actual app
    # viewport so system icons cannot make an empty launch window look valid.
    x_start, x_end = width // 10, width - width // 10
    y_start, y_end = height * 15 // 100, height * 85 // 100
    position = 0
    for y in range(height):
        filter_type = raw[position]
        position += 1
        scanline = bytearray(raw[position : position + stride])
        position += stride
        if filter_type > 4:
            raise ValueError(f"unsupported PNG filter {filter_type}")
        for index in range(stride):
            left = scanline[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            up = previous[index]
            up_left = (
                previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            )
            if filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = up
            elif filter_type == 3:
                predictor = (left + up) // 2
            elif filter_type == 4:
                predictor = _paeth(left, up, up_left)
            else:
                predictor = 0
            scanline[index] = (scanline[index] + predictor) & 0xFF

        if y_start <= y < y_end and y % 4 == 0:
            for x in range(x_start + (x_start % 4), x_end, 4):
                pixel = x * bytes_per_pixel
                colors[tuple(scanline[pixel : pixel + 3])] += 1
                sample_count += 1
        previous = scanline

    if not colors or sample_count == 0:
        raise ValueError("capture contains no app viewport pixels")
    dominant_share = max(colors.values()) / sample_count
    return {
        "width": width,
        "height": height,
        "viewport_unique_rgb_colors": len(colors),
        "viewport_dominant_color_share": dominant_share,
        "viewport_foreground_pixel_share": 1.0 - dominant_share,
    }


def frame_is_blank(result: dict[str, int | float]) -> bool:
    return (
        result["viewport_unique_rgb_colors"] < 6
        or result["viewport_foreground_pixel_share"] < MIN_FOREGROUND_PIXEL_SHARE
    )


def has_interactive_app_content(path: Path) -> bool:
    """Reject Android splash/transition trees without an app control."""
    try:
        root = ElementTree.parse(path).getroot()
    except (OSError, ElementTree.ParseError):
        return False

    for node in root.iter("node"):
        if node.get("package") != APP_PACKAGE:
            continue
        if node.get("class") != "android.widget.Button":
            continue
        if node.get("enabled") != "true" or node.get("clickable") != "true":
            continue
        if node.get("content-desc", "").strip() or node.get("text", "").strip():
            return True
    return False


def inspect_window_state(path: Path) -> dict[str, str]:
    """Use actual input focus, never a resumed app behind a system dialog."""
    state = path.read_text(encoding="utf-8", errors="replace")
    # A full WindowManager dump starts with saved LAST ANR state, including
    # historical display/focus lines. Live sections start at POLICY STATE.
    # Scoped display/window dumps have no LAST ANR header and need no slicing.
    history = re.search(r"^WINDOW MANAGER LAST ANR\b", state, re.MULTILINE)
    if history is not None:
        live = re.search(r"^WINDOW MANAGER POLICY STATE\b",
                         state[history.end():], re.MULTILINE)
        # A historical-only dump cannot establish present input focus.
        state = state[history.end() + live.start():] if live is not None else ""
    focuses = re.findall(r"^[ \t]*mCurrentFocus[ \t]*=[ \t]*([^\r\n]*)", state, re.MULTILINE)
    if not focuses:
        focuses = re.findall(r"^[ \t]*mFocusedWindow[ \t]*=[ \t]*([^\r\n]*)", state, re.MULTILINE)
    focuses = list(dict.fromkeys(value.strip() for value in focuses))
    focused_window = " | ".join(focuses)
    result = {"focused_window": focused_window}
    if len(focuses) > 1:
        result["focus_reason"] = "CONFLICTING_LIVE_FOCUS"
    # A live ANR is a blocker even when another live value names the app.
    for candidate in focuses:
        anr = re.search(r"Application Not Responding:\s*([\w.]+)", candidate)
        if anr:
            owner = anr.group(1)
            status = (
                "EMULATOR_SYSTEM_UI_ANR"
                if owner == SYSTEM_UI_PACKAGE
                else "APP_ANR" if owner == APP_PACKAGE else "EXTERNAL_APP_ANR"
            )
            return {**result, "focused_window": candidate,
                    "window_status": status, "anr_package": owner}
    if len(focuses) != 1 or not focused_window or focused_window == "null":
        return {**result, "window_status": "FOCUSED_WINDOW_UNAVAILABLE"}
    app_focused = re.search(
        rf"(?<![\w.]){re.escape(APP_PACKAGE)}(?=[/\s}}]|$)", focused_window
    )
    return {
        **result,
        "window_status": "APP_FOCUSED" if app_focused else "OTHER_FOCUSED_WINDOW",
    }


def window_check_exit_code(
    result: dict[str, str], *, require_app_focus: bool
) -> int:
    status = result["window_status"]
    if status in WINDOW_FAILURE_CODES:
        return WINDOW_FAILURE_CODES[status]
    if require_app_focus and status != "APP_FOCUSED":
        return 1
    return 0


def report_window_state(path: Path, *, require_app_focus: bool) -> int:
    try:
        result = inspect_window_state(path)
    except OSError as error:
        print(f"invalid focused-window capture: {error}", file=sys.stderr)
        return 2
    for name, value in result.items():
        print(f"{name}={value}")
    exit_code = window_check_exit_code(result, require_app_focus=require_app_focus)
    if exit_code:
        print(
            f"{result['window_status']}: focused Android window does not prove "
            "interactive BIL content; no dialog was dismissed or accepted.",
            file=sys.stderr,
        )
    return exit_code


def _capture_prelaunch_blocker(evidence: Path, exit_code: int) -> None:
    """Preserve the failed attempt; never dismiss a dialog or restart a process."""
    (evidence / "prelaunch-failure.txt").write_text(
        f"exit_status={exit_code}\nstage=verify-emulator-system-ui-before-launch\n",
        encoding="utf-8",
    )
    capture_failure_diagnostics(evidence)
    captures = (
        ("failure-screen.png", ["exec-out", "screencap", "-p"]),
        ("prelaunch-logcat.txt", ["logcat", "-d", "-t", "1500"]),
        (
            "prelaunch-uiautomator.txt",
            ["shell", "uiautomator", "dump", "/sdcard/bil-prelaunch-failure.xml"],
        ),
        (
            "prelaunch-pull.txt",
            [
                "pull",
                "/sdcard/bil-prelaunch-failure.xml",
                str(evidence / "prelaunch-failure-window.xml"),
            ],
        ),
    )
    for filename, arguments in captures:
        try:
            result = subprocess.run(
                ["adb", *arguments], capture_output=True, timeout=15, check=False
            )
            (evidence / filename).write_bytes(result.stdout)
            if result.returncode or result.stderr:
                (evidence / f"{filename}.errors.txt").write_bytes(result.stderr)
        except (OSError, subprocess.TimeoutExpired) as error:
            (evidence / f"{filename}.errors.txt").write_text(
                str(error), encoding="utf-8"
            )


def wait_for_boot_broadcast_idle(evidence: Path) -> bool:
    """Wait for actual broadcast completion, beyond sys.boot_completed=1."""
    command = ["adb", "shell", "cmd", "activity", "wait-for-broadcast-idle"]
    started = time.monotonic()
    stdout = stderr = ""
    return_code = None
    status = "COMMAND_ERROR"
    print(
        f"Waiting for Android boot broadcasts (limit={BOOT_BROADCAST_IDLE_TIMEOUT}s).",
        flush=True,
    )
    try:
        for attempt in range(3):
            remaining = BOOT_BROADCAST_IDLE_TIMEOUT - (time.monotonic() - started)
            if remaining <= 0:
                raise subprocess.TimeoutExpired(command, BOOT_BROADCAST_IDLE_TIMEOUT)
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=BOOT_BROADCAST_IDLE_TIMEOUT if attempt == 0 else remaining,
                check=False,
            )
            # ActivityManager may restart during Android 29 boot. Retry only
            # this interrupted Binder read, before any app installation/launch.
            # The genuine idle marker and the total time limit remain required.
            interrupted = result.returncode != 0 and "Broken pipe" in (
                result.stdout + result.stderr
            )
            if not interrupted or attempt == 2:
                break
            time.sleep(1)
        stdout, stderr, return_code = result.stdout, result.stderr, result.returncode
        marker_found = BOOT_BROADCAST_IDLE_MARKER in (
            line.strip() for line in stdout.splitlines()
        )
        status = (
            "IDLE" if return_code == 0 and marker_found
            else "NONZERO_EXIT" if return_code != 0
            else "INVALID_IDLE_OUTPUT"
        )
    except subprocess.TimeoutExpired as error:
        status = "TIMEOUT"
        stdout = error.stdout or ""
        stderr = error.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        stderr += f"\nBoot broadcast idle timed out after {BOOT_BROADCAST_IDLE_TIMEOUT}s."
    except OSError as error:
        stderr = str(error)
    receipt = {
        "command": command,
        "timeout_seconds": BOOT_BROADCAST_IDLE_TIMEOUT,
        "elapsed_seconds": round(time.monotonic() - started, 3),
        "adb_return_code": return_code,
        "status": status,
        "broadcast_idle_confirmed": status == "IDLE",
        "app_startup_proven": False,
    }
    (evidence / "prelaunch-boot-idle.stdout.txt").write_text(stdout, encoding="utf-8")
    (evidence / "prelaunch-boot-idle.stderr.txt").write_text(stderr, encoding="utf-8")
    (evidence / "prelaunch-boot-idle-receipt.json").write_text(
        json.dumps(receipt, indent=2) + "\n", encoding="utf-8"
    )
    return status == "IDLE"


def verify_emulator_before_launch(evidence: Path) -> int:
    """Check System UI and input focus before any APK installation or launch."""
    evidence.mkdir(parents=True, exist_ok=True)
    if not wait_for_boot_broadcast_idle(evidence):
        print("EMULATOR_BOOT_BROADCAST_NOT_IDLE: launch blocked.", file=sys.stderr)
        _capture_prelaunch_blocker(evidence, 25)
        return 25
    for attempt in range(15):
        try:
            pid = subprocess.run(
                ["adb", "shell", "pidof", SYSTEM_UI_PACKAGE],
                capture_output=True, text=True, timeout=15, check=False,
            )
            window = subprocess.run(
                ["adb", "shell", "dumpsys", "window"],
                capture_output=True, text=True, timeout=15, check=False,
            )
            (evidence / "prelaunch-system-ui-pid.txt").write_text(
                pid.stdout, encoding="utf-8"
            )
            window_path = evidence / "prelaunch-focused-window.txt"
            window_path.write_text(window.stdout, encoding="utf-8")
            (evidence / "prelaunch-adb-errors.txt").write_text(
                pid.stderr + window.stderr, encoding="utf-8"
            )
            status = inspect_window_state(window_path)
            (evidence / "prelaunch-window-check.txt").write_text(
                "".join(f"{key}={value}\n" for key, value in status.items()),
                encoding="utf-8",
            )
            code = window_check_exit_code(status, require_app_focus=False)
            if code in (20, 21, 22):
                print(f"{status['window_status']}: emulator launch blocked.", file=sys.stderr)
                _capture_prelaunch_blocker(evidence, code)
                return code
            if pid.returncode == 0 and pid.stdout.strip() and window.returncode == 0 and code == 0:
                return 0
        except (OSError, subprocess.TimeoutExpired) as error:
            (evidence / "prelaunch-adb-errors.txt").write_text(
                str(error), encoding="utf-8"
            )
        if attempt < 14:
            time.sleep(2)
    print(
        "EMULATOR_SYSTEM_UI_UNAVAILABLE: System UI/focused window was not ready "
        "before launching BIL.",
        file=sys.stderr,
    )
    _capture_prelaunch_blocker(evidence, 24)
    return 24


def startup_is_ready(
    frame_result: dict[str, int | float],
    accessibility_tree: Path,
    window_state: Path | None = None,
) -> bool:
    if window_state is not None:
        try:
            focus = inspect_window_state(window_state)
        except OSError:
            return False
        if window_check_exit_code(focus, require_app_focus=True):
            return False
    return not frame_is_blank(frame_result) and has_interactive_app_content(
        accessibility_tree
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("screenshot", nargs="?", type=Path)
    parser.add_argument("accessibility_tree", nargs="?", type=Path)
    parser.add_argument("--window-state", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--window-health-only", action="store_true")
    parser.add_argument("--require-app-focus", action="store_true")
    mode.add_argument("--verify-emulator-before-launch", type=Path)
    mode.add_argument("--capture-failure-diagnostics", type=Path)
    args = parser.parse_args(argv)
    if args.capture_failure_diagnostics is not None:
        if (args.screenshot is not None or args.accessibility_tree is not None or
                args.window_state is not None or args.require_app_focus):
            parser.error("diagnostics cannot be combined with startup acceptance inputs")
        capture_failure_diagnostics(args.capture_failure_diagnostics)
        print("diagnostics_only=true; app_startup_proven=false")
        return 0
    if args.verify_emulator_before_launch is not None:
        return verify_emulator_before_launch(args.verify_emulator_before_launch)
    if args.window_health_only:
        if args.window_state is None:
            parser.error("--window-health-only requires --window-state")
        return report_window_state(
            args.window_state, require_app_focus=args.require_app_focus
        )
    if args.screenshot is None or args.accessibility_tree is None:
        parser.error("a screenshot and accessibility tree are required")
    if args.window_state is not None:
        window_exit = report_window_state(args.window_state, require_app_focus=True)
        if window_exit:
            return window_exit
    try:
        result = inspect_frame(args.screenshot)
    except (OSError, ValueError, zlib.error) as error:
        print(f"invalid startup capture: {error}", file=sys.stderr)
        return 2
    for name, value in result.items():
        print(f"{name}={value}")
    if frame_is_blank(result):
        print(
            "Android app viewport has too little foreground detail to prove "
            "the startup screen is visible.",
            file=sys.stderr,
        )
        return 1
    if not has_interactive_app_content(args.accessibility_tree):
        print(
            "Android accessibility tree has no enabled, clickable app button; "
            "the capture may still be the native splash or transition frame.",
            file=sys.stderr,
        )
        return 1
    print("accessible_interactive_app_content=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
