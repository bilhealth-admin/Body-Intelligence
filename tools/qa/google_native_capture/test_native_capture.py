import hashlib
import html
import json
import shlex
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import zipfile

from native_capture import (Blocked, Device, MEAL_GOAL_CHAPTER, MEAL_GOAL_STAGE, PACKAGE, PRODUCER, REPO, android_text_commands,
                            capture_premium_meal_goal_chapter, classify_blocker, extract_signed_inputs,
                            finalize_capture,
                            package_identity, parse_nodes, redact, select,
                            validate_manifest, validate_meal_goal_content, validate_producer, validate_receipt,
                            visible_premium_active)

SOURCE = "1b23d4d4bb73d467f9c3cf1425b2eb2d8cc78c2d"
CERT = "b" * 64


def producer():
    return ({"id": 101, "head_sha": SOURCE, "path": PRODUCER, "repository": {"full_name": REPO},
             "status": "completed", "conclusion": "success", "event": "workflow_dispatch"},
            {"id": 202, "name": "bil-android-signed-aab-" + SOURCE, "expired": False,
             "size_in_bytes": 500, "digest": "sha256:" + "a" * 64,
             "workflow_run": {"id": 101, "head_sha": SOURCE}})


def ui(label="More", package=PACKAGE, bounds="[0,0][100,100]", cls="android.widget.Button"):
    return f'<node text="{label}" content-desc="" package="{package}" bounds="{bounds}" enabled="true" class="{cls}" />'


