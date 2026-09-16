"""Offline scheduling tests. These never launch Flutter or a cloud call."""
from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest import mock

from tool.release import run_full_validation_batches as runner


class FullValidationSchedulingTest(unittest.TestCase):
    def test_child_output_is_visible_before_exit_and_retained_in_log(self):
        visible = threading.Event()

        class Terminal(io.StringIO):
            def write(self, text):
                result = super().write(text)
                if "live test output" in text:
                    visible.set()
                return result

        def start(command, cwd, stdout, stderr):
            stdout.write(b"live test output\n")
            stdout.flush()
            child = mock.Mock(pid=123)

            def wait(timeout):
                self.assertTrue(visible.wait(5), "output was hidden until exit")
                return 0

            child.wait.side_effect = wait
            return child

        with tempfile.TemporaryDirectory(prefix="bil-validation-output-") as folder:
            path = Path(folder) / "visible.log"
            terminal = Terminal()
            with mock.patch.object(runner.subprocess, "Popen", side_effect=start), \
                    contextlib.redirect_stdout(terminal):
                result = runner.run(["fake-test"], path, 10)
            self.assertEqual(result["status"], "PASS")
            self.assertEqual(path.read_text(), "live test output\n")
            self.assertIn("live test output", terminal.getvalue())

    def test_discovery_partitions_every_flutter_file_once(self):
        files = sorted(p.relative_to(runner.ROOT).as_posix()
                       for p in (runner.ROOT / "test").rglob("*_test.dart"))
        batches = runner.groups(files)
        self.assertEqual(len(batches), 10)
        self.assertTrue(all(batches))
        scheduled = [name for batch in batches for name in batch]
        self.assertCountEqual(scheduled, files)
        self.assertEqual(len(scheduled), len(set(scheduled)))
        self.assertIn("test/epic15_store_screenshot_golden_test.dart", batches[0])

    def test_long_commands_and_performance_isolation_never_drop_files(self):
        base = ["dart", "snapshot", "test", "--no-pub"]
        files = [f"test/{'long_' * 40}{i}_test.dart" for i in range(200)]
        files.insert(88, "test/performance_budget_test.dart")
        commands = runner.command_parts(base, files)
        self.assertGreater(len(commands), 2)
        self.assertEqual([name for cmd in commands for name in cmd[len(base):]], files)
        self.assertIn([*base, "test/performance_budget_test.dart"], commands)
        self.assertTrue(all(len(runner.subprocess.list2cmdline(cmd)) <= 24000
                            for cmd in commands))

    def test_all_local_auxiliary_suites_are_explicit_and_network_is_not_granted(self):
        suites = dict(runner.auxiliary_commands("deno", "node"))
        self.assertEqual(set(suites), {"release_python", "backend_deno",
                                       "postgres_local", "release_node"})
        deno = suites["backend_deno"]
        self.assertIn("--frozen", deno)
        self.assertIn("--no-prompt", deno)
        self.assertNotIn("--no-check", deno)
        self.assertNotIn("--allow-net", deno)
        self.assertEqual(sorted(name for name in deno if name.endswith("_test.ts")),
                         sorted(p.relative_to(runner.ROOT).as_posix()
                                for p in (runner.ROOT / "supabase/functions").rglob("*_test.ts")))
        self.assertIn("supabase/tests/store_refund_retry_execution_test.mjs",
                      suites["postgres_local"])

    def execute(self, codes):
        temporary = tempfile.TemporaryDirectory(prefix="bil-validation-unit-")
        self.addCleanup(temporary.cleanup)
        evidence = Path(temporary.name) / "run"
        evidence.mkdir()
        batches = [["test/a_test.dart", "test/performance_budget_test.dart",
                    "test/b_test.dart"], ["test/c_test.dart"]]
        calls = []
        outcomes = iter(codes)

        def fake_run(command, path, timeout):
            calls.append((command, path.name))
            code = next(outcomes)
            return {"status": "PASS" if code == 0 else "FAIL", "exit_code": code}

        output = io.StringIO()
        with mock.patch.object(runner, "run", side_effect=fake_run), \
                contextlib.redirect_stdout(output):
            result = runner.pipeline(evidence, ["dart", "snapshot"], batches,
                                     60, [("local_aux", ["node", "local_test.mjs"])])
        summary = json.loads((evidence / "summary.json").read_text())
        latest = json.loads((evidence.parent / "latest_full_validation.json").read_text())
        self.assertEqual(latest["status"], summary["status"])
        self.last_output = output.getvalue()
        self.assertIn(f"VALIDATION_STATUS={summary['status']}", self.last_output)
        return result, calls, summary

    def test_success_runs_all_groups_serially(self):
        code, calls, summary = self.execute([0, 0, 0, 0, 0, 0])
        self.assertEqual(code, 0)
        self.assertEqual(summary["status"], "HOST_SUITE_PASS")
        self.assertEqual([call[1] for call in calls], [
            "analysis.log", "batch_01_local_aux.log", "batch_01_flutter_01.log",
            "batch_01_flutter_02.log", "batch_01_flutter_03.log", "batch_02_flutter_01.log"])

    def test_failing_auxiliary_still_finishes_current_group_but_not_next(self):
        code, calls, summary = self.execute([0, 1, 0, 0, 0])
        self.assertEqual(code, 1)
        self.assertEqual(summary["status"], "STOPPED_AT_BATCH_1")
        self.assertEqual(len(summary["batches"]), 1)
        self.assertEqual(len(calls), 5)
        self.assertTrue(calls[-1][1].endswith("flutter_03.log"))
        self.assertIn("BATCH 1/2 FAIL (all command results):", self.last_output)
        self.assertIn("local_aux: FAIL", self.last_output)
        self.assertIn("flutter_03: PASS", self.last_output)
        self.assertNotIn("BATCH 2/2 START", self.last_output)

    def test_failing_flutter_part_does_not_skip_rest_of_its_group(self):
        code, calls, summary = self.execute([0, 0, 1, 0, 0])
        self.assertEqual(code, 1)
        self.assertEqual(summary["status"], "STOPPED_AT_BATCH_1")
        self.assertEqual(len(calls), 5)
        self.assertEqual(summary["batches"][0]["results"][-1]["status"], "PASS")

    def test_analysis_failure_starts_no_test(self):
        code, calls, summary = self.execute([1])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 1)
        self.assertEqual(summary["status"], "STOPPED_AT_ANALYSIS")
        self.assertEqual(summary["batches"], [])

    def test_next_invocation_restarts_analysis_and_first_group(self):
        self.execute([0, 0, 1, 0, 0])
        _, calls, summary = self.execute([0, 0, 0, 0, 0, 0])
        self.assertEqual(calls[0][1], "analysis.log")
        self.assertEqual(calls[1][1], "batch_01_local_aux.log")
        self.assertEqual(summary["status"], "HOST_SUITE_PASS")
        for command, _ in calls:
            self.assertNotIn("--update-goldens", command)
            self.assertNotIn("--fail-fast", command)
            self.assertNotIn("--plain-name", command)

    def test_lock_rejects_concurrent_run_and_releases_after_exit(self):
        with tempfile.TemporaryDirectory(prefix="bil-validation-lock-") as folder:
            path = Path(folder) / "lock"
            with runner.exclusive_run(path):
                with self.assertRaisesRegex(RuntimeError, "already owns"):
                    with runner.exclusive_run(path):
                        self.fail("second runner entered")
            with runner.exclusive_run(path):
                pass


if __name__ == "__main__":
    unittest.main()
