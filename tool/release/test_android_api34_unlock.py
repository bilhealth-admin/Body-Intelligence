"""State-machine controls use fake ADB only; no attached device is accessed."""
from pathlib import Path
import subprocess
import tempfile
import unittest

import android_api34_unlock as unlock


def window(awake=True, locked=False, focus='com.google.android.apps.nexuslauncher/.Launcher'):
    return ('WINDOW MANAGER POLICY STATE\n'
            f'    mAwake={str(awake).lower()}\n'
            '    KeyguardServiceDelegate\n'
            f'      showing={str(locked).lower()}\n'
            f'      inputRestricted={str(locked).lower()}\n'
            f'  mCurrentFocus=Window{{123 u0 {focus}}}\n')


class AdbControl:
    def __init__(self, states):
        self.states = list(states)
        self.calls = []
        self.time = 0.0
        self.devices = 'List of devices attached\nemulator-5554 device product:test\n'
        self.qemu, self.api, self.boot = '1', '34', '1'
        self.input_service = 'Service input: found'
        self.error_command = None
        self.command_advance = 0.01

    def clock(self):
        return self.time

    def sleep(self, seconds):
        self.time += seconds

    def run(self, argv, **kwargs):
        self.calls.append(argv)
        self.time += self.command_advance
        args = argv[1:] if argv[1] == 'devices' else argv[3:]
        if args == ['devices', '-l']:
            text = self.devices
        elif args == ['shell', 'getprop', 'ro.kernel.qemu']:
            text = self.qemu
        elif args == ['shell', 'getprop', 'ro.build.version.sdk']:
            text = self.api
        elif args == ['shell', 'getprop', 'sys.boot_completed']:
            text = self.boot
        elif args == ['shell', 'dumpsys', 'window']:
            text = self.states.pop(0) if len(self.states) > 1 else self.states[0]
        elif args == ['shell', 'service', 'check', 'input']:
            text = self.input_service
        elif args in (['shell', 'input', 'keyevent', '224'], ['shell', 'wm', 'dismiss-keyguard']):
            text = ''
        else:
            raise AssertionError('Unexpected ADB operation: ' + repr(argv))
        return subprocess.CompletedProcess(argv, 1 if args == self.error_command else 0, text, '')

    @property
    def mutations(self):
        return [x[3:] for x in self.calls if x[3:5] in (['shell', 'input'], ['shell', 'wm'])]


