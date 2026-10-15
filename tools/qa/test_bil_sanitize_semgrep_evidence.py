import json
import unittest

from bil_sanitize_semgrep_evidence import sanitize


class SanitizedEvidenceTest(unittest.TestCase):
    def test_source_secret_and_error_messages_never_enter_public_record(self):
        value = sanitize({
            "version": "1.181.0",
            "results": [{"check_id": "secret-rule", "path": "tool/example.mjs",
                         "start": {"line": 7}, "extra": {
                             "severity": "ERROR", "lines": "private-synthetic-token",
                             "message": "private-synthetic-token", "metavars": {
                                 "$VALUE": {"abstract_content": "private-synthetic-token"}}}}],
            "errors": [{"type": "ParseError", "level": "warn", "code": 3,
                        "path": "tool/example.mjs", "rule_id": "slow-rule",
                        "message": "private-synthetic-token"}],
            "paths": {"scanned": ["tool/example.mjs"]},
        })
        self.assertNotIn("private-synthetic-token", json.dumps(value))
        self.assertEqual(value["result"], "PARTIAL")
        self.assertEqual(value["findings_count"], 1)
        self.assertEqual(value["scanned_paths_count"], 1)
        self.assertEqual(value["errors"][0]["path"], "tool/example.mjs")
        self.assertEqual(value["errors"][0]["rule_id"], "slow-rule")

    def test_findings_are_distinct_from_an_empty_successful_scan(self):
        value = sanitize({"version": "1", "results": [], "errors": []})
        self.assertEqual(value["result"], "CLEAN_SCAN")
        value = sanitize({"version": "1", "results": [{
            "check_id": "review", "path": "app.js", "start": {"line": 1}}], "errors": []})
        self.assertEqual(value["result"], "FINDINGS_REVIEW")

    def test_empty_or_unusable_output_cannot_become_a_clean_scan(self):
        for value in [{}, {"version": "1"}, {"version": "1", "results": []}]:
            with self.assertRaises(ValueError):
                sanitize(value)


if __name__ == "__main__":
    unittest.main()
