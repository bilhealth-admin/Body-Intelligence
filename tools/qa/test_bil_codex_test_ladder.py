"""Regression checks for local gate integrity; no Flutter or network calls."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import bil_codex_test_ladder as ladder


class LadderGateTests(unittest.TestCase):
    def test_full_queues_eight_shards_with_single_test_worker(self):
        with patch.object(ladder, "run_command", return_value={"exit_code": 0}) as command:
            result = ladder.run_stage("full", 2)
        self.assertTrue(result["passed"])
        self.assertEqual(len(result["jobs"]), 8)
        commands = [call.args[1] for call in command.call_args_list]
        self.assertTrue(all("--concurrency=1" in args for args in commands))
        self.assertEqual({args[-1] for args in commands},
                         {"--shard-index=" + str(i) for i in range(8)})
        self.assertTrue(all("--total-shards=8" in args for args in commands))

    def test_full_rejects_more_than_two_shards_before_launch(self):
        with patch.object(ladder, "run_command") as command:
            with self.assertRaises(ValueError):
                ladder.run_stage("full", 3)
        command.assert_not_called()

    def test_arabic_gate_requires_v2_matrix_and_interactions(self):
        with patch.object(ladder, "run_suites", return_value={"passed": False}) as suites:
            self.assertFalse(ladder.run_stage("arabic", 8)["passed"])
        stage, jobs, parallel, _ = suites.call_args.args
        self.assertEqual(stage, "arabic")
        self.assertEqual(parallel, 1)
        self.assertIn("test/features/nutrition/meal_vision_v2_matrix_test.dart", jobs[1][1])
        self.assertIn("test/features/nutrition/meal_vision_v2_interaction_test.dart", jobs[1][1])
        self.assertIn("test/features/nutrition/meal_vision_reference_capture_test.dart", jobs[1][1])

    def test_fingerprint_excludes_diagnostics_but_tracks_real_baselines(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            def git(*args):
                return subprocess.run(["git", *args], cwd=root, check=True,
                                      capture_output=True).stdout.decode().strip()
            git("init")
            diagnostic = root / "test/screen/failures/example_testImage.png"
            golden = root / "test/screen/goldens/example.png"
            for file in (diagnostic, golden):
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(b"initial")
            git("add", ".")
            git("-c", "core.hooksPath=NUL", "-c", "user.name=QA",
                "-c", "user.email=qa@example.invalid", "commit", "-m", "fixture")
            head = git("rev-parse", "HEAD")
            with patch.object(ladder, "ROOT", root), patch.object(ladder, "BASE", "HEAD"):
                stamp = ladder.fingerprint(head)
                diagnostic.write_bytes(b"generated diff")
                self.assertEqual(ladder.fingerprint(head), stamp)
                golden.write_bytes(b"changed baseline")
                self.assertNotEqual(ladder.fingerprint(head), stamp)

    def test_format_batches_cover_complete_scope_before_analysis(self):
        targets = [f"test/file_{i}.dart" for i in range(182)]
        with patch.object(ladder, "changed_dart_targets", return_value=targets), \
                patch.object(ladder, "run_command", return_value={"exit_code": 0}) as command:
            self.assertTrue(ladder.run_source()["passed"])
        commands = [call.args[1] for call in command.call_args_list]
        self.assertEqual([file for args in commands[:-1] for file in args[4:]], targets)
        self.assertTrue(all(len(args[4:]) <= 40 for args in commands[:-1]))
        self.assertEqual(commands[-1], ["flutter", "analyze", "--no-pub"])

    def test_windows_launcher_is_resolved_without_shell(self):
        with patch.object(ladder.shutil, "which", return_value=r"G:\SDK\flutter.bat"):
            self.assertEqual(ladder.executable_args(["flutter", "test"]),
                             [r"G:\SDK\flutter.bat", "test"])

    def test_missing_comparison_ref_cannot_reduce_format_scope(self):
        with patch.object(ladder, "git", side_effect=subprocess.CalledProcessError(128, "git")):
            with self.assertRaises(subprocess.CalledProcessError):
                ladder.changed_dart_targets()

    def test_retry_runs_only_red_suite_without_losing_failure(self):
        green = {"exit_code": 0, "log": "green.log"}
        previous = {"jobs": {"p0-green": green,
                             "p0-red": {"exit_code": 1, "log": "old-red.log"}}}
        with patch.object(ladder, "run_command", return_value=
                          {"exit_code": 0, "log": "retry.log"}) as command:
            result = ladder.run_suites("p0", [("green", "green.dart"),
                                              ("red", "red.dart")], 1, previous)
        command.assert_called_once_with("p0-red", ["flutter", "test", "--no-pub",
                                                   "--timeout=3m", "red.dart"])
        self.assertTrue(result["passed"])
        self.assertEqual(result["jobs"]["p0-green"], green)
        self.assertEqual(previous["jobs"]["p0-red"]["log"], "old-red.log")

    def run_gate(self, output, argv, *, stamps, passed):
        def fake_git(*args, **kwargs):
            value = ladder.BRANCH if args[0] == "branch" else "head"
            return subprocess.CompletedProcess(args, 0, value.encode(), b"")

        with patch.object(ladder, "OUT", output), \
                patch.object(ladder, "git", side_effect=fake_git), \
                patch.object(ladder.shutil, "which", return_value="launcher"), \
                patch.object(ladder.subprocess, "run", return_value=
                             subprocess.CompletedProcess([], 0, "Flutter 3.44.6", "")), \
                patch.object(ladder, "run_command", return_value={"exit_code": 0}), \
                patch.object(ladder, "fingerprint", side_effect=stamps), \
                patch.object(ladder, "run_stage", return_value={"passed": passed}) as stage, \
                patch.object(ladder.sys, "argv", ["ladder", *argv]):
            result = ladder.main()
        return result, stage

    def seed_green(self, output):
        (output / "manifest.json").write_text(json.dumps({
            "head": "head", "worktree_sha256": "stamp",
            "stages": {name: {"passed": True} for name in ladder.STAGES},
        }), encoding="utf-8")

    def test_changed_worktree_discards_success_before_saving(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            result, _ = self.run_gate(output, ["--through-stage", "source"],
                                      stamps=["stamp", "changed"], passed=True)
            self.assertEqual(result, 2)
            self.assertEqual(json.loads((output / "manifest.json").read_text())["stages"], {})

    def test_forced_red_prerequisite_invalidates_downstream_green(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            self.seed_green(output)
            result, _ = self.run_gate(output, ["--through-stage", "source", "--force"],
                                      stamps=["stamp", "stamp"], passed=False)
            self.assertEqual(result, 1)
            stages = json.loads((output / "manifest.json").read_text())["stages"]
            self.assertEqual(stages, {"source": {"passed": False}})

    def test_full_requires_every_earlier_gate_on_current_fingerprint(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            with self.assertRaises(SystemExit) as error:
                self.run_gate(output, ["--from-stage", "full", "--through-stage", "full"],
                              stamps=["stamp"], passed=True)
            self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
