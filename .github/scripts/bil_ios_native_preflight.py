#!/usr/bin/env python3
"""Prepare Swift packages and verify actual Debug Simulator settings for QA.

Flutter 3.44.6 caches an empty settings map when its internal Xcode query
times out. Resolve the package graph before that query in the fresh native
job. This preparation never proves that compilation or native tests pass.
"""

import argparse
import json
from pathlib import Path
import re
import sys

from bil_native_bounded_command import run_bounded


PACKAGE_TIMEOUT_SECONDS = 600
SETTINGS_TIMEOUT_SECONDS = 180
BUNDLE_ID = "com.bilhealth.bodyintelligencelog"


def runner_settings(raw, workspace):
    """Select the Runner section, rather than an unrelated package target."""
    sections = []
    current = None
    for line in raw.splitlines():
        header = re.fullmatch(r"Build settings for action .+ and target (.+):", line.strip())
        if header:
            current = {} if header.group(1) == "Runner" else None
            if current is not None:
                sections.append(current)
            continue
        setting = re.fullmatch(r"\s+([A-Za-z0-9_]+) = (.*)", line)
        if current is not None and setting:
            key, value = setting.groups()
            if key in current and current[key] != value:
                raise ValueError("Conflicting Runner build settings")
            current[key] = value
    if len(sections) != 1:
        raise ValueError("Exactly one Runner settings section is required")
    settings = sections[0]
    expected = {
        "CONFIGURATION": "Debug",
        "PLATFORM_NAME": "iphonesimulator",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "WRAPPER_NAME": "Runner.app",
    }
    if any(settings.get(key) != value for key, value in expected.items()):
        raise ValueError("Expected the actual Debug Runner Simulator target")
    build_dir = (workspace / "build/ios").resolve()
    if Path(settings.get("BUILD_DIR", "")).resolve() != build_dir:
        raise ValueError("Xcode BUILD_DIR differs from the Flutter build directory")
    target = settings.get("TARGET_BUILD_DIR")
    if not target or Path(target).resolve() != build_dir / "Debug-iphonesimulator":
        raise ValueError("Expected TARGET_BUILD_DIR inside the current Simulator build")
    return {**expected, "BUILD_DIR": str(build_dir), "TARGET_BUILD_DIR": target}


def prepare(workspace, output, *, run=run_bounded, host=sys.platform):
    workspace = Path(workspace).resolve()
    output = Path(output).resolve()
    output.relative_to(workspace)
    if host != "darwin" or not (workspace / "ios/Runner.xcodeproj").is_dir():
        raise ValueError("An existing macOS iOS QA workspace is required")
    build_dir = (workspace / "build/ios").resolve()
    build_dir.relative_to(workspace)
    packages = (build_dir / "SourcePackages").resolve()
    packages.relative_to(build_dir)
    packages.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = output / "native-preflight.json"
    receipt = {
        "status": "RUNNING", "stage": "resolve-packages",
        "scope": "Package preparation and resolved settings only; compilation and native journeys remain required",
        "native_tests_proven": False, "signed_release_proven": False,
        "package_timeout_seconds": PACKAGE_TIMEOUT_SECONDS,
        "settings_timeout_seconds": SETTINGS_TIMEOUT_SECONDS,
    }

    def save():
        receipt_path.write_bytes((json.dumps(receipt, indent=2) + "\n").encode("utf-8"))

    # Match Flutter's project, scheme, SDK, destination, package cache and BUILD_DIR.
    common = [
        "xcrun", "xcodebuild", "-clonedSourcePackagesDirPath", str(packages),
        "-skipPackageUpdates",
        "-project", str(workspace / "ios/Runner.xcodeproj"), "-scheme", "Runner",
        "-configuration", "Debug", "-sdk", "iphonesimulator",
        "-destination", "generic/platform=iOS Simulator", f"BUILD_DIR={build_dir}",
    ]
    try:
        for label, action, timeout in (
            ("resolve-packages", "-resolvePackageDependencies", PACKAGE_TIMEOUT_SECONDS),
            ("simulator-settings", "-showBuildSettings", SETTINGS_TIMEOUT_SECONDS),
        ):
            receipt["stage"] = label
            save()
            code = run(
                [*common, action], label=f"ios-preflight-{label}",
                log_path=output / f"preflight-{label}.log",
                receipt_path=output / f"preflight-{label}-result.json",
                timeout_seconds=timeout,
            )
            if code != 0:
                receipt.update(status="FAIL", exit_code=code)
                save()
                return code
        receipt["stage"] = "validate-runner-settings"
        settings_log = output / "preflight-simulator-settings.log"
        receipt["settings"] = runner_settings(settings_log.read_text(encoding="utf-8"), workspace)
        receipt.update(status="PREPARED", exit_code=0)
        save()
        return 0
    except Exception as failure:
        # Persist controlled diagnostics only, never exception argv or Xcode output.
        receipt.update(status="FAIL", exit_code=1, error_type=type(failure).__name__)
        save()
        return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    return prepare(args.workspace, args.output)


if __name__ == "__main__":
    raise SystemExit(main())
