"""Controller regression tests: all HTTP operations are mocked."""
import io
import json
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


if __name__ == "__main__":
    unittest.main()
