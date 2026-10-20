#!/usr/bin/env python3
"""Strict regression tests against the genuine frozen verifier and dump fixtures."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from android_startup_focus_controller import (
    current_focus_value,
    fresh_boot_anr_lines,
    install_live_focus_parser,
    load_frozen_verifier,
)

ROOT = Path(os.environ["BIL_FROZEN_APP_ROOT"]).resolve()
FIXTURES = Path(__file__).with_name("android_startup_focus_fixtures")


class LiveFocusControllerTest(unittest.TestCase):
    def _classify(self, text: str):
        module = load_frozen_verifier(ROOT)
        install_live_focus_parser(module)
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "window.txt"
            capture.write_text(text, encoding="utf-8")
            return module, module.inspect_window_state(capture)

    def test_actual_api34_historical_launcher_does_not_hide_current_anr(self):
        capture = FIXTURES / "api34-history-current-launcher-anr.txt"
        original = load_frozen_verifier(ROOT)
        before = original.inspect_window_state(capture)
        self.assertEqual(before["window_status"], "OTHER_FOCUSED_WINDOW")
        self.assertEqual(original.window_check_exit_code(before, require_app_focus=False), 0)
        install_live_focus_parser(original)
        after = original.inspect_window_state(capture)
        self.assertEqual(after["window_status"], "EXTERNAL_APP_ANR")
        self.assertEqual(after["anr_package"], "com.google.android.apps.nexuslauncher")
        self.assertEqual(original.window_check_exit_code(after, require_app_focus=False), 22)
        self.assertEqual(original.window_check_exit_code(after, require_app_focus=True), 22)

    def test_historical_bil_focus_never_passes_a_current_anr(self):
        text = (FIXTURES / "historical-bil-current-system-anr.txt").read_text()
        module, result = self._classify(text)
        self.assertEqual(result["window_status"], "EMULATOR_SYSTEM_UI_ANR")
        self.assertEqual(module.window_check_exit_code(result, require_app_focus=True), 20)

    def test_historical_anr_is_not_mistaken_for_current_healthy_focus(self):
        module, result = self._classify((FIXTURES / "historical-anr-current-bil.txt").read_text())
        self.assertEqual(result["window_status"], "APP_FOCUSED")
        self.assertEqual(module.window_check_exit_code(result, require_app_focus=True), 0)

    def test_history_without_a_live_boundary_fails_closed(self):
        module, result = self._classify((FIXTURES / "history-only.txt").read_text())
        self.assertEqual(result["window_status"], "FOCUSED_WINDOW_UNAVAILABLE")
        self.assertEqual(module.window_check_exit_code(result, require_app_focus=False), 23)

    def test_secondary_display_cannot_replace_primary_anr(self):
        module, result = self._classify((FIXTURES / "two-displays.txt").read_text())
        self.assertEqual(result["window_status"], "EXTERNAL_APP_ANR")
        self.assertEqual(module.window_check_exit_code(result, require_app_focus=True), 22)

    def test_ambiguous_unsectioned_focus_fails_closed(self):
        module, result = self._classify(
            "mCurrentFocus=Window{a u0 com.bilhealth.bodyintelligencelog/.MainActivity}\n"
            "mCurrentFocus=Window{b u0 Application Not Responding: com.android.systemui}\n"
        )
        self.assertEqual(result["window_status"], "FOCUSED_WINDOW_UNAVAILABLE")
        self.assertEqual(module.window_check_exit_code(result, require_app_focus=True), 23)

    def test_current_null_focus_is_not_replaced_by_resumed_bil(self):
        module, result = self._classify(
            "mCurrentFocus=null\n"
            "mFocusedApp=ActivityRecord{a u0 com.bilhealth.bodyintelligencelog/.MainActivity}\n"
        )
        self.assertEqual(result["window_status"], "FOCUSED_WINDOW_UNAVAILABLE")

    def test_all_three_live_anr_owners_preserve_original_exit_codes(self):
        for owner, code in (("com.android.systemui", 20),
                            ("com.bilhealth.bodyintelligencelog", 21),
                            ("com.google.android.apps.nexuslauncher", 22)):
            with self.subTest(owner=owner):
                module, result = self._classify(f"mCurrentFocus=Window{{a u0 Application Not Responding: {owner}}}\n")
                self.assertEqual(module.window_check_exit_code(result, require_app_focus=True), code)

    def test_no_other_frozen_verifier_function_is_replaced(self):
        module = load_frozen_verifier(ROOT)
        names = ("main", "startup_is_ready", "inspect_frame", "has_interactive_app_content", "window_check_exit_code")
        original = {name: getattr(module, name) for name in names}
        install_live_focus_parser(module)
        self.assertTrue(all(getattr(module, name) is value for name, value in original.items()))

    def test_changed_frozen_verifier_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "tool/release/verify_android_startup_frame.py"
            target.parent.mkdir(parents=True)
            target.write_bytes((ROOT / "tool/release/verify_android_startup_frame.py").read_bytes() + b"\n")
            with self.assertRaisesRegex(ValueError, "audited5da bytes"):
                load_frozen_verifier(root)

    def test_wrong_application_source_blocks_before_loading_any_gate(self):
        from android_startup_focus_controller import assert_frozen_checkout
        import subprocess
        with patch("android_startup_focus_controller.subprocess.run", return_value=subprocess.CompletedProcess([], 0, "a" * 40, "")):
            with self.assertRaisesRegex(ValueError, "fixed5da source"):
                assert_frozen_checkout(ROOT)

    def test_fresh_anr_log_events_are_never_accepted_as_a_clean_boot(self):
        text = (
            "10-20 12:12:35.123 525 600 E ActivityManager: ANR in com.google.android.apps.nexuslauncher\n"
            "10-20 12:12:35.124 525 600 I am_anr: [0,123,com.android.systemui,0,input]\n"
        )
        self.assertEqual(len(fresh_boot_anr_lines(text)), 2)

    def test_plain_diagnostic_text_does_not_fabricate_an_anr_event(self):
        self.assertEqual(fresh_boot_anr_lines("Window list: historical Application Not Responding\nNo ANR event captured\n"), [])

    def test_every_frozen_upstream_regression_passes_with_live_parser(self):
        module = load_frozen_verifier(ROOT)
        install_live_focus_parser(module)
        path = ROOT / "tool/release/test_verify_android_startup_frame.py"
        spec = importlib.util.spec_from_file_location("frozen_startup_tests", path)
        tests = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(tests)
        suite = unittest.defaultTestLoader.loadTestsFromModule(tests)
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            result = unittest.TextTestRunner(stream=output).run(suite)
        self.assertGreaterEqual(result.testsRun, 20)
        self.assertTrue(result.wasSuccessful(), output.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
