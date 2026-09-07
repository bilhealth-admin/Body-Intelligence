"""Portable release scheduling checks; never starts Flutter."""

from __future__ import annotations

import contextlib
import io
import subprocess
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


if __name__ == "__main__":
    unittest.main()
