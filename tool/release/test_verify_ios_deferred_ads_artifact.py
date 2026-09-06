#!/usr/bin/env python3
"""Regress the native Google ads failure which source-plist checks missed."""

import pathlib
import plistlib
import tempfile
import unittest
import zipfile

from verify_ios_deferred_ads_artifact import (
    ArtifactError, DART_SNAPSHOT_MARKERS, verify_app, verify_ipa,
)


class ArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.app = self.root / "Runner.app"
        self.app.mkdir()
        self.info = {"CFBundleExecutable": "Runner", "CFBundleVersion": "9"}
        self.write_info()
        (self.app / "Runner").write_bytes(bytes.fromhex("cffaedfe") + b"safe native runtime")

    def write_info(self):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))

    def make_ipa(self):
        ipa = self.root / "app.ipa"
        with zipfile.ZipFile(ipa, "w") as archive:
            for path in self.app.rglob("*"):
                if path.is_file():
                    archive.write(path, f"Payload/Runner.app/{path.relative_to(self.app).as_posix()}")
        return ipa

    def test_absent_native_sdk_accepts_app_and_ipa(self):
        self.assertEqual(verify_app(self.app, expected_build="9"), 1)
        self.assertEqual(verify_ipa(self.make_ipa(), expected_build="9"), 1)

    def write_aot(self, suffix=b"", *, exports=True):
        image = self.app / "Frameworks/App.framework/App"
        image.parent.mkdir(parents=True, exist_ok=True)
        image.write_bytes(bytes.fromhex("cffaedfe") +
                          (b"\0".join(DART_SNAPSHOT_MARKERS) if exports else b"") +
                          b"\0package:google_mobile_ads/src/ad_instance_manager.dart\0"
                          b"GoogleMobileAds UserMessagingPlatform" + suffix)

    def test_verified_dart_aot_api_names_are_not_native_sdk_linkage(self):
        self.write_aot()
        self.assertEqual(verify_app(self.app), 2)
        self.assertEqual(verify_ipa(self.make_ipa()), 2)

    def test_aot_name_without_snapshot_exports_cannot_get_exception(self):
        self.write_aot(exports=False)
        with self.assertRaisesRegex(ArtifactError, "not an identified Dart AOT"):
            verify_app(self.app)

    def test_native_sdk_symbols_remain_forbidden_inside_verified_aot(self):
        for marker in (b"FLTGoogleMobileAdsPlugin", b"GADMobileAds",
                       b"GADApplicationVerifyPublisherInitializedCorrectly",
                       b"_OBJC_CLASS_$_GADRequest", b"_OBJC_METACLASS_$_UMPConsentForm"):
            with self.subTest(marker=marker):
                self.write_aot(b"\0" + marker)
                with self.assertRaisesRegex(ArtifactError, "native ads code"):
                    verify_ipa(self.make_ipa())

    def test_runner_never_gets_dart_api_name_exception(self):
        for marker in (b"google_mobile_ads", b"GoogleMobileAds", b"UserMessagingPlatform"):
            with self.subTest(marker=marker):
                (self.app / "Runner").write_bytes(bytes.fromhex("cffaedfe") +
                    b"\0".join(DART_SNAPSHOT_MARKERS) + marker)
                with self.assertRaisesRegex(ArtifactError, "native ads code"):
                    verify_app(self.app)

    def test_generic_aot_names_do_not_hide_later_native_sdk_symbols(self):
        self.write_aot(b"x" * (1024 * 1024) + b"_OBJC_CLASS_$_UMPConsentInformation")
        with self.assertRaisesRegex(ArtifactError, "native ads code"):
            verify_ipa(self.make_ipa())

    def test_missing_id_does_not_make_static_linked_sdk_safe(self):
        with (self.app / "Runner").open("ab") as handle:
            handle.write(b"GADApplicationVerifyPublisherInitializedCorrectly")
        with self.assertRaisesRegex(ArtifactError, "native ads code"):
            verify_app(self.app)
        with self.assertRaisesRegex(ArtifactError, "native ads code"):
            verify_ipa(self.make_ipa())

    def test_objc_class_is_rejected_even_without_exception_symbol(self):
        with (self.app / "Runner").open("ab") as handle:
            handle.write(b"GADMobileAds")
        with self.assertRaisesRegex(ArtifactError, "GADMobileAds"):
            verify_app(self.app)

    def test_marker_crossing_read_boundary_is_rejected(self):
        (self.app / "Runner").write_bytes(
            bytes.fromhex("cffaedfe") + b"x" * (1024 * 1024 - 7) + b"FLTGoogleMobileAdsPlugin"
        )
        with self.assertRaisesRegex(ArtifactError, "FLTGoogleMobileAdsPlugin"):
            verify_app(self.app)

    def test_framework_rejected_without_symbols(self):
        framework = self.app / "Frameworks/GoogleMobileAds.framework"
        framework.mkdir(parents=True)
        (framework / "GoogleMobileAds").write_bytes(bytes.fromhex("cffaedfe"))
        with self.assertRaisesRegex(ArtifactError, "framework/plugin"):
            verify_app(self.app)

    def test_ump_plugin_is_also_excluded(self):
        framework = self.app / "Frameworks/UserMessagingPlatform.framework"
        framework.mkdir(parents=True)
        (framework / "UserMessagingPlatform").write_bytes(b"placeholder")
        with self.assertRaisesRegex(ArtifactError, "framework/plugin"):
            verify_app(self.app)

    def test_plugin_resource_bundle_is_excluded(self):
        bundle = self.app / "google_mobile_ads_google_mobile_ads.bundle"
        bundle.mkdir()
        (bundle / "Info.plist").write_bytes(b"resource")
        with self.assertRaisesRegex(ArtifactError, "framework/plugin"):
            verify_app(self.app)

    def test_top_level_sdk_signatures_are_rejected(self):
        for sdk in ("GoogleMobileAds", "UserMessagingPlatform"):
            with self.subTest(sdk=sdk):
                ipa = self.make_ipa()
                with zipfile.ZipFile(ipa, "a") as archive:
                    archive.writestr(f"Signatures/{sdk}.xcframework-ios.signature", b"signed")
                with self.assertRaisesRegex(ArtifactError, "framework/plugin"):
                    verify_ipa(ipa)

    def test_ads_names_in_non_native_flutter_assets_do_not_false_positive(self):
        asset = self.app / "flutter_assets/NOTICES"
        asset.parent.mkdir()
        asset.write_bytes(b"FLTGoogleMobileAdsPlugin GADMobileAds")
        self.assertEqual(verify_app(self.app), 1)

    def test_id_and_bypass_are_rejected(self):
        for key in ("GADApplicationIdentifier", "GADIntegrationManager"):
            with self.subTest(key=key):
                self.info[key] = "not-allowed"
                self.write_info()
                with self.assertRaisesRegex(ArtifactError, "ID or integration bypass"):
                    verify_app(self.app)
                del self.info[key]

    def test_wrong_build_and_missing_executable_rejected(self):
        with self.assertRaisesRegex(ArtifactError, "build number"):
            verify_app(self.app, expected_build="8")
        (self.app / "Runner").unlink()
        with self.assertRaisesRegex(ArtifactError, "executable is missing"):
            verify_app(self.app)

    def test_non_native_executable_rejected(self):
        (self.app / "Runner").write_bytes(b"not executable")
        with self.assertRaisesRegex(ArtifactError, "not Mach-O"):
            verify_app(self.app)

    def test_two_payload_apps_rejected(self):
        ipa = self.make_ipa()
        with zipfile.ZipFile(ipa, "a") as archive:
            archive.writestr("Payload/Second.app/Info.plist", b"bad")
        with self.assertRaisesRegex(ArtifactError, "exactly one"):
            verify_ipa(ipa)

    def test_traversal_rejected_without_extracting(self):
        ipa = self.make_ipa()
        with zipfile.ZipFile(ipa, "a") as archive:
            archive.writestr("Payload/Runner.app/../../bad", b"bad")
        with self.assertRaisesRegex(ArtifactError, "unsafe path"):
            verify_ipa(ipa)

    def test_duplicate_path_rejected(self):
        ipa = self.make_ipa()
        with zipfile.ZipFile(ipa, "a") as archive:
            archive.writestr("Payload/Runner.app/runner", b"bad")
        with self.assertRaisesRegex(ArtifactError, "case-colliding"):
            verify_ipa(ipa)


if __name__ == "__main__":
    unittest.main()
