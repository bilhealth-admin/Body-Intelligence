#!/usr/bin/env python3
"""Execute the real prehook against a fake SDK; never boot or retry an emulator."""
import contextlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).with_name("run_android_startup_memory_controller.sh")


class AndroidStartupPrehookTests(unittest.TestCase):
    @contextlib.contextmanager
    def fixture(self, *, adb_ok=True, build="16428233", api="34"):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sdk = root / "sdk with spaces"
            bin_dir = root / "host-bin"
            app = root / "app"
            avd = root / "avd/test.avd"
            for path in (sdk / "platform-tools", sdk / "emulator", bin_dir, app, avd):
                path.mkdir(parents=True)
            (avd / "config.ini").write_text("hw.ramSize=4096\nhw.cpu.ncore=2\n")
            def executable(path, body):
                path.write_text("#!" + sys.executable + "\n" + body)
                path.chmod(0o755)
            # Only unrelated source/host checks are stubbed. SDK process argv,
            # loader errors, actual background scripts and PID handshakes run.
            executable(bin_dir / "python3", "import sys\nsys.stdin.read()\n")
            executable(bin_dir / "git", "pass\n")
            executable(bin_dir / "adb", "raise SystemExit('HOSTILE_PATH_ADB_MUST_NOT_RUN')\n")
            executable(sdk / "platform-tools/adb", """import os,sys,time
from pathlib import Path
args=sys.argv[1:]
if args==['version']:
    if os.environ['TEST_ADB_OK']!='1': raise SystemExit(127)
    print('Android Debug Bridge version 1.0.41')
elif args==['wait-for-device']:
    while not Path(os.environ['TEST_DEVICE_CONNECTED']).exists(): time.sleep(0.02)
elif args and args[0]=='logcat':
    print('10-20 00:00:00.000 1 1 I TestBoot: startup log stream',flush=True)
    while True: time.sleep(0.1)
elif args==['get-state']: print('device')
elif args and args[0]=='shell': print('MemTotal: 4000000 kB')
elif args not in (['kill-server'],['start-server']): raise SystemExit(98)
""")
            executable(sdk / "emulator/emulator", """import json,os,sys
from pathlib import Path
Path(os.environ['TEST_EMULATOR_ARGV']).write_text(json.dumps(sys.argv[1:]))
if sys.argv[1:]!=['-no-window','-version']:
    print('qemu-system-x86_64: error while loading shared libraries: libpulse.so.0',file=sys.stderr)
    raise SystemExit(127)
print('Android emulator version 37.2.12.0 (build_id '+os.environ['TEST_EMULATOR_BUILD']+')')
""")
            environment = dict(os.environ, ANDROID_HOME=str(sdk), ANDROID_AVD_HOME=str(avd.parent),
                               BIL_FROZEN_APP_ROOT=str(app), BIL_ANDROID_EMULATOR_API=api,
                               PATH=str(bin_dir) + os.pathsep + os.environ["PATH"], TEST_ADB_OK="1" if adb_ok else "0",
                               TEST_DEVICE_CONNECTED=str(root / "device-ready"), TEST_EMULATOR_ARGV=str(root / "emulator-argv.json"),
                               TEST_EMULATOR_BUILD=build)
            processes = []
            try:
                yield root, sdk, app, environment, processes
            finally:
                for process in processes:
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass

    def prelaunch(self, environment, processes):
        process = subprocess.Popen(["bash", str(SCRIPT), "prelaunch"], env=environment,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        processes.append(process)
        stdout, stderr = process.communicate(timeout=15)
        return process.returncode, stdout.decode(), stderr.decode()

    def collector_check(self, evidence, phase):
        script = SCRIPT.read_text()
        start = script.index("check_collectors() {")
        end = script.index("\nassert_source() {", start)
        # Exercise the actual guard, not a second implementation of its rules.
        body = script[start:end] + '\ncheck_collectors "$1"\n'
        return subprocess.run(["bash", "-euc", body, "guard", phase],
                              env=dict(os.environ, evidence=str(evidence)), capture_output=True, timeout=5)

    def test_headless_version_and_explicit_sdk_adb_start_both_collectors_for_both_apis(self):
        for api in ("34", "35"):
            with self.subTest(api=api), self.fixture(api=api) as (root, sdk, app, env, processes):
                code, stdout, stderr = self.prelaunch(env, processes)
                self.assertEqual(code, 0, stderr)
                self.assertEqual(json.loads((root / "emulator-argv.json").read_text()), ["-no-window", "-version"])
                evidence = app / "artifacts/release/android_emulator_smoke" / ("api-" + api)
                self.assertIn("Android Debug Bridge", (evidence / "adb-version.txt").read_text())
                self.assertEqual((evidence / "prelaunch-collector-status.txt").read_text().strip(), "COLLECTORS_STARTED_WAITING_FOR_FIRST_DEVICE")
                self.assertEqual(self.collector_check(evidence, "waiting").returncode, 0)
                self.assertNotEqual(self.collector_check(evidence, "connected").returncode, 0)
                Path(env["TEST_DEVICE_CONNECTED"]).touch()
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    checked = self.collector_check(evidence, "connected")
                    if checked.returncode == 0:
                        break
                    time.sleep(0.03)
                self.assertEqual(checked.returncode, 0, checked.stderr)
                self.assertIn("TestBoot", (evidence / "full-boot-logcat.txt").read_text())

    def test_previous_non_headless_probe_reproduces_loader_failure(self):
        with self.fixture() as (root, sdk, app, env, processes):
            result = subprocess.run([str(sdk / "emulator/emulator"), "-version"], env=env, capture_output=True)
            self.assertEqual(result.returncode, 127)
            self.assertIn(b"libpulse.so.0", result.stderr)

    def test_broken_sdk_adb_loader_fails_before_emulator_or_collectors(self):
        with self.fixture(adb_ok=False) as (root, sdk, app, env, processes):
            code, stdout, stderr = self.prelaunch(env, processes)
            self.assertEqual(code, 127)
            self.assertFalse((root / "emulator-argv.json").exists())
            self.assertFalse(list(app.rglob("*-collector.pid")))

    def test_wrong_emulator_build_cannot_start_collectors(self):
        with self.fixture(build="WRONG") as (root, sdk, app, env, processes):
            code, stdout, stderr = self.prelaunch(env, processes)
            self.assertNotEqual(code, 0)
            self.assertFalse(list(app.rglob("*-collector.pid")))

    def test_missing_sdk_adb_never_uses_ambient_path(self):
        with self.fixture() as (root, sdk, app, env, processes):
            (sdk / "platform-tools/adb").unlink()
            code, stdout, stderr = self.prelaunch(env, processes)
            self.assertEqual(code, 127)
            self.assertIn("exact Android SDK ADB", stderr)

    def test_dead_or_mismatched_collector_and_empty_log_block(self):
        with self.fixture() as (root, sdk, app, env, processes):
            self.assertEqual(self.prelaunch(env, processes)[0], 0)
            evidence = app / "artifacts/release/android_emulator_smoke/api-34"
            resource_pid = (evidence / "resource-collector.pid").read_text()
            (evidence / "resource-collector-started.pid").write_text("1\n")
            self.assertNotEqual(self.collector_check(evidence, "waiting").returncode, 0)
            (evidence / "resource-collector-started.pid").write_text(resource_pid)
            for role in ("resource", "boot-logcat"):
                (evidence / (role + "-device-connected.pid")).write_text((evidence / (role + "-collector.pid")).read_text())
            self.assertNotEqual(self.collector_check(evidence, "connected").returncode, 0)
            (evidence / "full-boot-logcat.txt").write_text("boot data\n")
            self.assertEqual(self.collector_check(evidence, "connected").returncode, 0)
            os.kill(int(resource_pid), signal.SIGTERM)
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline and self.collector_check(evidence, "waiting").returncode == 0:
                time.sleep(0.03)
            self.assertNotEqual(self.collector_check(evidence, "waiting").returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
