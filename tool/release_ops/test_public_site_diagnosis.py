"""Controller regression tests: all HTTP operations are mocked."""
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import public_site_diagnosis as diagnosis


class DiagnosisTest(unittest.TestCase):
    def record(self, **changes):
        return {"url": "https://www.bilhealth.com/.well-known/apple-app-site-association",
                "headers": {}, "http_status": 503, **changes}

    def test_exact_application_guard_identifies_source(self):
        result = diagnosis.classify(self.record(), b"Association document is invalid.")
        self.assertEqual(result["diagnostic_hint"], "APPLICATION_WORKER_FAIL_CLOSED_RESPONSE")
        self.assertEqual(result["safe_body_markers"], ["BIL_WORKER_ASSOCIATION_CONTRACT_REJECTION"])

    def test_unrecognized_body_is_not_published(self):
        result = diagnosis.classify(self.record(), b"Private error details: secret-value")
        self.assertIsNone(result["safe_error_excerpt"])
        self.assertNotIn("secret-value", json.dumps(result))

    def test_challenge_header_distinguishes_cf_challenge(self):
        result = diagnosis.classify(self.record(headers={"cf-mitigated": "challenge"}), b"Just a moment...")
        self.assertEqual(result["diagnostic_hint"], "CLOUDFLARE_CHALLENGE_HEADER")

    def test_malformed_association_shape_does_not_abort_other_probes(self):
        for body in (b'{"applinks":null}', b'{"applinks":{"details":false}}'):
            result = diagnosis.classify(self.record(), body)
            self.assertEqual(result["association_summary"], [])

    def test_later_success_cannot_erase_initial_failure(self):
        def fake_probe(spec):
            url, agent, required, window = spec
            return {"url": url, "user_agent": agent, "required_release_endpoint": required,
                    "sample_window": window, "http_status": 503 if required and url.endswith("apple-app-site-association") else 200}
        with tempfile.TemporaryDirectory() as directory, patch.object(diagnosis, "endpoint_probe", side_effect=fake_probe), patch.object(diagnosis.time, "sleep"), patch("sys.stdout", new=io.StringIO()):
            self.assertFalse(diagnosis.public_endpoints(Path(directory)))
            report = json.loads((Path(directory) / "public-endpoint-diagnosis.json").read_text())
            self.assertEqual(report["release_transport_status"], "FAILED_OR_BLOCKED")
            self.assertFalse(report["retries_used_for_acceptance"])
            self.assertTrue(all(row["http_status"] == 200 for row in report["observations"] if row["sample_window"] == "later-sample"))

    def test_secret_binding_values_are_excluded(self):
        result = diagnosis.settings_summary({"bindings": [{"name": "KEY", "type": "plain_text", "text": "secret-value"}, {"name": "ASSETS", "type": "assets"}]})
        self.assertNotIn("secret-value", json.dumps(result))
        self.assertEqual(result["binding_names_and_types_only"][1], {"name": "ASSETS", "type": "assets"})

    def test_multipart_hashes_javascript_without_metadata_or_source(self):
        code = b"export default {fetch(){return new Response('okay')}};"
        body = b'--sample\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n{"secret":"secret-value"}\r\n--sample\r\nContent-Disposition: form-data; name="worker.mjs"; filename="worker.mjs"\r\nContent-Type: application/javascript\r\n\r\n' + code + b'\r\n--sample--\r\n'
        result = diagnosis.worker_code_summary(body, diagnosis.sha(code), "multipart/form-data; boundary=sample")
        self.assertTrue(result["candidate_worker_module_found"])
        self.assertEqual(len(result["modules"]), 1)
        self.assertNotIn("secret-value", json.dumps(result))
        self.assertNotIn("export default", json.dumps(result))

    def test_redirects_are_not_followed(self):
        self.assertIsNone(diagnosis.NoRedirect().redirect_request(None, None, 302, "Moved", {}, "https://other.invalid"))

    def test_invalid_api_identifier_is_rejected(self):
        with self.assertRaises(ValueError):
            diagnosis.valid_id("../other-resource")

    def test_cf_success_errors_null_is_supported(self):
        raw = b'{"success":true,"errors":null,"result":{"bindings":null}}'
        response = {"http_status": 200, "headers": {"content-type": "application/json"}, "body_sha256": diagnosis.sha(raw)}
        with patch.dict(os.environ, {"CLOUDFLARE_API_TOKEN": "test-placeholder"}), patch.object(diagnosis, "fetch", return_value=(response, raw)):
            safe, value, _ = diagnosis.cf_get("/fixed-test-resource")
        self.assertTrue(safe["success"])
        self.assertEqual(safe["errors_shape"], "null")
        self.assertEqual(safe["error_codes"], [])
        settings = diagnosis.settings_summary(value)
        self.assertEqual(settings["binding_names_and_types_only"], [])
        self.assertEqual(settings["bindings_shape"], "null")

    def test_unexpected_list_shapes_are_reported_without_secret_values(self):
        for value in ({"secret": "secret-value"}, "secret-value", 8):
            report = {}
            self.assertEqual(diagnosis.object_rows(value, "collection", report), [])
            self.assertEqual(report["shape_warnings"], ["collection:EXPECTED_LIST_OR_NULL"])
            self.assertNotIn("secret-value", json.dumps(report))

    def test_cloudflare_null_collections_do_not_abort_later_reads(self):
        def fake_get(resource):
            value = None
            if resource.startswith("/accounts?"):
                value = [{"id": "a" * 32}]
            elif resource.endswith("/settings"):
                value = {"bindings": None}
            elif resource.endswith("/deployments"):
                value = {"deployments": None}
            elif resource.startswith("/zones?"):
                value = [{"id": "b" * 32}]
            return {"success": True, "http_status": 200, "content_type": "application/javascript"}, value, b"export default {}"
        with tempfile.TemporaryDirectory() as directory, patch.object(diagnosis, "cf_get", side_effect=fake_get), patch("sys.stdout", new=io.StringIO()):
            root = Path(directory)
            worker = root / "tool/release/bilhealth_site_worker.mjs"
            worker.parent.mkdir(parents=True)
            worker.write_bytes(b"export default {}")
            self.assertTrue(diagnosis.cloudflare(root / "out", root))
            result = json.loads((root / "out/cloudflare-diagnosis.json").read_text())
            self.assertIn("dns_workouts.bilhealth.com", result["resources"])
            self.assertEqual(result["resources"]["worker_deployments"]["deployments_shape"], "null")

    def test_partial_report_preserves_safe_phase_if_later_read_raises(self):
        def fake_get(resource):
            if resource.startswith("/accounts?"):
                return {"success": True}, [{"id": "a" * 32}], b""
            if resource.endswith("/settings"):
                return {"success": True}, {"bindings": None}, b""
            raise TypeError("Exception details must never be persisted")
        with tempfile.TemporaryDirectory() as directory, patch.object(diagnosis, "cf_get", side_effect=fake_get):
            root = Path(directory)
            worker = root / "tool/release/bilhealth_site_worker.mjs"
            worker.parent.mkdir(parents=True)
            worker.write_bytes(b"export default {}")
            with self.assertRaises(TypeError):
                diagnosis.cloudflare(root / "out", root)
            text = (root / "out/cloudflare-diagnosis.json").read_text()
            result = json.loads(text)
            self.assertEqual(result["phase"], "worker_script")
            self.assertIn("worker_settings", result["resources"])
            self.assertNotIn("Exception details", text)


if __name__ == "__main__":
    unittest.main()
