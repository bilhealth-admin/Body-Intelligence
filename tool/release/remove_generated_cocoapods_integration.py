#!/usr/bin/env python3
"""Remove only Flutter-generated CocoaPods scaffolding after iOS plugin sanitization.

The operation is deliberately fail-closed:
- the Podfile must byte-match Flutter 3.44.6's official iOS template;
- the Xcode project/workspace must contain no installed Pods integration;
- only the exact Pods-Runner xcconfig include lines may be removed.
"""

from __future__ import annotations

import json
import os
import pathlib
import re
import shutil

ROOT = pathlib.Path.cwd()
IOS = ROOT / "ios"
FLUTTER_ROOT = pathlib.Path(os.environ.get("FLUTTER_ROOT", ""))
PODFILE = IOS / "Podfile"
PODFILE_LOCK = IOS / "Podfile.lock"
PODS_DIR = IOS / "Pods"
PBXPROJ = IOS / "Runner.xcodeproj" / "project.pbxproj"
WORKSPACE = IOS / "Runner.xcworkspace" / "contents.xcworkspacedata"
PLUGIN_METADATA = ROOT / ".flutter-plugins-dependencies"

POD_INCLUDES = {
    IOS / "Flutter" / "Debug.xcconfig": {
        '#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"',
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"',
    },
    IOS / "Flutter" / "Release.xcconfig": {
        '#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"',
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"',
    },
}


def _normalize_newlines(value: str) -> str:
    return value.replace("\r\n", "\n")


def _assert_ios_plugin_graph_is_sanitized() -> None:
    if not PLUGIN_METADATA.is_file():
        raise SystemExit(".flutter-plugins-dependencies is missing.")
    payload = json.loads(PLUGIN_METADATA.read_text(encoding="utf-8"))
    plugins = payload.get("plugins", {})
    ios = plugins.get("ios")
    if not isinstance(ios, list):
        raise SystemExit("iOS Flutter plugin metadata is malformed.")
    names = {entry.get("name") for entry in ios if isinstance(entry, dict)}
    if "simple_barcode_scanner" in names:
        raise SystemExit("simple_barcode_scanner still participates in the iOS native graph.")
    if not names:
        raise SystemExit("Refusing cleanup because the iOS native plugin graph is unexpectedly empty.")


def _assert_no_installed_pods_project_state() -> None:
    pbx = PBXPROJ.read_text(encoding="utf-8")
    workspace = WORKSPACE.read_text(encoding="utf-8")
    forbidden = (
        "[CP]",
        "Pods-Runner",
        "Pods_Runner",
        "Pods.xcodeproj",
        "PODS_ROOT",
        "PODS_PODFILE_DIR_PATH",
    )
    for marker in forbidden:
        if marker in pbx or marker in workspace:
            raise SystemExit(f"Installed/custom CocoaPods project state detected: {marker}")
    if PODS_DIR.exists():
        raise SystemExit("ios/Pods already exists; refusing to remove an installed Pods graph.")


def _assert_generated_podfile() -> None:
    if not PODFILE.is_file():
        return
    if not FLUTTER_ROOT.is_dir():
        raise SystemExit("FLUTTER_ROOT is missing or invalid.")
    template = FLUTTER_ROOT / "packages" / "flutter_tools" / "templates" / "cocoapods" / "Podfile-ios"
    if not template.is_file():
        raise SystemExit(f"Flutter Podfile template is missing: {template}")
    actual = _normalize_newlines(PODFILE.read_text(encoding="utf-8"))
    expected = _normalize_newlines(template.read_text(encoding="utf-8"))
    if actual != expected:
        raise SystemExit("ios/Podfile is not the untouched Flutter template; refusing automatic removal.")


def _remove_exact_pods_includes() -> None:
    for path, removable in POD_INCLUDES.items():
        source = _normalize_newlines(path.read_text(encoding="utf-8"))
        output = []
        for line in source.splitlines():
            if line.strip() in removable:
                continue
            if "Pods/Target Support Files/" in line:
                raise SystemExit(f"Unexpected CocoaPods xcconfig include in {path}: {line}")
            output.append(line)
        path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")


def main() -> None:
    _assert_ios_plugin_graph_is_sanitized()
    _assert_no_installed_pods_project_state()
    _assert_generated_podfile()
    _remove_exact_pods_includes()

    if PODFILE_LOCK.exists():
        raise SystemExit("Podfile.lock exists before the first iOS build; refusing automatic removal.")
    if PODFILE.exists():
        PODFILE.unlink()

    _assert_no_installed_pods_project_state()
    if PODFILE.exists():
        raise SystemExit("Generated Podfile was not removed.")
    for path in POD_INCLUDES:
        if "Pods/Target Support Files/" in path.read_text(encoding="utf-8"):
            raise SystemExit(f"CocoaPods include remains in {path}.")
    print("IOS_GENERATED_COCOAPODS_CLEANUP=PASS")


if __name__ == "__main__":
    main()
