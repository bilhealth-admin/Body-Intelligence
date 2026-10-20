#!/usr/bin/env python3
"""Controller-only live-focus parser; delegate every other gate to frozen5775."""

from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

APP_SOURCE = "5775d082a1b4c7a29e4ed4d6e01693b31923dc31"
APP_TREE = "7ea15defb433ad134ee5066f538d8e790c45f809"
VERIFIER_SHA256 = "8987ae192d4668b9195d8fee72405203cf092b5d93d6b746b407cf6080aecc33"
SMOKE_SHA256 = "57946da72058607a5a0a3b3f2e5986d85d8eb3c3f4d88e43b69e810df8e84ee5"


def fresh_boot_anr_lines(state: str) -> list[str]:
    """Only actual ANR log tags/events in a stream started before this clean boot."""
    marker = re.compile(r"\b(?:ActivityManager|ActivityTaskManager)\s*:\s*ANR in\b|\bam_anr\s*:")
    return [line for line in state.splitlines() if marker.search(line)]


def current_focus_value(state: str) -> str:
    """Exclude historical LAST ANR snapshots and require an unambiguous live focus."""
    history = re.search(r"^WINDOW MANAGER LAST ANR\b", state, re.MULTILINE)
    if history is not None:
        # AOSP's whole-service dump emits the historical window/display snapshot
        # before live policy/animator/session/display sections. The historical
        # snapshot itself can contain DISPLAY CONTENTS and mCurrentFocus.
        live = re.search(
            r"^WINDOW MANAGER (?:POLICY STATE|ANIMATOR STATE|SESSIONS)\b",
            state[history.end():], re.MULTILINE,
        )
        if live is None:
            return ""  # History-only/unknown layout never proves current focus.
        state = state[history.end() + live.start():]

    displays = list(re.finditer(r"^\s*Display: mDisplayId=(\d+)\b", state, re.MULTILINE))
    if displays:
        primary = [index for index, match in enumerate(displays) if match.group(1) == "0"]
        if len(primary) != 1:
            return ""
        index = primary[0]
        start = displays[index].start()
        end = displays[index + 1].start() if index + 1 < len(displays) else len(state)
        state = state[start:end]
        next_section = re.search(r"^WINDOW MANAGER ", state, re.MULTILINE)
        if next_section is not None:
            state = state[:next_section.start()]

    for field in ("mCurrentFocus", "mFocusedWindow"):
        matches = re.findall(rf"^\s*{field}\s*=\s*(.+)$", state, re.MULTILINE)
        values = {value.strip() for value in matches}
        if values:
            return values.pop() if len(values) == 1 else ""
    return ""


def load_frozen_verifier(root: Path):
    path = root / "tool/release/verify_android_startup_frame.py"
    if hashlib.sha256(path.read_bytes()).hexdigest() != VERIFIER_SHA256:
        raise ValueError("Frozen startup verifier does not match the audited5775 bytes")
    spec = importlib.util.spec_from_file_location("verify_android_startup_frame", path)
    if spec is None or spec.loader is None:
        raise ValueError("Cannot load frozen startup verifier")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def install_live_focus_parser(module) -> None:
    original = module.inspect_window_state

    def inspect_live_window_state(path: Path) -> dict[str, str]:
        focus = current_focus_value(path.read_text(encoding="utf-8", errors="replace"))
        # Keep the original package-boundary, null-focus, ANR-owner and exit-code
        # rules. Normalize only the input selected from the live display dump.
        with tempfile.TemporaryDirectory(prefix="bil-live-focus-") as directory:
            normalized = Path(directory) / "live-window.txt"
            normalized.write_text(f"mCurrentFocus={focus or 'null'}\n", encoding="utf-8")
            return original(normalized)

    module.inspect_window_state = inspect_live_window_state


def assert_frozen_checkout(root: Path) -> None:
    head = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if head != APP_SOURCE:
        raise ValueError("Application checkout is not the fixed5775 source")
    tree = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD^{tree}"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if tree != APP_TREE:
        raise ValueError("Application checkout tree is not the fixed5775 tree")
    if Path(__file__).resolve().is_relative_to(root.resolve()):
        raise ValueError("Controller must be outside the frozen application checkout")
    subprocess.run(
        ["git", "-C", str(root), "diff", "--exit-code", "--", "android", "lib",
         "pubspec.yaml", "pubspec.lock", "tool/release/verify_android_startup_frame.py",
         "tool/release/run_android_emulator_smoke.sh"],
        capture_output=True, text=True, check=True,
    )
    for relative, expected in (
        ("tool/release/verify_android_startup_frame.py", VERIFIER_SHA256),
        ("tool/release/run_android_emulator_smoke.sh", SMOKE_SHA256),
    ):
        if hashlib.sha256((root / relative).read_bytes()).hexdigest() != expected:
            raise ValueError(f"Frozen application gate changed: {relative}")


def main(argv: list[str] | None = None) -> int:
    root = Path(os.environ.get("BIL_FROZEN_APP_ROOT", ".")).resolve()
    assert_frozen_checkout(root)
    verifier = load_frozen_verifier(root)
    install_live_focus_parser(verifier)
    return verifier.main(argv)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"CONTROLLER_SOURCE_OR_CAPTURE_BLOCKED: {error}", file=sys.stderr)
        sys.exit(70)
