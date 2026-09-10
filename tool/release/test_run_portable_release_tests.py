"""Portable release scheduling checks; never starts Flutter."""

from __future__ import annotations

import contextlib
import io
import subprocess
from types import SimpleNamespace
import unittest
from unittest import mock

from tool.release import run_portable_release_tests as runner


class PortableReleaseSchedulingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.portable = [
            "test/a_test.dart",
            runner.PERFORMANCE_BUDGET_TEST,
            "test/z_test.dart",
        ]
        self.discovery = (
            sorted([*self.portable, *runner.EXCLUDED_TESTS]),
            self.portable,
        )

    def run_main(self, returncodes: list[int], argv: list[str] | None = None):
        output = io.StringIO()
        results = [subprocess.CompletedProcess([], code) for code in returncodes]
        with (
            mock.patch.object(runner, "discover_tests", return_value=self.discovery),
            mock.patch.object(runner.subprocess, "run", side_effect=results) as run,
            contextlib.redirect_stdout(output),
        ):
            code = runner.main([] if argv is None else argv)
        return code, run.call_args_list, output.getvalue()

    def test_real_inventory_is_partitioned_without_duplicates_or_omissions(self):
        all_tests, portable = runner.discover_tests()
        performance, remaining = runner.partition_tests(portable)
        scheduled = [*performance, *remaining]

        self.assertEqual(len(runner.EXCLUDED_TESTS), 29)
        self.assertEqual(performance, [runner.PERFORMANCE_BUDGET_TEST])
        self.assertEqual(len(scheduled), len(set(scheduled)))
        self.assertCountEqual(scheduled, portable)
        self.assertEqual(set(all_tests) - set(scheduled), runner.EXCLUDED_TESTS)
        self.assertNotIn(runner.PERFORMANCE_BUDGET_TEST, remaining)

    def test_partition_preserves_the_remaining_order(self):
        self.assertEqual(
            runner.partition_tests(self.portable),
            ([runner.PERFORMANCE_BUDGET_TEST], ["test/a_test.dart", "test/z_test.dart"]),
        )

    def test_partition_rejects_missing_performance_or_duplicate_paths(self):
        for paths in (
            [],
            ["test/a_test.dart"],
            [runner.PERFORMANCE_BUDGET_TEST, runner.PERFORMANCE_BUDGET_TEST],
            [*self.portable, "test/a_test.dart"],
        ):
            with self.subTest(paths=paths), self.assertRaises(SystemExit):
                runner.partition_tests(paths)

    def test_command_batches_preserve_every_test_once(self):
        tests = ["test/a_test.dart", "test/b_test.dart", "test/c_test.dart"]
        batches = runner.partition_test_batches(
            ["flutter", "test"],
            tests,
            command_line_limit=48,
        )
        self.assertGreater(len(batches), 1)
        self.assertEqual([path for batch in batches for path in batch], tests)

    def test_performance_runs_serial_first_then_every_other_file_once(self):
        code, calls, output = self.run_main([0, 0])
        prefix = [
            runner.resolve_flutter_executable(),
            "test",
            "--no-pub",
            "--timeout",
            "30s",
        ]
        self.assertEqual(code, 0)
        self.assertEqual(
            calls,
            [
                mock.call(
                    [*prefix, "--concurrency", "1", runner.PERFORMANCE_BUDGET_TEST],
                    cwd=runner.REPOSITORY_ROOT,
                    check=False,
                ),
                mock.call(
                    [*prefix, "test/a_test.dart", "test/z_test.dart"],
                    cwd=runner.REPOSITORY_ROOT,
                    check=False,
                ),
            ],
        )
        self.assertIn("PORTABLE_RELEASE_SCHEDULED_TEST_FILES=3\n", output)
        self.assertIn("PORTABLE_RELEASE_PERFORMANCE_SCHEDULED_TEST_FILES=1\n", output)
        self.assertIn("PORTABLE_RELEASE_REMAINING_SCHEDULED_TEST_FILES=2\n", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=3\n"))

    def test_performance_failure_stops_without_retry_or_remaining_tests(self):
        code, calls, output = self.run_main([7])
        self.assertEqual(code, 7)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertNotIn("PORTABLE_RELEASE_PHASE=remaining_portable", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=1\n"))

    def test_remaining_failure_is_preserved_without_retry(self):
        code, calls, output = self.run_main([0, 9])
        self.assertEqual(code, 9)
        self.assertEqual(len(calls), 2)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=3\n"))

    def test_list_only_reports_schedule_without_invoking_flutter(self):
        code, calls, output = self.run_main([], ["--list-only"])
        self.assertEqual(code, 0)
        self.assertEqual(calls, [])
        self.assertIn("PORTABLE_RELEASE_SCHEDULED_TEST_FILES=3\n", output)
        self.assertNotIn("PORTABLE_RELEASE_PHASE=", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=0\n"))

    def test_performance_only_never_starts_an_empty_flutter_invocation(self):
        self.discovery = (self.discovery[0], [runner.PERFORMANCE_BUDGET_TEST])
        code, calls, output = self.run_main([0])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1)
        self.assertIn("PORTABLE_RELEASE_REMAINING_SCHEDULED_TEST_FILES=0\n", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=1\n"))

    def test_code_only_preserves_default_suite_and_uses_reviewed_policy(self):
        policy = runner.load_code_only_policy()
        policy.discover()
        _, portable = runner.discover_tests()
        selected = set(portable) - set(policy.NOT_RUN)
        self.assertNotIn("test/release_metadata_test.dart", selected)
        self.assertIn("test/release_metadata_test.dart", portable)
        self.assertIn("test/premium_splash_experience_test.dart", policy.MIXED_NAMES)
        self.assertIn(runner.PERFORMANCE_BUDGET_TEST, selected)

    def test_code_only_real_policy_keeps_every_invocation_serial(self):
        code, calls, output = self.run_main([0, 0], ["--code-only"])
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)
        for call in calls:
            command = call.args[0]
            self.assertEqual(command.count("--concurrency"), 1)
            self.assertEqual(command[command.index("--concurrency") + 1], "1")
            self.assertFalse(command[0].endswith(".bat"))
            self.assertTrue(command[1].endswith("flutter_tools.snapshot"))
            self.assertIn("--dart-define=BIL_CAPTURE_COMMUNITY_REVIEW=false", command)
            self.assertIn("--dart-define=BIL_CAPTURE_HEALTH_REVIEW=false", command)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertEqual(calls[1].args[0][-2:], ["test/a_test.dart", "test/z_test.dart"])
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=3\n"))

    def test_code_only_real_policy_preserves_performance_failure(self):
        code, calls, output = self.run_main([7], ["--code-only"])
        self.assertEqual(code, 7)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertNotIn("PORTABLE_RELEASE_PHASE=remaining_portable", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=1\n"))

    def test_code_only_mixed_files_are_filtered_and_never_use_batch_shell(self):
        policy = SimpleNamespace(
            discover=mock.Mock(), NOT_RUN={"test/z_test.dart": "image data"},
            MIXED_NAMES={"test/a_test.dart": "^(?!visual).*$"},
            flutter_test_command=lambda _: ["native-dart", "snapshot", "test", "--concurrency", "1"],
        )
        with mock.patch.object(runner, "load_code_only_policy", return_value=policy):
            code, calls, output = self.run_main([0, 0], ["--code-only"])
        self.assertEqual(code, 0)
        policy.discover.assert_called_once_with()
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0].args[0][-1], runner.PERFORMANCE_BUDGET_TEST)
        self.assertEqual(calls[1].args[0][-3:], ["test/a_test.dart", "--name", "^(?!visual).*$"])
        self.assertTrue(all(call.args[0][0] == "native-dart" for call in calls))
        self.assertTrue(all("test/z_test.dart" not in call.args[0] for call in calls))
        self.assertIn("PORTABLE_RELEASE_NOT_RUN=test/z_test.dart", output)
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=2\n"))

    def test_code_only_mixed_failure_is_not_converted_to_success(self):
        policy = SimpleNamespace(
            discover=mock.Mock(), NOT_RUN={},
            MIXED_NAMES={"test/a_test.dart": "^logic$", "test/z_test.dart": "^other$"},
            flutter_test_command=lambda _: ["native-dart", "snapshot", "test"],
        )
        with mock.patch.object(runner, "load_code_only_policy", return_value=policy):
            code, calls, _ = self.run_main([0, 9], ["--code-only"])
        self.assertEqual(code, 9)
        self.assertEqual(len(calls), 2)

    def test_code_only_list_does_not_start_flutter(self):
        policy = SimpleNamespace(discover=mock.Mock(), NOT_RUN={}, MIXED_NAMES={})
        with mock.patch.object(runner, "load_code_only_policy", return_value=policy):
            code, calls, output = self.run_main([], ["--code-only", "--list-only"])
        self.assertEqual((code, calls), (0, []))
        self.assertTrue(output.endswith("PORTABLE_RELEASE_EXECUTED_TEST_FILES=0\n"))


if __name__ == "__main__":
    unittest.main()
