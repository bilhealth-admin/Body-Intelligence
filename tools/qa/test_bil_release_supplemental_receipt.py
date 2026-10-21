"""Pure evidence-envelope checks; never run an audit or query a service."""
from copy import deepcopy
from pathlib import Path
import re
import unittest

import bil_release_supplemental_receipt as receipt


class SupplementalReceiptTests(unittest.TestCase):
    def values(self):
        reports = {name: {"packages_checked": 2, "findings": []}
                   for name in receipt.OSV_REPORTS}
        reports["cloudflare-npm-audit.json"] = {"metadata": {"vulnerabilities": {"total": 0}}}
        reports["repository_inventory.json"] = {
            "secret_candidates": [], "conflict_candidates": [], "syntax_errors": [],
        }
        return dict(source_sha="a" * 40, current_sha="a" * 40, prior_status="success",
                    outcomes={name: {"outcome": "success"} for name in receipt.REQUIRED_STEPS},
                    available=set(receipt.REQUIRED_LOGS), reports=reports)

    def test_all_success_on_exact_source_is_bounded_source_pass_only(self):
        result = receipt.final_receipt(**self.values())
        self.assertEqual(result["status"], "PASS")
        self.assertIn("signed artifacts or store readiness", result["not_proved"])

    def test_other_source_or_prior_failure_cannot_pass(self):
        for changes in ({"current_sha": "b" * 40}, {"source_sha": "short"},
                        {"prior_status": "failure"}, {"prior_status": "cancelled"}):
            with self.subTest(changes=changes):
                values = self.values(); values.update(changes)
                self.assertEqual(receipt.final_receipt(**values)["status"], "FAIL")

    def test_every_required_step_must_have_success_outcome(self):
        for name in receipt.REQUIRED_STEPS:
            for outcome in (None, "skipped", "failure", "cancelled"):
                with self.subTest(step=name, outcome=outcome):
                    values = self.values()
                    values["outcomes"][name] = {"outcome": outcome}
                    self.assertEqual(receipt.final_receipt(**values)["status"], "FAIL")

    def test_any_missing_or_empty_log_prevents_pass(self):
        for name in receipt.REQUIRED_LOGS:
            with self.subTest(missing=name):
                values = self.values(); values["available"].remove(name)
                result = receipt.final_receipt(**values)
                self.assertEqual(result["status"], "FAIL")
                self.assertIn(name, result["missing_evidence"])

    def test_empty_incomplete_or_flagged_osv_report_prevents_pass(self):
        for name in receipt.OSV_REPORTS:
            for data in ({}, {"packages_checked": 0, "findings": []},
                         {"packages_checked": True, "findings": []},
                         {"packages_checked": 1, "findings": [{"id": "fixture"}]}):
                with self.subTest(report=name, data=data):
                    values = self.values(); values["reports"][name] = data
                    self.assertEqual(receipt.final_receipt(**values)["status"], "FAIL")

    def test_npm_missing_metadata_or_findings_cannot_pass(self):
        for data in ({}, {"metadata": None}, {"metadata": {"vulnerabilities": []}},
                     {"metadata": {"vulnerabilities": {"total": False}}},
                     {"metadata": {"vulnerabilities": {"total": 1}}}):
            values = self.values(); values["reports"]["cloudflare-npm-audit.json"] = data
            self.assertEqual(receipt.final_receipt(**values)["status"], "FAIL")

    def test_repository_candidates_are_never_silently_dismissed(self):
        for key in ("secret_candidates", "conflict_candidates", "syntax_errors"):
            values = self.values()
            values["reports"]["repository_inventory.json"][key] = [{"path": "fixture"}]
            self.assertEqual(receipt.final_receipt(**values)["status"], "FAIL")
        values = self.values(); values["reports"]["repository_inventory.json"] = {}
        self.assertEqual(receipt.final_receipt(**values)["status"], "FAIL")

    def test_receipt_does_not_copy_report_payloads_or_credential_strings(self):
        values = self.values()
        values["outcomes"]["toolchain"]["outputs"] = {"secret": "private-fixture-only"}
        values["reports"]["pub-osv.json"]["credential"] = "private-fixture-only"
        result = receipt.final_receipt(**deepcopy(values))
        self.assertNotIn("private-fixture-only", str(result))
        self.assertEqual(result["status"], "PASS")

    def test_existing_workflow_wires_every_required_outcome_and_evidence(self):
        root = Path(__file__).resolve().parents[2]
        text = (root / ".github/workflows/bil_owner_comprehensive_validation.yml").read_text(encoding="utf-8")
        job = text.split("\n  supplemental-source-audits:\n", 1)[1]
        ids = re.findall(r"^        id: ([a-z_]+)$", job, re.MULTILINE)
        self.assertEqual(set(ids), set(receipt.REQUIRED_STEPS))
        self.assertEqual(len(ids), len(set(ids)))
        for name in receipt.REQUIRED_LOGS:
            self.assertIn(name, job, name)
        self.assertIn("ref: ${{ github.sha }}", job)
        self.assertIn('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', job)
        self.assertIn("--enforce-lockfile", job)
        self.assertIn("app:dependencies --configuration releaseRuntimeClasspath", job)
        self.assertIn('--health-cmd "pg_isready -U postgres -d community_qa"', job)
        self.assertIn("psql -h 127.0.0.1 -U postgres -d community_qa -X -v ON_ERROR_STOP=1", job)
        self.assertIn("-f tool/release/test_community_attention_isolated.sql", job)
        self.assertIn("if-no-files-found: error", job)
        self.assertNotIn("${{ secrets.", job)
        self.assertNotIn("continue-on-error:", job)
        self.assertNotIn("flutter test", job)
        self.assertNotIn("flutter analyze", job)
        self.assertNotIn("flutter build", job)
        self.assertNotIn("wrangler deploy", job)


if __name__ == "__main__":
    unittest.main()
