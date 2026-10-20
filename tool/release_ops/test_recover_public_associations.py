import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import recover_public_associations as recovery


class RecoveryTest(unittest.TestCase):
    def test_aasa_keeps_exact_source_bytes_only_with_document_shape(self):
        raw = b'{"applinks":{"details":[{"appID":"existing.public.identity"}]}}\n'
        self.assertEqual(recovery.candidate_document("aasa", raw), raw)
        self.assertIsNone(recovery.candidate_document("aasa", b'{"error":"private-details"}'))

    def test_dal_keeps_statements_excluding_debug_error_payload(self):
        raw = b'{"statements":[{"relation":"existing-public"}],"debugString":"secret-error","maxAge":"20s"}'
        result = recovery.candidate_document("dal", raw)
        self.assertNotIn(b"secret-error", result)
        self.assertEqual(json.loads(result)["maxAge"], "20s")
        self.assertIsNone(recovery.candidate_document("dal", b'{"statements":[]}'))

    def test_disabled_or_unknown_previews_cannot_trigger_new_url(self):
        version = recovery.VERSIONS["last_good_20261018"]
        self.assertIsNone(recovery.preview_base("owner", False, version))
        self.assertIsNone(recovery.preview_base("owner.invalid/steal", True, version))
        self.assertIsNone(recovery.preview_base("owner", True, "f" * 36))
        self.assertEqual(recovery.preview_base("owner", True, version), "https://7e894d19-bilhealth.owner.workers.dev")

    def test_version_metadata_excludes_binding_values_and_annotations(self):
        result = recovery.version_summary({"id": "public-id", "annotations": {"secret": "secret-annotation"},
            "resources": {"bindings": [{"name": "TOKEN", "type": "plain_text", "text": "secret-value"}], "assets": {"jwt": "secret-jwt"}}})
        text = json.dumps(result)
        for secret in ("secret-value", "secret-jwt", "secret-annotation"):
            self.assertNotIn(secret, text)

    def test_read_denials_do_not_erase_public_candidates_or_enable_preview(self):
        raw = b'{"applinks":{"details":[{"appID":"existing.public.identity"}]}}'
        def fake_fetch(url, headers):
            return {"url": url, "http_status": 200, "headers": {}, "body_sha256": recovery.sha(raw)}, raw
        with tempfile.TemporaryDirectory() as directory, patch.object(recovery, "fetch", side_effect=fake_fetch) as getter, patch.object(recovery, "cf_get", return_value=({"success": False, "http_status": 403}, None, b"")) as cf_getter, patch("sys.stdout", new=io.StringIO()):
            self.assertTrue(recovery.collect(Path(directory)))
            report = json.loads((Path(directory) / "association-recovery-report.json").read_text())
            self.assertEqual(getter.call_count, 4)
            self.assertEqual(cf_getter.call_count, 4)
            self.assertEqual(report["candidate_count"], 2)
            self.assertFalse(report["origin_repaired"])
            self.assertEqual(report["mutations"], 0)

    def test_enabled_previews_fetch_only_both_known_existing_versions(self):
        def fake_cf(path):
            if path.endswith("/workers/subdomain"):
                value = {"subdomain": "owner"}
            elif path.endswith("/bilhealth/subdomain"):
                value = {"previews_enabled": True}
            else:
                value = {"id": path.rsplit("/", 1)[1]}
            return {"success": True, "http_status": 200}, value, b""
        def fake_fetch(url, headers):
            return {"url": url, "http_status": 404, "headers": {}}, b"not found"
        with tempfile.TemporaryDirectory() as directory, patch.object(recovery, "fetch", side_effect=fake_fetch) as getter, patch.object(recovery, "cf_get", side_effect=fake_cf), patch("sys.stdout", new=io.StringIO()):
            self.assertTrue(recovery.collect(Path(directory)))
            self.assertEqual(getter.call_count, 8)
            previews = [call.args[0] for call in getter.call_args_list if ".workers.dev" in call.args[0]]
            self.assertEqual(len(previews), 4)
            self.assertTrue(all(url.startswith(("https://7e894d19-bilhealth.owner.workers.dev/", "https://6a7dab10-bilhealth.owner.workers.dev/")) for url in previews))


if __name__ == "__main__":
    unittest.main()
