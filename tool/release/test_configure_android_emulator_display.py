#!/usr/bin/env python3
"""Real AVD file/CLI and bounded runtime readback regressions; no emulator start."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import configure_android_emulator_display as display


class AndroidDisplayConfigurationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / 'test.avd' / 'config.ini'
        self.config.parent.mkdir()
        self.before = (
            b'# original profile\r\n'
            b'hw.lcd.width = 1080\r\n'
            b'hw.lcd.height=2400\r\n'
            b'hw.lcd.density=420\r\n'
            b'hw.cpu.ncore=2\r\n'
            b'hw.ramSize=4096\r\n'
            b'hw.gpu.mode=auto\r\n'
            b'image.sysdir.1=system-images/android-36/google_apis/x86_64/\r\n'
        )
        self.config.write_bytes(self.before)

    def test_only_api34_and36_change_real_config_and_preserve_other_properties(self):
        for api in (34, 36):
            with self.subTest(api=api):
                self.config.write_bytes(self.before)
                receipt = display.configure_display(api, self.config)
                self.assertEqual(receipt['status'], 'CONFIGURED')
                self.assertTrue(receipt['changed'])
                expected = self.before.replace(b'hw.lcd.width = 1080', b'hw.lcd.width=720').replace(b'hw.lcd.height=2400', b'hw.lcd.height=1280').replace(b'hw.lcd.density=420', b'hw.lcd.density=320')
                self.assertEqual(self.config.read_bytes(), expected)
                self.assertNotEqual(receipt['before_sha256'], receipt['after_sha256'])

    def test_four_successful_api_configurations_remain_byte_identical(self):
        for api in (26, 29, 33, 35):
            with self.subTest(api=api):
                result = display.configure_display(api, self.config)
                self.assertEqual(result['status'], 'UNCHANGED_API')
                self.assertFalse(result['changed'])
                self.assertEqual(self.config.read_bytes(), self.before)

    def test_unchanged_api_does_not_require_a_file_or_make_adb_calls(self):
        for api in (26, 29, 33, 35):
            runner = mock.Mock(side_effect=AssertionError('Unexpected ADB call'))
            self.assertEqual(display.configure_display(api, self.root / 'missing')['status'], 'UNCHANGED_API')
            self.assertEqual(display.verify_runtime_display(api, runner)['status'], 'UNCHANGED_API')
            runner.assert_not_called()

    def test_configuration_is_idempotent_without_rewriting_the_file(self):
        display.configure_display(34, self.config)
        os.utime(self.config, ns=(1_000_000_000, 1_000_000_000))
        result = display.configure_display(34, self.config)
        self.assertFalse(result['changed'])
        self.assertEqual(result['before_sha256'], result['after_sha256'])
        self.assertEqual(self.config.stat().st_mtime_ns, 1_000_000_000)

    def test_duplicate_display_properties_cannot_override_the_reviewed_value(self):
        self.config.write_bytes(self.before + b'hw.lcd.width=4096\r\nhw.lcd.density=160\r\n')
        display.configure_display(36, self.config)
        after = self.config.read_bytes()
        self.assertEqual(after.count(b'hw.lcd.width='), 1)
        self.assertEqual(after.count(b'hw.lcd.density='), 1)
        self.assertIn(b'hw.lcd.width=720\r\n', after)
        self.assertIn(b'hw.lcd.density=320\r\n', after)

    def test_missing_properties_are_appended_without_destroying_the_existing_entry(self):
        self.config.write_bytes(b'hw.cpu.ncore=2')
        display.configure_display(36, self.config)
        self.assertEqual(self.config.read_text(), 'hw.cpu.ncore=2\nhw.lcd.width=720\nhw.lcd.height=1280\nhw.lcd.density=320\n')

    def test_missing_or_wrong_target_is_not_created_or_overwritten(self):
        for target in (self.root / 'missing.avd' / 'config.ini', self.root / 'profile.ini'):
            with self.subTest(target=target):
                with self.assertRaises(display.DisplayContractError):
                    display.configure_display(34, target)
                self.assertFalse(target.exists())
        self.assertEqual(self.config.read_bytes(), self.before)

    def test_unknown_api_fails_before_mutating_configuration(self):
        with self.assertRaises(ValueError):
            display.configure_display(99, self.config)
        self.assertEqual(self.config.read_bytes(), self.before)

    def test_actual_cli_writes_readback_receipt_and_does_not_claim_app_startup(self):
        evidence = self.root / 'evidence'
        result = subprocess.run([
            sys.executable, str(Path(display.__file__)), 'configure', '--api-level', '36',
            '--config', str(self.config), '--evidence-dir', str(evidence),
        ], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        receipt = json.loads((evidence / 'avd-display-config.json').read_text())
        self.assertEqual(receipt['display'], display.DISPLAY)
        self.assertFalse(receipt['app_startup_proven'])
        self.assertIn('hw.lcd.width=720', self.config.read_text())


class AndroidDisplayRuntimeTest(unittest.TestCase):
    @staticmethod
    def runner(size='Physical size: 720x1280\r\n', density='Physical density: 320\r\n'):
        return mock.Mock(side_effect=[
            subprocess.CompletedProcess(['adb', 'shell', 'wm', 'size'], 0, size, ''),
            subprocess.CompletedProcess(['adb', 'shell', 'wm', 'density'], 0, density, ''),
        ])

    def test_matching_physical_display_requires_both_readbacks_without_wm_mutation(self):
        for api in (34, 36):
            with self.subTest(api=api):
                runner = self.runner()
                result = display.verify_runtime_display(api, runner)
                self.assertEqual(result['status'], 'MATCHED')
                self.assertEqual(result['physical_size'], [720, 1280])
                self.assertEqual(result['physical_density'], 320)
                self.assertEqual([call.args[0] for call in runner.call_args_list], [['adb', 'shell', 'wm', 'size'], ['adb', 'shell', 'wm', 'density']])
                self.assertTrue(all(call.kwargs['timeout'] == 8 for call in runner.call_args_list))

    def test_logical_override_does_not_hide_a_full_size_physical_framebuffer(self):
        with self.assertRaisesRegex(display.DisplayContractError, 'Physical framebuffer'):
            display.verify_runtime_display(34, self.runner('Physical size: 1080x2400\nOverride size: 720x1280\n'))

    def test_wrong_or_ambiguous_physical_readback_is_rejected(self):
        for size, density in (
            ('Physical size: 1080x2400\n', 'Physical density: 320\n'),
            ('Physical size: 720x1280\n', 'Physical density: 420\n'),
            ('', 'Physical density: 320\n'),
            ('Physical size: 720x1280\nPhysical size: 720x1280\n', 'Physical density: 320\n'),
            ('Physical size: 720x1280\nOverride size: 1080x2400\n', 'Physical density: 320\n'),
            ('Physical size: 720x1280\n', 'Physical density: 320\nOverride density: 420\n'),
        ):
            with self.subTest(size=size, density=density):
                with self.assertRaises(display.DisplayContractError):
                    display.verify_runtime_display(36, self.runner(size, density))

    def test_adb_denial_and_timeout_fail_without_retry(self):
        for result in (
            subprocess.CompletedProcess([], 1, '', 'denied'),
            subprocess.TimeoutExpired(['adb', 'shell', 'wm', 'size'], 8),
        ):
            with self.subTest(result=result):
                runner = mock.Mock(side_effect=result if isinstance(result, Exception) else None, return_value=result)
                with self.assertRaises(display.DisplayContractError) as error:
                    display.verify_runtime_display(34, runner)
                self.assertEqual(runner.call_count, 1)
                self.assertEqual(len(error.exception.receipt['commands']), 1)

    def test_malformed_or_duplicated_override_is_not_silently_accepted(self):
        for size, density in (
            ('Physical size: 720x1280\nOverride size: invalid\n', 'Physical density: 320\n'),
            ('Physical size: 720x1280\nOverride size: 720x1280\nOverride size: 720x1280\n', 'Physical density: 320\n'),
            ('Physical size: 720x1280\n', 'Physical density: 320\nOverride density: unknown\n'),
        ):
            with self.subTest(size=size, density=density):
                with self.assertRaises(display.DisplayContractError):
                    display.verify_runtime_display(34, self.runner(size, density))

    def test_failure_is_saved_and_returns_nonzero_without_claiming_startup(self):
        with tempfile.TemporaryDirectory() as folder:
            with mock.patch.object(display, 'verify_runtime_display', side_effect=display.DisplayContractError('physical mismatch')):
                with contextlib.redirect_stdout(io.StringIO()):
                    code = display.main(['verify-runtime', '--api-level', '34', '--evidence-dir', folder])
            self.assertEqual(code, 5)
            receipt = json.loads((Path(folder) / 'runtime-display.json').read_text())
            self.assertEqual(receipt['status'], 'FAILED')
            self.assertFalse(receipt['app_startup_proven'])


if __name__ == '__main__':
    unittest.main()
