import pathlib
import plistlib
import tempfile
import unittest
import zipfile

from verify_final_artifact_identity import android_identity, ios_archive, ios_info_identity


class FinalArtifactIdentityTest(unittest.TestCase):
    expected = {"package": "com.bilhealth.bodyintelligencelog", "version": "1.0.0", "build": "37"}

    def info(self, **changes):
        return plistlib.dumps({"CFBundleIdentifier": self.expected["package"],
                              "CFBundleShortVersionString": "1.0.0",
                              "CFBundleVersion": "37", **changes})

    def test_ios_binary_plist_identity(self):
        raw = plistlib.dumps(plistlib.loads(self.info()), fmt=plistlib.FMT_BINARY)
        result = ios_info_identity(raw, **self.expected)
        self.assertEqual(result["build"], "37")
        self.assertFalse(result["signing_verified_by_this_check"])

    def test_ios_each_identity_field_must_match(self):
        for field in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion"):
            with self.subTest(field=field), self.assertRaises(ValueError):
                ios_info_identity(self.info(**{field: "wrong"}), **self.expected)

    def test_android_manifest_reads_actual_identity(self):
        raw = b'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.bilhealth.bodyintelligencelog" android:versionName="1.0.0" android:versionCode="33"/>'
        result = android_identity(raw, **(self.expected | {"build": "33"}))
        self.assertEqual(result["build"], "33")
        for old, new in ((b'bodyintelligencelog', b'wrong'), (b'1.0.0', b'2.0.0'), (b'"33"', b'"32"')):
            with self.subTest(old=old), self.assertRaises(ValueError):
                android_identity(raw.replace(old, new), **(self.expected | {"build": "33"}))

    def scan(self, extras=None, privacy=True):
        with tempfile.TemporaryDirectory() as work:
            path = pathlib.Path(work) / "candidate.ipa"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("Payload/Runner.app/Info.plist", self.info())
                if privacy:
                    archive.writestr("Payload/Runner.app/PrivacyInfo.xcprivacy", plistlib.dumps({"NSPrivacyTracking": False}))
                for name, raw in (extras or {}).items():
                    archive.writestr(name, raw)
            return ios_archive(path, **self.expected)

    def test_archive_inventory_does_not_claim_runtime_or_signing(self):
        result = self.scan({"Payload/Runner.app/Frameworks/Example.framework/Info.plist": plistlib.dumps({"CFBundleIdentifier": "example.sdk", "CFBundleShortVersionString": "2.0"}),
                            "Payload/Runner.app/Frameworks/Example.framework/PrivacyInfo.xcprivacy": plistlib.dumps({"NSPrivacyTracking": True, "NSPrivacyTrackingDomains": ["fixture.invalid"]})})
        self.assertEqual(len(result["privacy_manifests"]), 2)
        self.assertTrue(any(x["declared_tracking"] for x in result["privacy_manifests"]))
        self.assertTrue(any(x["declared_tracking_domains"] == ["fixture.invalid"]
                            for x in result["privacy_manifests"]))
        self.assertFalse(result["privacy_runtime_verified"])
        self.assertFalse(result["static_linked_sdk_completeness_verified"])
        self.assertEqual(len(result["ipa_sha256"]), 64)

    def test_missing_app_privacy_manifest_fails(self):
        with self.assertRaises(ValueError):
            self.scan(privacy=False)

    def test_unsafe_archive_path_fails(self):
        with self.assertRaises(ValueError):
            self.scan({"../outside": b"invalid"})

    def test_ambiguous_top_level_app_fails(self):
        with self.assertRaises(ValueError):
            self.scan({"Payload/Other.app/Info.plist": self.info()})

    def test_invalid_privacy_boolean_fails(self):
        with self.assertRaises(ValueError):
            self.scan({"Payload/Runner.app/Resources.bundle/PrivacyInfo.xcprivacy": plistlib.dumps({"NSPrivacyTracking": "false"})})

    def test_tracking_domains_must_be_strings(self):
        with self.assertRaises(ValueError):
            self.scan({"Payload/Runner.app/Resources.bundle/PrivacyInfo.xcprivacy": plistlib.dumps({"NSPrivacyTrackingDomains": [7]})})


if __name__ == "__main__":
    unittest.main()
