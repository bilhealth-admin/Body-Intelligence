#!/usr/bin/env python3
"""Verify Flutter's generated iOS graph excludes owner-deferred native ads.

This is a read-only post-build graph check. The signed-artifact scanner remains
authoritative for the final IPA.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from urllib.parse import urlparse


PLUGIN = "google_mobile_ads"
OVERRIDE_RELATIVE = pathlib.PurePosixPath(
    "bil_release_plugin_overrides/google_mobile_ads"
)
SPM_PACKAGE = pathlib.PurePath(
    "ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage"
)
SPM_MANIFEST = SPM_PACKAGE / "Package.swift"
FORBIDDEN_MARKERS = (
    "google_mobile_ads",
    "googlemobileads",
    "google-mobile-ads",
    "usermessagingplatform",
    "googleusermessagingplatform",
    "fltgooglemobileadsplugin",
)


class PluginGraphError(RuntimeError):
    """Generated release metadata does not establish native ads exclusion."""


def _load_json(path: pathlib.Path, description: str) -> dict[str, object]:
    if not path.is_file():
        raise PluginGraphError(f"{description} is missing.")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise PluginGraphError(f"{description} is unreadable or malformed.") from error
    if not isinstance(value, dict):
        raise PluginGraphError(f"{description} root must be an object.")
    return value


def _entries(value: object, description: str) -> list[dict[str, object]]:
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        raise PluginGraphError(f"{description} must be a list of objects.")
    return value


def _names(value: object, description: str) -> list[str]:
    entries = _entries(value, description)
    names = [entry.get("name") for entry in entries]
    if not all(isinstance(name, str) and name for name in names):
        raise PluginGraphError(f"{description} contains a malformed plugin name.")
    if len(names) != len(set(names)):
        raise PluginGraphError(f"{description} contains duplicate plugin names.")
    return names


def _mapping_entry(text: str) -> tuple[str, str] | None:
    content = text.split("#", 1)[0].rstrip()
    match = re.fullmatch(r"([A-Za-z0-9_-]+)\s*:\s*(.*)", content)
    if match is None:
        return None
    return match.group(1), match.group(2)


def _direct_mapping(
    lines: list[str], parent: tuple[int, int] | None
) -> dict[str, tuple[int, int, str]]:
    start = 0 if parent is None else parent[0] + 1
    end = len(lines)
    if parent is not None:
        for index in range(start, len(lines)):
            stripped = lines[index].strip()
            if stripped and not stripped.startswith("#"):
                indent = len(lines[index]) - len(lines[index].lstrip(" "))
                if indent <= parent[1]:
                    end = index
                    break
    content: list[tuple[int, int, str]] = []
    for index in range(start, end):
        if "\t" in lines[index]:
            raise PluginGraphError("Deferred package pubspec uses tab indentation.")
        stripped = lines[index].strip()
        if stripped and not stripped.startswith("#"):
            indent = len(lines[index]) - len(lines[index].lstrip(" "))
            if parent is None or indent > parent[1]:
                content.append((index, indent, stripped))
    if not content:
        raise PluginGraphError("Deferred package pubspec contains an empty mapping.")
    direct_indent = min(item[1] for item in content)
    result: dict[str, tuple[int, int, str]] = {}
    for index, indent, stripped in content:
        if indent != direct_indent:
            continue
        entry = _mapping_entry(stripped)
        if entry is None:
            raise PluginGraphError("Deferred package pubspec has malformed indentation.")
        key, value = entry
        if key in result:
            raise PluginGraphError(
                f"Deferred package pubspec contains duplicate {key} mappings."
            )
        result[key] = (index, indent, value)
    return result


def _mapping_keys(
    lines: list[str], key: str, parent: tuple[int, int] | None = None
) -> tuple[int, int]:
    direct = _direct_mapping(lines, parent)
    match = direct.get(key)
    if match is None:
        raise PluginGraphError(
            f"Deferred package pubspec must contain one direct {key} mapping."
        )
    if match[2]:
        raise PluginGraphError(
            f"Deferred package pubspec {key} must be a block mapping."
        )
    return match[0], match[1]


def _platform_keys(pubspec: str) -> set[str]:
    lines = pubspec.splitlines()
    flutter = _mapping_keys(lines, "flutter")
    plugin = _mapping_keys(lines, "plugin", flutter)
    platforms = _mapping_keys(lines, "platforms", plugin)
    return set(_direct_mapping(lines, platforms))


def _assert_absent(text: str, description: str) -> None:
    lowered = text.casefold()
    found = next((marker for marker in FORBIDDEN_MARKERS if marker in lowered), None)
    if found:
        raise PluginGraphError(f"{description} retains native ads marker {found}.")


def _assert_absent_bytes(contents: bytes, description: str) -> None:
    lowered = contents.lower()
    found = next(
        (marker for marker in FORBIDDEN_MARKERS if marker.encode("ascii") in lowered),
        None,
    )
    if found:
        raise PluginGraphError(f"{description} retains native ads marker {found}.")


def _assert_spm_package_absent(root: pathlib.Path) -> None:
    package = root / SPM_PACKAGE
    signatures = package / "Signatures"
    if signatures.exists() and not signatures.is_dir():
        raise PluginGraphError("Generated Flutter Swift package Signatures is invalid.")
    if not signatures.is_dir():
        return
    for path in signatures.rglob("*.xcframework-ios.signature"):
        if not path.is_file():
            raise PluginGraphError("Generated Flutter Swift package signature is invalid.")
        relative = path.relative_to(package).as_posix()
        _assert_absent(relative, "Generated Flutter Swift package signature path")
        _assert_absent_bytes(
            path.read_bytes(), "Generated Flutter Swift package signature"
        )


def _shadow_root(root: pathlib.Path, package_config: dict[str, object]) -> pathlib.Path:
    packages = _entries(package_config.get("packages"), "package_config packages")
    matches = [entry for entry in packages if entry.get("name") == PLUGIN]
    if len(matches) != 1:
        raise PluginGraphError("package_config must contain one google_mobile_ads entry.")
    root_uri = matches[0].get("rootUri")
    if not isinstance(root_uri, str) or not root_uri:
        raise PluginGraphError("Deferred package rootUri is missing.")
    parsed = urlparse(root_uri)
    relative = pathlib.PurePosixPath(parsed.path.rstrip("/"))
    if (
        parsed.scheme
        or parsed.netloc
        or parsed.params
        or parsed.query
        or parsed.fragment
        or "\\" in root_uri
        or relative.is_absolute()
        or ".." in relative.parts
    ):
        raise PluginGraphError("Deferred package rootUri must be a safe relative path.")
    if root_uri.rstrip("/") != OVERRIDE_RELATIVE.as_posix() or relative != OVERRIDE_RELATIVE:
        raise PluginGraphError("Deferred package rootUri is outside the approved override.")
    dart_tool = (root / ".dart_tool").resolve(strict=True)
    if not dart_tool.is_relative_to(root):
        raise PluginGraphError(".dart_tool resolves outside the project root.")
    expected = root / ".dart_tool" / pathlib.Path(*OVERRIDE_RELATIVE.parts)
    if not expected.is_dir():
        raise PluginGraphError("Deferred package override directory is missing.")
    resolved = expected.resolve(strict=True)
    if not resolved.is_relative_to(dart_tool):
        raise PluginGraphError("Deferred package override resolves outside .dart_tool.")
    return resolved


def verify_project(project_root: pathlib.Path) -> dict[str, int]:
    root = project_root.resolve(strict=True)
    metadata = _load_json(root / ".flutter-plugins-dependencies", "Flutter plugin metadata")
    plugins = metadata.get("plugins")
    if not isinstance(plugins, dict):
        raise PluginGraphError("Flutter plugin metadata has no plugins object.")
    ios_names = _names(plugins.get("ios"), "iOS plugin metadata")
    android_names = _names(plugins.get("android"), "Android plugin metadata")
    if PLUGIN in ios_names:
        raise PluginGraphError("iOS plugin metadata still contains google_mobile_ads.")
    if android_names.count(PLUGIN) != 1:
        raise PluginGraphError("Android plugin metadata must retain google_mobile_ads once.")
    graph_names = _names(metadata.get("dependencyGraph"), "Flutter dependency graph")
    if graph_names.count(PLUGIN) != 1:
        raise PluginGraphError("Dart dependency graph must retain google_mobile_ads once.")

    package_config = _load_json(
        root / ".dart_tool" / "package_config.json", "package_config.json"
    )
    shadow = _shadow_root(root, package_config)
    marker = _load_json(
        shadow / ".bil-deferred-ios-google-mobile-ads.json",
        "Deferred package provenance marker",
    )
    if marker.get("status") != "ios-native-platform-removed" or marker.get("plugin") != PLUGIN:
        raise PluginGraphError("Deferred package provenance marker is invalid.")
    source_root_uri = marker.get("source_root_uri")
    if not isinstance(source_root_uri, str) or urlparse(source_root_uri).scheme != "file":
        raise PluginGraphError("Deferred package provenance source is invalid.")
    pubspec_path = shadow / "pubspec.yaml"
    if not pubspec_path.is_file():
        raise PluginGraphError("Deferred package pubspec is missing.")
    pubspec = pubspec_path.read_text(encoding="utf-8")
    if not any(line.strip() == "name: google_mobile_ads" for line in pubspec.splitlines()):
        raise PluginGraphError("Deferred package identity is not google_mobile_ads.")
    platforms = _platform_keys(pubspec)
    if "ios" in platforms or "android" not in platforms:
        raise PluginGraphError("Deferred package must remove only its iOS platform.")
    dart_api = shadow / "lib" / "google_mobile_ads.dart"
    android = shadow / "android"
    if not dart_api.is_file() or dart_api.stat().st_size == 0:
        raise PluginGraphError("Deferred package no longer retains its Dart API.")
    if not android.is_dir() or not any(path.is_file() for path in android.rglob("*")):
        raise PluginGraphError("Deferred package no longer retains Android implementation.")

    registrant = root / "ios" / "Runner" / "GeneratedPluginRegistrant.m"
    if not registrant.is_file():
        raise PluginGraphError("Generated iOS plugin registrant is missing.")
    _assert_absent(registrant.read_text(encoding="utf-8"), "iOS plugin registrant")

    spm = root / SPM_MANIFEST
    if not spm.is_file():
        raise PluginGraphError("Generated Flutter Swift package manifest is missing.")
    spm_text = spm.read_text(encoding="utf-8")
    if "FlutterGeneratedPluginSwiftPackage" not in spm_text or "Package(" not in spm_text:
        raise PluginGraphError("Generated Flutter Swift package manifest is malformed.")
    _assert_absent(spm_text, "Generated Flutter Swift package manifest")
    _assert_spm_package_absent(root)

    for relative in ("ios/Podfile.lock", "ios/Pods/Manifest.lock"):
        lock = root / relative
        if lock.exists():
            if not lock.is_file():
                raise PluginGraphError(f"{relative} is not a regular file.")
            _assert_absent(lock.read_text(encoding="utf-8"), relative)

    return {"ios_plugins": len(ios_names), "android_plugins": len(android_names)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=pathlib.Path, default=pathlib.Path.cwd())
    args = parser.parse_args()
    try:
        counts = verify_project(args.project_root)
    except (PluginGraphError, OSError, UnicodeError, ValueError) as error:
        print(f"IOS_DEFERRED_ADS_PLUGIN_GRAPH_GATE=FAIL: {error}", file=sys.stderr)
        return 1
    print("IOS_DEFERRED_ADS_PLUGIN_GRAPH_GATE=PASS")
    print("IOS_DEFERRED_ADS_IOS_PLUGIN_METADATA=ABSENT")
    print("IOS_DEFERRED_ADS_ANDROID_PLUGIN_METADATA=PRESENT")
    print("IOS_DEFERRED_ADS_GENERATED_REGISTRANT=ABSENT")
    print("IOS_DEFERRED_ADS_GENERATED_SPM=ABSENT")
    print(f"IOS_DEFERRED_ADS_IOS_PLUGIN_COUNT={counts['ios_plugins']}")
    print(f"IOS_DEFERRED_ADS_ANDROID_PLUGIN_COUNT={counts['android_plugins']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
