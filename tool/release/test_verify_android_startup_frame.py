#!/usr/bin/env python3
"""Focused checks for the Android launch-frame blank-screen guard."""

from __future__ import annotations

import contextlib
import io
import json
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_android_startup_frame import (
    frame_is_blank,
    has_interactive_app_content,
    inspect_frame,
    inspect_window_state,
    main,
    startup_is_ready,
    wait_for_boot_broadcast_idle,
    window_check_exit_code,
)
import verify_android_startup_frame as startup


class BoundedFailureDiagnosticsTest(unittest.TestCase):
    def test_diagnostic_mode_cannot_bypass_a_startup_or_window_acceptance_check(self):
        for arguments in (
            ['--capture-failure-diagnostics', 'unused', '--verify-emulator-before-launch', 'unused'],
            ['--capture-failure-diagnostics', 'unused', '--window-health-only'],
            ['--capture-failure-diagnostics', 'unused', '--require-app-focus'],
            ['--capture-failure-diagnostics', 'unused', 'screen.png', 'tree.xml'],
        ):
            with self.subTest(arguments=arguments), \
                    patch.object(startup.subprocess, 'run') as command, \
                    contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    startup.main(arguments)
                self.assertEqual(error.exception.code, 2)
                command.assert_not_called()

    def test_diagnostic_only_cli_never_claims_readiness_even_when_adb_is_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(startup.subprocess, 'run', side_effect=OSError('adb unavailable')):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    result = startup.main(['--capture-failure-diagnostics', directory])
            receipt = json.loads((Path(directory) / 'failure-diagnostics.json').read_text())
            self.assertEqual(result, 0, 'A diagnostic command is separate from the original ANR exit')
            self.assertIn('diagnostics_only=true; app_startup_proven=false', output.getvalue())
            self.assertNotIn('accessible_interactive_app_content=true', output.getvalue())
            self.assertTrue(all(row['status'] == 'COMMAND_ERROR' for row in receipt['commands']))

    def test_read_only_commands_preserve_real_output_and_a_missing_anr_record(self):
        seen = []

        def adb(command, **options):
            seen.append(command)
            self.assertEqual(options['timeout'], 8)
            self.assertFalse(options['check'])
            options['stdout'].write(b'<no ANR has occurred since boot>\n' if
                                    command[-1] == 'lastanr' else b'read-only diagnostic fixture\n')
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            with patch.object(startup.subprocess, 'run', side_effect=adb):
                startup.capture_failure_diagnostics(evidence)
                startup.capture_failure_diagnostics(evidence)
            receipt = json.loads((evidence / 'failure-diagnostics.json').read_text())
            self.assertFalse(receipt['app_startup_proven'])
            self.assertEqual(len(seen), 5, 'The prelaunch guard and EXIT trap must not repeat capture')
            self.assertEqual(seen, [
                ['adb', 'shell', 'dumpsys', 'activity', 'lastanr'],
                ['adb', 'shell', 'dumpsys', 'dropbox', '--print', 'system_app_anr'],
                ['adb', 'logcat', '-b', 'events', '-d', '-t', '500'],
                ['adb', 'shell', 'dumpsys', 'cpuinfo'],
                ['adb', 'shell', 'ps', '-A', '-T', '-o', 'PID,TID,NAME'],
            ])
            self.assertIn('<no ANR', (evidence / 'failure-diagnostic-last-anr.txt').read_text())
            self.assertTrue(all(row['status'] == 'CAPTURED' for row in receipt['commands']))

    def test_timeout_permission_failure_and_output_limit_are_evidence_not_startup_success(self):
        def adb(command, **options):
            if command[-1] == 'lastanr':
                raise subprocess.TimeoutExpired(command, 8)
            if command[-1] == 'system_app_anr':
                options['stderr'].write(b'Permission denied\n')
                return subprocess.CompletedProcess(command, 1)
            options['stdout'].write(b'x' * (512 * 1024 + 17))
            return subprocess.CompletedProcess(command, 0)

        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            with patch.object(startup.subprocess, 'run', side_effect=adb):
                startup.capture_failure_diagnostics(evidence)
            receipt = json.loads((evidence / 'failure-diagnostics.json').read_text())
            self.assertFalse(receipt['app_startup_proven'])
            self.assertEqual(receipt['commands'][0]['status'], 'TIMEOUT')
            self.assertEqual(receipt['commands'][1]['status'], 'NONZERO_EXIT')
            self.assertIn('Permission denied',
                          (evidence / 'failure-diagnostic-system-app-anr.txt.errors.txt').read_text())
            for row in receipt['commands'][2:]:
                self.assertTrue(row['stdout_truncated'])
                self.assertEqual((evidence / row['file']).stat().st_size, 512 * 1024)


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def _rgb_png(
    width: int,
    height: int,
    marked: bool,
    *,
    mark_height_fraction: float = 1 / 3,
) -> bytes:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            in_mark = (
                marked
                and width // 3 <= x < 2 * width // 3
                and height // 2
                <= y
                < height // 2 + int(height * mark_height_fraction)
            )
            rows.extend(
                (200 + x % 56, 200 + y % 56, 255)
                if in_mark
                else (8, 119, 249)
            )
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(rows))
        + _chunk(b"IEND", b"")
    )


