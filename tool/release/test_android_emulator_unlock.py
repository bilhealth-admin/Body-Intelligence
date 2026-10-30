"""State-machine controls use fake ADB only; no attached device is accessed."""
from pathlib import Path
import json
import subprocess
import tempfile
import unittest

import android_emulator_unlock as unlock

# Exact non-sensitive policy/focus excerpts from the six current CI emulators.
# Unrelated dumpsys data is omitted; full-dump SHA256 identifies each source.
ACTUAL_POLICY_FIXTURES = json.loads(r'''
[
  {
    "api": 26,
    "source_sha": "42db4553d09be845e403051c526b92678d3684d0",
    "source_dump_sha256": "66832b278777adc60f54e12423a743be3dfff8d912eebf76e3d30c3d57b9c771",
    "window": "WINDOW MANAGER POLICY STATE\n    mAwake=true\n    KeyguardServiceDelegate\n      showing=false\n      showingAndNotOccluded=true\n      inputRestricted=false\n      occluded=false\n      secure=false\n      dreaming=false\n      systemIsReady=true\n      deviceHasKeyguard=true\n      enabled=true\n      offReason=0\n      currentUser=-10000\n      bootCompleted=true\n      screenState=2\n      interactiveState=1\n      KeyguardStateMonitor\n        mIsShowing=false\n        mSimSecure=false\n        mInputRestricted=false\n        mTrusted=false\n        mCurrentUserId=0\n\n  mCurrentFocus=Window{14b811d u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n",
    "expected_flags": [
      true,
      false,
      false
    ],
    "expected_exit": 0
  },
  {
    "api": 29,
    "source_sha": "42db4553d09be845e403051c526b92678d3684d0",
    "source_dump_sha256": "40fd5edd4d8b498f452b7486debc17085436a6753694846e9db1cb1743b95722",
    "window": "WINDOW MANAGER POLICY STATE\n    mAwake=true mScreenOnEarly=true mScreenOnFully=true\n    KeyguardServiceDelegate\n      showing=false\n      showingAndNotOccluded=true\n      inputRestricted=false\n      occluded=false\n      secure=false\n      dreaming=false\n      systemIsReady=true\n      deviceHasKeyguard=true\n      enabled=true\n      offReason=0\n      currentUser=-10000\n      bootCompleted=true\n      screenState=SCREEN_STATE_ON\n      interactiveState=INTERACTIVE_STATE_AWAKE\n      KeyguardStateMonitor\n        mIsShowing=false\n        mSimSecure=false\n        mInputRestricted=false\n        mTrusted=false\n        mCurrentUserId=0\n  mCurrentFocus=Window{ffbbc07 u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n",
    "expected_flags": [
      true,
      false,
      false
    ],
    "expected_exit": 0
  },
  {
    "api": 33,
    "source_sha": "42db4553d09be845e403051c526b92678d3684d0",
    "source_dump_sha256": "a53bfb546804b8baa35dc5663e01832c171d1bfcee9db0ba7f906c345c85c6ef",
    "window": "WINDOW MANAGER POLICY STATE\n    mAwake=true mScreenOnEarly=true mScreenOnFully=true\n    KeyguardServiceDelegate\n      showing=false\n      showingAndNotOccluded=true\n      inputRestricted=false\n      occluded=false\n      secure=false\n      dreaming=false\n      systemIsReady=true\n      deviceHasKeyguard=true\n      enabled=true\n      offReason=0\n      currentUser=-10000\n      bootCompleted=true\n      screenState=SCREEN_STATE_ON\n      interactiveState=INTERACTIVE_STATE_AWAKE\n      KeyguardStateMonitor\n        mIsShowing=false\n        mSimSecure=false\n        mInputRestricted=false\n        mTrusted=false\n        mCurrentUserId=0\n  mCurrentFocus=Window{f4cbe67 u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n",
    "expected_flags": [
      true,
      false,
      false
    ],
    "expected_exit": 0
  },
  {
    "api": 34,
    "source_sha": "42db4553d09be845e403051c526b92678d3684d0",
    "source_dump_sha256": "b4d8aa3a4849acb6a3fb7d634f331c82e302821086db08db658b3f4d4483794a",
    "window": "WINDOW MANAGER POLICY STATE\n    mAwake=true mScreenOnEarly=true mScreenOnFully=true\n    KeyguardServiceDelegate\n      showing=false\n      inputRestricted=false\n      occluded=false\n      secure=false\n      dreaming=false\n      systemIsReady=true\n      deviceHasKeyguard=true\n      enabled=true\n      offReason=0\n      currentUser=-10000\n      bootCompleted=true\n      screenState=SCREEN_STATE_ON\n      interactiveState=INTERACTIVE_STATE_AWAKE\n      KeyguardStateMonitor\n        mIsShowing=false\n        mSimSecure=false\n        mInputRestricted=false\n        mTrusted=false\n        mCurrentUserId=0\n  mCurrentFocus=Window{e88d26d u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n",
    "expected_flags": [
      true,
      false,
      false
    ],
    "expected_exit": 0
  },
  {
    "api": 35,
    "source_sha": "42db4553d09be845e403051c526b92678d3684d0",
    "source_dump_sha256": "ae2bcd8f06e4a0493ff583afd64a69e92e5417f4dc5106c36f37ee1104baba47",
    "window": "WINDOW MANAGER POLICY STATE\n    mAwake=true mScreenOnEarly=true mScreenOnFully=true\n    KeyguardServiceDelegate\n      showing=false\n      inputRestricted=false\n      occluded=false\n      secure=false\n      dreaming=false\n      systemIsReady=true\n      deviceHasKeyguard=true\n      enabled=true\n      offReason=0\n      currentUser=-10000\n      bootCompleted=true\n      screenState=SCREEN_STATE_ON\n      interactiveState=INTERACTIVE_STATE_AWAKE\n      KeyguardStateMonitor\n        mIsShowing=false\n        mSimSecure=false\n        mInputRestricted=false\n        mTrusted=false\n        mCurrentUserId=0\n  mCurrentFocus=Window{b600bd1 u0 Application Not Responding: com.google.android.googlesdksetup}\n",
    "expected_flags": [
      true,
      false,
      false
    ],
    "expected_exit": 22
  },
  {
    "api": 36,
    "source_sha": "42db4553d09be845e403051c526b92678d3684d0",
    "source_dump_sha256": "52ac5b253ecda702a49fa4063baf4efde761cbb6caeb83c9d53085af83128a4b",
    "window": "WINDOW MANAGER POLICY STATE\n    mAwake=true mScreenOnEarly=true mScreenOnFully=true\n    KeyguardServiceDelegate\n      showing=false\n      inputRestricted=false\n      occluded=false\n      secure=false\n      dreaming=false\n      systemIsReady=true\n      deviceHasKeyguard=true\n      enabled=true\n      offReason=0\n      currentUser=-10000\n      bootCompleted=true\n      screenState=SCREEN_STATE_ON\n      interactiveState=INTERACTIVE_STATE_AWAKE\n      KeyguardStateMonitor\n        mIsShowing=false\n        mSimSecure=false\n        mInputRestricted=false\n        mTrusted=false\n        mCurrentUserId=0\n  mCurrentFocus=Window{aed899c u0 com.google.android.apps.nexuslauncher/com.google.android.apps.nexuslauncher.NexusLauncherActivity}\n",
    "expected_flags": [
      true,
      false,
      false
    ],
    "expected_exit": 0
  }
]
''')


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
        elif args == ['logcat', '-b', 'events', '-b', 'crash', '-d', '-t', '300']:
            text = 'events fixture before input\n'
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


