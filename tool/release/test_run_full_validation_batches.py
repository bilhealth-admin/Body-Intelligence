from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from run_full_validation_batches import (
    PURCHASE_REVIEW_DEFINES,
    command_parts,
    groups,
    pipeline,
)


class FullValidationCommandPartsTest(unittest.TestCase):
    def test_purchase_confirmation_uses_isolated_review_configuration(self) -> None:
        base = ["dart", "flutter_tools.snapshot", "test", "--no-pub"]
        ordinary_before = "test/app_foundation_services_test.dart"
        purchase = "test/features/commerce/app_purchase_confirmation_test.dart"
        subscription = "test/features/commerce/app_subscription_confirmation_test.dart"
        ordinary_after = "test/app_router_invalid_route_test.dart"

        parts = command_parts(
            base,
            [ordinary_before, purchase, subscription, ordinary_after],
        )

        configured = [
            part for part in parts
            if "--dart-define=BIL_PAYMENTS_ENABLED=true" in part
        ]
        self.assertEqual(len(configured), 1)
        self.assertEqual(configured[0][-2:], [purchase, subscription])
        for define in PURCHASE_REVIEW_DEFINES:
            self.assertIn(define, configured[0])
        self.assertTrue(all(ordinary_before not in part for part in configured))
        self.assertTrue(all(ordinary_after not in part for part in configured))
        self.assertTrue(
            all("--dart-define=BIL_PAYMENTS_ENABLED=true" not in part
                for part in parts if part not in configured)
        )

    def test_full_inventory_is_kept_in_one_pass(self) -> None:
        files = ["test/first_test.dart", "test/last_test.dart"]
        self.assertEqual(groups(files), [files])

    def test_full_pass_continues_after_a_failed_test_command(self) -> None:
        commands: list[list[str]] = []

        def fake_run(command: list[str], path: Path, timeout: int) -> dict:
            commands.append(command)
            failed = "first_test.dart" in command
            return {
                "status": "FAIL" if failed else "PASS",
                "exit_code": 1 if failed else 0,
                "log": str(path),
            }

        with tempfile.TemporaryDirectory() as directory:
            evidence = Path(directory) / "run"
            evidence.mkdir()
            with patch("run_full_validation_batches.run", side_effect=fake_run):
                with contextlib.redirect_stdout(io.StringIO()):
                    exit_code = pipeline(
                        evidence,
                        ["flutter"],
                        [["first_test.dart"], ["last_test.dart"]],
                        timeout=1,
                        auxiliary=[],
                    )

            summary = json.loads((evidence / "summary.json").read_text())

        self.assertEqual(exit_code, 1)
        self.assertEqual(summary["status"], "HOST_SUITE_FAIL")
        self.assertEqual([group["status"] for group in summary["batches"]], ["FAIL", "PASS"])
        self.assertEqual(len(commands), 3)
        self.assertEqual(summary["failed_commands"][0]["batch"], 1)


if __name__ == "__main__":
    unittest.main()
