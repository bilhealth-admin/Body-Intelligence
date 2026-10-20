#!/usr/bin/env python3
"""Read-only clean-boot readiness before the action's original MENU key event."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

from android_startup_focus_controller import current_focus_value, fresh_boot_anr_lines

EXPECTED_HOME = "com.google.android.apps.nexuslauncher"
MAX_LOG_BYTES = 64 * 1024 * 1024


def inspect_state(properties: dict[str, str], window: str, home: str, log: str) -> tuple[bool, str]:
    if fresh_boot_anr_lines(log):
        raise ValueError("FRESH_CLEAN_BOOT_ANR")
    focus = current_focus_value(window)
    if "Application Not Responding:" in focus or re.search(r"\b(?:ANR|Application Error):", focus):
        raise ValueError("CURRENT_FOCUS_ERROR_DIALOG")
    if properties != {"boot_completed": "1", "boot_animation": "stopped", "device_provisioned": "1", "user_setup_complete": "1"}:
        return False, "BOOT_OR_PROVISIONING_INCOMPLETE"
    components = re.findall(r"^\s*([A-Za-z][\w.]*/[A-Za-z.$][\w.$]*)\s*$", home, re.MULTILINE)
    if len(components) != 1 or components[0].split("/", 1)[0] != EXPECTED_HOME:
        return False, "RESOLVED_HOME_NOT_EXPECTED"
    package, activity = components[0].split("/", 1)
    component = package + "/" + (package + activity if activity.startswith(".") else activity)
    focused_components = re.findall(r"\b([A-Za-z][\w.]*/[A-Za-z.$][\w.$]*)(?:\s|\})", focus)
    normalized_focus = []
    for candidate in focused_components:
        focused_package, focused_activity = candidate.split("/", 1)
        normalized_focus.append(focused_package + "/" + (focused_package + focused_activity if focused_activity.startswith(".") else focused_activity))
    if normalized_focus != [component]:
        return False, "FOCUSED_HOME_NOT_READY"
    return True, "HEALTHY_FOCUSED_HOME"


def execute(adb: Path, port: int, args: list[str], deadline: float) -> str:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("PRE_INPUT_READINESS_DEADLINE")
    result = subprocess.run([str(adb), "-s", f"emulator-{port}", *args], capture_output=True, text=True, timeout=min(15, remaining), check=True)
    if len(result.stdout.encode()) > 4 * 1024 * 1024:
        raise ValueError("BOUNDED_ADB_RESPONSE_EXCEEDED")
    return result.stdout.strip()


def clean_boot_log(evidence: Path) -> str:
    path = evidence / "full-boot-logcat.txt"
    if not path.is_file() or not 0 < path.stat().st_size <= MAX_LOG_BYTES:
        raise ValueError("COMPLETE_CLEAN_BOOT_LOG_MISSING_OR_OVERSIZED")
    return path.read_text(errors="replace")


def run(port: int) -> None:
    if port != 5554:
        raise ValueError("UNEXPECTED_EMULATOR_PORT")
    api = os.environ["BIL_ANDROID_EMULATOR_API"]
    if api not in ("34", "35"):
        raise ValueError("UNEXPECTED_API")
    evidence = Path(os.environ["BIL_FROZEN_APP_ROOT"]) / "artifacts/release/android_emulator_smoke" / f"api-{api}"
    evidence.mkdir(parents=True, exist_ok=True)
    adb = Path(os.environ["ANDROID_HOME"]) / "platform-tools/adb"
    if not adb.is_file() or not os.access(adb, os.X_OK):
        raise ValueError("EXACT_SDK_ADB_MISSING")
    started = time.monotonic()
    deadline = started + 120
    receipt = {"classification": "PRE_INPUT_DEVICE_READINESS_ONLY", "application_startup_proven": False,
               "app_source": "5775d082a1b4c7a29e4ed4d6e01693b31923dc31", "controller_source": os.environ.get("BIL_CONTROLLER_SOURCE"),
               "boot_attempts": 1, "input_events_sent_by_guard": 0, "original_key_event_preserved_in_action": True,
               "fresh_boot_ANR_ignored": False, "timeout_seconds": 120, "observations": [], "ready_for_original_key_event": False}
    stable_since = None
    stable_samples = 0
    try:
        while time.monotonic() < deadline:
            log = clean_boot_log(evidence)
            properties = {
                "boot_completed": execute(adb, port, ["shell", "getprop", "sys.boot_completed"], deadline),
                "boot_animation": execute(adb, port, ["shell", "getprop", "init.svc.bootanim"], deadline),
                "device_provisioned": execute(adb, port, ["shell", "settings", "get", "global", "device_provisioned"], deadline),
                "user_setup_complete": execute(adb, port, ["shell", "settings", "get", "secure", "user_setup_complete"], deadline),
            }
            home = execute(adb, port, ["shell", "cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.HOME"], deadline)
            window = execute(adb, port, ["shell", "dumpsys", "window"], deadline)
            now = time.monotonic()
            if now >= deadline:
                raise TimeoutError("PRE_INPUT_READINESS_DEADLINE")
            ready, state = inspect_state(properties, window, home, log)
            # Re-read the live stream after ADB observations; never drop an ANR
            # arriving while the readiness snapshot was collected.
            inspect_state(properties, window, home, clean_boot_log(evidence))
            observation = {"elapsed_seconds": round(now-started, 3), "state": state, "properties": properties,
                           "focused_window": current_focus_value(window), "resolved_home": home}
            receipt["observations"].append(observation)
            if ready:
                stable_since = stable_since if stable_since is not None else now
                stable_samples += 1
                if stable_samples >= 3 and now - stable_since >= 2:
                    (evidence / "pre-input-ready-window.txt").write_text(window)
                    receipt["ready_for_original_key_event"] = True
                    receipt["status"] = "HEALTHY_HOME_READY_FOR_ORIGINAL_KEY_ONCE"
                    return
            else:
                stable_since = None
                stable_samples = 0
            time.sleep(min(1, max(0, deadline-time.monotonic())))
        raise TimeoutError("PRE_INPUT_HEALTHY_HOME_NOT_READY")
    except Exception as error:
        receipt["status"] = "BLOCKED"
        receipt["failure_type"] = type(error).__name__
        receipt["failure_code"] = str(error) if isinstance(error, (ValueError, TimeoutError)) else "READINESS_OBSERVATION_FAILED"
        raise
    finally:
        receipt["elapsed_seconds"] = round(time.monotonic()-started, 3)
        (evidence / "pre-input-readiness.json").write_text(json.dumps(receipt, indent=2)+"\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    run(parser.parse_args().port)
