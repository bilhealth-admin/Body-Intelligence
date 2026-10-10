"""Regression checks for local gate integrity; no Flutter or network calls."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import bil_codex_test_ladder as ladder


class LadderGateTests(unittest.TestCase):
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
