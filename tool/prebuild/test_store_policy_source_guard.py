#!/usr/bin/env python3
"""Deterministic local tests for BIL's read-only store-policy source audit."""
import plistlib
import tempfile
import unittest
from pathlib import Path

from store_policy_source_guard import run


def write(root, name, text):
    p = root / name
    p.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(text, bytes):
        p.write_bytes(text)
    else:
        p.write_text(text, encoding="utf-8")
    return p


def fixture(root):
    manifest = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
      <uses-permission android:name="android.permission.health.READ_STEPS"/>
      <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
      <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
      <application><activity android:name=".Rationale" android:exported="true">
        <intent-filter>
          <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>
          <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
          <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
        </intent-filter>
      </activity></application>
    </manifest>'''
    write(root, "android/app/src/main/AndroidManifest.xml", manifest)
    write(root, "android/app/build.gradle.kts",
          'targetSdk = 36\nimplementation("com.google.android.play:integrity:1.6.0")\n')
    write(root, "ios/Runner/Info.plist", plistlib.dumps({
        k: "Relevant feature-initiated purpose."
        for k in (
            "NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
            "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription",
            "NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription",
            "NSBluetoothAlwaysUsageDescription",
        )
    }))
    write(root, "ios/Runner/PrivacyInfo.xcprivacy", plistlib.dumps({
        "NSPrivacyTracking": False,
        "NSPrivacyAccessedAPITypes": [{"NSPrivacyAccessedAPIType": "UserDefaults"}],
    }))
    write(root, "pubspec.yaml", "in_app_review: ^2.0.12\n")
    write(root, "lib/app/services/store_review_prompt_service.dart",
          "_review.requestReview(); minimumExperience promptCooldown _canRequestNow();")
    write(root, "lib/features/commerce/presentation/commerce_paywall.dart",
          "paywall-terms-link paywall-privacy-link onRestore")
    write(root, "lib/features/community/presentation/community_post_card.dart",
          "'report' 'block'")
    write(root, "lib/features/community/presentation/community_safety_page.dart",
          "acceptContentPolicy")


class StorePolicySourceGuardTest(unittest.TestCase):
    def test_baseline_passes_static_heuristics_but_requires_human_review(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture(root)
            result = run(root)
            self.assertTrue(result["pass"], result["errors"])
            self.assertGreater(len(result["warnings"]), 0)
            self.assertEqual(len(result["counts"]["health_permissions"]), 3)

    def test_extra_health_permission_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture(root)
            manifest = root / "android/app/src/main/AndroidManifest.xml"
            xml = manifest.read_text()
            xml = xml.replace("<application>",
                              '<uses-permission android:name="android.permission.health.READ_HEART_RATE"/><application>')
            manifest.write_text(xml)
            result = run(root)
            self.assertFalse(result["pass"])
            self.assertIn("HEALTH_CONNECT_SCOPE_MISMATCH",
                          [error["code"] for error in result["errors"]])

    def test_custom_rating_prompt_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture(root)
            review = root / "lib/app/services/store_review_prompt_service.dart"
            review.write_text(review.read_text() + "\nshowDialog(context: context);")
            result = run(root)
            self.assertFalse(result["pass"])
            self.assertIn("CUSTOM_RATING_PREPROMPT",
                          [error["code"] for error in result["errors"]])


if __name__ == "__main__":
    unittest.main()
