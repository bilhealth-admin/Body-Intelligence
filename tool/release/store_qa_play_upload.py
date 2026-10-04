"""Owner-authorized Play testing uploads only; never a public-release verdict.

No automatic retries: an ambiguous write requires operator reconciliation.
The Edits API cannot enumerate another operator's uncommitted edits or prove
the Publishing Overview review state. The owner must inspect that state first;
ERROR_IF_IN_REVIEW is an additional server-side commit guard, not that proof.
"""

from __future__ import annotations

import argparse
import base64
import contextlib
import copy
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

PACKAGE = "com.bilhealth.bodyintelligencelog"
API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD_ROOT = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
TOKEN_URI = "https://oauth2.googleapis.com/token"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
COMMIT_QUERY = "changesNotSentForReview=true&changesInReviewBehavior=ERROR_IF_IN_REVIEW"
SA_ENV = "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64"
SOURCE_SHA = "3f0085e6e6686f2e87e9cf14789e9e578ea64159"
MANIFEST_DIGEST_ENV = "BIL_STORE_QA_MANIFEST_SHA256"
OBSERVED_NO_REVIEW_VALIDATION_ERROR = {
    "http_code": 400, "code": 400, "status": "INVALID_ARGUMENT",
    "message": "Changes cannot be sent for review automatically. Please set the query "
               "parameter changesNotSentForReview to true. Once committed, the changes "
               "in this edit can be sent for review from the Google Play Console UI.",
}
SEALED_ANDROID32 = {
    "run_id": 37229040573, "job_id": 111514615723, "artifact_id": 11313338798,
    "archive_digest": "sha256:a7cd8ec1ee310e027886359179db3134dc0b0abb4b8c6e25e4849a3eecf97603",
    "controller_sha": "5f14ba8358ffe3061cc6300b988ca4075e8afe7f",
    "manifest_sha256": "5e16a9cbe08884aad1fceeb16a269d7fc92a0e6310dc2f2e0fc4cec5d360fada",
    "aab_sha256": "9819aabf66c0ed86d1fc3a88e583158b707b50282113fb2f2e38cfaa4f8aa11a",
    "aab_byte_length": 183645353,
}


class SafeFailure(Exception):
    """Only a fixed code and sanitized operational evidence may be printed."""

    def __init__(self, code: str, report: dict | None = None,
                 *, google_api_error: dict | None = None):
        super().__init__(code)
        self.code = code
        self.report = report
        self.google_api_error = google_api_error


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def validate_manifest(manifest: dict) -> dict:
    if not isinstance(manifest, dict) or not isinstance(manifest.get("android"), dict):
        raise SafeFailure("STORE_QA_MANIFEST_BOUNDARY_REJECTED")
    android = manifest.get("android", {})
    if (
        manifest.get("phase") != "STORE_QA_ONLY"
        or manifest.get("no_review_submission") is not True
        or manifest.get("no_production_rollout") is not True
        or android.get("package_name") != PACKAGE
        or android.get("track") != "internal"
        or android.get("release_status") not in ("draft", "completed")
        or android.get("changes_not_sent_for_review") is not True
        or android.get("review_boundary") != "ERROR_IF_IN_REVIEW"
        or manifest.get("source_sha") != SOURCE_SHA
        or manifest.get("release_version") != "1.0.0"
        or type(android.get("build_number")) is not int
        or not 31 < android["build_number"] <= 2_100_000_000
    ):
        raise SafeFailure("STORE_QA_MANIFEST_BOUNDARY_REJECTED")
    return android


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate field")
        result[key] = value
    return result