class Api34UnlockTest(unittest.TestCase):
    def execute(self, fake, serial='emulator-5554'):
        with tempfile.TemporaryDirectory() as folder:
            result = unlock.bootstrap(serial, Path(folder), run=fake.run,
                                      clock=fake.clock, sleep=fake.sleep)
            self.assertTrue((Path(folder) / 'api34-state-aware-unlock.json').is_file())
        self.assertEqual(result['command_retries'], 0)
        self.assertNotIn(['shell', 'input', 'keyevent', '82'], fake.mutations)
        return result

    def test_awake_unlocked_sends_no_input_or_service_probe(self):
        fake = AdbControl([window()])
        result = self.execute(fake)
        self.assertEqual(result['exit_code'], 0)
        self.assertEqual(fake.mutations, [])
        self.assertEqual(result['input_command_count'], 0)
        self.assertFalse(any('service' in call for call in fake.calls))

    def test_initial_null_focus_waits_for_known_focus_without_input(self):
        initial = window().replace(
            'mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/.Launcher}',
            'mCurrentFocus=null')
        fake = AdbControl([initial, window()])
        result = self.execute(fake)
        self.assertEqual(result['exit_code'], 0)
        self.assertEqual(len(result['observations']), 2)
        self.assertEqual(fake.mutations, [])

    def test_missing_initial_policy_waits_for_published_fields_without_input(self):
        fake = AdbControl(['WINDOW MANAGER POLICY STATE\n mCurrentFocus=null\n', window()])
        result = self.execute(fake)
        self.assertEqual(result['exit_code'], 0)
        self.assertFalse(result['observations'][0]['policy_ready'])
        self.assertEqual(fake.mutations, [])

    def test_initial_state_never_ready_expires_same_deadline_without_input(self):
        for state in ['WINDOW MANAGER POLICY STATE\n mCurrentFocus=null\n',
                      window().replace('mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/.Launcher}',
                                       'mCurrentFocus=null')]:
            with self.subTest(state=state):
                fake = AdbControl([state])
                result = self.execute(fake)
                self.assertNotEqual(result['exit_code'], 0)
                self.assertGreater(len(result['observations']), 1)
                self.assertLessEqual(result['elapsed_seconds'], unlock.DEADLINE_SECONDS + 0.02)
                self.assertEqual(fake.mutations, [])

    def test_missing_initial_policy_cannot_hide_anr_or_conflicting_known_flags(self):
        states = ['WINDOW MANAGER POLICY STATE\n mCurrentFocus=Application Not Responding: com.example.other\n',
                  window().replace('      inputRestricted=false\n', '') + ' mAwake=false\n',
                  window() + ' mFocusedWindow=Window{456 u0 ignored}\n mCurrentFocus=Window{456 u0 another/.Page}\n']
        for state in states:
            with self.subTest(state=state):
                fake = AdbControl([state])
                result = self.execute(fake)
                self.assertNotEqual(result['exit_code'], 0)
                self.assertEqual(len(result['observations']), 1)
                self.assertEqual(fake.mutations, [])

    def test_locked_only_dismisses_keyguard_once(self):
        fake = AdbControl([window(locked=True), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_asleep_only_uses_non_toggle_wakeup(self):
        fake = AdbControl([window(awake=False), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'input', 'keyevent', '224']])

    def test_asleep_locked_wakes_then_dismisses_with_readback(self):
        fake = AdbControl([window(False, True), window(True, True), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'input', 'keyevent', '224'],
                                          ['shell', 'wm', 'dismiss-keyguard']])
        self.assertEqual(len([c for c in fake.calls if 'window' in c]), 3)

    def test_async_readback_observes_without_repeating_input(self):
        fake = AdbControl([window(locked=True), window(locked=True), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_live_anr_blocks_all_input_even_if_locked(self):
        for owner, code in [('com.android.systemui', 20),
                            ('com.bilhealth.bodyintelligencelog', 21),
                            ('com.google.android.apps.nexuslauncher', 22)]:
            with self.subTest(owner=owner):
                fake = AdbControl([window(locked=True, focus='Application Not Responding: ' + owner)])
                self.assertEqual(self.execute(fake)['exit_code'], code)
                self.assertEqual(fake.mutations, [])

    def test_anr_during_wake_readback_prevents_dismissal(self):
        fake = AdbControl([window(False, True), window(focus='Application Not Responding: com.android.systemui')])
        self.assertEqual(self.execute(fake)['exit_code'], 20)
        self.assertEqual(fake.mutations, [['shell', 'input', 'keyevent', '224']])

    def test_anr_after_dismissal_is_failure_and_never_dismissed(self):
        fake = AdbControl([window(locked=True), window(focus='Application Not Responding: com.example.other')])
        self.assertEqual(self.execute(fake)['exit_code'], 22)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_unknown_or_conflicting_state_fails_without_input(self):
        for state in [window().replace('mAwake=true', 'mAwake=unknown'),
                      window().replace('showing=false', 'showing=unknown'),
                      window().replace('inputRestricted=false', 'inputRestricted=unknown'),
                      window() + ' mAwake=false\n',
                      window() + ' mKeyguardShowing=true\n']:
            with self.subTest(state=state):
                fake = AdbControl([state])
                self.assertNotEqual(self.execute(fake)['exit_code'], 0)
                self.assertEqual(fake.mutations, [])

    def test_hidden_but_input_restricted_keyguard_is_not_called_unlocked(self):
        fake = AdbControl([window().replace('inputRestricted=false', 'inputRestricted=true'), window()])
        result = self.execute(fake)
        self.assertEqual(result['exit_code'], 0)
        self.assertFalse(result['observations'][0]['keyguard_showing'])
        self.assertTrue(result['observations'][0]['keyguard_input_restricted'])
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_unknown_focus_cannot_trigger_wakeup_even_if_asleep(self):
        state = window(awake=False).replace(
            'mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/.Launcher}',
            'mCurrentFocus=null')
        fake = AdbControl([state])
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])

    def test_historical_anr_does_not_override_live_state(self):
        history = 'WINDOW MANAGER LAST ANR\n mAwake=false\n mKeyguardShowing=true\n mCurrentFocus=Application Not Responding: old.app\n'
        fake = AdbControl([history + window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])

    def test_physical_serial_is_refused_before_adb(self):
        fake = AdbControl([window()])
        self.assertNotEqual(self.execute(fake, serial='00008110-physical')['exit_code'], 0)
        self.assertEqual(fake.calls, [])

    def test_emulator_shaped_non_qemu_device_is_refused(self):
        fake = AdbControl([window()]); fake.qemu = '0'
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])

    def test_wrong_api_and_incomplete_boot_are_refused(self):
        for field, value in [('api', '33'), ('boot', '0')]:
            fake = AdbControl([window()]); setattr(fake, field, value)
            self.assertNotEqual(self.execute(fake)['exit_code'], 0)
            self.assertEqual(fake.mutations, [])

    def test_multiple_offline_or_unknown_target_inventory_is_refused(self):
        for devices in ['List of devices attached\nemulator-5554 device\nphysical device\n',
                        'List of devices attached\nemulator-5554 offline\n',
                        'List of devices attached\nemulator-5554 device\nemulator-5556 offline\n', 'unknown']:
            fake = AdbControl([window()]); fake.devices = devices
            self.assertNotEqual(self.execute(fake)['exit_code'], 0)
            self.assertEqual(fake.mutations, [])

    def test_missing_input_service_does_not_trigger_input_retry(self):
        fake = AdbControl([window(locked=True)]); fake.input_service = 'Service input: not found'
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])

    def test_readback_deadline_is_not_success_or_a_repeated_unlock(self):
        fake = AdbControl([window(locked=True)])
        result = self.execute(fake)
        self.assertNotEqual(result['exit_code'], 0)
        self.assertLessEqual(result['elapsed_seconds'], unlock.DEADLINE_SECONDS + 0.02)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_command_cannot_finish_after_shared_deadline_and_pass(self):
        fake = AdbControl([window()]); fake.command_advance = 7
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])

    def test_failed_command_and_unknown_focus_fail_closed(self):
        fake = AdbControl([window(locked=True)]); fake.error_command = ['shell', 'wm', 'dismiss-keyguard']
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])
        no_focus = window().replace('mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/.Launcher}', 'mCurrentFocus=null')
        fake = AdbControl([no_focus])
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])


if __name__ == '__main__':
    unittest.main()
