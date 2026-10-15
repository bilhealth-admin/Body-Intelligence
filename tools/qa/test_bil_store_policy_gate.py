import copy
from pathlib import Path
import tempfile
import subprocess
import unittest

from tools.qa.bil_store_policy_gate import (
    implementation_input_paths, permission_issues, permission_names, release_decision, validate_requirements,
)


def row():
    return {
        "id": "G01", "platform": "Google", "clause": "App Access",
        "official_urls": ["https://support.google.com/googleplay/android-developer/answer/15748846"],
        "read_date": "2026-10-15", "applies": True, "rationale": "Reviewer needs paid access",
        "implementation": "Production entitlement repository", "proof_test": "Receipt-bound gate tests",
        "status": "BLOCKED", "evidence": "Signed reviewer journey unavailable",
        "minimum_action": "Verify exact artifact with the review account",
        "needs_signed_device_console": True, "previous_rejection": "Android32 paywall", "risk": "P0",
    }


class PolicyEvidenceTest(unittest.TestCase):
    def test_complete_blocked_record_is_valid_but_cannot_certify(self):
        validate_requirements([row()])
        self.assertEqual(release_decision([row()]), "BLOCKED")

    def test_empty_inventory_cannot_pass(self):
        with self.assertRaises(ValueError):
            validate_requirements([])

    def test_missing_proof_cannot_pass(self):
        sample = row()
        sample["proof_test"] = ""
        with self.assertRaises(ValueError):
            validate_requirements([sample])

    def test_unofficial_source_cannot_certify_a_rule(self):
        sample = row()
        sample["official_urls"] = ["https://support.google.com.outside.example/policy"]
        with self.assertRaises(ValueError):
            validate_requirements([sample])

    def test_source_pass_is_never_an_artifact_pass(self):
        sample = row()
        sample.update(status="PASS", status_scope="source_only")
        validate_requirements([sample])
        self.assertEqual(release_decision([sample]), "BLOCKED")
        sample.pop("status_scope")
        with self.assertRaises(ValueError):
            validate_requirements([sample])

    def test_not_applicable_needs_an_explicit_reason_and_applicability(self):
        sample = row()
        sample["status"] = "NOT APPLICABLE"
        with self.assertRaises(ValueError):
            validate_requirements([sample])

    def test_duplicate_policy_ids_cannot_hide_a_missing_requirement(self):
        with self.assertRaises(ValueError):
            validate_requirements([row(), copy.deepcopy(row())])

    def test_snapshot_includes_real_native_assets_and_unicode_not_ignored_or_failure_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            visible = ["ios/Runner/Native.swift", "ios/App.xcodeproj/project.pbxproj",
                       "android/app/src/main/Bridge.java", "assets/صور/meal.png",
                       "test/goldens/approved.png", "lib/a.dart", "pubspec.lock",
                       "supabase/tests/reviewer.mjs", "supabase/config.toml",
                       "tool/prebuild/policy.py", "analysis_options.yaml",
                       "devtools_options.yaml", ".gitattributes", ".metadata",
                       ".gitignore", "wrangler.site.jsonc"]
            for name in visible + ["test/a/failures/test.png", "android/local.properties"]:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"fixture")
            (root / ".gitignore").write_bytes(b"android/local.properties\n")
            self.assertEqual(implementation_input_paths(root), sorted(visible))

    def test_merged_manifest_does_not_inherit_source_removal(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "AndroidManifest.xml"
            path.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
                xmlns:tools="http://schemas.android.com/tools">
              <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>
              <uses-permission android:name="android.permission.health.READ_BODY_FAT"/>
            </manifest>''')
            self.assertEqual(permission_issues(permission_names(path)), {"android.permission.health.READ_BODY_FAT"})
            path.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
              <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
            </manifest>''')
            self.assertEqual(permission_issues(permission_names(path)), {"com.google.android.gms.permission.AD_ID"})


if __name__ == "__main__":
    unittest.main()
