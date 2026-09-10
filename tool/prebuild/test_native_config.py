"""Native release configuration regressions, without loading any media."""

from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android/app/src/main/res"
ANDROID = "{http://schemas.android.com/apk/res/android}"


class AndroidConfigurationTest(unittest.TestCase):
    def test_navigation_bar_attribute_is_version_qualified(self):
        seen = set()
        for path in RES.glob("values*/styles.xml"):
            for item in ET.parse(path).iter("item"):
                if item.get("name") != "android:windowLightNavigationBar":
                    continue
                match = re.search(r"-v(\d+)$", path.parent.name)
                self.assertIsNotNone(match, str(path))
                self.assertGreaterEqual(int(match[1]), 27)
                self.assertEqual(item.text, "false")
                seen.add(path.parent.name)
        self.assertEqual(seen, {"values-v27", "values-night-v27",
                                "values-v31", "values-night-v31"})

    def test_health_and_sessions_excluded_from_os_backup_and_transfer(self):
        app = ET.parse(ROOT / "android/app/src/main/AndroidManifest.xml").find("application")
        self.assertEqual(app.get(ANDROID + "allowBackup"), "false")
        self.assertEqual(app.get(ANDROID + "fullBackupContent"), "false")
        self.assertEqual(app.get(ANDROID + "dataExtractionRules"), "@xml/data_extraction_rules")
        rules = ET.parse(RES / "xml/data_extraction_rules.xml").getroot()
        expected = {"root", "file", "database", "sharedpref", "external",
                    "device_root", "device_file", "device_database", "device_sharedpref"}
        for section in ("cloud-backup", "device-transfer"):
            entries = rules.find(section).findall("exclude")
            self.assertEqual({e.get("domain") for e in entries}, expected)
            self.assertTrue(all(e.get("path") == "." for e in entries))

    def test_indonesian_native_resources_use_android_resource_alias(self):
        names = {e.get("name") for e in ET.parse(RES / "values-in/strings.xml").iter("string")}
        self.assertIn("health_permissions_rationale_body", names)
        self.assertFalse((RES / "values-id").exists())


if __name__ == "__main__":
    unittest.main()