class AndroidUnlockTest(unittest.TestCase):
    def execute(self, fake, serial='emulator-5554', expected_api=34):
        with tempfile.TemporaryDirectory() as folder:
            result = unlock.bootstrap(serial, Path(folder), expected_api=expected_api, run=fake.run,
                                      clock=fake.clock, sleep=fake.sleep)
            self.assertTrue((Path(folder) / 'android-state-aware-unlock.json').is_file())
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
        fake = AdbControl([window(locked=True), window(locked=True), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_asleep_only_uses_non_toggle_wakeup(self):
        fake = AdbControl([window(awake=False), window(awake=False), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'input', 'keyevent', '224']])

    def test_asleep_locked_wakes_then_dismisses_with_readback(self):
        fake = AdbControl([window(False, True), window(False, True), window(True, True), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'input', 'keyevent', '224'],
                                          ['shell', 'wm', 'dismiss-keyguard']])
        self.assertEqual(len([c for c in fake.calls if 'window' in c]), 4)

    def test_async_readback_observes_without_repeating_input(self):
        fake = AdbControl([window(locked=True), window(locked=True), window(locked=True), window()])
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
        fake = AdbControl([window(False, True), window(False, True), window(focus='Application Not Responding: com.android.systemui')])
        self.assertEqual(self.execute(fake)['exit_code'], 20)
        self.assertEqual(fake.mutations, [['shell', 'input', 'keyevent', '224']])

    def test_anr_after_dismissal_is_failure_and_never_dismissed(self):
        fake = AdbControl([window(locked=True), window(locked=True), window(focus='Application Not Responding: com.example.other')])
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
        fake = AdbControl([window().replace('inputRestricted=false', 'inputRestricted=true'), window().replace('inputRestricted=false', 'inputRestricted=true'), window()])
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

    def test_actual_six_policy_excerpts_parse_and_preserve_the_anr_gate(self):
        self.assertEqual([sample['api'] for sample in ACTUAL_POLICY_FIXTURES], [26, 29, 33, 34, 35, 36])
        for sample in ACTUAL_POLICY_FIXTURES:
            with self.subTest(api=sample['api']):
                self.assertEqual(list(unlock.window_flags(sample['window'])), sample['expected_flags'])
                fake = AdbControl([sample['window']]); fake.api = str(sample['api'])
                result = self.execute(fake, expected_api=sample['api'])
                self.assertEqual(result['exit_code'], sample['expected_exit'])
                self.assertEqual(fake.mutations, [])
                self.assertFalse(result['provisioning_or_provider_readiness_proven'])

    def test_supported_expected_api_still_requires_an_exact_sdk_match(self):
        for api in (26, 29, 33, 34, 35, 36):
            with self.subTest(api=api):
                fake = AdbControl([window()]); fake.api = str(29 if api == 26 else 26)
                self.assertNotEqual(self.execute(fake, expected_api=api)['exit_code'], 0)
                self.assertEqual(fake.mutations, [])
        for api in (25, 27, 37, True, '34', None):
            with self.subTest(api=api):
                fake = AdbControl([window()])
                self.assertNotEqual(self.execute(fake, expected_api=api)['exit_code'], 0)
                self.assertEqual(fake.calls, [])

    def test_legacy_extra_field_does_not_override_canonical_showing(self):
        legacy = window().replace('      showing=false\n',
                                  '      showing=false\n      showingAndNotOccluded=true\n')
        self.assertEqual(unlock.window_flags(legacy), (True, False, False))
        for conflict in [legacy.replace('      inputRestricted=false', '      showing=true\n      inputRestricted=false'),
                         legacy + '  mKeyguardShowing=true\n']:
            with self.subTest(conflict=conflict), self.assertRaises(unlock.BootstrapFailure):
                unlock.window_flags(conflict)

    def test_delegate_cannot_borrow_fields_from_other_or_nested_blocks(self):
        missing = window().replace('      inputRestricted=false\n', '')
        samples = [missing + '  OtherBlock\n    inputRestricted=false\n',
                   missing.replace('  mCurrentFocus=', '      NestedBlock\n        inputRestricted=false\n  mCurrentFocus=')]
        for sample in samples:
            with self.subTest(sample=sample), self.assertRaises(unlock.InitialStateNotReady):
                unlock.window_flags(sample)
        oversized = window().replace('      inputRestricted=false\n',
                                      '\n' * (unlock.DELEGATE_LINE_LIMIT + 1) + '      inputRestricted=false\n')
        with self.assertRaisesRegex(unlock.BootstrapFailure, 'bounded block'):
            unlock.window_flags(oversized)

    def assert_multiple_delegates_are_refused(self, blocks):
        sample = ('WINDOW MANAGER POLICY STATE\n    mAwake=true\n' + blocks +
                  '  mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/.Launcher}\n')
        with self.assertRaisesRegex(unlock.BootstrapFailure, 'Multiple keyguard delegates') as caught:
            unlock.window_flags(sample)
        self.assertNotIsInstance(caught.exception, unlock.InitialStateNotReady)
        fake = AdbControl([sample])
        result = self.execute(fake)
        self.assertNotEqual(result['exit_code'], 0)
        self.assertEqual(fake.mutations, [])
        self.assertEqual(len([call for call in fake.calls if 'window' in call]), 1)

    def test_partial_delegates_cannot_supply_a_cross_block_pair(self):
        self.assert_multiple_delegates_are_refused(
            '    KeyguardServiceDelegate\n      showing=false\n'
            '    KeyguardServiceDelegate\n      inputRestricted=false\n')

    def test_reversed_partial_delegates_cannot_supply_a_cross_block_pair(self):
        self.assert_multiple_delegates_are_refused(
            '    KeyguardServiceDelegate\n      inputRestricted=false\n'
            '    KeyguardServiceDelegate\n      showing=false\n')

    def test_duplicate_complete_delegates_are_also_refused(self):
        self.assert_multiple_delegates_are_refused(
            '    KeyguardServiceDelegate\n      showing=false\n      inputRestricted=false\n' * 2)

    def test_early_capture_is_readonly_once_and_precedes_any_input(self):
        fake = AdbControl([window(locked=True), window(locked=True), window()])
        result = self.execute(fake)
        capture = [i for i, call in enumerate(fake.calls) if 'logcat' in call]
        self.assertEqual(len(capture), 1)
        mutation = next(i for i, call in enumerate(fake.calls) if call[3:5] == ['shell', 'wm'])
        self.assertLess(capture[0], mutation)
        self.assertTrue(any('window' in call for call in fake.calls[capture[0] + 1:mutation]))
        self.assertNotIn('-c', fake.calls[capture[0]])
        self.assertEqual(result['early_readonly_capture']['status'], 'CAPTURED')

    def test_early_capture_failure_cannot_replace_anr_or_repeat_input(self):
        fake = AdbControl([window(focus='Application Not Responding: com.google.android.googlesdksetup')])
        fake.error_command = ['logcat', '-b', 'events', '-b', 'crash', '-d', '-t', '300']
        result = self.execute(fake)
        self.assertEqual(result['exit_code'], 22)
        self.assertEqual(result['early_readonly_capture']['status'], 'NONZERO_EXIT')
        self.assertEqual(len([call for call in fake.calls if 'logcat' in call]), 1)
        self.assertEqual(fake.mutations, [])

    def test_unknown_post_input_focus_still_fails_without_retry(self):
        unknown = window().replace('mCurrentFocus=Window{123 u0 com.google.android.apps.nexuslauncher/.Launcher}',
                                   'mCurrentFocus=null')
        fake = AdbControl([window(locked=True), window(locked=True), unknown])
        self.assertNotEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [['shell', 'wm', 'dismiss-keyguard']])

    def test_lock_clearing_during_readonly_capture_does_not_trigger_input(self):
        fake = AdbControl([window(locked=True), window()])
        self.assertEqual(self.execute(fake)['exit_code'], 0)
        self.assertEqual(fake.mutations, [])


if __name__ == '__main__':
    unittest.main()