def load_manifest(path: Path, environment: dict) -> dict:
    try:
        raw = path.read_bytes()
        expected = environment.get(MANIFEST_DIGEST_ENV, "")
        if (len(raw) > 1_048_576 or not re.fullmatch(r"[0-9a-f]{64}", expected)
                or hashlib.sha256(raw).hexdigest() != expected):
            raise SafeFailure("STORE_QA_MANIFEST_DIGEST_MISMATCH")
        manifest = json.loads(raw, object_pairs_hook=unique_object,
                              parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite")))
        validate_manifest(manifest)
        return manifest
    except (OSError, ValueError, TypeError):
        raise SafeFailure("STORE_QA_MANIFEST_REFERENCE_INVALID") from None


def sanitized_google_error(raw: bytes, http_code: int) -> dict:
    """Whitelist API diagnostics, never its raw body, metadata or request URL."""
    result = {"http_code": http_code}
    try:
        payload = json.loads(raw, object_pairs_hook=unique_object)
        error = payload.get("error")
        if not isinstance(error, dict):
            return result
    except (ValueError, TypeError, AttributeError):
        return result

    def scrub(value: str) -> str:
        value = re.sub(r"-----BEGIN [^-]+-----.*?(?:-----END [^-]+-----|$)",
                       "[REDACTED_KEY]", value, flags=re.S)
        value = re.sub(r"(?i)\b(?:https?://|www\.)[^\s<>\"']+", "[REDACTED_URL]", value)
        value = re.sub(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+",
                       "[REDACTED_EMAIL]", value)
        value = re.sub(r"(?i)\bbearer\s+\S+", "[REDACTED_AUTH]", value)
        value = re.sub(r"(?i)\b(?:access_token|refresh_token|id_token|private_key|"
                       r"client_secret|api_key|assertion|authorization|password|token)"
                       r"[\"']?\s*[:=]\s*(?:\"[^\"]*\"|'[^']*'|[^\s,;]+)",
                       "[REDACTED_SECRET]", value)
        value = re.sub(r"\b[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b",
                       "[REDACTED_JWT]", value)
        value = re.sub(r"[A-Za-z0-9_+/=-]{40,}", "[REDACTED_OPAQUE]", value)
        return re.sub(r"[\x00-\x1f\x7f]", " ", value)

    if type(error.get("code")) is int and 100 <= error["code"] <= 599:
        result["code"] = error["code"]
    status = error.get("status")
    if isinstance(status, str) and re.fullmatch(r"[A-Z][A-Z0-9_]{0,63}", status):
        result["status"] = scrub(status)
    reasons = []
    for group in (error.get("errors"), error.get("details")):
        if isinstance(group, list):
            for item in group[:8]:
                reason = item.get("reason") if isinstance(item, dict) else None
                if isinstance(reason, str) and re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,95}", reason):
                    reason = scrub(reason)
                    if reason not in reasons:
                        reasons.append(reason)
    if reasons:
        result["reasons"] = reasons[:4]
    if isinstance(error.get("message"), str):
        result["message"] = scrub(error["message"][:8192])[:1200]
    while len(canonical(result)) > 2048 and result.get("message"):
        result["message"] = result["message"][:-max(1, len(result["message"]) // 8)]
    return result


def load_credentials(reference: str | None) -> dict:
    try:
        if reference:
            raw = Path(reference).read_bytes()
        else:
            raw = base64.b64decode(os.environ[SA_ENV], validate=True)
        if len(raw) > 1_048_576:
            raise ValueError("credential size")
        credentials = json.loads(raw)
        if (
            credentials.get("type") != "service_account"
            or not str(credentials.get("client_email", "")).endswith(".gserviceaccount.com")
            or "BEGIN PRIVATE KEY" not in str(credentials.get("private_key", ""))
            or credentials.get("token_uri", TOKEN_URI) != TOKEN_URI
        ):
            raise ValueError("credential structure")
        return credentials
    except (OSError, ValueError, KeyError, TypeError):
        raise SafeFailure("GOOGLE_CREDENTIAL_REFERENCE_UNAVAILABLE_OR_INVALID") from None


def openssl_sign(payload: bytes, private_key: str) -> bytes:
    # Ubuntu CI provides a private POSIX temporary directory and OpenSSL.
    # Do not pretend chmod is an owner-only Windows ACL.
    if os.name != "posix":
        raise SafeFailure("POSIX_PRIVATE_SIGNING_WORKSPACE_REQUIRED")
    executable = shutil.which("openssl")
    if not executable:
        raise SafeFailure("OPENSSL_UNAVAILABLE")
    try:
        with tempfile.TemporaryDirectory(prefix="bil-play-oauth-") as temporary:
            os.chmod(temporary, 0o700)
            key_path = Path(temporary) / "signing-key.pem"
            descriptor = os.open(key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "w", encoding="utf-8") as key_file:
                key_file.write(private_key)
            signed = subprocess.run(
                [executable, "dgst", "-sha256", "-sign", str(key_path)],
                input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                check=True, timeout=15,
            )
            return signed.stdout
    except (OSError, subprocess.SubprocessError):
        raise SafeFailure("GOOGLE_JWT_SIGNING_FAILED") from None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        return None


class Transport:
    def __init__(self):
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method: str, url: str, headers: dict, data=None,
                *, timeout: int = 60) -> tuple[int, bytes]:
        parsed = urllib.parse.urlsplit(url)
        if (parsed.scheme != "https" or parsed.username or parsed.password
                or parsed.fragment or parsed.netloc not in (
                    "oauth2.googleapis.com", "androidpublisher.googleapis.com")):
            raise SafeFailure("UNTRUSTED_GOOGLE_DESTINATION")
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with self.opener.open(request, timeout=timeout) as response:
                return response.status, response.read(8_388_609)
        except urllib.error.HTTPError as error:
            try:
                with error:
                    raw = error.read(65_537)
            except (OSError, TimeoutError, urllib.error.URLError, http.client.HTTPException):
                raw = b""
            diagnostic = sanitized_google_error(raw, error.code) if len(raw) <= 65_536 else {"http_code": error.code}
            raise SafeFailure(f"GOOGLE_HTTP_{error.code}", google_api_error=diagnostic) from None
        except (OSError, TimeoutError, urllib.error.URLError, http.client.HTTPException):
            code = "GOOGLE_READ_FAILED" if method == "GET" else "GOOGLE_WRITE_OUTCOME_UNKNOWN"
            raise SafeFailure(code) from None


def decode_json(raw: bytes) -> dict:
    try:
        if len(raw) > 8_388_608:
            raise ValueError("response size")
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("response shape")
        return result
    except (ValueError, TypeError):
        raise SafeFailure("GOOGLE_RESPONSE_SHAPE_REJECTED") from None


def authenticate(credentials: dict, transport: Transport) -> str:
    encode = lambda value: base64.urlsafe_b64encode(value).rstrip(b"=")
    now = int(time.time())
    header = encode(canonical({"alg": "RS256", "typ": "JWT"}))
    claims = encode(canonical({"iss": credentials["client_email"], "scope": SCOPE,
                               "aud": TOKEN_URI, "iat": now, "exp": now + 3600}))
    signing_input = header + b"." + claims
    signature = encode(openssl_sign(signing_input, credentials["private_key"]))
    form = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": (signing_input + b"." + signature).decode(),
    }).encode()
    status, raw = transport.request("POST", TOKEN_URI,
                                   {"Content-Type": "application/x-www-form-urlencoded"}, form)
    response = decode_json(raw)
    token = response.get("access_token")
    if status != 200 or not isinstance(token, str) or not token:
        raise SafeFailure("GOOGLE_OAUTH_FAILED")
    return token


