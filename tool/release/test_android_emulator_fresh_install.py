#!/usr/bin/env python3
"""Run the real Bash startup script with a bounded fake ADB, without an SDK.

The fake's pm clear returns before a pending OS stop kills the newly launched
process, matching the D186 API33 event ordering. That is a causal harness model,
not a claim to reproduce emulator internals. All focus/frame/ANR/crash gates in
the actual script still execute, with explicit boundary responses from stubs.
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tool/release/run_android_emulator_smoke.sh'
APP = 'com.bilhealth.bodyintelligencelog'

ADB = r'''#!/usr/bin/env bash
set -euo pipefail
s="$BIL_TEST_STATE"
printf '%s\n' "$*" >> "$s/adb-trace.txt"
case "$*" in
  'wait-for-device') exit 0 ;;
  'get-state') printf 'device\n'; exit 0 ;;
  'shell getprop sys.boot_completed') printf '1\n'; exit 0 ;;
  'shell getprop ro.build.version.sdk') printf '33\n'; exit 0 ;;
  'shell pm list packages --user 0 com.bilhealth.bodyintelligencelog')
    if [[ "$BIL_TEST_MODE" == list-failed ]]; then echo 'package service unavailable' >&2; exit 1; fi
    if [[ "$BIL_TEST_MODE" == malformed-list ]]; then printf 'unexpected-output\n'; exit 0; fi
    if [[ "$BIL_TEST_MODE" == already-installed ]]; then printf 'package:com.bilhealth.bodyintelligencelog\r\n'; fi
    exit 0 ;;
  'install build/app/outputs/flutter-apk/app-debug.apk')
    if [[ "$BIL_TEST_MODE" == install-failed ]]; then echo 'Failure [INSTALL_FAILED_TEST]' >&2; exit 1; fi
    touch "$s/installed"; printf 'Performing Streamed Install\nSuccess\n'; exit 0 ;;
  'shell pm clear com.bilhealth.bodyintelligencelog')
    touch "$s/pending-clear-stop"; printf 'Success\n'; exit 0 ;;
  'shell am start -n com.bilhealth.bodyintelligencelog/.MainActivity')
    [[ -f "$s/installed" ]] || exit 1
    touch "$s/running"; printf 'Starting: Intent { cmp=com.bilhealth.bodyintelligencelog/.MainActivity }\n'; exit 0 ;;
  'shell pidof com.bilhealth.bodyintelligencelog')
    if [[ -f "$s/pending-clear-stop" ]]; then
      rm -f "$s/running" "$s/pending-clear-stop"
      printf 'am_kill due to clearApplicationUserData\n' >> "$s/events.txt"
    fi
    if [[ -f "$s/running" ]]; then printf '4972\n'; fi
    exit 0 ;;
  'shell dumpsys window'|'shell dumpsys window windows')
    if [[ -f "$s/running" && "$BIL_TEST_MODE" != focus-failed ]]; then printf 'BIL_FOCUSED\n'; else printf 'LAUNCHER_FOCUSED\n'; fi
    exit 0 ;;
  'exec-out screencap -p') printf 'test-frame-not-real-png\n'; exit 0 ;;
esac
if [[ "$1" == pull ]]; then printf '<hierarchy/>\n' > "${@: -1}"; exit 0; fi
if [[ "$1" == logcat && "$*" == *'--pid='* && "$BIL_TEST_MODE" == crash ]]; then printf 'FATAL EXCEPTION: main\n'; exit 0; fi
exit 0
'''

PYTHON_BOUNDARY = r'''#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$BIL_TEST_STATE/validator-trace.txt"
if [[ "$*" == *'--capture-failure-diagnostics'* ]]; then exit 0; fi
if [[ "$*" == *'--verify-emulator-before-launch'* ]]; then
  [[ "$BIL_TEST_MODE" != prelaunch-anr ]] || exit 20
  exit 0
fi
if [[ "$*" == *'configure_android_emulator_display.py verify-runtime'* ]]; then exit 0; fi
if [[ "$*" == *'--window-health-only'* ]]; then
  if [[ "$BIL_TEST_MODE" == focus-anr ]]; then exit 20; fi
  [[ -f "$BIL_TEST_STATE/running" && "$BIL_TEST_MODE" != focus-failed ]] || exit 1
  exit 0
fi
if [[ "$1" == *'classify_android_startup_anr.py' ]]; then
  [[ "$BIL_TEST_MODE" != app-anr ]] || exit 1
  exit 0
fi
if [[ "$1" == *'verify_android_startup_frame.py' ]]; then
  [[ "$BIL_TEST_MODE" != frame-failed ]] || exit 1
  exit 0
fi
printf 'Unexpected validator boundary: %s\n' "$*" >&2
exit 99
'''

class AndroidEmulatorFreshInstallTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        candidates = []
        if os.name == 'nt':
            candidates.append(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
        found = shutil.which('bash')
        if found:
            candidates.append(Path(found))
        cls.bash = next((str(p) for p in candidates if p.is_file()), None)
        if cls.bash is None:
            raise RuntimeError('Bash is required for these real-script regressions; no silent skips')
        # A missing/unusable Bash is a hard test setup error, never zero tests PASS.
        probe = subprocess.run([cls.bash, '--noprofile', '--norc', '-c', '/usr/bin/true'],
                               text=True, capture_output=True, timeout=20, check=False)
        if probe.returncode != 0:
            raise RuntimeError('Bash cannot fork a minimal child process: ' + probe.stderr)
        cls.source = SCRIPT.read_text(encoding='utf-8')

    def run_script(self, mode: str = 'normal', *, late_clear: bool = False):
        with tempfile.TemporaryDirectory(prefix='bil-startup-fresh-fixture-') as raw:
            root = Path(raw)
            (root / 'bin').mkdir()
            (root / 'state').mkdir()
            apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
            apk.parent.mkdir(parents=True)
            apk.write_bytes(b'owned test APK boundary; not executable')
            source = self.source
            if late_clear:
                anchor = "stage='launch-main-activity'\n"
                self.assertEqual(source.count(anchor), 1)
                source = source.replace(anchor, "stage='clear-app-data'\nadb shell pm clear \"$app_id\" >/dev/null\n" + anchor)
            (root / 'smoke.sh').write_text(source, encoding='utf-8', newline='\n')
            for name, content in {
                'adb': ADB,
                'python3': PYTHON_BOUNDARY,
                'sleep': '#!/usr/bin/env bash\nexit 0\n',
                'timeout': '#!/usr/bin/env bash\nshift\nexec "$@"\n',
            }.items():
                p = root / 'bin' / name
                p.write_text(content, encoding='utf-8', newline='\n')
                p.chmod(0o755)
            env = dict(os.environ)
            env['PATH'] = str(root / 'bin') + os.pathsep + env.get('PATH', '')
            env['BIL_TEST_STATE'] = (root / 'state').as_posix()
            env['BIL_TEST_MODE'] = mode
            env['BIL_ANDROID_EMULATOR_API'] = '33'
            env['GITHUB_SHA'] = 'synthetic-owned-fixture'
            out = subprocess.run([self.bash, '--noprofile', '--norc', '-c',
                                  'export BIL_TEST_STATE="$PWD/state"; export PATH="$PWD/bin:$PATH"; exec /bin/bash smoke.sh'], cwd=root, env=env, text=True,
                                 capture_output=True, timeout=20, check=False)
            def read(path: Path) -> str:
                return path.read_text(encoding='utf-8') if path.exists() else ''
            evidence = root / 'artifacts/release/android_emulator_smoke/api-33'
            return out, read(root/'state/adb-trace.txt'), read(root/'state/events.txt'), read(evidence/'failure.txt'), read(root/'state/validator-trace.txt')

    def test_actual_workflow_explicitly_recreates_the_snapshot_disabled_avd(self):
        workflow = (ROOT / '.github/workflows/bil_android_isolated_emulator_smoke.yml').read_text(encoding='utf-8')
        self.assertIn('          force-avd-creation: true\n', workflow)
        self.assertIn("          python3 -m unittest discover -s tool/release -p 'test_android_emulator_fresh_install.py' -v\n", workflow)
        options = (ROOT / 'tool/release/android_emulator_launch_options.py').read_text(encoding='utf-8')
        self.assertIn('-no-snapshot', options)

    def test_fresh_install_launches_once_without_any_data_clear(self):
        result, trace, events, failure, validators = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(trace.count('shell am start -n '), 1)
        self.assertEqual(trace.count('install build/'), 1)
        self.assertLess(trace.index('shell pm list packages'), trace.index('install build/'))
        self.assertNotIn('shell pm clear', trace)
        self.assertNotIn('am_kill', events)
        self.assertEqual(failure, '')
        self.assertIn('classify_android_startup_anr.py', validators)
        self.assertIn('--pid=4972', trace)

    def test_actual_script_with_old_clear_sequence_is_killed_before_focus(self):
        result, trace, events, failure, _ = self.run_script(late_clear=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(trace.count('shell am start -n '), 1)
        self.assertIn('am_kill due to clearApplicationUserData', events)
        self.assertIn('stage=wait-for-app-foreground', failure)
        self.assertIn('BIL did not become the actual focused Android window', result.stderr)

    def test_existing_package_fails_before_install_or_launch_without_mutating_it(self):
        result, trace, _, failure, _ = self.run_script('already-installed')
        self.assertEqual(result.returncode, 5)
        self.assertIn('stage=verify-fresh-app-install', failure)
        self.assertNotIn('install build/', trace)
        self.assertNotIn('shell am start', trace)
        self.assertNotIn('shell pm clear', trace)

    def test_absence_query_failure_fails_closed_before_install(self):
        result, trace, _, failure, _ = self.run_script('list-failed')
        self.assertEqual(result.returncode, 5)
        self.assertIn('stage=verify-fresh-app-install', failure)
        self.assertNotIn('install build/', trace)
        self.assertNotIn('shell am start', trace)

    def test_unexpected_package_query_output_is_not_accepted_as_absence(self):
        result, trace, _, failure, _ = self.run_script('malformed-list')
        self.assertEqual(result.returncode, 5)
        self.assertIn('stage=verify-fresh-app-install', failure)
        self.assertNotIn('install build/', trace)

    def test_failed_install_cannot_reach_launch(self):
        result, trace, _, failure, _ = self.run_script('install-failed')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('stage=install-debug-apk', failure)
        self.assertNotIn('shell am start', trace)

    def test_foreground_failure_remains_failure_without_launch_retry(self):
        result, trace, _, failure, _ = self.run_script('focus-failed')
        self.assertEqual(result.returncode, 1)
        self.assertIn('stage=wait-for-app-foreground', failure)
        self.assertEqual(trace.count('shell am start -n '), 1)

    def test_first_frame_failure_remains_failure(self):
        result, trace, _, failure, _ = self.run_script('frame-failed')
        self.assertEqual(result.returncode, 1)
        self.assertIn('stage=wait-for-accessible-app-content-and-first-frame', failure)
        self.assertEqual(trace.count('shell am start -n '), 1)

    def test_prelaunch_system_ui_anr_prevents_install_and_launch(self):
        result, trace, _, failure, _ = self.run_script('prelaunch-anr')
        self.assertEqual(result.returncode, 20)
        self.assertIn('stage=verify-emulator-system-ui-before-launch', failure)
        self.assertNotIn('install build/', trace)
        self.assertNotIn('shell am start', trace)

    def test_foreground_anr_keeps_specific_exit_code(self):
        result, trace, _, failure, _ = self.run_script('focus-anr')
        self.assertEqual(result.returncode, 20)
        self.assertIn('stage=wait-for-app-foreground', failure)
        self.assertEqual(trace.count('shell am start -n '), 1)

    def test_app_anr_classification_remains_failure(self):
        result, _, _, failure, _ = self.run_script('app-anr')
        self.assertEqual(result.returncode, 1)
        self.assertIn('stage=verify-first-frame-content', failure)

    def test_fatal_app_crash_remains_failure(self):
        result, _, _, failure, _ = self.run_script('crash')
        self.assertEqual(result.returncode, 1)
        self.assertIn('stage=check-app-crash-log', failure)
        self.assertIn('fatal app crash', result.stderr)

if __name__ == '__main__':
    unittest.main()
