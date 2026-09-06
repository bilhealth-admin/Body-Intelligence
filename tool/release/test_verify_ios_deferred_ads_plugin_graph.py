#!/usr/bin/env python3
"""Tests for the post-build deferred-iOS Flutter plugin graph gate."""

from __future__ import annotations

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

from verify_ios_deferred_ads_plugin_graph import PluginGraphError, verify_project


class Fixture:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.metadata = self.root / ".flutter-plugins-dependencies"
        self.package_config = self.root / ".dart_tool/package_config.json"
        self.shadow = (
            self.root
            / ".dart_tool/bil_release_plugin_overrides/google_mobile_ads"
        )
        self.pubspec = self.shadow / "pubspec.yaml"
        self.registrant = self.root / "ios/Runner/GeneratedPluginRegistrant.m"
        self.spm = self.root / (
            "ios/Flutter/ephemeral/Packages/"
            "FlutterGeneratedPluginSwiftPackage/Package.swift"
        )
        self._create()

    @staticmethod
    def plugin(name: str) -> dict[str, object]:
        return {
            "name": name,
            "path": f"/generated/{name}",
            "native_build": True,
            "dependencies": [],
            "dev_dependency": False,
        }

    def _create(self) -> None:
        self.metadata.write_text(
            json.dumps(
                {
                    "plugins": {
                        "ios": [self.plugin("app_links")],
                        "android": [
                            self.plugin("app_links"),
                            self.plugin("google_mobile_ads"),
                        ],
                    },
                    "dependencyGraph": [
                        {"name": "app_links", "dependencies": []},
                        {"name": "google_mobile_ads", "dependencies": []},
                    ],
                }
            ),
            encoding="utf-8",
        )
        self.package_config.parent.mkdir(parents=True)
        self.package_config.write_text(
            json.dumps(
                {
                    "configVersion": 2,
                    "packages": [
                        {
                            "name": "google_mobile_ads",
                            "rootUri": (
                                "bil_release_plugin_overrides/"
                                "google_mobile_ads/"
                            ),
                            "packageUri": "lib/",
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        self.shadow.mkdir(parents=True)
        self.pubspec.write_text(
            """name: google_mobile_ads
flutter:
  plugin:
    platforms:
      android:
        package: io.flutter.plugins.googlemobileads
        pluginClass: GoogleMobileAdsPlugin
dependencies:
  flutter:
    sdk: flutter
""",
            encoding="utf-8",
        )
        marker = self.shadow / ".bil-deferred-ios-google-mobile-ads.json"
        marker.write_text(
            json.dumps(
                {
                    "status": "ios-native-platform-removed",
                    "plugin": "google_mobile_ads",
                    "source_root_uri": "file:///trusted/pub-cache/",
                }
            ),
            encoding="utf-8",
        )
        dart_api = self.shadow / "lib/google_mobile_ads.dart"
        dart_api.parent.mkdir()
        dart_api.write_text("library google_mobile_ads;\n", encoding="utf-8")
        android = self.shadow / "android/build.gradle"
        android.parent.mkdir()
        android.write_text("// Android remains available.\n", encoding="utf-8")
        self.registrant.parent.mkdir(parents=True)
        self.registrant.write_text(
            """#import "GeneratedPluginRegistrant.h"
@implementation GeneratedPluginRegistrant
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {}
@end
""",
            encoding="utf-8",
        )
        self.spm.parent.mkdir(parents=True)
        self.spm.write_text(
            """// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "FlutterGeneratedPluginSwiftPackage",
  products: [.library(
    name: "FlutterGeneratedPluginSwiftPackage",
    targets: ["FlutterGeneratedPluginSwiftPackage"]
  )],
  targets: [.target(name: "FlutterGeneratedPluginSwiftPackage")]
)
""",
            encoding="utf-8",
        )

    def metadata_json(self) -> dict[str, object]:
        return json.loads(self.metadata.read_text(encoding="utf-8"))

    def write_metadata(self, value: dict[str, object]) -> None:
        self.metadata.write_text(json.dumps(value), encoding="utf-8")

    def close(self) -> None:
        self.temporary.cleanup()


class PluginGraphTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = Fixture()
        self.addCleanup(self.fixture.close)

    def test_valid_generated_graph_passes_without_mutating_files(self) -> None:
        before = {
            path: path.read_bytes()
            for path in self.fixture.root.rglob("*")
            if path.is_file()
        }
        self.assertEqual(
            verify_project(self.fixture.root),
            {"ios_plugins": 1, "android_plugins": 2},
        )
        self.assertEqual(
            before,
            {
                path: path.read_bytes()
                for path in self.fixture.root.rglob("*")
                if path.is_file()
            },
        )

    def test_ios_metadata_cannot_rediscover_ads(self) -> None:
        data = self.fixture.metadata_json()
        data["plugins"]["ios"].append(Fixture.plugin("google_mobile_ads"))
        self.fixture.write_metadata(data)
        with self.assertRaisesRegex(PluginGraphError, "iOS plugin metadata"):
            verify_project(self.fixture.root)

    def test_android_metadata_must_remain(self) -> None:
        data = self.fixture.metadata_json()
        data["plugins"]["android"] = [Fixture.plugin("app_links")]
        self.fixture.write_metadata(data)
        with self.assertRaisesRegex(PluginGraphError, "Android plugin metadata"):
            verify_project(self.fixture.root)

    def test_dart_dependency_graph_must_remain(self) -> None:
        data = self.fixture.metadata_json()
        data["dependencyGraph"] = [
            {"name": "app_links", "dependencies": []}
        ]
        self.fixture.write_metadata(data)
        with self.assertRaisesRegex(PluginGraphError, "Dart dependency graph"):
            verify_project(self.fixture.root)

    def test_registrant_marker_is_rejected(self) -> None:
        self.fixture.registrant.write_text(
            "[FLTGoogleMobileAdsPlugin registerWithRegistrar:registry];",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(PluginGraphError, "registrant"):
            verify_project(self.fixture.root)

    def test_generated_spm_manifest_is_required(self) -> None:
        self.fixture.spm.unlink()
        with self.assertRaisesRegex(PluginGraphError, "Swift package.*missing"):
            verify_project(self.fixture.root)

    def test_generated_spm_cannot_link_gma_or_ump(self) -> None:
        for marker in ("GoogleMobileAds", "UserMessagingPlatform"):
            with self.subTest(marker=marker):
                fixture = Fixture()
                self.addCleanup(fixture.close)
                fixture.spm.write_text(
                    fixture.spm.read_text(encoding="utf-8") + marker,
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(PluginGraphError, "Swift package"):
                    verify_project(fixture.root)

    def test_generated_spm_signature_cannot_retain_native_ads(self) -> None:
        signatures = self.fixture.spm.parent / "Signatures"
        signatures.mkdir()
        signature = signatures / "GoogleMobileAds.xcframework-ios.signature"
        signature.write_text("signed", encoding="utf-8")
        with self.assertRaisesRegex(PluginGraphError, "signature path"):
            verify_project(self.fixture.root)

    def test_cocoapods_lock_cannot_retain_native_ads(self) -> None:
        for relative in ("ios/Podfile.lock", "ios/Pods/Manifest.lock"):
            with self.subTest(relative=relative):
                fixture = Fixture()
                self.addCleanup(fixture.close)
                lock = fixture.root / relative
                lock.parent.mkdir(parents=True, exist_ok=True)
                lock.write_text("- Google-Mobile-Ads-SDK (13.9.0)\n")
                with self.assertRaisesRegex(PluginGraphError, relative):
                    verify_project(fixture.root)

    def test_package_config_must_point_to_exact_relative_shadow(self) -> None:
        data = json.loads(self.fixture.package_config.read_text(encoding="utf-8"))
        data["packages"][0]["rootUri"] = "../outside/google_mobile_ads/"
        self.fixture.package_config.write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(PluginGraphError, "safe relative path"):
            verify_project(self.fixture.root)

    def test_shadow_symlink_cannot_escape_dart_tool(self) -> None:
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        shutil.rmtree(self.fixture.shadow)
        try:
            self.fixture.shadow.symlink_to(outside.name, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"Directory symlinks are unavailable: {error}")
        with self.assertRaisesRegex(PluginGraphError, "outside .dart_tool"):
            verify_project(self.fixture.root)

    def test_dart_tool_symlink_cannot_escape_project(self) -> None:
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        dart_tool = self.fixture.root / ".dart_tool"
        target = pathlib.Path(outside.name) / ".dart_tool"
        shutil.move(str(dart_tool), target)
        try:
            dart_tool.symlink_to(target, target_is_directory=True)
        except OSError as error:
            self.skipTest(f"Directory symlinks are unavailable: {error}")
        with self.assertRaisesRegex(PluginGraphError, "outside the project root"):
            verify_project(self.fixture.root)

    def test_shadow_pubspec_cannot_retain_ios(self) -> None:
        self.fixture.pubspec.write_text(
            self.fixture.pubspec.read_text(encoding="utf-8").replace(
                "      android:\n",
                "      ios:\n"
                "        pluginClass: FLTGoogleMobileAdsPlugin\n"
                "      android:\n",
            ),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(PluginGraphError, "remove only its iOS"):
            verify_project(self.fixture.root)

    def test_shadow_pubspec_detects_all_direct_ios_mapping_forms(self) -> None:
        replacements = (
            ("      ios: # deferred flag was not applied\n", "remove only its iOS"),
            (
                "      ios: {pluginClass: FLTGoogleMobileAdsPlugin}\n",
                "remove only its iOS",
            ),
            ("      ios:\n      ios: {}\n", "duplicate ios"),
            ("      ios\n", "malformed indentation"),
        )
        for replacement, expected in replacements:
            with self.subTest(replacement=replacement.strip()):
                fixture = Fixture()
                self.addCleanup(fixture.close)
                fixture.pubspec.write_text(
                    fixture.pubspec.read_text(encoding="utf-8").replace(
                        "      android:\n", replacement + "      android:\n"
                    ),
                    encoding="utf-8",
                )
                with self.assertRaisesRegex(PluginGraphError, expected):
                    verify_project(fixture.root)

    def test_shadow_must_retain_dart_and_android(self) -> None:
        (self.fixture.shadow / "lib/google_mobile_ads.dart").unlink()
        with self.assertRaisesRegex(PluginGraphError, "Dart API"):
            verify_project(self.fixture.root)
        fixture = Fixture()
        self.addCleanup(fixture.close)
        (fixture.shadow / "android/build.gradle").unlink()
        with self.assertRaisesRegex(PluginGraphError, "Android implementation"):
            verify_project(fixture.root)

    def test_provenance_marker_is_required_and_exact(self) -> None:
        marker = self.fixture.shadow / ".bil-deferred-ios-google-mobile-ads.json"
        marker.unlink()
        with self.assertRaisesRegex(PluginGraphError, "provenance marker"):
            verify_project(self.fixture.root)
        fixture = Fixture()
        self.addCleanup(fixture.close)
        marker = fixture.shadow / ".bil-deferred-ios-google-mobile-ads.json"
        marker.write_text(
            json.dumps({"status": "unknown", "plugin": "google_mobile_ads"}),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(PluginGraphError, "marker is invalid"):
            verify_project(fixture.root)
        fixture = Fixture()
        self.addCleanup(fixture.close)
        marker = fixture.shadow / ".bil-deferred-ios-google-mobile-ads.json"
        marker.write_text(
            json.dumps(
                {
                    "status": "ios-native-platform-removed",
                    "plugin": "google_mobile_ads",
                    "source_root_uri": "https://example.invalid/package/",
                }
            ),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(PluginGraphError, "provenance source"):
            verify_project(fixture.root)

    def test_cli_emits_truthful_pass_markers(self) -> None:
        script = pathlib.Path(__file__).with_name(
            "verify_ios_deferred_ads_plugin_graph.py"
        )
        result = subprocess.run(
            [sys.executable, str(script), "--project-root", str(self.fixture.root)],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("IOS_DEFERRED_ADS_PLUGIN_GRAPH_GATE=PASS", result.stdout)
        self.assertIn("IOS_DEFERRED_ADS_GENERATED_SPM=ABSENT", result.stdout)


if __name__ == "__main__":
    unittest.main()
