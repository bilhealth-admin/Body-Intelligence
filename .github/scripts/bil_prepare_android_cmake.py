#!/usr/bin/env python3
"""Provision the exact CMake package before Android notification SDK builds.

Only SDK-manager installation failures are retried. Build/test commands are never
run or retried here. A zero installer exit alone is not a successful provision.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


REVISION = "3.22.1"
PACKAGE = f"cmake;{REVISION}"
MAX_ATTEMPTS = 3
INSTALL_TIMEOUT_SECONDS = 300


class ProvisionError(RuntimeError):
    pass


def write_receipt(path, receipt):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_name(path.name + ".pending")
    pending.write_bytes((json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode("utf-8"))
    pending.replace(path)


def inside_sdk(path, sdk_root):
    resolved = path.resolve()
    if not resolved.is_relative_to(sdk_root):
        raise ProvisionError("SDK tool or metadata escapes the selected SDK root")
    return resolved


def verify_install(sdk_root, run):
    package_root = inside_sdk(sdk_root / "cmake" / REVISION, sdk_root)
    metadata = inside_sdk(package_root / "source.properties", sdk_root)
    binary = inside_sdk(package_root / "bin" / "cmake", sdk_root)
    if not metadata.is_file() or not binary.is_file():
        raise ProvisionError("Installed CMake binary and source.properties are required")
    revisions = re.findall(
        r"^\s*Pkg\.Revision\s*=\s*(\S+)\s*$",
        metadata.read_text(encoding="utf-8"),
        flags=re.MULTILINE,
    )
    if revisions != [REVISION]:
        raise ProvisionError("Installed CMake package revision does not match the pinned revision")
    result = run(
        [str(binary), "--version"],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    version_lines = result.stdout.splitlines()
    # Android's official 3.22.1 package reports its Git build identifier here.
    # Metadata must still be exactly 3.22.1; accept no other version/suffix form.
    version_pattern = rf"cmake version {re.escape(REVISION)}(?:-g[0-9A-Fa-f]+(?:-dirty)?)?"
    if result.returncode != 0 or not version_lines or re.fullmatch(version_pattern, version_lines[0].strip()) is None:
        raise ProvisionError("Installed CMake executable did not verify the pinned version")
    return str(binary)


def provision(sdk_root, receipt_path, *, run=subprocess.run, sleep=time.sleep):
    receipt = {
        "schema": "bil-android-cmake-provision-v1",
        "status": "IN_PROGRESS",
        "stage": "preflight",
        "package": PACKAGE,
        "expected_revision": REVISION,
        "attempts": [],
        "app_build_or_tests_executed": False,
        "source_head": os.environ.get("GITHUB_SHA"),
    }
    stage = "preflight"
    try:
        write_receipt(receipt_path, receipt)
        if not sdk_root:
            raise ProvisionError("ANDROID_SDK_ROOT or ANDROID_HOME is required")
        sdk_root = Path(sdk_root).resolve(strict=True)
        if not sdk_root.is_dir():
            raise ProvisionError("Android SDK root must be an existing directory")
        sdkmanager = inside_sdk(sdk_root / "cmdline-tools" / "latest" / "bin" / "sdkmanager", sdk_root)
        if not sdkmanager.is_file():
            raise ProvisionError("SDK-local cmdline-tools/latest/bin/sdkmanager is required")
        receipt["sdk_root"] = str(sdk_root)
        stage = "install"
        installed = False
        for attempt_number in range(1, MAX_ATTEMPTS + 1):
            attempt = {"number": attempt_number, "status": "RUNNING"}
            receipt["attempts"].append(attempt)
            receipt["stage"] = stage
            write_receipt(receipt_path, receipt)
            try:
                result = run(
                    [str(sdkmanager), f"--sdk_root={sdk_root}", PACKAGE],
                    capture_output=True,
                    text=True,
                    timeout=INSTALL_TIMEOUT_SECONDS,
                    check=False,
                )
                attempt.update(status="EXITED", exit_code=result.returncode)
                installed = result.returncode == 0
            except subprocess.TimeoutExpired:
                attempt.update(status="TIMEOUT", exit_code=None)
            write_receipt(receipt_path, receipt)
            if installed:
                break
            if attempt_number < MAX_ATTEMPTS:
                sleep(5)
        if not installed:
            raise ProvisionError("SDK-manager installation did not complete successfully within three bounded attempts")
        stage = "verify"
        receipt["stage"] = stage
        write_receipt(receipt_path, receipt)
        binary = verify_install(sdk_root, run)
        receipt.update(status="PASS", stage="complete", verified_revision=REVISION, binary=binary)
        write_receipt(receipt_path, receipt)
        return 0
    except Exception as error:
        receipt.update(status="FAIL", stage=stage, error_type=type(error).__name__)
        try:
            write_receipt(receipt_path, receipt)
        except OSError:
            pass
        print(f"CMake provisioning failed at {stage} ({type(error).__name__}); see the provision receipt.", file=sys.stderr)
        return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", default=os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME"))
    parser.add_argument("--receipt", required=True, type=Path)
    args = parser.parse_args(argv)
    return provision(args.sdk_root, args.receipt)


if __name__ == "__main__":
    raise SystemExit(main())
