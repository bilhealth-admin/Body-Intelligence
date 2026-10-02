#!/usr/bin/env python3
"""Fail-closed Android plugin build-script cleanup for the frozen BIL toolchain.

This does not modify Dart/Kotlin plugin source. It patches only the hosted
Gradle scripts after flutter pub get so Flutter 3.44's compatibility bridge,
not individual plugins, owns KGP application while android.builtInKotlin=false.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
from urllib.parse import unquote, urlparse

ROOT = pathlib.Path.cwd()
PACKAGE_CONFIG = ROOT / ".dart_tool" / "package_config.json"


def _package_root(name: str) -> pathlib.Path:
    if not PACKAGE_CONFIG.is_file():
        raise SystemExit(".dart_tool/package_config.json is missing; run flutter pub get first.")
    payload = json.loads(PACKAGE_CONFIG.read_text(encoding="utf-8"))
    matches = [p for p in payload.get("packages", []) if p.get("name") == name]
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one package_config entry for {name}, got {len(matches)}.")
    root_uri = matches[0].get("rootUri")
    if not isinstance(root_uri, str) or not root_uri:
        raise SystemExit(f"{name} rootUri is missing.")
    parsed = urlparse(root_uri)
    if parsed.scheme == "file":
        root = pathlib.Path(unquote(parsed.path))
    else:
        root = (PACKAGE_CONFIG.parent / unquote(root_uri)).resolve()
    if not root.is_dir():
        raise SystemExit(f"{name} package root does not exist: {root}")
    return root


def _verify_pubspec(root: pathlib.Path, name: str, version: str) -> None:
    source = (root / "pubspec.yaml").read_text(encoding="utf-8")
    name_count = len(re.findall(rf"^name:\s*{re.escape(name)}\s*$", source, re.MULTILINE))
    version_count = len(re.findall(rf"^version:\s*{re.escape(version)}\s*$", source, re.MULTILINE))
    if name_count != 1 or version_count != 1:
        raise SystemExit(f"Expected {name} {version}; refusing to patch a different package.")


def _replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one exact source block, found {count}.")
    return source.replace(old, new, 1)


def _patch_flutter_timezone() -> None:
    root = _package_root("flutter_timezone")
    _verify_pubspec(root, "flutter_timezone", "5.1.0")
    path = root / "android" / "build.gradle"
    source = path.read_text(encoding="utf-8")
    if "BIL_HOST_KGP_BRIDGE" in source:
        print("flutter_timezone already patched.")
        return

    old_apply = """def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
def builtInKotlinEnabled = project.findProperty('android.builtInKotlin')?.toString() == 'true'

apply plugin: 'com.android.library'
// AGP 9+ registers the Kotlin Android plugin (and the `kotlin {}` extension)
// itself only when android.builtInKotlin=true. Flutter 3.44 currently
// defaults that flag to false to support consumers that depend on
// unmigrated Flutter-SDK plugins (eg. integration_test). Apply the plugin
// ourselves whenever AGP isn't going to.
if (agpMajor < 9 || !builtInKotlinEnabled) {
    apply plugin: 'kotlin-android'
}
"""
    source = _replace_once(
        source,
        old_apply,
        """apply plugin: 'com.android.library'
// BIL_HOST_KGP_BRIDGE: Flutter 3.44 owns KGP application while the app keeps
// android.builtInKotlin=false. The plugin must not apply KGP itself.
""",
        "flutter_timezone KGP application",
    )

    old_kotlin = """kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
"""
    new_kotlin = """def configureBILKotlin = {
    extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension) {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }
}
if (extensions.findByName('kotlin') != null) {
    configureBILKotlin()
} else {
    pluginManager.withPlugin('org.jetbrains.kotlin.android') {
        configureBILKotlin()
    }
}
"""
    source = _replace_once(source, old_kotlin, new_kotlin, "flutter_timezone Kotlin compiler config")

    if re.search(r"apply\s+plugin\s*:\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]", source):
        raise SystemExit("flutter_timezone still applies KGP after patch.")
    path.write_text(source, encoding="utf-8")
    print("ANDROID_KGP_PATCH_flutter_timezone=PASS")


def _patch_in_app_review() -> None:
    root = _package_root("in_app_review")
    _verify_pubspec(root, "in_app_review", "2.0.12")
    path = root / "android" / "build.gradle"
    source = path.read_text(encoding="utf-8")
    if "BIL_HOST_KGP_BRIDGE" in source:
        print("in_app_review already patched.")
        return

    source = _replace_once(
        source,
        'apply plugin: "com.android.library"\napply plugin: "kotlin-android"\n',
        'apply plugin: "com.android.library"\n// BIL_HOST_KGP_BRIDGE: Flutter 3.44 owns KGP application.\n',
        "in_app_review KGP application",
    )
    source = _replace_once(
        source,
        """    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11
    }

""",
        "",
        "in_app_review legacy kotlinOptions",
    )

    deferred = """
def configureBILKotlin = {
    extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension) {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }
}
if (extensions.findByName('kotlin') != null) {
    configureBILKotlin()
} else {
    pluginManager.withPlugin('org.jetbrains.kotlin.android') {
        configureBILKotlin()
    }
}
"""
    source = source.rstrip() + "\n\n" + deferred.lstrip()
    if re.search(r"apply\s+plugin\s*:\s*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]", source):
        raise SystemExit("in_app_review still applies KGP after patch.")
    path.write_text(source, encoding="utf-8")
    print("ANDROID_KGP_PATCH_in_app_review=PASS")


def _verify_mobile_scanner() -> None:
    root = _package_root("mobile_scanner")
    _verify_pubspec(root, "mobile_scanner", "7.4.2")
    path = root / "android" / "build.gradle.kts"
    source = path.read_text(encoding="utf-8")
    if 'id("org.jetbrains.kotlin.android")' in source or 'id("kotlin-android")' in source:
        raise SystemExit("mobile_scanner 7.4.2 unexpectedly declares KGP in its plugins block.")
    if "builtInKotlin" not in source:
        raise SystemExit("mobile_scanner 7.4.2 built-in-Kotlin compatibility marker is missing.")
    print("ANDROID_KGP_PATCH_mobile_scanner=UPSTREAM_PASS")


def main() -> None:
    _verify_mobile_scanner()
    _patch_flutter_timezone()
    _patch_in_app_review()
    print("ANDROID_LEGACY_PLUGIN_KGP_CLEANUP=PASS")


if __name__ == "__main__":
    main()
