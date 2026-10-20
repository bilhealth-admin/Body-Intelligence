#!/usr/bin/env python3
"""Offline safety controls for temporary-function identity and process cleanup."""
import importlib.util
from pathlib import Path
import sys
import unittest

spec = importlib.util.spec_from_file_location("readiness_lifecycle", Path(__file__).with_name("lifecycle.py"))
lifecycle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lifecycle)


class IdentitySafety(unittest.TestCase):
    def setUp(self):
        self.original = {"slug": "app-attest", "id": "029befba-e782-4e28-a9c9-0269d39d1113", "version": 54}
        self.temporary = {"slug": "bil-readiness-fixture", "id": "00000000-0000-4000-8000-000000000001", "version": 1}
        self.before = [self.original]

    def test_exact_new_identity_is_the_only_cleanup_candidate(self):
        self.assertEqual(lifecycle.deletion_target(self.before, [self.original, self.temporary], self.temporary["slug"], self.temporary), self.temporary)

    def test_original_uuid_cannot_be_deleted_even_under_temporary_slug(self):
        renamed_original = {**self.temporary, "id": self.original["id"]}
        with self.assertRaisesRegex(lifecycle.Blocked, "original_identity"):
            lifecycle.deletion_target(self.before, [renamed_original], self.temporary["slug"])

    def test_changed_uuid_or_version_is_never_deleted(self):
        for changed in ({**self.temporary, "version": 2}, {**self.temporary, "id": "00000000-0000-4000-8000-000000000002"}):
            with self.subTest(changed=changed), self.assertRaisesRegex(lifecycle.Blocked, "identity_or_version_changed"):
                lifecycle.deletion_target(self.before, [changed], self.temporary["slug"], self.temporary)

    def test_absence_does_not_select_another_function(self):
        self.assertIsNone(lifecycle.deletion_target(self.before, self.before, self.temporary["slug"], self.temporary))

    def test_duplicate_slug_cannot_be_selected_for_cleanup(self):
        with self.assertRaisesRegex(lifecycle.Blocked, "duplicate_slug"):
            lifecycle.deletion_target(self.before, [self.temporary, self.temporary], self.temporary["slug"])

    def test_inventory_accepts_only_valid_unique_identities(self):
        self.assertEqual(lifecycle.inventory_rows({"functions": self.before}), self.before)
        for invalid in (None, {}, [None], [{**self.original, "id": "-" * 36}], [{**self.original, "version": True}], [{**self.original, "version": 0}], [self.original, self.original]):
            with self.subTest(invalid=invalid), self.assertRaises(lifecycle.Blocked):
                lifecycle.inventory_rows(invalid)

    def test_original_version_change_cannot_match_cleanup_receipt(self):
        changed = [{**self.original, "version": 55}]
        self.assertNotEqual(lifecycle.signatures(self.before), lifecycle.signatures(changed))

    def test_bounded_cli_timeout_is_an_explicit_blocked_result(self):
        with self.assertRaisesRegex(lifecycle.Blocked, "cli_process_group_timed_out"):
            lifecycle.bounded_cli([sys.executable, "-c", "import time; time.sleep(30)"], 0.05)


if __name__ == "__main__":
    unittest.main()