def inspect_aab(path: Path) -> dict:
    try:
        if path.suffix.lower() != ".aab" or not path.is_file():
            raise ValueError("artifact type")
        with zipfile.ZipFile(path) as archive:
            if "base/manifest/AndroidManifest.xml" not in archive.namelist():
                raise ValueError("base manifest")
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            while chunk := stream.read(1_048_576):
                digest.update(chunk)
        size = path.stat().st_size
        if size <= 0:
            raise ValueError("empty artifact")
        return {"byte_length": size, "sha256": digest.hexdigest()}
    except (OSError, ValueError, zipfile.BadZipFile):
        raise SafeFailure("SIGNED_AAB_REFERENCE_INVALID") from None


def verify_sealed_android32(root: Path) -> tuple[Path, dict]:
    """Only the already signed/verified exact build32 may use upload recovery."""
    root = root.resolve()
    if not root.is_dir():
        raise SafeFailure("SEALED_ANDROID32_ARTIFACT_ROOT_REQUIRED")

    def receipt(name: str) -> Path:
        matches = list(root.rglob(name))
        if (len(matches) != 1 or not matches[0].is_file() or matches[0].is_symlink()
                or root not in matches[0].resolve().parents):
            raise SafeFailure("SEALED_ANDROID32_RECEIPT_MISSING_OR_DUPLICATED")
        return matches[0]

    def raw(name: str) -> bytes:
        path = receipt(name)
        if path.stat().st_size > 2_097_152:
            raise SafeFailure("SEALED_ANDROID32_RECEIPT_TOO_LARGE")
        return path.read_bytes()

    aab = receipt("app-release.aab")
    artifact = inspect_aab(aab)
    if artifact != {"byte_length": SEALED_ANDROID32["aab_byte_length"],
                    "sha256": SEALED_ANDROID32["aab_sha256"]}:
        raise SafeFailure("SEALED_ANDROID32_AAB_IDENTITY_MISMATCH")
    text = {
        "BIL-source-head.txt": SOURCE_SHA,
        "BIL-control-head.txt": SEALED_ANDROID32["controller_sha"],
        "BIL-build-number.txt": "BUILD_NUMBER=32",
        "BIL-android-aab.size": str(SEALED_ANDROID32["aab_byte_length"]),
        "BIL-android-upload-certificate.txt": "ANDROID_UPLOAD_CERTIFICATE_SHA256=MATCH",
    }
    if any(raw(name).decode().strip() != expected for name, expected in text.items()):
        raise SafeFailure("SEALED_ANDROID32_SOURCE_VERSION_OR_CERTIFICATE_MISMATCH")
    checksum = raw("BIL-android-aab.sha256").decode().strip().split(maxsplit=1)
    if (len(checksum) != 2 or checksum[0] != SEALED_ANDROID32["aab_sha256"]
            or checksum[1] != "build/app/outputs/bundle/release/app-release.aab"):
        raise SafeFailure("SEALED_ANDROID32_CHECKSUM_RECEIPT_MISMATCH")
    if (hashlib.sha256(raw("BIL-store-qa-manifest.json")).hexdigest()
            != SEALED_ANDROID32["manifest_sha256"]
            or not raw("BIL-android-signature.txt").strip()):
        raise SafeFailure("SEALED_ANDROID32_MANIFEST_OR_SIGNATURE_MISMATCH")
    version = decode_json(raw("BIL-android-artifact-version.json"))
    if version != {"package": PACKAGE, "version_name": "1.0.0", "version_code": "32"}:
        raise SafeFailure("SEALED_ANDROID32_NATIVE_VERSION_MISMATCH")
    checkpoint = decode_json(raw("BIL-store-qa-source-android.json"))
    if checkpoint != {
        "source_sha": SOURCE_SHA, "controller_sha": SEALED_ANDROID32["controller_sha"],
        "platform": "android", "build_number": 32, "generated_native_configuration": [],
        "manifest_sha256": SEALED_ANDROID32["manifest_sha256"], "phase": "STORE_QA_ONLY",
        "configuration_gate": "PASS", "original_production_gate": "FAIL",
        "unresolved_review_count": 8,
    }:
        raise SafeFailure("SEALED_ANDROID32_CONFIGURATION_CHECKPOINT_MISMATCH")
    gate_lines = raw("BIL-android-gate-status.txt").decode().splitlines()
    for required in ("NATIVE_CRYPTO_GATE=PASS", "UPSTREAM_EXACT_SOURCE_QA=VERIFIED",
                     "RELEASE_PHASE=STORE_QA_ONLY", "PUBLIC_RELEASE_READY=NO"):
        if gate_lines.count(required) != 1:
            raise SafeFailure("SEALED_ANDROID32_NATIVE_GATE_RECEIPT_MISMATCH")
    return aab, dict(SEALED_ANDROID32, source_sha=SOURCE_SHA,
                     version="1.0.0", build_number=32, rebuild_performed=False)