class VerifyAndroidStartupFrameTest(unittest.TestCase):
    def test_solid_launch_color_has_no_proven_flutter_frame(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "blank.png"
            capture.write_bytes(_rgb_png(96, 128, marked=False))
            result = inspect_frame(capture)
        self.assertEqual(result["viewport_unique_rgb_colors"], 1)
        self.assertTrue(frame_is_blank(result))

    def test_visible_app_mark_proves_nonblank_viewport(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "visible.png"
            capture.write_bytes(_rgb_png(96, 128, marked=True))
            result = inspect_frame(capture)
        self.assertGreaterEqual(result["viewport_unique_rgb_colors"], 2)
        self.assertFalse(frame_is_blank(result))

    def test_colorful_splash_without_controls_is_not_ready(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "splash.png"
            tree = Path(directory) / "splash.xml"
            capture.write_bytes(
                _rgb_png(96, 128, marked=True, mark_height_fraction=0.06)
            )
            tree.write_text(
                '<hierarchy><node package="com.bilhealth.bodyintelligencelog" '
                'class="android.view.View" content-desc="BIL" '
                'clickable="false" enabled="true" /></hierarchy>',
                encoding="utf-8",
            )
            result = inspect_frame(capture)
            is_blank = frame_is_blank(result)
            has_content = has_interactive_app_content(tree)
            is_ready = startup_is_ready(result, tree)
        self.assertTrue(is_blank)
        self.assertFalse(has_content)
        self.assertFalse(is_ready)

    def test_enabled_app_button_proves_accessible_content(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "welcome.png"
            tree = Path(directory) / "welcome.xml"
            capture.write_bytes(_rgb_png(96, 128, marked=True))
            tree.write_text(
                '<hierarchy><node package="com.bilhealth.bodyintelligencelog" '
                'class="android.widget.Button" content-desc="Sign in" '
                'clickable="true" enabled="true" /></hierarchy>',
                encoding="utf-8",
            )
            result = inspect_frame(capture)
            self.assertTrue(has_interactive_app_content(tree))
            self.assertTrue(startup_is_ready(result, tree))

    def test_disabled_or_foreign_button_does_not_prove_app_content(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tree = Path(directory) / "not-ready.xml"
            tree.write_text(
                '<hierarchy>'
                '<node package="com.bilhealth.bodyintelligencelog" '
                'class="android.widget.Button" content-desc="Continue" '
                'clickable="true" enabled="false" />'
                '<node package="com.android.launcher" '
                'class="android.widget.Button" content-desc="Open" '
                'clickable="true" enabled="true" />'
                '</hierarchy>',
                encoding="utf-8",
            )
            has_content = has_interactive_app_content(tree)
        self.assertFalse(has_content)


class VerifyAndroidWindowFocusTest(unittest.TestCase):
    # Structural slice of the real API34 failure at source978758a2, artifact
    # 12949975082 (SHA256 f9284084...2dc8303). Unrelated process/window data is
    # omitted; history and live section order and package ownership are kept.
    CAPTURED_LAUNCHER_ANR = (
        "WINDOW MANAGER LAST ANR (dumpsys window lastanr)\n"
        "  Application at fault: com.google.android.apps.nexuslauncher\n"
        "Last ANR continued\n"
        "WINDOW MANAGER DISPLAY CONTENTS (dumpsys window displays)\n"
        "  Display: mDisplayId=0 (organized)\n"
        "  mCurrentFocus=Window{62bb822 u0 com.google.android.apps.nexuslauncher/"
        "com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n"
        "WINDOW MANAGER POLICY STATE (dumpsys window policy)\n"
        "WINDOW MANAGER SESSIONS (dumpsys window sessions)\n"
        "WINDOW MANAGER DISPLAY CONTENTS (dumpsys window displays)\n"
        "  Display: mDisplayId=0 (organized)\n"
        "  mCurrentFocus=Window{bf8c9af u0 Application Not Responding: "
        "com.google.android.apps.nexuslauncher}\n"
        "  mFocusedApp=ActivityRecord{b3855f4 u0 com.google.android.apps.nexuslauncher/"
        ".NexusLauncherActivity}\n"
    )

    def test_actual_capture_uses_live_anr_focus_instead_of_last_anr_snapshot(self):
        result = self._window_result(self.CAPTURED_LAUNCHER_ANR)
        self.assertEqual(result['window_status'], 'EXTERNAL_APP_ANR')
        self.assertEqual(result['anr_package'], 'com.google.android.apps.nexuslauncher')
        self.assertEqual(window_check_exit_code(result, require_app_focus=False), 22)
        self.assertEqual(window_check_exit_code(result, require_app_focus=True), 22)

    def test_historical_anr_does_not_override_current_healthy_bil_focus(self):
        state = (
            'WINDOW MANAGER LAST ANR (dumpsys window lastanr)\n'
            'Last ANR continued\n'
            'WINDOW MANAGER DISPLAY CONTENTS (dumpsys window displays)\n'
            'mCurrentFocus=Window{old u0 Application Not Responding: com.android.systemui}\n'
            'WINDOW MANAGER POLICY STATE (dumpsys window policy)\n'
            'WINDOW MANAGER DISPLAY CONTENTS (dumpsys window displays)\n'
            'mCurrentFocus=Window{live u0 com.bilhealth.bodyintelligencelog/.MainActivity}\n'
        )
        result = self._window_result(state)
        self.assertEqual(result['window_status'], 'APP_FOCUSED')
        self.assertEqual(window_check_exit_code(result, require_app_focus=True), 0)

    def test_history_without_a_live_section_cannot_prove_current_focus(self):
        state = self.CAPTURED_LAUNCHER_ANR.split('WINDOW MANAGER POLICY STATE', 1)[0]
        result = self._window_result(state)
        self.assertEqual(result['window_status'], 'FOCUSED_WINDOW_UNAVAILABLE')
        self.assertEqual(window_check_exit_code(result, require_app_focus=False), 23)

    def test_prelaunch_live_launcher_anr_blocks_without_waiting_or_dismissing(self):
        calls = []
        def adb(command, **options):
            calls.append(command)
            if command == ['adb', 'shell', 'pidof', 'com.android.systemui']:
                return subprocess.CompletedProcess(command, 0, '851\n', '')
            if command == ['adb', 'shell', 'dumpsys', 'window']:
                return subprocess.CompletedProcess(command, 0, self.CAPTURED_LAUNCHER_ANR, '')
            self.fail('Unexpected ADB command: ' + repr(command))
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(startup, 'wait_for_boot_broadcast_idle', return_value=True), \
                patch.object(startup.subprocess, 'run', side_effect=adb), \
                patch.object(startup, '_capture_prelaunch_blocker') as evidence, \
                patch.object(startup.time, 'sleep') as sleep, \
                contextlib.redirect_stderr(io.StringIO()):
            result = startup.verify_emulator_before_launch(Path(folder))
        self.assertEqual(result, 22)
        evidence.assert_called_once_with(Path(folder), 22)
        sleep.assert_not_called()
        self.assertEqual(len(calls), 2)

    def test_live_anr_blocks_conflicting_bil_focus_in_both_orders_and_aliases(self):
        bil = 'Window{bil u0 com.bilhealth.bodyintelligencelog/.MainActivity}'
        anr = 'Window{anr u0 Application Not Responding: com.google.android.apps.nexuslauncher}'
        for key in ['mCurrentFocus', 'mFocusedWindow']:
            for values in [(bil, anr), (anr, bil)]:
                with self.subTest(key=key, values=values):
                    state = 'WINDOW MANAGER POLICY STATE (dumpsys window policy)\n'
                    state += '\n'.join(f'{key}={value}' for value in values)
                    result = self._window_result(state)
                    self.assertEqual(result['window_status'], 'EXTERNAL_APP_ANR')
                    self.assertEqual(result['anr_package'], 'com.google.android.apps.nexuslauncher')
                    self.assertEqual(window_check_exit_code(result, require_app_focus=False), 22)
                    self.assertEqual(window_check_exit_code(result, require_app_focus=True), 22)

    def test_conflicting_live_bil_and_launcher_focus_never_passes_in_either_order(self):
        bil = 'Window{bil u0 com.bilhealth.bodyintelligencelog/.MainActivity}'
        launcher = 'Window{home u0 com.google.android.apps.nexuslauncher/.NexusLauncherActivity}'
        for key in ['mCurrentFocus', 'mFocusedWindow']:
            for values in [(bil, launcher), (launcher, bil)]:
                with self.subTest(key=key, values=values):
                    result = self._window_result('\n'.join(f'{key}={value}' for value in values))
                    self.assertEqual(result['window_status'], 'FOCUSED_WINDOW_UNAVAILABLE')
                    self.assertEqual(result['focus_reason'], 'CONFLICTING_LIVE_FOCUS')
                    self.assertEqual(window_check_exit_code(result, require_app_focus=False), 23)
                    self.assertEqual(window_check_exit_code(result, require_app_focus=True), 23)

    def test_identical_duplicate_live_bil_focus_keeps_the_positive_path(self):
        bil = 'Window{bil u0 com.bilhealth.bodyintelligencelog/.MainActivity}'
        for key in ['mCurrentFocus', 'mFocusedWindow']:
            with self.subTest(key=key):
                result = self._window_result(f'{key}={bil}\n{key}={bil}\n')
                self.assertEqual(result['window_status'], 'APP_FOCUSED')
                self.assertEqual(window_check_exit_code(result, require_app_focus=True), 0)

    def test_conflicting_null_and_live_bil_focus_cannot_prove_readiness(self):
        bil = 'Window{bil u0 com.bilhealth.bodyintelligencelog/.MainActivity}'
        for key in ['mCurrentFocus', 'mFocusedWindow']:
            for values in [('null', bil), (bil, 'null')]:
                with self.subTest(key=key, values=values):
                    result = self._window_result('\n'.join(f'{key}={value}' for value in values))
                    self.assertEqual(result['window_status'], 'FOCUSED_WINDOW_UNAVAILABLE')
                    self.assertEqual(window_check_exit_code(result, require_app_focus=False), 23)
                    self.assertEqual(window_check_exit_code(result, require_app_focus=True), 23)

    def _window_result(self, state: str) -> dict[str, str]:
        with tempfile.TemporaryDirectory() as directory:
            window = Path(directory) / "window.txt"
            window.write_text(state, encoding="utf-8")
            return inspect_window_state(window)

    def test_system_ui_anr_blocks_resumed_and_interactive_bil(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / "welcome.png"
            tree = Path(directory) / "welcome.xml"
            window = Path(directory) / "window.txt"
            capture.write_bytes(_rgb_png(96, 128, marked=True))
            tree.write_text(
                '<hierarchy><node package="com.bilhealth.bodyintelligencelog" '
                'class="android.widget.Button" content-desc="Sign in" '
                'clickable="true" enabled="true" /></hierarchy>',
                encoding="utf-8",
            )
            window.write_text(
                "topResumedActivity=ActivityRecord{abc u0 "
                "com.bilhealth.bodyintelligencelog/.MainActivity}\n"
                "mCurrentFocus=Window{def u0 Application Not Responding: "
                "com.android.systemui}\n"
                "mFocusedApp=ActivityRecord{abc u0 "
                "com.bilhealth.bodyintelligencelog/.MainActivity}\n",
                encoding="utf-8",
            )
            self.assertTrue(has_interactive_app_content(tree))
            self.assertFalse(startup_is_ready(inspect_frame(capture), tree, window))
            with contextlib.redirect_stdout(io.StringIO()) as output:
                with contextlib.redirect_stderr(io.StringIO()) as errors:
                    result = main(
                        [str(capture), str(tree), "--window-state", str(window)]
                    )
        self.assertEqual(result, 20)
        self.assertIn("window_status=EMULATOR_SYSTEM_UI_ANR", output.getvalue())
        self.assertIn("EMULATOR_SYSTEM_UI_ANR", errors.getvalue())

    def test_bil_anr_is_a_distinct_application_failure(self) -> None:
        result = self._window_result(
            "mCurrentFocus=Window{abc u0 Application Not Responding: "
            "com.bilhealth.bodyintelligencelog}"
        )
        self.assertEqual(result["window_status"], "APP_ANR")
        self.assertEqual(result["anr_package"], "com.bilhealth.bodyintelligencelog")
        self.assertEqual(window_check_exit_code(result, require_app_focus=False), 21)

    def test_another_app_anr_is_not_mislabelled_as_system_ui(self) -> None:
        result = self._window_result(
            "mCurrentFocus=Window{abc u0 Application Not Responding: com.example.other}"
        )
        self.assertEqual(result["window_status"], "EXTERNAL_APP_ANR")
        self.assertEqual(window_check_exit_code(result, require_app_focus=True), 22)

    def test_normal_permission_dialog_is_not_anr_or_bil_readiness(self) -> None:
        result = self._window_result(
            "topResumedActivity=ActivityRecord{abc u0 "
            "com.bilhealth.bodyintelligencelog/.MainActivity}\n"
            "mCurrentFocus=Window{def u0 com.google.android.permissioncontroller/"
            "com.android.permissioncontroller.permission.ui.GrantPermissionsActivity}"
        )
        self.assertEqual(result["window_status"], "OTHER_FOCUSED_WINDOW")
        self.assertEqual(window_check_exit_code(result, require_app_focus=False), 0)
        self.assertEqual(window_check_exit_code(result, require_app_focus=True), 1)

    def test_healthy_bil_focus_ignores_a_stale_anr_window_listing(self) -> None:
        result = self._window_result(
            "Window #7 Window{def u0 Application Not Responding: com.android.systemui}:\n"
            "mCurrentFocus=Window{abc u0 com.bilhealth.bodyintelligencelog/.MainActivity}"
        )
        self.assertEqual(result["window_status"], "APP_FOCUSED")
        self.assertEqual(window_check_exit_code(result, require_app_focus=True), 0)

    def test_resumed_activity_alone_is_never_proof_of_actual_focus(self) -> None:
        result = self._window_result(
            "topResumedActivity=ActivityRecord{abc u0 "
            "com.bilhealth.bodyintelligencelog/.MainActivity}\n"
            "mFocusedApp=ActivityRecord{abc u0 "
            "com.bilhealth.bodyintelligencelog/.MainActivity}"
        )
        self.assertEqual(result["window_status"], "FOCUSED_WINDOW_UNAVAILABLE")
        self.assertEqual(window_check_exit_code(result, require_app_focus=True), 23)

    def test_null_focus_is_not_replaced_by_a_resumed_app(self) -> None:
        result = self._window_result(
            "mCurrentFocus=null\nmFocusedApp=ActivityRecord{abc u0 "
            "com.bilhealth.bodyintelligencelog/.MainActivity}"
        )
        self.assertEqual(result["window_status"], "FOCUSED_WINDOW_UNAVAILABLE")

    def test_focused_window_alias_and_package_boundary(self) -> None:
        for package, expected in (
            ("com.bilhealth.bodyintelligencelog", "APP_FOCUSED"),
            ("com.bilhealth.bodyintelligencelog.other", "OTHER_FOCUSED_WINDOW"),
        ):
            with self.subTest(package=package):
                result = self._window_result(
                    f"mFocusedWindow=Window{{abc u0 {package}/.MainActivity}}"
                )
                self.assertEqual(result["window_status"], expected)

    def test_boot_idle_retries_interrupted_binder_read_but_requires_idle(self) -> None:
        from verify_android_startup_frame import wait_for_boot_broadcast_idle
        broken = subprocess.CompletedProcess([], 224, "cmd: Failure calling service activity: Broken pipe (32)", "")
        idle = subprocess.CompletedProcess([], 0, "All broadcast queues are idle!\n", "")
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            with patch("verify_android_startup_frame.subprocess.run", side_effect=[broken, idle]) as run:
                with patch("verify_android_startup_frame.time.sleep"):
                    self.assertTrue(wait_for_boot_broadcast_idle(evidence))
            self.assertEqual(run.call_count, 2)
            receipt = json.loads((evidence / "prelaunch-boot-idle-receipt.json").read_text())
            self.assertTrue(receipt["broadcast_idle_confirmed"])
            self.assertFalse(receipt["app_startup_proven"])

    def test_boot_idle_does_not_accept_persistent_broken_binder(self) -> None:
        from verify_android_startup_frame import wait_for_boot_broadcast_idle
        broken = subprocess.CompletedProcess([], 224, "cmd: Failure calling service activity: Broken pipe (32)", "")
        with tempfile.TemporaryDirectory() as directory:
            with patch("verify_android_startup_frame.subprocess.run", return_value=broken) as run:
                with patch("verify_android_startup_frame.time.sleep"):
                    self.assertFalse(wait_for_boot_broadcast_idle(Path(directory)))
            self.assertEqual(run.call_count, 3)

    def test_prelaunch_health_checks_window_without_accepting_a_bil_frame(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            window = Path(directory) / "window.txt"
            window.write_text(
                "mCurrentFocus=Window{abc u0 com.android.launcher/.Launcher}",
                encoding="utf-8",
            )
            with contextlib.redirect_stdout(io.StringIO()) as output:
                result = main(
                    ["--window-health-only", "--window-state", str(window)]
                )
        self.assertEqual(result, 0)
        self.assertIn("window_status=OTHER_FOCUSED_WINDOW", output.getvalue())
        self.assertNotIn("accessible_interactive_app_content=true", output.getvalue())

    def test_smoke_preserves_system_ui_failure_before_install_or_launch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "evidence"
            picture = _rgb_png(96, 128, marked=True)
            tree = (
                '<hierarchy><node package="android" class="android.widget.Button" '
                'text="Wait" resource-id="android:id/aerr_wait" '
                'clickable="true" enabled="true" /></hierarchy>'
            )
            operations = []

            def adb_read(command, **options):
                operations.append(command)
                if command == ["adb", "shell", "cmd", "activity", "wait-for-broadcast-idle"]:
                    return subprocess.CompletedProcess(
                        command, 0, "All broadcast queues are idle!\n", ""
                    )
                if command == ["adb", "shell", "pidof", "com.android.systemui"]:
                    return subprocess.CompletedProcess(command, 0, "123\n", "")
                if command == ["adb", "shell", "dumpsys", "window"]:
                    return subprocess.CompletedProcess(
                        command, 0,
                        "mCurrentFocus=Window{abc u0 Application Not Responding: "
                        "com.android.systemui}\n", "",
                    )
                if command in (
                    ["adb", "shell", "dumpsys", "activity", "lastanr"],
                    ["adb", "shell", "dumpsys", "dropbox", "--print", "system_app_anr"],
                    ["adb", "logcat", "-b", "events", "-d", "-t", "500"],
                    ["adb", "shell", "dumpsys", "cpuinfo"],
                    ["adb", "shell", "ps", "-A", "-T", "-o", "PID,TID,NAME"],
                ):
                    options['stdout'].write(b'read-only failure detail\n')
                    return subprocess.CompletedProcess(command, 0)
                if command == ["adb", "exec-out", "screencap", "-p"]:
                    return subprocess.CompletedProcess(command, 0, picture, b"")
                if command[1:3] == ["logcat", "-d"]:
                    return subprocess.CompletedProcess(command, 0, b"ANR fixture\n", b"")
                if command[1:4] == ["shell", "uiautomator", "dump"]:
                    return subprocess.CompletedProcess(command, 0, b"dumped\n", b"")
                if command[1] == "pull":
                    Path(command[-1]).write_text(tree, encoding="utf-8")
                    return subprocess.CompletedProcess(command, 0, b"pulled\n", b"")
                self.fail(f"Unexpected command in read-only prelaunch guard: {command}")

            with patch("verify_android_startup_frame.subprocess.run", side_effect=adb_read):
                with contextlib.redirect_stderr(io.StringIO()) as errors:
                    result = main(["--verify-emulator-before-launch", str(evidence)])
            self.assertEqual(result, 20)
            self.assertIn("EMULATOR_SYSTEM_UI_ANR", errors.getvalue())
            receipt = (evidence / "prelaunch-failure.txt").read_text()
            self.assertIn("exit_status=20", receipt)
            self.assertIn("stage=verify-emulator-system-ui-before-launch", receipt)
            self.assertEqual((evidence / "failure-screen.png").read_bytes(), picture)
            self.assertEqual(
                (evidence / "prelaunch-failure-window.xml").read_text(), tree
            )
            self.assertIn(
                "anr_package=com.android.systemui",
                (evidence / "prelaunch-window-check.txt").read_text(),
            )
            self.assertFalse((evidence / "startup.png").exists())
            idle = json.loads((evidence / "prelaunch-boot-idle-receipt.json").read_text())
            self.assertEqual(idle["status"], "IDLE")
            self.assertFalse(idle["app_startup_proven"])
            self.assertEqual(operations[0][-1], "wait-for-broadcast-idle")
            self.assertEqual(len(operations), 12)
            self.assertFalse(any(operation[1] in ('install', 'root', 'reboot')
                                 or 'start' in operation or 'kill' in operation
                                 for operation in operations))

    def test_missing_system_ui_process_cannot_pass_prelaunch_health(self) -> None:
        def adb_read(command, **options):
            if command[-1] == "wait-for-broadcast-idle":
                return subprocess.CompletedProcess(
                    command, 0, "All broadcast queues are idle!\n", ""
                )
            if command[1:3] == ["shell", "pidof"]:
                return subprocess.CompletedProcess(command, 1, "", "no process")
            if command[1:3] == ["shell", "dumpsys"]:
                return subprocess.CompletedProcess(
                    command, 0, "mCurrentFocus=Window{abc u0 com.android.launcher/.Home}", ""
                )
            return subprocess.CompletedProcess(command, 0, b"", b"")

        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            with patch("verify_android_startup_frame.subprocess.run", side_effect=adb_read):
                with patch("verify_android_startup_frame.time.sleep") as pause:
                    with contextlib.redirect_stderr(io.StringIO()) as errors:
                        result = main(["--verify-emulator-before-launch", str(evidence)])
            self.assertEqual(result, 24)
            self.assertEqual(pause.call_count, 14)
            self.assertIn("EMULATOR_SYSTEM_UI_UNAVAILABLE", errors.getvalue())
            self.assertIn(
                "exit_status=24", (evidence / "prelaunch-failure.txt").read_text()
            )

    def test_evidence_capture_failure_does_not_replace_original_anr_exit(self) -> None:
        def adb_read(command, **options):
            if command[-1] == "wait-for-broadcast-idle":
                return subprocess.CompletedProcess(
                    command, 0, "All broadcast queues are idle!\n", ""
                )
            if command[1:3] == ["shell", "pidof"]:
                return subprocess.CompletedProcess(command, 0, "123\n", "")
            if command[1:3] == ["shell", "dumpsys"]:
                return subprocess.CompletedProcess(
                    command, 0, "mCurrentFocus=Window{abc u0 Application Not Responding: "
                    "com.bilhealth.bodyintelligencelog}", "",
                )
            raise subprocess.TimeoutExpired(command, 15)

        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            with patch("verify_android_startup_frame.subprocess.run", side_effect=adb_read):
                with contextlib.redirect_stderr(io.StringIO()):
                    result = main(["--verify-emulator-before-launch", str(evidence)])
            self.assertEqual(result, 21)
            self.assertIn("exit_status=21", (evidence / "prelaunch-failure.txt").read_text())
            self.assertIn(
                "window_status=APP_ANR",
                (evidence / "prelaunch-window-check.txt").read_text(),
            )
            self.assertTrue((evidence / "failure-screen.png.errors.txt").is_file())
            self.assertTrue((evidence / "prelaunch-pull.txt.errors.txt").is_file())


class VerifyBootBroadcastIdleTest(unittest.TestCase):
    def test_success_requires_zero_exit_and_exact_idle_line(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            result = subprocess.CompletedProcess(
                [], 0, "Waiting for queue...\nAll broadcast queues are idle!\r\n", ""
            )
            with patch("verify_android_startup_frame.subprocess.run", return_value=result) as run:
                with contextlib.redirect_stdout(io.StringIO()):
                    ready = wait_for_boot_broadcast_idle(evidence)
            receipt = json.loads((evidence / "prelaunch-boot-idle-receipt.json").read_text())
            self.assertTrue(ready)
            self.assertEqual(receipt["status"], "IDLE")
            self.assertEqual(receipt["adb_return_code"], 0)
            self.assertEqual(receipt["timeout_seconds"], 120)
            self.assertGreaterEqual(receipt["elapsed_seconds"], 0)
            self.assertFalse(receipt["app_startup_proven"])
            self.assertEqual(run.call_args.kwargs["timeout"], 120)

    def test_nonzero_exit_never_passes_even_with_idle_text(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            result = subprocess.CompletedProcess(
                [], 7, "All broadcast queues are idle!\n", "remote failure\n"
            )
            with patch("verify_android_startup_frame.subprocess.run", return_value=result):
                with contextlib.redirect_stdout(io.StringIO()):
                    ready = wait_for_boot_broadcast_idle(evidence)
            receipt = json.loads((evidence / "prelaunch-boot-idle-receipt.json").read_text())
            self.assertFalse(ready)
            self.assertEqual(receipt["status"], "NONZERO_EXIT")
            self.assertEqual(receipt["adb_return_code"], 7)
            self.assertEqual(
                (evidence / "prelaunch-boot-idle.stderr.txt").read_text(), "remote failure\n"
            )

    def test_timeout_keeps_partial_output_and_never_proves_startup(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory)
            timeout = subprocess.TimeoutExpired(
                ["adb"], 120, output=b"Waiting for queue...\n", stderr=b"partial error\n"
            )
            with patch("verify_android_startup_frame.subprocess.run", side_effect=timeout):
                with contextlib.redirect_stdout(io.StringIO()):
                    ready = wait_for_boot_broadcast_idle(evidence)
            receipt = json.loads((evidence / "prelaunch-boot-idle-receipt.json").read_text())
            self.assertFalse(ready)
            self.assertEqual(receipt["status"], "TIMEOUT")
            self.assertIsNone(receipt["adb_return_code"])
            self.assertFalse(receipt["broadcast_idle_confirmed"])
            self.assertIn(
                "Waiting for queue...",
                (evidence / "prelaunch-boot-idle.stdout.txt").read_text(),
            )
            self.assertIn(
                "120s", (evidence / "prelaunch-boot-idle.stderr.txt").read_text()
            )

    def test_zero_exit_with_missing_or_misleading_marker_is_failure(self) -> None:
        for output in ("", "Waiting for queue...", "NOT All broadcast queues are idle!"):
            with self.subTest(output=output), tempfile.TemporaryDirectory() as directory:
                evidence = Path(directory)
                result = subprocess.CompletedProcess([], 0, output, "")
                with patch("verify_android_startup_frame.subprocess.run", return_value=result):
                    with contextlib.redirect_stdout(io.StringIO()):
                        ready = wait_for_boot_broadcast_idle(evidence)
                receipt = json.loads(
                    (evidence / "prelaunch-boot-idle-receipt.json").read_text()
                )
                self.assertFalse(ready)
                self.assertEqual(receipt["status"], "INVALID_IDLE_OUTPUT")


if __name__ == "__main__":
    unittest.main()
