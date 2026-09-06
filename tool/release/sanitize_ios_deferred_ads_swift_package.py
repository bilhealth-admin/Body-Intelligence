#!/usr/bin/env python3
"""Remove deferred ads from Flutter's existing, build-local Swift manifest.

Flutter 3.44's --no-pub deliberately skips plugin/Swift package regeneration.
Changing discovery metadata alone therefore leaves the earlier pub-get graph
linked. Change only the two generated ads dependency declarations, before Xcode;
never strip an archive, change the package cache, or bypass artifact validation.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

from verify_ios_deferred_ads_plugin_graph import SPM_MANIFEST


class SwiftPackageError(ValueError):
    """The generated manifest cannot be safely sanitized."""


ADS_MARKER = re.compile(
    r"google[-_]mobile[-_]ads|googlemobileads|usermessagingplatform",
    re.IGNORECASE,
)
PACKAGE = re.compile(
    r'\s*\.package\(name: "google_mobile_ads", path: "[^"\r\n]+"\),?\s*'
)
PRODUCT = re.compile(
    r'\s*\.product\(name: "google-mobile-ads", package: "google_mobile_ads"\),?\s*'
)


def sanitize_manifest(source: str) -> str:
    if not all(marker in source for marker in (
        "// Generated file. Do not edit.", "import PackageDescription",
        'name: "FlutterGeneratedPluginSwiftPackage"', "let package = Package(",
    )):
        raise SwiftPackageError("Expected Flutter's generated Swift package manifest.")
    lines = source.splitlines(keepends=True)
    packages = [index for index, line in enumerate(lines) if PACKAGE.fullmatch(line)]
    products = [index for index, line in enumerate(lines) if PRODUCT.fullmatch(line)]
    if not ADS_MARKER.search(source):
        return source
    if len(packages) != 1 or len(products) != 1:
        raise SwiftPackageError("Expected exactly one generated ads package/product pair.")
    removed = set(packages + products)
    result = "".join(line for index, line in enumerate(lines) if index not in removed)
    if ADS_MARKER.search(result):
        raise SwiftPackageError("Unrecognized ads reference remains; manifest was not changed.")
    return result


def sanitize_project(project_root: pathlib.Path) -> bool:
    root = project_root.resolve(strict=True)
    manifest = root / SPM_MANIFEST
    resolved = manifest.resolve(strict=True)
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise SwiftPackageError("Generated manifest resolves outside its build project.")
    # Preserve the exact line endings and every non-ads byte of generated content.
    original = resolved.read_bytes()
    sanitized = sanitize_manifest(original.decode("utf-8")).encode("utf-8")
    if sanitized == original:
        return False
    resolved.write_bytes(sanitized)
    if resolved.read_bytes() != sanitized:
        raise SwiftPackageError("Generated manifest write verification failed.")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=pathlib.Path, default=pathlib.Path.cwd())
    args = parser.parse_args()
    try:
        changed = sanitize_project(args.project_root)
    except (OSError, ValueError, UnicodeError) as error:
        print(f"IOS_DEFERRED_ADS_SWIFT_PREPARATION=FAIL: {error}", file=sys.stderr)
        return 1
    print("IOS_DEFERRED_ADS_SWIFT_PREPARATION=PASS")
    print(f"IOS_DEFERRED_ADS_SWIFT_CHANGED={str(changed).upper()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
