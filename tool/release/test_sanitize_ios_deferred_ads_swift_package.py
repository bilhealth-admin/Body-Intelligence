#!/usr/bin/env python3
"""Regression: pub-get Swift graph persists through flutter build --no-pub."""

import pathlib
import tempfile
import unittest

from sanitize_ios_deferred_ads_swift_package import (
    SPM_MANIFEST, SwiftPackageError, sanitize_manifest, sanitize_project,
)
from test_verify_ios_deferred_ads_plugin_graph import Fixture
from verify_ios_deferred_ads_plugin_graph import PluginGraphError, verify_project


MANIFEST = '''// swift-tools-version: 5.9
// Generated file. Do not edit.
import PackageDescription
let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    dependencies: [
        .package(name: "app_links", path: "../.symlinks/plugins/app_links-7.0.0/ios/app_links"),
        .package(name: "google_mobile_ads", path: "../.symlinks/plugins/google_mobile_ads-9.1.0/ios/google_mobile_ads"),
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(name: "FlutterGeneratedPluginSwiftPackage", dependencies: [
            .product(name: "app-links", package: "app_links"),
            .product(name: "google-mobile-ads", package: "google_mobile_ads"),
            .product(name: "FlutterFramework", package: "FlutterFramework")
        ])
    ]
)
'''


class SwiftSanitizerTests(unittest.TestCase):
    def test_reproduces_stale_no_pub_graph_then_passes_unchanged_graph_gate(self):
        fixture = Fixture()
        self.addCleanup(fixture.close)
        fixture.spm.write_bytes(MANIFEST.encode())
        others = {path: path.read_bytes() for path in fixture.root.rglob('*')
                  if path.is_file() and path != fixture.spm}
        with self.assertRaisesRegex(PluginGraphError, 'manifest retains native ads marker'):
            verify_project(fixture.root)
        sanitize_project(fixture.root)
        self.assertEqual(verify_project(fixture.root), {'ios_plugins': 1, 'android_plugins': 2})
        self.assertEqual(others, {path: path.read_bytes() for path in others})

    def test_only_the_two_generated_ads_declarations_change(self):
        result = sanitize_manifest(MANIFEST)
        expected = "".join(line for line in MANIFEST.splitlines(keepends=True)
                           if 'google_mobile_ads' not in line)
        self.assertEqual(result, expected)
        self.assertEqual(sanitize_manifest(result), result)
        self.assertIn('.package(name: "app_links"', result)
        self.assertIn('.product(name: "FlutterFramework"', result)

    def test_crlf_preserved(self):
        self.assertEqual(sanitize_manifest(MANIFEST.replace("\n", "\r\n")),
                         sanitize_manifest(MANIFEST).replace("\n", "\r\n"))

    def test_last_or_sole_ads_entry_without_comma_is_removed(self):
        sole = ''.join(line for line in MANIFEST.splitlines(keepends=True)
                       if '.package(name: "app_links"' not in line
                       and '.product(name: "app-links"' not in line
                       and '.package(name: "FlutterFramework"' not in line
                       and '.product(name: "FlutterFramework"' not in line)
        sole = sole.replace('google_mobile_ads"),', 'google_mobile_ads")')
        sole = sole.replace('ios/google_mobile_ads"),', 'ios/google_mobile_ads")')
        result = sanitize_manifest(sole)
        self.assertNotIn('google_mobile_ads', result)
        self.assertIn('dependencies: [', result)

    def test_duplicate_or_missing_pair_rejected(self):
        package_line = next(line for line in MANIFEST.splitlines(keepends=True)
                            if '.package(name: "google_mobile_ads"' in line)
        for altered in (MANIFEST + package_line, MANIFEST.replace(package_line, "")):
            with self.subTest(altered=altered), self.assertRaises(SwiftPackageError):
                sanitize_manifest(altered)

    def test_unrecognized_ads_reference_rejected(self):
        for extra in ('// GoogleMobileAds\n', '// UserMessagingPlatform\n'):
            with self.subTest(extra=extra), self.assertRaises(SwiftPackageError):
                sanitize_manifest(MANIFEST + extra)

    def test_non_generated_manifest_rejected(self):
        with self.assertRaises(SwiftPackageError):
            sanitize_manifest(MANIFEST.replace("// Generated file. Do not edit.", ""))

    def test_actual_generated_file_is_sanitized_before_archive(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            manifest = root / SPM_MANIFEST
            manifest.parent.mkdir(parents=True)
            manifest.write_bytes(MANIFEST.encode())
            self.assertTrue(sanitize_project(root))
            self.assertEqual(manifest.read_bytes(), sanitize_manifest(MANIFEST).encode())
            self.assertFalse(sanitize_project(root))

    def test_refusal_leaves_file_intact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            manifest = root / SPM_MANIFEST
            manifest.parent.mkdir(parents=True)
            invalid = (MANIFEST + '// GoogleMobileAds\n').encode()
            manifest.write_bytes(invalid)
            with self.assertRaises(SwiftPackageError):
                sanitize_project(root)
            self.assertEqual(manifest.read_bytes(), invalid)


if __name__ == "__main__":
    unittest.main()