class ProducerGuardTests(unittest.TestCase):
    def test_only_exact_successful_signed_source_is_accepted(self):
        run, artifact = producer()
        validate_producer(run, artifact, SOURCE, 101, 202)

    def test_other_source_rejected_even_with_success(self):
        run, artifact = producer()
        run["head_sha"] = "c" * 40
        with self.assertRaisesRegex(Blocked, "source_mismatch"):
            validate_producer(run, artifact, SOURCE, 101, 202)

    def test_debug_producer_rejected(self):
        run, artifact = producer()
        run["path"] = ".github/workflows/bil_android_isolated_emulator_smoke.yml"
        with self.assertRaisesRegex(Blocked, "signed_workflow"):
            validate_producer(run, artifact, SOURCE, 101, 202)

    def test_expired_or_digestless_artifact_rejected(self):
        for field, value in (("expired", True), ("digest", None)):
            run, artifact = producer()
            artifact[field] = value
            with self.assertRaises(Blocked):
                validate_producer(run, artifact, SOURCE, 101, 202)

    def test_archive_traversal_rejected_before_extract(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
            archive = Path(d) / "archive.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("../escape.apk", b"x")
            with self.assertRaisesRegex(Blocked, "unsafe_artifact_entry"):
                extract_signed_inputs(archive, Path(d) / "out")
            self.assertFalse((Path(d) / "escape.apk").exists())

    def test_archive_duplicates_rejected(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
            archive = Path(d) / "archive.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("one/BIL-Android33-derived-universal.apk", b"x")
                z.writestr("two/BIL-Android33-derived-universal.apk", b"y")
            with self.assertRaisesRegex(Blocked, "ambiguous_artifact_entry"):
                extract_signed_inputs(archive, Path(d) / "out")

    def test_receipt_bound_to_actual_bytes_certificate_and_no_recompile(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
            apk = Path(d) / "fixture.apk"
            apk.write_bytes(b"guard fixture only, never installed")
            receipt = {"status": "VERIFIED_DERIVED_SIGNED_QA_APK", "source_sha": SOURCE,
                       "build": 33, "package": PACKAGE, "app_recompiled": False,
                       "play_upload_performed": False, "installation_source": "not_installed",
                       "certificate_sha256": CERT, "apk_sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
                       "aab_sha256": "a" * 64}
            validate_receipt(receipt, apk, SOURCE, CERT)
            apk.write_bytes(b"changed")
            with self.assertRaisesRegex(Blocked, "hash_or_certificate"):
                validate_receipt(receipt, apk, SOURCE, CERT)


class VisibleUIParserTests(unittest.TestCase):
    def test_adb_failure_does_not_expose_credential_command_or_output(self):
        secret = "do-not-log-this-password"
        device = Device("emulator-fixture-only", ".", (secret,))
        error = subprocess.CalledProcessError(1, ["adb", "shell", "input text " + secret], output=secret.encode(), stderr=secret.encode())
        with patch("native_capture.subprocess.run", side_effect=error):
            with self.assertRaises(Blocked) as raised:
                device.adb("shell", "input text " + secret)
        self.assertEqual(str(raised.exception), "adb_operation_failed")
        self.assertNotIn(secret, str(raised.exception))
        self.assertTrue(raised.exception.__suppress_context__)

    def test_written_snapshot_removes_password_fields_and_xml_escaped_credentials(self):
        secret = "Password<&'\"%s"
        unknown_password = "not-provided-in-secret-environment"
        encoded = html.escape(secret, quote=True)
        xml = ('<?xml version="1.0"?><hierarchy>'
               + ui('reviewer@example.test')
               + f'<node text="{html.escape(unknown_password)}" content-desc="password content" password="true" package="{PACKAGE}" bounds="[0,100][100,200]" enabled="true" />'
               + f'<node text="{encoded}" content-desc="{html.escape(encoded,quote=True)}" package="{PACKAGE}" bounds="[0,200][100,300]" enabled="true" />'
               + '</hierarchy>')
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
            device = Device("emulator-fixture-only", d, (secret,))
            device.adb = Mock(side_effect=["dumped", xml])
            device.nodes("blocked-ui")
            saved = (Path(d)/"blocked-ui.xml").read_text(encoding="utf-8")
            self.assertNotIn(unknown_password, saved)
            self.assertNotIn("password content", saved)
            self.assertNotIn(secret, saved)
            self.assertNotIn(encoded, saved)
            self.assertNotIn("reviewer@example.test", saved)
            self.assertIn("[PASSWORD_REDACTED]", saved)
            self.assertIn("[REDACTED]", saved)

    def test_password_punctuation_is_quoted_and_percent_s_is_not_rewritten(self):
        value = "Ab%s ';$()&<>"
        commands = android_text_commands(value)
        reconstructed = ''.join(' ' if c == 'input keyevent KEYCODE_SPACE' else shlex.split(c)[2] for c in commands)
        self.assertEqual(reconstructed, value)
        self.assertFalse(any(shlex.split(c) == ['input','text','%s'] for c in commands))
        with self.assertRaises(Blocked):
            android_text_commands('a\nb')

    def test_onboarding_is_detected_without_inventing_health_profile(self):
        nodes = parse_nodes("<hierarchy>" + ui("What is your current weight?") + "</hierarchy>")
        self.assertEqual(classify_blocker(nodes), "onboarding_requires_explicit_test_profile_no_values_invented")

    def test_other_package_does_not_trigger_app_blocker(self):
        nodes = parse_nodes("<hierarchy>" + ui("Verify your email", package="com.other.app") + "</hierarchy>")
        self.assertIsNone(classify_blocker(nodes))

    def test_visible_node_selection_uses_observed_bounds(self):
        nodes = parse_nodes("<?xml version='1.0'?><hierarchy>" + ui() + "</hierarchy>")
        self.assertEqual(select(nodes, "More")["center"], (50, 50))

    def test_selector_ambiguity_is_blocking_not_guessed(self):
        nodes = parse_nodes("<hierarchy>" + ui() + ui(bounds="[0,200][100,300]") + "</hierarchy>")
        with self.assertRaisesRegex(Blocked, "ambiguous"):
            select(nodes, "More")

    def test_other_package_cannot_impersonate_app(self):
        nodes = parse_nodes("<hierarchy>" + ui(package="com.other.app") + "</hierarchy>")
        with self.assertRaises(Blocked):
            select(nodes, "More")

    def test_doctype_is_rejected(self):
        with self.assertRaisesRegex(Blocked, "unsafe"):
            parse_nodes('<!DOCTYPE x [<!ENTITY x SYSTEM "file:///tmp/test">]><hierarchy/>')

    def test_login_requires_exact_two_visible_edit_fields(self):
        nodes = parse_nodes("<hierarchy>" + ui("Email address", cls="android.widget.EditText") +
                            ui("Password", bounds="[0,120][100,220]", cls="android.widget.EditText") + "</hierarchy>")
        self.assertEqual(select(nodes, "", edit_index=1)["center"], (50, 170))
        with self.assertRaisesRegex(Blocked, "two_fields"):
            select(nodes[:1], "", edit_index=0)

    def test_credentials_and_emails_are_not_saved_in_xml(self):
        self.assertEqual(redact("hello reviewer@example.test and secret_value", ("secret_value",)),
                         "hello [EMAIL_REDACTED] and [REDACTED]")


class BinaryIdentityTests(unittest.TestCase):
    def test_installed_package_version_guard(self):
        package_identity("versionCode=33 minSdk=26\nversionName=1.0.0")
        with self.assertRaisesRegex(Blocked, "code_mismatch"):
            package_identity("versionCode=32\nversionName=1.0.0")

    def test_manifest_requires_production_release_package(self):
        xml = f'<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{PACKAGE}" android:versionCode="33" android:versionName="1.0.0"><application android:debuggable="false" /></manifest>'
        validate_manifest(xml)
        with self.assertRaisesRegex(Blocked, "debuggable"):
            validate_manifest(xml.replace('debuggable="false"', 'debuggable="true"'))


def meal_goal_nodes(package=PACKAGE, missing=(), combined=False):
    rows = [ui("Calorie goals by meal", package=package),
            ui("Set a separate calorie goal for each meal.", package=package, bounds="[0,120][800,220]")]
    for index, meal in enumerate(("breakfast", "lunch", "dinner", "snack")):
        if meal not in missing:
            label = meal + (" No meal goal" if combined else "")
            top = 300 + index * 180
            rows.append(ui(label, package=package, bounds=f"[0,{top}][800,{top + 120}]"))
    return parse_nodes("<hierarchy>" + "".join(rows) + "</hierarchy>")


class PremiumMealGoalEvidenceTests(unittest.TestCase):
    def test_complete_real_xml_content_proves_four_read_only_rows_without_values(self):
        for combined in (False, True):
            proof = validate_meal_goal_content(meal_goal_nodes(combined=combined), (1080, 1920))
            self.assertEqual(proof["meal_rows"], ["breakfast", "lunch", "dinner", "snack"])
            self.assertTrue(proof["read_only"])
            self.assertFalse(proof["goals_saved_or_cleared"])
            self.assertEqual(proof["package"], PACKAGE)
            self.assertNotIn("No meal goal", json.dumps(proof))

    def test_title_or_four_labels_without_actual_content_is_not_feature_proof(self):
        title = parse_nodes("<hierarchy>" + ui("Calorie goals by meal") + "</hierarchy>")
        with self.assertRaisesRegex(Blocked, "content_not_visible"):
            validate_meal_goal_content(title, (1080, 1920))
        without_intro = [n for n in meal_goal_nodes() if "Set a separate" not in n["text"]]
        with self.assertRaisesRegex(Blocked, "content_not_visible"):
            validate_meal_goal_content(without_intro, (1080, 1920))

    def test_each_missing_meal_prevents_certification(self):
        for missing in ("breakfast", "lunch", "dinner", "snack"):
            with self.subTest(missing=missing), self.assertRaisesRegex(Blocked, "four_meals_not_visible"):
                validate_meal_goal_content(meal_goal_nodes(missing=(missing,)), (1080, 1920))

    def test_other_package_cannot_supply_content_or_fill_missing_rows(self):
        with self.assertRaisesRegex(Blocked, "wrong_app_package"):
            validate_meal_goal_content(meal_goal_nodes(package="com.other.app"), (1080, 1920))
        mixed = meal_goal_nodes(missing=("snack",)) + [meal_goal_nodes(package="com.other.app")[-1]]
        with self.assertRaisesRegex(Blocked, "four_meals_not_visible"):
            validate_meal_goal_content(mixed, (1080, 1920))

    def test_paywall_or_unverified_badge_blocks_even_with_stale_content(self):
        for label in ("Plans", "View Premium plans", "Plans View Premium plans", "Explore Premium", "Retry subscription check", "Restore purchases", "Continue · $1.99"):
            nodes = meal_goal_nodes() + parse_nodes("<hierarchy>" + ui(label) + "</hierarchy>")
            with self.subTest(label=label), self.assertRaisesRegex(Blocked, "paywall_or_unverified"):
                validate_meal_goal_content(nodes, (1080, 1920))

    def test_offscreen_or_invisible_meal_does_not_count_as_visible(self):
        nodes = meal_goal_nodes()
        nodes[-1]["center"] = (400, 2200)
        with self.assertRaisesRegex(Blocked, "four_meals_not_visible"):
            validate_meal_goal_content(nodes, (1080, 1920))
        nodes = meal_goal_nodes()
        nodes[-1]["visible-to-user"] = "false"
        with self.assertRaisesRegex(Blocked, "four_meals_not_visible"):
            validate_meal_goal_content(nodes, (1080, 1920))

    def test_ambiguous_or_merged_meal_rows_fail_closed(self):
        nodes = meal_goal_nodes()
        nodes[-1]["center"] = nodes[-2]["center"]
        with self.assertRaisesRegex(Blocked, "distinct_rows_not_visible"):
            validate_meal_goal_content(nodes, (1080, 1920))
        duplicate = parse_nodes("<hierarchy>" + ui("snack", bounds="[0,1200][800,1320]") + "</hierarchy>")
        with self.assertRaisesRegex(Blocked, "ambiguous_row"):
            validate_meal_goal_content(meal_goal_nodes() + duplicate, (1080, 1920))

    def test_foreign_active_badge_does_not_unlock_the_capture_chapter(self):
        own_free = parse_nodes("<hierarchy>" + ui("Explore Premium") + ui("Active", package="com.other.app") + "</hierarchy>")
        self.assertFalse(visible_premium_active(own_free))
        own_active = parse_nodes("<hierarchy>" + ui("Active") + "</hierarchy>")
        self.assertTrue(visible_premium_active(own_active))

    def test_wait_snapshots_and_rejects_paywall_without_any_input_command(self):
        device = Device("emulator-fixture-only", ".", ())
        device.adb = Mock(return_value="Physical size: 1080x1920")
        device.nodes = Mock(return_value=parse_nodes("<hierarchy>" + ui("View Premium plans") + "</hierarchy>"))
        with self.assertRaisesRegex(Blocked, "paywall_or_unverified"):
            device.wait_meal_goal_content()
        device.adb.assert_called_once_with("shell", "wm", "size")
        device.nodes.assert_called_once_with("premium-meal-calorie-goals")

    def test_wait_requires_four_visible_meals_after_loading_and_never_taps(self):
        device = Device("emulator-fixture-only", ".", ())
        device.adb = Mock(return_value="Physical size: 1080x1920")
        device.nodes = Mock(side_effect=[meal_goal_nodes(missing=("snack",)), meal_goal_nodes()])
        with patch("native_capture.time.sleep") as sleep:
            proof = device.wait_meal_goal_content()
        self.assertEqual(proof["meal_rows"], ["breakfast", "lunch", "dinner", "snack"])
        self.assertEqual(device.nodes.call_count, 2)
        sleep.assert_called_once_with(1)
        device.adb.assert_called_once_with("shell", "wm", "size")

    def test_navigation_opens_goals_then_meal_feature_and_never_an_editor(self):
        device = Mock(spec=Device)
        proof = validate_meal_goal_content(meal_goal_nodes(), (1080, 1920))
        device.wait_meal_goal_content.return_value = proof
        result = {"stages": [], "blocked_chapters": [], "not_demonstrated": [MEAL_GOAL_CHAPTER]}
        with patch("native_capture.time.sleep"):
            self.assertTrue(capture_premium_meal_goal_chapter(device, result))
        self.assertEqual([entry[0] for entry in device.method_calls],
                         ["more", "scroll_to", "tap", "scroll_to", "tap", "wait_meal_goal_content"])
        self.assertEqual([entry.args[0] for entry in device.tap.call_args_list],
                         ["Goals", "Calorie Goals By Meal"])
        self.assertEqual(result["stages"], [MEAL_GOAL_STAGE])
        self.assertEqual(result["not_demonstrated"], [])
        self.assertEqual(result["premium_meal_goal_evidence"], proof)
        device.adb.assert_not_called()

    def test_failed_feature_journey_stays_blocked_and_unproven(self):
        device = Mock(spec=Device)
        device.wait_meal_goal_content.side_effect = Blocked("meal_calorie_goals_paywall_or_unverified")
        result = {"stages": [], "blocked_chapters": [], "not_demonstrated": [MEAL_GOAL_CHAPTER]}
        self.assertFalse(capture_premium_meal_goal_chapter(device, result))
        self.assertEqual(result["stages"], [])
        self.assertEqual(result["not_demonstrated"], [MEAL_GOAL_CHAPTER])
        self.assertNotIn("premium_meal_goal_evidence", result)
        self.assertEqual(result["blocked_chapters"], [{"chapter": "premium_meal_calorie_goals", "code": "meal_calorie_goals_paywall_or_unverified"}])
        self.assertEqual([entry.args[0] for entry in device.tap.call_args_list],
                         ["Goals", "Calorie Goals By Meal"])
        device.adb.assert_not_called()


class RecordingFinalizationTests(unittest.TestCase):
    def test_finalization_error_blocks_exit_even_with_earlier_valid_clips(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
            device = Mock()
            device.clips = [{"path": "earlier-valid.mp4", "sha256": "a"*64}]
            device.stop.side_effect = RuntimeError("credential-bearing message must not be saved")
            result = {"status": "PARTIAL_NATIVE_EVIDENCE_REQUIRES_REMAINING_JOURNEYS_AND_VISUAL_REVIEW", "blocked_chapters": []}
            exit_code = finalize_capture(device, d, result)
            saved = json.loads((Path(d)/"capture-receipt.json").read_text())
            self.assertEqual(exit_code, 1)
            self.assertEqual(saved["status"], "BLOCKED_NATIVE_JOURNEY_NOT_CERTIFIED")
            self.assertEqual(saved["failure_code"], "native_recording_finalization_failed")
            self.assertEqual(saved["recording_finalization_error"], "RuntimeError")
            self.assertNotIn("credential-bearing", json.dumps(saved))

    def test_no_valid_video_blocks_exit_even_if_stop_returns_normally(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as d:
            device = Mock()
            device.clips = []
            result = {"status": "PARTIAL_NATIVE_EVIDENCE_REQUIRES_REMAINING_JOURNEYS_AND_VISUAL_REVIEW", "blocked_chapters": []}
            self.assertEqual(finalize_capture(device, d, result), 1)
            self.assertEqual(result["failure_code"], "no_valid_native_video_recorded")


if __name__ == "__main__":
    unittest.main()
