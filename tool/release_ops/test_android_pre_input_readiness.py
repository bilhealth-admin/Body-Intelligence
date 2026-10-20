#!/usr/bin/env python3
import copy
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import android_pre_input_readiness as guard
import patch_emulator_pre_input_guard as patcher

READY = {"boot_completed": "1", "boot_animation": "stopped", "device_provisioned": "1", "user_setup_complete": "1"}
HOME = "com.google.android.apps.nexuslauncher/.NexusLauncherActivity"
WINDOW = "mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n"
LOG = "10-20 13:24:00.000 500 500 I ActivityManager: device booting\n"


class PreInputControls(unittest.TestCase):
    def test_only_healthy_provisioned_focused_home_is_ready(self):
        self.assertEqual(guard.inspect_state(READY, WINDOW, HOME, LOG), (True, "HEALTHY_FOCUSED_HOME"))

    def test_every_incomplete_boot_or_provisioning_property_blocks(self):
        for key in READY:
            with self.subTest(key=key):
                values = copy.copy(READY); values[key] = "0"
                self.assertFalse(guard.inspect_state(values, WINDOW, HOME, LOG)[0])

    def test_null_or_ambiguous_or_setup_focus_is_not_ready(self):
        for window in ("mCurrentFocus=null", "mCurrentFocus=Window{1 u0 com.google.android.googlesdksetup/.DefaultActivity}", WINDOW+"mCurrentFocus=null\n"):
            with self.subTest(window=window):
                self.assertFalse(guard.inspect_state(READY, window, HOME, LOG)[0])

    def test_resolved_setup_or_other_home_component_is_blocked(self):
        for home in ("com.google.android.googlesdksetup/.DefaultActivity", HOME+"\n"+HOME, "No activity found", "com.google.android.apps.nexuslauncher/.WrongActivity"):
            self.assertFalse(guard.inspect_state(READY, WINDOW, home, LOG)[0])

    def test_fresh_boot_previous_anr_blocks_even_healthy_current_focus(self):
        for event in ("I am_anr  : [0,1515,com.google.android.googlesdksetup,1,Input dispatching timed out]", "E ActivityManager: ANR in com.google.android.apps.nexuslauncher"):
            with self.assertRaisesRegex(ValueError, "FRESH_CLEAN_BOOT_ANR"):
                guard.inspect_state(READY, WINDOW, HOME, LOG+event)

    def test_current_anr_dialog_blocks_before_any_key(self):
        with self.assertRaisesRegex(ValueError, "CURRENT_FOCUS_ERROR_DIALOG"):
            guard.inspect_state(READY, "mCurrentFocus=Window{1 u0 Application Not Responding: com.google.android.googlesdksetup}", HOME, LOG)

    def test_complete_clean_boot_log_is_mandatory(self):
        with tempfile.TemporaryDirectory() as d:
            evidence = Path(d)
            for value in (None, ""):
                if value is not None: (evidence/"full-boot-logcat.txt").write_text(value)
                with self.assertRaisesRegex(ValueError, "LOG_MISSING_OR_OVERSIZED"):
                    guard.clean_boot_log(evidence)

    def test_observation_uses_exact_sdk_device_and_remaining_deadline(self):
        with patch.object(guard.time, "monotonic", return_value=10), patch.object(guard.subprocess, "run", return_value=SimpleNamespace(stdout="1\n")) as run:
            self.assertEqual(guard.execute(Path("/sdk/platform-tools/adb"),5554,["shell","getprop","sys.boot_completed"],12),"1")
        self.assertEqual(run.call_args.args[0], ["/sdk/platform-tools/adb","-s","emulator-5554","shell","getprop","sys.boot_completed"])
        self.assertEqual(run.call_args.kwargs["timeout"],2)
        with patch.object(guard.time, "monotonic", return_value=13), patch.object(guard.subprocess, "run") as run:
            with self.assertRaises(TimeoutError): guard.execute(Path("/sdk/adb"),5554,["shell"],12)
            run.assert_not_called()

    def test_patch_is_exact_addition_and_rejects_any_other_upstream_bytes(self):
        original = (Path(__file__).parent/"android_pre_input_fixtures/emulator-manager.js").read_bytes()
        changed = patcher.patched_bytes(original)
        self.assertEqual(changed.replace(patcher.INSERTION,b"",1),original)
        self.assertLess(changed.index(patcher.INSERTION),changed.index(b"await adb(port, `shell input keyevent 82`);"))
        for bad in (original+b"\n", changed):
            with self.assertRaises(ValueError): patcher.patched_bytes(bad)


if __name__ == "__main__": unittest.main()