class PlayClient:
    def __init__(self, token: str, transport: Transport):
        self.token = token
        self.transport = transport
        self.owned_edits: set[str] = set()

    def json(self, method: str, resource: str, body=None) -> dict:
        base = f"/applications/{PACKAGE}/edits"
        if not resource.startswith(base):
            raise SafeFailure("PLAY_PACKAGE_BOUNDARY_REJECTED")
        if resource == base:
            if method != "POST" or body != {}:
                raise SafeFailure("PLAY_OPERATION_BOUNDARY_REJECTED")
        else:
            match = re.match(rf"/applications/{re.escape(PACKAGE)}/edits/([^/:?]+)", resource)
            if not match or match[1] not in self.owned_edits:
                raise SafeFailure("UNOWNED_PLAY_EDIT_REJECTED")
            suffix = resource[len(base + "/" + match[1]):]
            allowed = {("GET", ""), ("DELETE", ""), ("GET", "/tracks"),
                       ("GET", "/bundles"), ("GET", "/apks"),
                       ("PUT", "/tracks/internal"), ("POST", ":validate"),
                       ("POST", ":commit?" + COMMIT_QUERY)}
            if (method, suffix) not in allowed:
                raise SafeFailure("PLAY_OPERATION_BOUNDARY_REJECTED")
            if method == "PUT" and (not isinstance(body, dict) or body.get("track") != "internal"):
                raise SafeFailure("NON_INTERNAL_TRACK_MUTATION_REJECTED")
        headers = {"Authorization": f"Bearer {self.token}", "Accept": "application/json"}
        data = None if body is None else canonical(body)
        if data is not None:
            headers["Content-Type"] = "application/json"
        status, raw = self.transport.request(method, API_ROOT + resource, headers, data)
        if method == "DELETE" and status in (200, 204):
            return {}
        return decode_json(raw)

    def create_edit(self) -> str:
        edit = self.json("POST", f"/applications/{PACKAGE}/edits", {})
        edit_id = edit.get("id")
        if not isinstance(edit_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", edit_id):
            raise SafeFailure("OWN_EDIT_ID_INVALID")
        self.owned_edits.add(edit_id)
        return edit_id

    def upload(self, edit_id: str, aab: Path, artifact: dict) -> dict:
        if edit_id not in self.owned_edits:
            raise SafeFailure("UNOWNED_PLAY_EDIT_REJECTED")
        resource = f"/applications/{PACKAGE}/edits/{edit_id}/bundles?uploadType=media"
        headers = {"Authorization": f"Bearer {self.token}",
                   "Content-Type": "application/octet-stream",
                   "Content-Length": str(artifact["byte_length"])}
        # urllib -> http.client streams this file object with explicit length.
        # No retry on uncertain upload, and no full-AAB allocation in memory.
        with aab.open("rb") as stream:
            status, raw = self.transport.request("POST", UPLOAD_ROOT + resource,
                                                 headers, stream, timeout=300)
        if status not in (200, 201):
            raise SafeFailure("BUNDLE_UPLOAD_RESPONSE_REJECTED")
        return decode_json(raw)


@contextlib.contextmanager
def owned_edit(client: PlayClient, report: dict):
    report["step"] = "CREATE_OWN_EDIT"
    edit_id = client.create_edit()
    state = {"committed": False}
    try:
        yield edit_id, state
    finally:
        if not state["committed"]:
            primary_error = sys.exc_info()[0] is not None
            try:
                client.json("DELETE", f"/applications/{PACKAGE}/edits/{edit_id}")
                report["own_edit_cleanup"].append("DELETE_CONFIRMED")
            except SafeFailure as error:
                report["own_edit_cleanup"].append(error.code)
                if not primary_error:
                    raise SafeFailure("OWN_EDIT_CLEANUP_NOT_CONFIRMED", report) from None


def snapshot(client: PlayClient, edit_id: str) -> dict:
    root = f"/applications/{PACKAGE}/edits/{edit_id}"
    tracks = client.json("GET", root + "/tracks").get("tracks", [])
    bundles = client.json("GET", root + "/bundles").get("bundles", [])
    apks = client.json("GET", root + "/apks").get("apks", [])
    if not all(isinstance(items, list) for items in (tracks, bundles, apks)):
        raise SafeFailure("PLAY_SNAPSHOT_SHAPE_REJECTED")
    names = [track.get("track") for track in tracks]
    if any(not isinstance(name, str) for name in names) or len(set(names)) != len(names):
        raise SafeFailure("PLAY_TRACK_IDENTITY_REJECTED")
    codes = [item.get("versionCode") for item in [*bundles, *apks]]
    for track in tracks:
        for release in track.get("releases", []):
            codes.extend(release.get("versionCodes", []))
    if any(not re.fullmatch(r"\d+", str(code)) for code in codes):
        raise SafeFailure("PLAY_VERSION_CATALOG_REJECTED")
    return {"tracks": tracks, "bundles": bundles, "apks": apks,
            "highest_version_code": max((int(code) for code in codes), default=0)}


def snapshot_receipt(state: dict) -> dict:
    return {"highest_version_code": state["highest_version_code"],
            "bundle_versions": sorted(int(x["versionCode"]) for x in state["bundles"]),
            "apk_versions": sorted(int(x["versionCode"]) for x in state["apks"]),
            "tracks": [{"track": x["track"],
                        "canonical_sha256": hashlib.sha256(canonical(x)).hexdigest(),
                        "releases": [{"status": r.get("status"),
                                      "version_codes": r.get("versionCodes", [])}
                                     for r in x.get("releases", [])]}
                       for x in state["tracks"]]}


def internal_update(before: dict, android: dict, release_version: str) -> dict:
    internal = next((x for x in before["tracks"] if x["track"] == "internal"), None)
    if internal is None:
        raise SafeFailure("EXISTING_INTERNAL_TRACK_IDENTITY_REQUIRED")
    releases = internal.get("releases", [])
    if any(release.get("status") not in ("completed", "halted") for release in releases):
        raise SafeFailure("EXISTING_INTERNAL_DRAFT_OR_PENDING_RELEASE")
    update = copy.deepcopy(internal)
    new_release = {
        "name": f"BIL Store QA {release_version} ({android['build_number']})",
        "versionCodes": [str(android["build_number"])],
        "status": android["release_status"],
    }
    # A completed testing upgrade supersedes its old test release, not any
    # production release. Drafts retain the old serving release until reviewed
    # by the owner. Every previously uploaded bundle remains in the catalog.
    update["releases"] = ([new_release] if android["release_status"] == "completed"
                          else copy.deepcopy(releases) + [new_release])
    return update


def verify_bundle(bundle: dict, expected: int, artifact: dict) -> None:
    if str(bundle.get("versionCode")) != str(expected):
        raise SafeFailure("BUNDLE_VERSION_MISMATCH")
    if bundle.get("sha256", "").lower() != artifact["sha256"]:
        raise SafeFailure("BUNDLE_SHA256_MISMATCH")


def verify_preserved(before: dict, after: dict, expected_internal: dict,
                     android: dict, artifact: dict) -> None:
    old_other = {x["track"]: x for x in before["tracks"] if x["track"] != "internal"}
    new_other = {x["track"]: x for x in after["tracks"] if x["track"] != "internal"}
    if canonical(old_other) != canonical(new_other):
        raise SafeFailure("NON_INTERNAL_TRACK_STATE_CHANGED")
    actual_internal = next((x for x in after["tracks"] if x["track"] == "internal"), None)
    if not isinstance(actual_internal, dict):
        raise SafeFailure("INTERNAL_RELEASE_READBACK_MISMATCH")
    actual_releases = actual_internal.get("releases", [])
    if android["release_status"] == "completed":
        if (not isinstance(actual_releases, list) or len(actual_releases) != 1
                or actual_releases[0].get("status") != "completed"
                or actual_releases[0].get("versionCodes") != [str(android["build_number"])]):
            raise SafeFailure("INTERNAL_RELEASE_READBACK_MISMATCH")
    elif canonical(actual_internal) != canonical(expected_internal):
        raise SafeFailure("INTERNAL_RELEASE_READBACK_MISMATCH")
    matching = [x for x in after["bundles"] if str(x.get("versionCode")) == str(android["build_number"])]
    if len(matching) != 1:
        raise SafeFailure("UPLOADED_BUNDLE_READBACK_MISSING_OR_DUPLICATED")
    verify_bundle(matching[0], android["build_number"], artifact)
    for previous in before["bundles"]:
        if previous not in after["bundles"]:
            raise SafeFailure("PREEXISTING_BUNDLE_STATE_CHANGED")
    if canonical(before["apks"]) != canonical(after["apks"]):
        raise SafeFailure("PREEXISTING_APK_STATE_CHANGED")


def run(manifest: dict, aab: Path | None, client: PlayClient, *, preflight: bool = False,
        publishing_state_checked: bool = False) -> dict:
    android = validate_manifest(manifest)
    report = {"phase": "STORE_QA_ONLY", "package_name": PACKAGE,
              "source_sha": manifest["source_sha"], "expected_version_code": android["build_number"],
              "track": "internal", "release_status": android["release_status"],
              "no_review_submission": True, "no_production_rollout": True,
              "committed": False, "commit_attempted": False,
              "upload_performed": False, "upload_attempted": False, "own_edit_cleanup": [],
              "native_billing_proved": False, "public_release_ready": False,
              "publishing_state": "OWNER_UI_CHECK_NOT_API_PROOF" if publishing_state_checked else "UNVERIFIED",
              "existing_non_internal_pending_changes": "PRESERVE_DO_NOT_SUBMIT_OR_CLEAR"}
    try:
        with owned_edit(client, report) as (edit_id, edit_state):
            report["step"] = "READ_PREUPLOAD_CATALOG"
            before = snapshot(client, edit_id)
            report["before"] = snapshot_receipt(before)
            if preflight:
                report["mode"] = "PREFLIGHT_NO_UPLOAD_NO_COMMIT"
            else:
                if not publishing_state_checked:
                    raise SafeFailure("OWNER_PENDING_EDITS_AND_REVIEW_CHECK_REQUIRED")
                if android["build_number"] <= before["highest_version_code"]:
                    raise SafeFailure("NEW_VERSION_NOT_ABOVE_EXISTING_CATALOG")
                update = internal_update(before, android, manifest["release_version"])
                if aab is None:
                    raise SafeFailure("SIGNED_AAB_REFERENCE_REQUIRED")
                artifact = inspect_aab(aab)
                report["artifact"] = artifact
                report["upload_attempted"] = True
                report["upload_performed"] = None  # Until a response proves its outcome.
                report["step"] = "UPLOAD_BUNDLE"
                uploaded = client.upload(edit_id, aab, artifact)
                report["upload_performed"] = True
                verify_bundle(uploaded, android["build_number"], artifact)
                if inspect_aab(aab) != artifact:
                    raise SafeFailure("AAB_CHANGED_DURING_UPLOAD")
                root = f"/applications/{PACKAGE}/edits/{edit_id}"
                # Only the existing internal track is updated. A completed
                # upgrade replaces the old test release; all other tracks and
                # all preexisting bundle/APK catalog entries remain unchanged.
                report["step"] = "UPDATE_INTERNAL_TRACK"
                client.json("PUT", root + "/tracks/internal", update)
                report["step"] = "READ_STAGED_CATALOG"
                staged = snapshot(client, edit_id)
                verify_preserved(before, staged, update, android, artifact)
                report["step"] = "VALIDATE_OWN_EDIT"
                try:
                    client.json("POST", root + ":validate")
                    report["precommit_validation"] = "SUCCESS"
                except SafeFailure as error:
                    # Live Discovery: validate has no no-review query parameter.
                    # Official Edits workflow: commit itself performs validation.
                    # Only this exact observed contradiction delegates validation
                    # to the unchanged, protected no-review commit below.
                    if (error.code != "GOOGLE_HTTP_400"
                            or error.google_api_error != OBSERVED_NO_REVIEW_VALIDATION_ERROR):
                        raise
                    report["precommit_validation"] = "NO_REVIEW_PARAMETER_UNSUPPORTED_USE_PROTECTED_COMMIT"
                    report["precommit_validation_api_error"] = error.google_api_error
                report["commit_attempted"] = True
                report["committed"] = None  # Never assert false for an ambiguous write.
                report["step"] = "COMMIT_NO_REVIEW"
                client.json("POST", root + ":commit?" + COMMIT_QUERY)
                edit_state["committed"] = True
                report["committed"] = True
        if preflight:
            return report
        with owned_edit(client, report) as (read_edit, _):
            report["step"] = "READ_FRESH_COMMITTED_CATALOG"
            after = snapshot(client, read_edit)
            verify_preserved(before, after, update, android, artifact)
            report["after"] = snapshot_receipt(after)
        report["mode"] = "UPLOAD_AND_FRESH_READBACK_COMPLETED"
        report["step"] = "COMPLETE"
        report["installation_boundary"] = (
            "NOT_INSTALLABLE_DRAFT" if android["release_status"] == "draft"
            else "NATIVE_INSTALL_ELIGIBILITY_AND_BILLING_UNVERIFIED")
        return report
    except SafeFailure as error:
        error.report = report
        raise


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--aab")
    parser.add_argument("--sealed-artifact-root",
                        help="Upload-only recovery of the hard-pinned already signed build32")
    parser.add_argument("--credentials", help="Existing service-account JSON reference; values never logged")
    parser.add_argument("--preflight", action="store_true")
    parser.add_argument("--owner-publishing-state-checked", action="store_true",
                        help="Owner inspected pending edits/review state; preserve pending non-internal changes, never submit them")
    arguments = parser.parse_args(argv)
    try:
        manifest = load_manifest(Path(arguments.manifest), os.environ)
        sealed = None
        aab = Path(arguments.aab) if arguments.aab else None
        if arguments.sealed_artifact_root:
            if arguments.preflight or arguments.aab or manifest["android"]["build_number"] != 32:
                raise SafeFailure("SEALED_ANDROID32_RECOVERY_BOUNDARY_REJECTED")
            aab, sealed = verify_sealed_android32(Path(arguments.sealed_artifact_root))
            if os.environ.get(MANIFEST_DIGEST_ENV) != SEALED_ANDROID32["manifest_sha256"]:
                raise SafeFailure("SEALED_ANDROID32_MANIFEST_IDENTITY_MISMATCH")
        if not arguments.preflight and (aab is None or not arguments.owner_publishing_state_checked):
            raise SafeFailure("UPLOAD_REQUIRES_AAB_AND_OWNER_PUBLISHING_STATE_CHECK")
        transport = Transport()
        client = PlayClient(authenticate(load_credentials(arguments.credentials), transport), transport)
        report = run(manifest, aab, client,
                     preflight=arguments.preflight,
                     publishing_state_checked=arguments.owner_publishing_state_checked)
        if sealed:
            report["sealed_artifact_recovery"] = sealed
        print(json.dumps(report, sort_keys=True))
        return 0
    except SafeFailure as error:
        print(json.dumps({"result": "FAILED_CLOSED", "code": error.code,
                          "report": error.report,
                          "google_api_error": error.google_api_error}, sort_keys=True))
    except Exception:
        print(json.dumps({"result": "FAILED_CLOSED", "code": "LOCAL_INPUT_OR_RESPONSE_INVALID"}))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
