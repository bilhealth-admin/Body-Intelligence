"""Mock HTTP/native signing only; never calls Play or proves native billing."""

from __future__ import annotations

import base64
import copy
import hashlib
import http.client
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import urllib.error
import urllib.parse
import zipfile

from tool.release import store_qa_play_upload as upload


def manifest(status="completed"):
    return {"phase": "STORE_QA_ONLY", "source_sha": upload.SOURCE_SHA,
            "release_version": "1.0.0", "no_review_submission": True,
            "no_production_rollout": True,
            "android": {"package_name": upload.PACKAGE, "build_number": 32,
                        "track": "internal", "release_status": status,
                        "changes_not_sent_for_review": True,
                        "review_boundary": "ERROR_IF_IN_REVIEW"}}


def initial_state():
    return {"tracks": [
        {"track": "internal", "releases": [
            {"name": "Paused old13", "versionCodes": ["13"], "status": "halted"}]},
        {"track": "production", "releases": [
            {"name": "Pending owner29", "versionCodes": ["29"], "status": "draft",
             "releaseNotes": [{"language": "en-GB", "text": "Preserve owner's pending change"}]}]},
        {"track": "alpha", "releases": [
            {"versionCodes": ["28"], "status": "completed"}]},
        {"track": "wear:production", "releases": []}],
        "bundles": [{"versionCode": 13, "sha256": "a" * 64},
                    {"versionCode": 29, "sha256": "b" * 64}], "apks": []}


class FakePlay:
    """Explicit HTTP edit-service model; no production state or paid override."""

    def __init__(self):
        self.live = initial_state()
        self.edits = {}
        self.operations = []
        self.created = []
        self.deleted = []
        self.upload_count = 0
        self.upload_override = None
        self.upload_failure = None
        self.commit_failure = None
        self.validate_failure = None
        self.corrupt_non_internal_on_readback = False
        self.normalize_internal_name_on_readback = False
        self.corrupt_internal_on_readback = None

    def create_edit(self):
        edit_id = f"edit{len(self.created) + 1}"
        self.created.append(edit_id)
        state = copy.deepcopy(self.live)
        if self.corrupt_non_internal_on_readback and len(self.created) == 2:
            state["tracks"][1]["releases"][0]["name"] = "Unexpected owner change"
        if self.normalize_internal_name_on_readback and len(self.created) == 2:
            state["tracks"][0]["releases"][0]["name"] = "Server-managed display label"
        if self.corrupt_internal_on_readback and len(self.created) == 2:
            state["tracks"][0]["releases"] = copy.deepcopy(self.corrupt_internal_on_readback)
        self.edits[edit_id] = state
        self.operations.append(("POST", f"/applications/{upload.PACKAGE}/edits", {}))
        return edit_id

    def json(self, method, resource, body=None):
        self.operations.append((method, resource, copy.deepcopy(body)))
        edit_id = resource.split("/edits/", 1)[1].split("/", 1)[0].split(":", 1)[0]
        if edit_id not in self.edits:
            raise upload.SafeFailure("GOOGLE_HTTP_404")
        state = self.edits[edit_id]
        if method == "DELETE":
            self.deleted.append(edit_id)
            del self.edits[edit_id]
            return {}
        if method == "GET":
            kind = resource.rsplit("/", 1)[1]
            return {kind: copy.deepcopy(state[kind])}
        if method == "PUT":
            assert resource.endswith("/tracks/internal")
            state["tracks"] = [body if x["track"] == "internal" else x for x in state["tracks"]]
            return copy.deepcopy(body)
        if ":validate" in resource:
            if self.validate_failure:
                raise self.validate_failure
            return {"id": edit_id}
        if ":commit" in resource:
            if self.commit_failure:
                raise upload.SafeFailure(self.commit_failure)
            self.live = copy.deepcopy(state)
            del self.edits[edit_id]
            return {"id": edit_id}
        raise AssertionError("Unexpected mocked HTTP operation")

    def upload(self, edit_id, aab, artifact):
        self.upload_count += 1
        if self.upload_failure:
            raise upload.SafeFailure(self.upload_failure)
        bundle = self.upload_override or {"versionCode": 32, "sha256": artifact["sha256"]}
        self.edits[edit_id]["bundles"].append(copy.deepcopy(bundle))
        return copy.deepcopy(bundle)


class StoreQaPlayUploadTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.aab = Path(self.temporary.name) / "test-only-not-native-signed.aab"
        with zipfile.ZipFile(self.aab, "w") as archive:
            archive.writestr("base/manifest/AndroidManifest.xml", b"MOCK_PROTOCOL_TEST_ONLY")
        self.client = FakePlay()

    def run_upload(self, configuration=None, **options):
        return upload.run(configuration or manifest(), self.aab, self.client,
                          publishing_state_checked=True, **options)

    def assert_rejected(self, expected, configuration=None):
        with self.assertRaises(upload.SafeFailure) as failure:
            self.run_upload(configuration)
        self.assertEqual(expected, failure.exception.code)
        return failure.exception.report

    def test_completed_internal_replaces_only_test_track_and_keeps_old_catalog(self):
        before = copy.deepcopy(self.client.live)
        report = self.run_upload()
        self.assertTrue(report["committed"])
        self.assertEqual("completed", report["release_status"])
        self.assertFalse(report["native_billing_proved"])
        self.assertFalse(report["public_release_ready"])
        self.assertEqual("NATIVE_INSTALL_ELIGIBILITY_AND_BILLING_UNVERIFIED", report["installation_boundary"])
        self.assertEqual(before["tracks"][1:], self.client.live["tracks"][1:])
        self.assertEqual(1, len(self.client.live["tracks"][0]["releases"]))
        self.assertEqual(["32"], self.client.live["tracks"][0]["releases"][0]["versionCodes"])
        self.assertEqual("completed", self.client.live["tracks"][0]["releases"][0]["status"])
        for previous in before["bundles"]:
            self.assertIn(previous, self.client.live["bundles"])
        self.assertEqual("COMPLETE", report["step"])
        self.assertEqual(["13"], report["before"]["tracks"][0]["releases"][0]["version_codes"])
        self.assertEqual(["edit2"], self.client.deleted)
        self.assertEqual({}, self.client.edits)
        commits = [path for method, path, _ in self.client.operations if ":commit" in path]
        self.assertEqual(1, len(commits))
        self.assertTrue(commits[0].endswith("?" + upload.COMMIT_QUERY))
        puts = [path for method, path, _ in self.client.operations if method == "PUT"]
        self.assertEqual([f"/applications/{upload.PACKAGE}/edits/edit1/tracks/internal"], puts)

    def test_draft_reports_not_installable_and_keeps_serving_release(self):
        self.client.live["tracks"][0]["releases"][0]["status"] = "completed"
        old = copy.deepcopy(self.client.live["tracks"][0]["releases"][0])
        report = self.run_upload(manifest("draft"))
        self.assertEqual("NOT_INSTALLABLE_DRAFT", report["installation_boundary"])
        self.assertEqual(old, self.client.live["tracks"][0]["releases"][0])

    def test_exact_observed_no_review_validate_error_delegates_to_protected_validating_commit(self):
        self.client.validate_failure = upload.SafeFailure(
            "GOOGLE_HTTP_400", google_api_error=copy.deepcopy(upload.OBSERVED_NO_REVIEW_VALIDATION_ERROR))
        report = self.run_upload()
        self.assertTrue(report["committed"])
        self.assertEqual("NO_REVIEW_PARAMETER_UNSUPPORTED_USE_PROTECTED_COMMIT", report["precommit_validation"])
        self.assertEqual(upload.OBSERVED_NO_REVIEW_VALIDATION_ERROR, report["precommit_validation_api_error"])
        commits = [path for _, path, _ in self.client.operations if ":commit" in path]
        self.assertEqual([f"/applications/{upload.PACKAGE}/edits/edit1:commit?" + upload.COMMIT_QUERY], commits)
        self.assertFalse(report["native_billing_proved"])
        self.assertFalse(report["public_release_ready"])
        self.assertEqual(1, self.client.upload_count)

    def test_every_other_precommit_validation_error_aborts_without_commit(self):
        exact = upload.OBSERVED_NO_REVIEW_VALIDATION_ERROR
        cases = [("GOOGLE_HTTP_400", None), ("GOOGLE_HTTP_403", exact),
                 ("GOOGLE_WRITE_OUTCOME_UNKNOWN", exact)]
        for key, value in (("http_code", 403), ("code", 403), ("status", "FAILED_PRECONDITION"),
                           ("message", exact["message"] + " Other validation failure."),
                           ("reasons", ["CHANGES_ALREADY_IN_REVIEW"])):
            changed = dict(exact, **{key: value})
            cases.append(("GOOGLE_HTTP_400", changed))
        for code, diagnostic in cases:
            with self.subTest(code=code, diagnostic=diagnostic):
                self.client = FakePlay()
                self.client.validate_failure = upload.SafeFailure(code, google_api_error=diagnostic)
                report = self.assert_rejected(code)
                self.assertEqual("VALIDATE_OWN_EDIT", report["step"])
                self.assertFalse(report["commit_attempted"])
                self.assertFalse(any(":commit" in path for _, path, _ in self.client.operations))
                self.assertEqual(["edit1"], self.client.deleted)

    def test_no_review_validation_fallback_never_ignores_commit_error_or_retries(self):
        self.client.validate_failure = upload.SafeFailure(
            "GOOGLE_HTTP_400", google_api_error=copy.deepcopy(upload.OBSERVED_NO_REVIEW_VALIDATION_ERROR))
        self.client.commit_failure = "GOOGLE_HTTP_400"
        report = self.assert_rejected("GOOGLE_HTTP_400")
        self.assertTrue(report["commit_attempted"])
        self.assertIsNone(report["committed"])
        self.assertEqual("COMMIT_NO_REVIEW", report["step"])
        self.assertEqual(1, len([path for _, path, _ in self.client.operations if ":commit" in path]))
        self.assertEqual(1, self.client.upload_count)

    def make_sealed_receipt_fixture(self):
        """Receipt shape only: actual sealed AAB hash is separately mocked."""
        root = Path(self.temporary.name) / "sealed"
        root.mkdir()
        (root / "app-release.aab").write_bytes(self.aab.read_bytes())
        text = {
            "BIL-source-head.txt": upload.SOURCE_SHA,
            "BIL-control-head.txt": upload.SEALED_ANDROID32["controller_sha"],
            "BIL-build-number.txt": "BUILD_NUMBER=32",
            "BIL-android-aab.size": str(upload.SEALED_ANDROID32["aab_byte_length"]),
            "BIL-android-upload-certificate.txt": "ANDROID_UPLOAD_CERTIFICATE_SHA256=MATCH",
            "BIL-android-aab.sha256": upload.SEALED_ANDROID32["aab_sha256"] + "  build/app/outputs/bundle/release/app-release.aab",
            "BIL-android-signature.txt": "MOCK_SIGNATURE_RECEIPT_NOT_NATIVE_PROOF",
            "BIL-android-gate-status.txt": "NATIVE_CRYPTO_GATE=PASS\nUPSTREAM_EXACT_SOURCE_QA=VERIFIED\nRELEASE_PHASE=STORE_QA_ONLY\nPUBLIC_RELEASE_READY=NO",
        }
        for name, value in text.items():
            (root / name).write_text(value + "\n", encoding="utf-8")
        repository = Path(__file__).resolve().parents[2]
        manifest_bytes = (repository / "docs/release/BIL_STORE_QA_CANDIDATE_2026-10-04.json").read_bytes()
        self.assertEqual(upload.SEALED_ANDROID32["manifest_sha256"], hashlib.sha256(manifest_bytes).hexdigest())
        (root / "BIL-store-qa-manifest.json").write_bytes(manifest_bytes)
        (root / "BIL-android-artifact-version.json").write_text(json.dumps(
            {"package": upload.PACKAGE, "version_name": "1.0.0", "version_code": "32"}))
        checkpoint = {
            "source_sha": upload.SOURCE_SHA, "controller_sha": upload.SEALED_ANDROID32["controller_sha"],
            "platform": "android", "build_number": 32, "generated_native_configuration": [],
            "manifest_sha256": upload.SEALED_ANDROID32["manifest_sha256"], "phase": "STORE_QA_ONLY",
            "configuration_gate": "PASS", "original_production_gate": "FAIL", "unresolved_review_count": 8,
        }
        (root / "BIL-store-qa-source-android.json").write_text(json.dumps(checkpoint))
        return root

    def test_sealed_recovery_receipts_bind_original_source_controller_hash_and_build(self):
        root = self.make_sealed_receipt_fixture()
        expected = {"byte_length": upload.SEALED_ANDROID32["aab_byte_length"],
                    "sha256": upload.SEALED_ANDROID32["aab_sha256"]}
        with mock.patch.object(upload, "inspect_aab", return_value=expected):
            aab, receipt = upload.verify_sealed_android32(root)
        self.assertEqual((root / "app-release.aab").resolve(), aab)
        self.assertEqual(37229040573, receipt["run_id"])
        self.assertEqual(11313338798, receipt["artifact_id"])
        self.assertEqual(upload.SOURCE_SHA, receipt["source_sha"])
        self.assertEqual(32, receipt["build_number"])
        self.assertFalse(receipt["rebuild_performed"])
        # Real hashing must reject this tiny fixture; it is not native proof.
        with self.assertRaisesRegex(upload.SafeFailure, "SEALED_ANDROID32_AAB_IDENTITY_MISMATCH"):
            upload.verify_sealed_android32(root)

    def test_sealed_recovery_rejects_changed_receipt_duplicate_file_and_wrong_native_gate(self):
        root = self.make_sealed_receipt_fixture()
        expected = {"byte_length": upload.SEALED_ANDROID32["aab_byte_length"],
                    "sha256": upload.SEALED_ANDROID32["aab_sha256"]}
        for name, changed, code in (
            ("BIL-control-head.txt", "a" * 40, "SEALED_ANDROID32_SOURCE_VERSION_OR_CERTIFICATE_MISMATCH"),
            ("BIL-build-number.txt", "BUILD_NUMBER=31", "SEALED_ANDROID32_SOURCE_VERSION_OR_CERTIFICATE_MISMATCH"),
            ("BIL-android-gate-status.txt", "NATIVE_CRYPTO_GATE=NOT_RUN_OWNER_WAIVED", "SEALED_ANDROID32_NATIVE_GATE_RECEIPT_MISMATCH"),
            ("BIL-store-qa-source-android.json", "{}", "SEALED_ANDROID32_CONFIGURATION_CHECKPOINT_MISMATCH"),
            ("BIL-android-artifact-version.json", "{}", "SEALED_ANDROID32_NATIVE_VERSION_MISMATCH"),
        ):
            with self.subTest(name=name):
                original = (root / name).read_bytes()
                (root / name).write_text(changed)
                with mock.patch.object(upload, "inspect_aab", return_value=expected), \
                        self.assertRaisesRegex(upload.SafeFailure, code):
                    upload.verify_sealed_android32(root)
                (root / name).write_bytes(original)
        duplicate = root / "duplicate"
        duplicate.mkdir()
        (duplicate / "app-release.aab").write_bytes(self.aab.read_bytes())
        with self.assertRaisesRegex(upload.SafeFailure, "SEALED_ANDROID32_RECEIPT_MISSING_OR_DUPLICATED"):
            upload.verify_sealed_android32(root)

    def test_preflight_only_lists_all_numbers_and_deletes_its_own_edit(self):
        self.client.live["apks"] = [{"versionCode": 40}]
        report = upload.run(manifest(), None, self.client, preflight=True)
        self.assertEqual(40, report["before"]["highest_version_code"])
        self.assertEqual([13, 29], report["before"]["bundle_versions"])
        self.assertEqual([40], report["before"]["apk_versions"])
        self.assertEqual("PREFLIGHT_NO_UPLOAD_NO_COMMIT", report["mode"])
        self.assertFalse(report["upload_performed"])
        self.assertFalse(report["commit_attempted"])
        self.assertEqual(0, self.client.upload_count)
        self.assertEqual(["edit1"], self.client.deleted)

    def test_no_owner_ui_assurance_rejects_before_upload(self):
        with self.assertRaisesRegex(upload.SafeFailure, "OWNER_PENDING_EDITS_AND_REVIEW_CHECK_REQUIRED"):
            upload.run(manifest(), self.aab, self.client)
        self.assertEqual(0, self.client.upload_count)
        self.assertEqual(["edit1"], self.client.deleted)

    def test_existing_internal_draft_or_pending_fails_before_upload(self):
        for status in ("draft", "inProgress", "statusUnspecified"):
            with self.subTest(status=status):
                self.client = FakePlay()
                self.client.live["tracks"][0]["releases"][0]["status"] = status
                self.assert_rejected("EXISTING_INTERNAL_DRAFT_OR_PENDING_RELEASE")
                self.assertEqual(0, self.client.upload_count)
                self.assertEqual(["edit1"], self.client.deleted)

    def test_missing_internal_identity_never_creates_or_renames_a_track(self):
        self.client.live["tracks"][0]["track"] = "qa"
        self.assert_rejected("EXISTING_INTERNAL_TRACK_IDENTITY_REQUIRED")
        self.assertEqual(0, self.client.upload_count)
        self.assertFalse(any(method == "PUT" for method, _, _ in self.client.operations))

    def test_equal_or_lower_existing_code_never_reuploads(self):
        for code in (32, 33):
            with self.subTest(code=code):
                self.client = FakePlay()
                self.client.live["bundles"].append({"versionCode": code, "sha256": "c" * 64})
                self.assert_rejected("NEW_VERSION_NOT_ABOVE_EXISTING_CATALOG")
                self.assertEqual(0, self.client.upload_count)

    def test_response_hash_or_version_mismatch_never_updates_or_commits(self):
        artifact = upload.inspect_aab(self.aab)
        for bundle, code in (({"versionCode": 33, "sha256": artifact["sha256"]}, "BUNDLE_VERSION_MISMATCH"),
                             ({"versionCode": 32, "sha256": "f" * 64}, "BUNDLE_SHA256_MISMATCH")):
            with self.subTest(code=code):
                self.client = FakePlay()
                self.client.upload_override = bundle
                self.assert_rejected(code)
                self.assertEqual(1, self.client.upload_count)
                self.assertFalse(any(method == "PUT" or ":commit" in path
                                     for method, path, _ in self.client.operations))

    def test_unknown_upload_is_not_retried_or_reported_as_not_uploaded(self):
        self.client.upload_failure = "GOOGLE_WRITE_OUTCOME_UNKNOWN"
        report = self.assert_rejected("GOOGLE_WRITE_OUTCOME_UNKNOWN")
        self.assertEqual(1, self.client.upload_count)
        self.assertTrue(report["upload_attempted"])
        self.assertIsNone(report["upload_performed"])
        self.assertFalse(report["commit_attempted"])
        self.assertEqual(["edit1"], self.client.deleted)

    def test_unknown_commit_is_not_retried_or_claimed_uncommitted(self):
        self.client.commit_failure = "GOOGLE_WRITE_OUTCOME_UNKNOWN"
        report = self.assert_rejected("GOOGLE_WRITE_OUTCOME_UNKNOWN")
        self.assertTrue(report["commit_attempted"])
        self.assertIsNone(report["committed"])
        self.assertEqual(1, len([path for _, path, _ in self.client.operations if ":commit" in path]))
        self.assertEqual(["edit1"], self.client.deleted)

    def test_fresh_readback_change_fails_without_rollback_or_track_repair(self):
        self.client.corrupt_non_internal_on_readback = True
        report = self.assert_rejected("NON_INTERNAL_TRACK_STATE_CHANGED")
        self.assertTrue(report["committed"])
        self.assertEqual(["edit2"], self.client.deleted)
        self.assertEqual(1, len([path for method, path, _ in self.client.operations if method == "PUT"]))

    def test_completed_readback_accepts_only_server_label_normalization(self):
        self.client.normalize_internal_name_on_readback = True
        self.assertTrue(self.run_upload()["committed"])
        for releases in (
            [{"versionCodes": ["32"], "status": "draft"}],
            [{"versionCodes": ["13", "32"], "status": "completed"}],
            [{"versionCodes": ["32"], "status": "completed"},
             {"versionCodes": ["13"], "status": "completed"}],
        ):
            with self.subTest(releases=releases):
                self.client = FakePlay()
                self.client.corrupt_internal_on_readback = releases
                report = self.assert_rejected("INTERNAL_RELEASE_READBACK_MISMATCH")
                self.assertTrue(report["committed"])
                self.assertEqual(["edit2"], self.client.deleted)

    def test_manifest_rejects_production_wrong_package_bad_flags_and_statuses(self):
        cases = []
        for key, value in (("track", "production"), ("track", "alpha"),
                           ("package_name", "another.package"), ("release_status", "inProgress"),
                           ("build_number", True), ("build_number", "32"), ("build_number", 31),
                           ("changes_not_sent_for_review", False),
                           ("review_boundary", "CANCEL_IN_REVIEW_AND_SUBMIT")):
            configuration = manifest()
            configuration["android"][key] = value
            cases.append(configuration)
        for key in ("no_review_submission", "no_production_rollout"):
            configuration = manifest()
            configuration[key] = False
            cases.append(configuration)
        for key, value in (("source_sha", "a" * 40), ("release_version", "1.0.1")):
            configuration = manifest()
            configuration[key] = value
            cases.append(configuration)
        for configuration in cases:
            with self.subTest(configuration=configuration):
                self.assert_rejected("STORE_QA_MANIFEST_BOUNDARY_REJECTED", configuration)
        self.assertEqual([], self.client.created)

    def test_manifest_bytes_require_exact_digest_before_authentication_or_edits(self):
        path = Path(self.temporary.name) / "manifest.json"
        raw = json.dumps(manifest()).encode()
        # Fixture writing is test-owned temporary data, never a release file.
        path.write_bytes(raw)
        digest = hashlib.sha256(raw).hexdigest()
        self.assertEqual(manifest(), upload.load_manifest(path, {upload.MANIFEST_DIGEST_ENV: digest}))
        for expected in ("", "a" * 63, "a" * 64, digest.upper()):
            with self.subTest(expected=expected):
                output = io.StringIO()
                with mock.patch.dict(upload.os.environ, {upload.MANIFEST_DIGEST_ENV: expected}), \
                        mock.patch.object(upload, "authenticate") as authenticate, \
                        mock.patch.object(upload, "load_credentials") as credentials, \
                        mock.patch("sys.stdout", output):
                    code = upload.main(["--manifest", str(path), "--preflight"])
                self.assertEqual(1, code)
                self.assertEqual("STORE_QA_MANIFEST_DIGEST_MISMATCH", json.loads(output.getvalue())["code"])
                authenticate.assert_not_called()
                credentials.assert_not_called()

    def test_exact_digest_does_not_authorize_wrong_source_or_duplicate_fields(self):
        path = Path(self.temporary.name) / "manifest.json"
        configuration = manifest()
        configuration["source_sha"] = "f" * 40
        for raw, expected in (
            (json.dumps(configuration).encode(), "STORE_QA_MANIFEST_BOUNDARY_REJECTED"),
            (b'{"phase":"STORE_QA_ONLY","phase":"OVERRIDE"}', "STORE_QA_MANIFEST_REFERENCE_INVALID"),
        ):
            path.write_bytes(raw)
            with mock.patch.dict(upload.os.environ, {
                upload.MANIFEST_DIGEST_ENV: hashlib.sha256(raw).hexdigest()
            }), mock.patch.object(upload, "authenticate") as authenticate, \
                    mock.patch("sys.stdout", io.StringIO()) as output:
                self.assertEqual(1, upload.main(["--manifest", str(path), "--preflight"]))
            self.assertEqual(expected, json.loads(output.getvalue())["code"])
            authenticate.assert_not_called()

    def test_client_rejects_any_non_internal_write_and_unowned_edit(self):
        transport = mock.Mock()
        client = upload.PlayClient("MOCK_NON_USABLE_TOKEN", transport)
        client.owned_edits.add("owned")
        root = f"/applications/{upload.PACKAGE}/edits/owned"
        for method, resource, body in (
            ("PUT", root + "/tracks/production", {"track": "production"}),
            ("POST", root + "/tracks/alpha", {}),
            ("DELETE", root + "/tracks/internal", None),
            ("POST", root + ":commit", None),
            ("POST", root + ":commit?changesNotSentForReview=false", None),
            ("DELETE", f"/applications/{upload.PACKAGE}/edits/someoneelse", None),
            ("PUT", root + "/tracks/internal", {"track": "production"}),
        ):
            with self.subTest(method=method, resource=resource):
                with self.assertRaises(upload.SafeFailure):
                    client.json(method, resource, body)
        transport.request.assert_not_called()

    def test_oauth_uses_exact_existing_scope_and_never_exports_credentials(self):
        credentials = {"client_email": "mock@example.iam.gserviceaccount.com",
                       "private_key": "NON_USABLE_TEST_PRIVATE_KEY"}
        transport = mock.Mock()
        transport.request.return_value = (200, b'{"access_token":"NON_USABLE_TEST_TOKEN"}')
        with mock.patch.object(upload, "openssl_sign", return_value=b"mock-signature"):
            token = upload.authenticate(credentials, transport)
        self.assertEqual("NON_USABLE_TEST_TOKEN", token)
        method, destination, _, payload = transport.request.call_args.args
        self.assertEqual("POST", method)
        self.assertEqual(upload.TOKEN_URI, destination)
        form = urllib.parse.parse_qs(payload.decode())
        claims_part = form["assertion"][0].split(".")[1]
        claims = json.loads(base64.urlsafe_b64decode(claims_part + "=" * (-len(claims_part) % 4)))
        self.assertEqual(upload.SCOPE, claims["scope"])
        self.assertEqual(upload.TOKEN_URI, claims["aud"])
        self.assertNotIn(credentials["private_key"], payload.decode())

    def test_media_upload_streams_exact_file_once_without_buffering_or_retry(self):
        artifact = upload.inspect_aab(self.aab)
        captured = []

        def request(method, url, headers, body, **kwargs):
            captured.append((method, url, headers, body.read(), kwargs))
            return 200, json.dumps({"versionCode": 32, "sha256": artifact["sha256"]}).encode()

        transport = mock.Mock()
        transport.request.side_effect = request
        client = upload.PlayClient("MOCK_NON_USABLE_TOKEN", transport)
        client.owned_edits.add("owned")
        response = client.upload("owned", self.aab, artifact)
        self.assertEqual(32, response["versionCode"])
        self.assertEqual(1, len(captured))
        method, destination, headers, content, _ = captured[0]
        self.assertEqual("POST", method)
        self.assertTrue(destination.startswith(upload.UPLOAD_ROOT))
        self.assertTrue(destination.endswith("/edits/owned/bundles?uploadType=media"))
        self.assertEqual(str(len(content)), headers["Content-Length"])
        self.assertEqual(artifact["sha256"], hashlib.sha256(content).hexdigest())

    def test_transport_never_retries_unknown_writes_or_forwards_redirects(self):
        transport = upload.Transport()
        transport.opener = mock.Mock()
        transport.opener.open.side_effect = TimeoutError("MOCK timeout")
        with self.assertRaisesRegex(upload.SafeFailure, "GOOGLE_WRITE_OUTCOME_UNKNOWN"):
            transport.request("POST", upload.TOKEN_URI, {}, b"MOCK request")
        self.assertEqual(1, transport.opener.open.call_count)
        self.assertIsNone(upload.NoRedirect().redirect_request(None, None, 302, None, {}, "https://evil.invalid"))
        with self.assertRaisesRegex(upload.SafeFailure, "UNTRUSTED_GOOGLE_DESTINATION"):
            transport.request("POST", "https://evil.invalid", {}, b"MOCK request")
        self.assertEqual(1, transport.opener.open.call_count)

    def test_truncated_post_preserves_unknown_write_and_operation_receipt(self):
        transport = upload.Transport()
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        response.read.side_effect = http.client.IncompleteRead(b'{"id":', 20)
        transport.opener = mock.Mock()
        transport.opener.open.return_value = response

        def upload_with_truncated_response(edit_id, aab, artifact):
            self.client.upload_count += 1
            transport.request("POST", upload.UPLOAD_ROOT + "/MOCK", {}, b"MOCK")

        self.client.upload = upload_with_truncated_response
        report = self.assert_rejected("GOOGLE_WRITE_OUTCOME_UNKNOWN")
        self.assertTrue(report["upload_attempted"])
        self.assertIsNone(report["upload_performed"])
        self.assertFalse(report["commit_attempted"])
        self.assertEqual(1, self.client.upload_count)
        self.assertEqual(1, transport.opener.open.call_count)
        self.assertEqual(["edit1"], self.client.deleted)
        self.assertEqual("UPLOAD_BUNDLE", report["step"])

    def test_truncated_get_is_read_failure_not_a_write_or_automatic_retry(self):
        transport = upload.Transport()
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.status = 200
        response.read.side_effect = http.client.IncompleteRead(b"partial", 20)
        transport.opener = mock.Mock()
        transport.opener.open.return_value = response
        with self.assertRaisesRegex(upload.SafeFailure, "GOOGLE_READ_FAILED"):
            transport.request("GET", upload.API_ROOT + "/MOCK", {})
        self.assertEqual(1, transport.opener.open.call_count)

    def test_official_review_error_keeps_exact_reason_but_never_raw_metadata(self):
        raw = json.dumps({"error": {
            "code": 400, "status": "FAILED_PRECONDITION",
            "message": "You already have changes in review. See https://developers.google.com/private?token=NO_PRINT",
            "details": [{"reason": "CHANGES_ALREADY_IN_REVIEW",
                         "metadata": {"editId": "NEVER_PRINT_EDIT", "token": "NEVER_PRINT_TOKEN"}}],
            "unsafe": "NEVER_PRINT_RAW"
        }}).encode()
        transport = upload.Transport()
        transport.opener = mock.Mock()
        transport.opener.open.side_effect = urllib.error.HTTPError(
            "https://androidpublisher.googleapis.com/MOCK", 400, "Bad Request", {}, io.BytesIO(raw))
        with self.assertRaises(upload.SafeFailure) as failure:
            transport.request("POST", upload.API_ROOT + "/MOCK", {}, b"MOCK")
        self.assertEqual("GOOGLE_HTTP_400", failure.exception.code)
        diagnostic = failure.exception.google_api_error
        self.assertEqual(400, diagnostic["code"])
        self.assertEqual("FAILED_PRECONDITION", diagnostic["status"])
        self.assertEqual(["CHANGES_ALREADY_IN_REVIEW"], diagnostic["reasons"])
        self.assertIn("already have changes in review", diagnostic["message"])
        rendered = json.dumps(diagnostic)
        for forbidden in ("https://", "NO_PRINT", "NEVER_PRINT", "metadata", "unsafe"):
            self.assertNotIn(forbidden, rendered)
        self.assertEqual(1, transport.opener.open.call_count)

    def test_main_keeps_commit_step_unknown_outcome_and_sanitized_api_receipt(self):
        path = Path(self.temporary.name) / "manifest.json"
        raw = json.dumps(manifest()).encode()
        path.write_bytes(raw)
        diagnostic = {"http_code": 400, "code": 400, "status": "FAILED_PRECONDITION",
                      "reasons": ["CHANGES_ALREADY_IN_REVIEW"],
                      "message": "You already have changes in review."}
        original_json = self.client.json

        def json_with_commit_rejection(method, resource, body=None):
            if ":commit" in resource:
                self.client.operations.append((method, resource, body))
                raise upload.SafeFailure("GOOGLE_HTTP_400", google_api_error=diagnostic)
            return original_json(method, resource, body)

        self.client.json = json_with_commit_rejection
        output = io.StringIO()
        with mock.patch.dict(upload.os.environ, {
            upload.MANIFEST_DIGEST_ENV: hashlib.sha256(raw).hexdigest()
        }), mock.patch.object(upload, "load_credentials", return_value={}), \
                mock.patch.object(upload, "authenticate", return_value="MOCK_NON_USABLE_TOKEN"), \
                mock.patch.object(upload, "PlayClient", return_value=self.client), \
                mock.patch("sys.stdout", output):
            code = upload.main(["--manifest", str(path), "--aab", str(self.aab),
                                "--owner-publishing-state-checked"])
        receipt = json.loads(output.getvalue())
        self.assertEqual(1, code)
        self.assertEqual("GOOGLE_HTTP_400", receipt["code"])
        self.assertEqual(diagnostic, receipt["google_api_error"])
        self.assertEqual("COMMIT_NO_REVIEW", receipt["report"]["step"])
        self.assertTrue(receipt["report"]["commit_attempted"])
        self.assertIsNone(receipt["report"]["committed"])
        self.assertEqual(["DELETE_CONFIRMED"], receipt["report"]["own_edit_cleanup"])
        self.assertEqual(1, len([path for _, path, _ in self.client.operations if ":commit" in path]))
        self.assertNotIn("MOCK_NON_USABLE_TOKEN", output.getvalue())

    def test_api_error_whitelist_redacts_secrets_and_has_strict_2048_budget(self):
        message = ("private_key=\"NEVER_PRINT_KEY\" access_token=NEVER_PRINT_ACCESS "
                   "assertion=NEVER_PRINT_ASSERTION password='NEVER_PRINT_PASSWORD' "
                   "Bearer NEVER_PRINT_BEARER email=private@example.com "
                   "https://example.com/?token=NEVER_PRINT_QUERY "
                   "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxIn0.signature "
                   "-----BEGIN PRIVATE KEY-----\nNEVER_PRINT_PEM\n-----END PRIVATE KEY----- "
                   + "م" * 6000)
        diagnostic = upload.sanitized_google_error(json.dumps({"error": {
            "code": 403, "status": "PERMISSION_DENIED", "message": message,
            "errors": [{"reason": "forbidden", "message": "NEVER_PRINT_NESTED"}],
            "details": [{"reason": "PERMISSION_DENIED", "metadata": {"secret": "NEVER_PRINT_METADATA"}}],
            "private_key": "NEVER_PRINT_FIELD"
        }}).encode(), 403)
        rendered = upload.canonical(diagnostic)
        self.assertLessEqual(len(rendered), 2048)
        for forbidden in (b"NEVER_PRINT", b"private@example.com", b"https://", b"eyJhbGci", b"PRIVATE KEY"):
            self.assertNotIn(forbidden, rendered)
        self.assertEqual(["forbidden", "PERMISSION_DENIED"], diagnostic["reasons"])


if __name__ == "__main__":
    unittest.main()
