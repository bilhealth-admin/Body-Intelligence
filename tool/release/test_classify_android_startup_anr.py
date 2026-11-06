"""Regression fixtures for S2/API33's real lowmemorykiller false positive."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from xml.etree import ElementTree

import classify_android_startup_anr as subject


# Exact startup-logcat.txt:4474 from run42138963255/job127634949103.
CARRIERCONFIG_KILL = (
    "11-06 00:58:48.344   126   126 I lowmemorykiller: Kill 'com.android.carrierconfig' "
    "(1605), uid 10148, oom_score_adj 999 to free 26660kB rss, 31612kB swap; "
    "reason: device is not responding\n"
)
WELCOME_UI = (
    '<hierarchy><node package="com.bilhealth.bodyintelligencelog" '
    'class="android.widget.Button" content-desc="Sign in" clickable="true" '
    'enabled="true" /></hierarchy>'
)


def dialog_xml(text: str, attribute: str = "text") -> str:
    root = ElementTree.Element("hierarchy")
    ElementTree.SubElement(root, "node", {
        "package": "android", "resource-id": "android:id/aerr_message",
        "class": "android.widget.TextView", attribute: text,
    })
    return ElementTree.tostring(root, encoding="unicode")


class StartupAnrClassificationTest(unittest.TestCase):
    def test_actual_carrierconfig_kill_is_not_an_anr(self):
        result = subject.classify_anr(CARRIERCONFIG_KILL, WELCOME_UI)
        self.assertEqual(result["status"], "NO_ANR_EVIDENCE")
        self.assertEqual(result["logcat_anr_records"], [])
        self.assertEqual(result["ui_anr_text"], [])
        self.assertFalse(result["app_startup_proven"])

    def test_explicit_anr_for_any_app_or_system_ui_still_fails(self):
        for package in (
            "com.bilhealth.bodyintelligencelog", "com.android.systemui",
            "com.google.android.apps.nexuslauncher",
        ):
            with self.subTest(package=package):
                record = f"11-06 00:58:48.344 482 521 E ActivityManager: ANR in {package}\n"
                result = subject.classify_anr(CARRIERCONFIG_KILL + record, WELCOME_UI)
                self.assertEqual(result["status"], "ANR_DETECTED")
                self.assertEqual(result["logcat_anr_records"][0]["line"], 2)

    def test_space_delimited_application_not_responding_record_fails(self):
        result = subject.classify_anr(
            "E WindowManager: Application Not Responding: com.android.systemui\n",
            WELCOME_UI,
        )
        self.assertEqual(result["status"], "ANR_DETECTED")

    def test_real_brief_anr_records_and_space_padded_pids_still_fail(self):
        for package in (
            "com.bilhealth.bodyintelligencelog", "com.android.systemui",
            "com.google.android.apps.nexuslauncher",
        ):
            for pid in ("123", "  123"):
                with self.subTest(package=package, pid=pid):
                    record = f"E/ActivityManager({pid}): ANR in {package}\n"
                    result = subject.classify_anr(record, WELCOME_UI)
                    self.assertEqual(result["status"], "ANR_DETECTED")
                    self.assertEqual(result["logcat_anr_records"][0]["record"], record.strip())

    def test_brief_lowmemorykiller_reason_is_not_an_anr(self):
        brief = CARRIERCONFIG_KILL.replace(
            "11-06 00:58:48.344   126   126 I lowmemorykiller:",
            "I/lowmemorykiller(  126):",
        )
        result = subject.classify_anr(brief, WELCOME_UI)
        self.assertEqual(result["status"], "NO_ANR_EVIDENCE")
        self.assertEqual(result["logcat_anr_records"], [])

    def test_english_and_arabic_ui_dialog_text_still_fails(self):
        for text in ("BIL isn't responding", "BIL isn’t responding",
                     "BIL is not responding", "BIL لا يستجيب",
                     "Application Not Responding: com.android.systemui"):
            for attribute in ("text", "content-desc"):
                with self.subTest(text=text, attribute=attribute):
                    result = subject.classify_anr("", dialog_xml(text, attribute))
                    self.assertEqual(result["status"], "ANR_DETECTED")
                    self.assertEqual(result["ui_anr_text"], [text])

    def test_corrupt_ui_evidence_cannot_be_accepted(self):
        with self.assertRaises(ElementTree.ParseError):
            subject.classify_anr(CARRIERCONFIG_KILL, "<hierarchy")

    def test_cli_preserves_success_and_failure_receipts(self):
        helper = Path(subject.__file__).resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            logcat, ui, receipt = (root / name for name in ("logcat.txt", "ui.xml", "result.json"))
            for log, xml, expected_exit, status in (
                (CARRIERCONFIG_KILL, WELCOME_UI, 0, "NO_ANR_EVIDENCE"),
                (CARRIERCONFIG_KILL, dialog_xml("BIL لا يستجيب"), 1, "ANR_DETECTED"),
                ("E/ActivityManager(123): ANR in com.bilhealth.bodyintelligencelog\n",
                 WELCOME_UI, 1, "ANR_DETECTED"),
            ):
                logcat.write_text(log, encoding="utf-8")
                ui.write_text(xml, encoding="utf-8")
                result = subprocess.run(
                    [sys.executable, str(helper), "--logcat", str(logcat),
                     "--ui", str(ui), "--evidence", str(receipt)],
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, expected_exit, result.stderr)
                self.assertEqual(json.loads(receipt.read_text())["status"], status)
            ui.write_text("<hierarchy", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(helper), "--logcat", str(logcat),
                 "--ui", str(ui), "--evidence", str(receipt)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
