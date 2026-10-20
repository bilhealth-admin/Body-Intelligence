#!/usr/bin/env python3
"""Exercise the actual readiness loop, including late ANR and stability reset."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import android_pre_input_readiness as guard

HOME = "com.google.android.apps.nexuslauncher/.NexusLauncherActivity"
WINDOW = "mCurrentFocus=Window{123 u0 " + HOME + "}\n"
SETUP = "mCurrentFocus=Window{456 u0 com.google.android.googlesdksetup/.DefaultActivity}\n"
BOOT = "10-20 13:24:00.000 500 500 I ActivityManager: device booting\n"
ANR = "10-20 13:24:01.000 500 500 E ActivityManager: ANR in com.google.android.googlesdksetup\n"


class ActualReadinessLoopControls(unittest.TestCase):
    def fixture(self, root):
        sdk = root / "sdk"
        adb = sdk / "platform-tools/adb"
        adb.parent.mkdir(parents=True)
        adb.write_text("#!/bin/sh\nexit 99\n")
        adb.chmod(0o700)
        app = root / "app"
        evidence = app / "artifacts/release/android_emulator_smoke/api-34"
        evidence.mkdir(parents=True)
        (evidence / "full-boot-logcat.txt").write_text(BOOT)
        env = {"BIL_ANDROID_EMULATOR_API": "34", "BIL_FROZEN_APP_ROOT": str(app),
               "ANDROID_HOME": str(sdk), "BIL_CONTROLLER_SOURCE": "test-controller"}
        return evidence, env

    def run_control(self, windows, *, late_anr=False):
        with tempfile.TemporaryDirectory() as directory:
            evidence, env = self.fixture(Path(directory))
            clock = [0.0]
            calls = []
            frames = iter(windows)

            def execute(adb, port, args, deadline):
                self.assertEqual(port, 5554)
                self.assertEqual(deadline, 120)
                self.assertGreater(deadline, clock[0])
                calls.append(tuple(args))
                if args == ["shell", "getprop", "sys.boot_completed"]:
                    return "1"
                if args == ["shell", "getprop", "init.svc.bootanim"]:
                    return "stopped"
                if args[:3] == ["shell", "settings", "get"]:
                    return "1"
                if args[:3] == ["shell", "cmd", "package"]:
                    return HOME
                self.assertEqual(args, ["shell", "dumpsys", "window"])
                if late_anr:
                    (evidence / "full-boot-logcat.txt").write_text(BOOT + ANR)
                return next(frames)

            def sleep(seconds):
                self.assertEqual(seconds, 1)
                clock[0] += seconds

            failure = None
            with patch.dict(os.environ, env), patch.object(guard.time, "monotonic", side_effect=lambda: clock[0]), \
                 patch.object(guard.time, "sleep", side_effect=sleep), patch.object(guard, "execute", side_effect=execute):
                try:
                    guard.run(5554)
                except ValueError as error:
                    failure = error
            receipt = json.loads((evidence / "pre-input-readiness.json").read_text())
            # No command in the actual loop sends any input, dismisses a dialog,
            # stops an app, clears a log, or starts another emulator attempt.
            self.assertTrue(all(command[:1] == ("shell",) for command in calls))
            self.assertFalse(any("input" in command or "am" in command or "logcat" in command for command in calls))
            return receipt, failure

    def test_actual_loop_waits_for_three_samples_over_two_seconds(self):
        receipt, failure = self.run_control([WINDOW, WINDOW, WINDOW])
        self.assertIsNone(failure)
        self.assertTrue(receipt["ready_for_original_key_event"])
        self.assertEqual([x["elapsed_seconds"] for x in receipt["observations"]], [0, 1, 2])
        self.assertEqual(receipt["input_events_sent_by_guard"], 0)
        self.assertFalse(receipt["application_startup_proven"])

    def test_unhealthy_focus_resets_continuous_home_stability(self):
        receipt, failure = self.run_control([WINDOW, SETUP, WINDOW, WINDOW, WINDOW])
        self.assertIsNone(failure)
        self.assertTrue(receipt["ready_for_original_key_event"])
        self.assertEqual(receipt["elapsed_seconds"], 4)
        self.assertEqual(len(receipt["observations"]), 5)
        self.assertEqual(receipt["observations"][1]["state"], "FOCUSED_HOME_NOT_READY")

    def test_anr_arriving_during_adb_snapshot_blocks_before_success(self):
        receipt, failure = self.run_control([WINDOW], late_anr=True)
        self.assertIsInstance(failure, ValueError)
        self.assertEqual(str(failure), "FRESH_CLEAN_BOOT_ANR")
        self.assertEqual(receipt["status"], "BLOCKED")
        self.assertFalse(receipt["ready_for_original_key_event"])
        self.assertEqual(receipt["observations"], [])
        self.assertEqual(receipt["input_events_sent_by_guard"], 0)


if __name__ == "__main__":
    unittest.main()
