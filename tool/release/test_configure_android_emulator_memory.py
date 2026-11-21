"""Exercise owned AVD rewrites and reject the observed broken guest contract."""
import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import configure_android_emulator_memory as memory


class AndroidEmulatorMemoryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "test.avd" / "config.ini"
        self.config.parent.mkdir()

    def fake_runtime(self, **overrides):
        outputs = {
            "ro.build.version.sdk": "29\n", "dalvik.vm.heapsize": "256m\n",
            "dalvik.vm.heapgrowthlimit": "128m\n",
            "/proc/meminfo": "MemTotal:        2015000 kB\nMemFree: 12345 kB\n",
        }
        outputs.update(overrides)
        calls = []

        def run(argv, **kwargs):
            calls.append((argv, kwargs))
            return subprocess.CompletedProcess(argv, 0, outputs[argv[-1]], "")

        return run, calls

    def test_replaces_observed_16_mib_and_preserves_unrelated_crlf_lines(self):
        self.config.write_bytes(
            b"hw.cpu.ncore=2\r\nvm.heapSize=16\r\nhw.ramSize=1536\r\n"
            b"hw.lcd.width=1080\r\nhw.lcd.height=1920\r\n")
        result = memory.configure_memory(29, self.config)
        self.assertEqual(self.config.read_bytes(),
                         b"hw.cpu.ncore=2\r\nvm.heapSize=256\r\nhw.ramSize=2048\r\n"
                         b"hw.lcd.width=1080\r\nhw.lcd.height=1920\r\n")
        self.assertTrue(result["changed"])
        self.assertEqual(result["original_memory_lines"]["vm.heapSize"], "vm.heapSize=16")
        self.assertNotIn(b"hw.heapSize=", self.config.read_bytes())

    def test_already_configured_is_byte_identical(self):
        self.config.write_bytes(b"vm.heapSize=256\nhw.ramSize=2048\ncustom=value\n")
        before = self.config.read_bytes()
        self.assertFalse(memory.configure_memory(29, self.config)["changed"])
        self.assertEqual(self.config.read_bytes(), before)

    def test_missing_properties_added_after_unterminated_line(self):
        self.config.write_bytes(b"custom=value")
        memory.configure_memory(29, self.config)
        self.assertEqual(self.config.read_bytes(),
                         b"custom=value\nhw.ramSize=2048\nvm.heapSize=256\n")

    def test_conflicting_duplicate_is_refused_before_any_write(self):
        before = b"vm.heapSize=16\nvm.heapSize=256\nhw.ramSize=1536\n"
        self.config.write_bytes(before)
        with self.assertRaisesRegex(memory.MemoryContractError, "Ambiguous"):
            memory.configure_memory(29, self.config)
        self.assertEqual(self.config.read_bytes(), before)

    def test_unchanged_apis_never_read_a_path_or_call_adb(self):
        for api in (26, 33, 34, 35, 36):
            with self.subTest(api=api), mock.patch.object(
                    Path, "read_bytes", side_effect=AssertionError("unexpected read")):
                self.assertEqual(memory.configure_memory(api, self.config)["status"],
                                 "UNCHANGED_API")
                self.assertEqual(memory.verify_runtime_memory(
                    api, run=mock.Mock(side_effect=AssertionError("unexpected ADB"))
                )["status"], "UNCHANGED_API")

    def test_unsupported_api_and_symbolic_config_are_refused(self):
        with self.assertRaisesRegex(memory.MemoryContractError, "Unsupported"):
            memory.configure_memory(28, self.config)
        with mock.patch.object(Path, "is_symlink", return_value=True):
            with self.assertRaisesRegex(memory.MemoryContractError, "symbolic"):
                memory.configure_memory(29, self.config)

    def test_runtime_good_uses_only_four_bounded_readonly_commands(self):
        run, calls = self.fake_runtime()
        receipt = memory.verify_runtime_memory(29, run=run)
        self.assertEqual(receipt["status"], "MATCHED")
        self.assertEqual(len(calls), 4)
        for argv, kwargs in calls:
            self.assertEqual(argv[:2], ["adb", "shell"])
            self.assertIn(argv[2], ("getprop", "cat"))
            self.assertEqual(kwargs["timeout"], 8)
            self.assertFalse(kwargs["check"])

    def test_actual_failed_heap_value_and_low_growth_are_rejected(self):
        for overrides in ({"dalvik.vm.heapsize": "16m"},
                          {"dalvik.vm.heapgrowthlimit": "16m"}):
            with self.subTest(overrides=overrides):
                run, calls = self.fake_runtime(**overrides)
                with self.assertRaises(memory.MemoryContractError):
                    memory.verify_runtime_memory(29, run=run)
                self.assertEqual(len(calls), 4)

    def test_wrong_sdk_or_ram_and_ambiguous_memtotal_are_rejected(self):
        for overrides in ({"ro.build.version.sdk": "26"},
                          {"/proc/meminfo": "MemTotal: 512000 kB"},
                          {"/proc/meminfo": "MemTotal: 2015000 kB\nMemTotal: 2015000 kB"}):
            with self.subTest(overrides=overrides):
                run, _ = self.fake_runtime(**overrides)
                with self.assertRaises(memory.MemoryContractError):
                    memory.verify_runtime_memory(29, run=run)

    def test_readback_failure_has_no_fallback_or_retry(self):
        run = mock.Mock(return_value=subprocess.CompletedProcess(
            ["adb"], 1, "", "transport unavailable"))
        with self.assertRaisesRegex(memory.MemoryContractError, "command failed"):
            memory.verify_runtime_memory(29, run=run)
        self.assertEqual(run.call_count, 1)

    def test_timeout_has_no_fallback_or_retry(self):
        run = mock.Mock(side_effect=subprocess.TimeoutExpired(["adb"], 8))
        with self.assertRaisesRegex(memory.MemoryContractError, "timed out"):
            memory.verify_runtime_memory(29, run=run)
        self.assertEqual(run.call_count, 1)

    def test_cli_preserves_failure_receipt_and_never_claims_app_start(self):
        self.config.write_bytes(b"vm.heapSize=16\nvm.heapSize=256\n")
        evidence = self.root / "evidence"
        with contextlib.redirect_stdout(io.StringIO()):
            code = memory.main(["configure", "--api-level", "29",
                                "--config", str(self.config),
                                "--evidence-dir", str(evidence)])
        import json
        receipt = json.loads((evidence / "avd-memory-config.json").read_text())
        self.assertEqual(code, 5)
        self.assertEqual(receipt["status"], "FAILED")
        self.assertFalse(receipt["app_startup_proven"])

    def test_actual_workflow_configures_memory_before_emulator_launch(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github/workflows/bil_android_isolated_emulator_smoke.yml").read_text()
        hook = workflow.split("          pre-emulator-launch-script: |\n", 1)[1].split(
            "          script:", 1)[0]
        self.assertIn("configure_android_emulator_memory.py configure --api-level ${{ matrix.api-level }}", hook)
        self.assertLess(hook.index("configure_android_emulator_memory.py"),
                        hook.index("adb kill-server"))
        self.assertIn("'test_configure_android_emulator_memory.py'", workflow)
        self.assertNotIn("          heap-size:", workflow)

    def test_runtime_readback_is_after_os_gate_and_before_fresh_install(self):
        root = Path(__file__).resolve().parents[2]
        script = (root / "tool/release/run_android_emulator_smoke.sh").read_text()
        self.assertLess(script.index("--verify-emulator-before-launch"),
                        script.index("configure_android_emulator_memory.py verify-runtime"))
        self.assertLess(script.index("configure_android_emulator_memory.py verify-runtime"),
                        script.index("stage='verify-fresh-app-install'"))
        self.assertLess(script.index("stage='verify-fresh-app-install'"),
                        script.index('adb install "$apk"'))


if __name__ == "__main__":
    unittest.main()
