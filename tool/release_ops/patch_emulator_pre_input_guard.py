#!/usr/bin/env python3
"""Insert one fail-closed guard into the exact pinned action's runtime module."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

UPSTREAM_ACTION_TAG_OBJECT = "4c44018e59b437e86cdfc41da381398f93ed8808"
UPSTREAM_COMMIT = "a421e43855164a8197daf9d8d40fe71c6996bb0d"
LIB_SHA256 = "a63db8fe9ffb4fb3651e9a2c97f8bac5ca4ce0078a7bbe61ef2e02019082c577"
SOURCE_SHA256 = "1e9ca00c20d35d925440afc1ce82303c42cddc4c1ac196da65e39209ef87696f"
ACTION_SHA256 = "a7c4de9a466ae7d70a599ffdc5a27b2bccadd7b2d602e24b44f8b490cb7bbdfe"
NEEDLE = b"        await waitForDevice(port, emulatorBootTimeout);\n        await adb(port, `shell input keyevent 82`);"
INSERTION = b"""        const readinessGuard = process.env.BIL_EMULATOR_READY_GUARD;
        if (!readinessGuard || !fs.statSync(readinessGuard).isFile()) {
            throw new Error('BIL exact pre-input readiness guard is required');
        }
        await exec.exec('python3', [readinessGuard, '--port', String(port)]);
"""


def patched_bytes(original: bytes) -> bytes:
    if hashlib.sha256(original).hexdigest() != LIB_SHA256 or original.count(NEEDLE) != 1:
        raise ValueError("EXACT_PINNED_UPSTREAM_RUNTIME_REQUIRED")
    anchor = b"        await adb(port, `shell input keyevent 82`);"
    result = original.replace(NEEDLE, NEEDLE.replace(anchor, INSERTION + anchor))
    if result.replace(INSERTION, b"", 1) != original or result.count(INSERTION) != 1:
        raise ValueError("PATCH_NOT_EXACT_SINGLE_ADDITION")
    return result


def git(root: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=True).stdout.strip()


def patch(root: Path, output: Path) -> None:
    if git(root, "rev-parse", "HEAD") != UPSTREAM_COMMIT or git(root, "status", "--porcelain", "--untracked-files=all"):
        raise ValueError("UPSTREAM_ACTION_CHECKOUT_NOT_PRISTINE_PIN")
    for relative, digest in (("src/emulator-manager.ts", SOURCE_SHA256), ("action.yml", ACTION_SHA256)):
        if hashlib.sha256((root / relative).read_bytes()).hexdigest() != digest:
            raise ValueError("UPSTREAM_SOURCE_OR_ACTION_ENTRYPOINT_CHANGED")
    target = root / "lib/emulator-manager.js"
    original = target.read_bytes()
    changed = patched_bytes(original)
    target.write_bytes(changed)
    if git(root, "diff", "--name-only") != "lib/emulator-manager.js":
        raise ValueError("UNEXPECTED_UPSTREAM_ACTION_CHANGE")
    receipt = {"upstream_repository": "ReactiveCircus/android-emulator-runner", "upstream_commit": UPSTREAM_COMMIT,
               "original_action_annotated_tag_object": UPSTREAM_ACTION_TAG_OBJECT,
               "upstream_tree": git(root, "rev-parse", "HEAD^{tree}"), "runtime_path": "lib/emulator-manager.js",
               "runtime_before_sha256": hashlib.sha256(original).hexdigest(), "runtime_after_sha256": hashlib.sha256(changed).hexdigest(),
               "source_sha256": SOURCE_SHA256, "action_entrypoint_sha256": ACTION_SHA256,
               "patch_kind": "exactly one added await before original keyevent82", "original_key_event_count": changed.count(b"await adb(port, `shell input keyevent 82`);"),
               "all_other_action_bytes_unchanged": True, "patch": git(root, "diff", "--", "lib/emulator-manager.js")}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2)+"\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--action-root", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    arguments = parser.parse_args()
    patch(arguments.action_root, arguments.receipt)
