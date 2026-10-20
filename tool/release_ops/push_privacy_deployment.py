"""Fixed-scope community-push-dispatch deployment evidence; no schema APIs.

The deployment itself remains one explicit, pinned Supabase CLI command in the
workflow. This helper uses Management GETs and deliberately unauthorized Edge
requests only. It never receives the dispatch secret or invokes a valid push.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

PROJECT = "tgmanzhqulksykhslrzb"
SLUG = "community-push-dispatch"
SOURCE = "6bf23994712ffbdcb2d8179defec5852e5d08ae1"
FUNCTION_ID = "ba01cf66-fe1f-486e-9c8c-31248d3ad33c"
PREVIOUS_VERSION = 56
PREVIOUS_BUNDLE = "d7f2aae00790ad1e4936f6782ad8d4034cc822b313c4536074b7463225256162"
META_KEYS = ("id", "slug", "name", "status", "version", "verify_jwt", "import_map", "ezbr_sha256")


class GuardFailure(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise GuardFailure("unexpected_redirect")


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def sanitized_metadata(value: dict) -> dict:
    return {key: value.get(key) for key in META_KEYS}


def validate_previous(value: dict) -> None:
    expected = {"id": FUNCTION_ID, "slug": SLUG, "name": SLUG,
                "status": "ACTIVE", "version": PREVIOUS_VERSION,
                "verify_jwt": False, "import_map": False, "ezbr_sha256": PREVIOUS_BUNDLE}
    if sanitized_metadata(value) != expected:
        raise GuardFailure("previous_function_identity_or_version_changed")


def other_functions(rows: list[dict]) -> list[dict]:
    return sorted((sanitized_metadata(row) for row in rows
                   if row.get("slug") != SLUG), key=lambda row: str(row["slug"]))


def require_others_unchanged(before: list[dict], after: list[dict]) -> None:
    if before != after:
        raise GuardFailure("another_function_changed_during_single_function_operation")


def source_manifest(root: Path, allow_tests: bool = False) -> dict[str, str]:
    if not root.is_dir() or root.is_symlink():
        raise GuardFailure("source_directory_missing_or_linked")
    expected = {"index.ts", "server.ts"}
    code = {p.relative_to(root).as_posix() for p in root.rglob("*")
            if p.is_file() and p.suffix in (".ts", ".js", ".mjs")}
    if allow_tests:
        code = {name for name in code if not name.endswith("_test.ts")}
    if code != expected:
        raise GuardFailure("unexpected_function_module_set")
    result = {}
    for name in sorted(expected):
        path = root / name
        if path.is_symlink() or path.stat().st_size > 1024 * 1024:
            raise GuardFailure("source_file_unsafe")
        result[name] = digest(path.read_bytes())
    return result


def require_same_source(actual: dict, expected: dict) -> None:
    if actual != expected:
        raise GuardFailure("deployed_function_source_does_not_match_tested_source")


def management(path: str, binary: bool = False):
    allowed = {"", "/" + SLUG, "/" + SLUG + "/body"}
    if path not in allowed:
        raise GuardFailure("management_resource_out_of_scope")
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        raise GuardFailure("missing_existing_management_credential")
    request = urllib.request.Request(
        "https://api.supabase.com/v1/projects/" + PROJECT + "/functions" + path,
        headers={"Authorization": "Bearer " + token,
                 "Accept": "application/octet-stream" if binary else "application/json",
                 "Accept-Encoding": "identity"}, method="GET")
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=45) as response:
            raw = response.read(16 * 1024 * 1024 + 1)
            if len(raw) > 16 * 1024 * 1024:
                raise GuardFailure("management_response_too_large")
            if binary:
                return raw, {"content_type": response.headers.get("Content-Type"),
                             "content_encoding": response.headers.get("Content-Encoding")}
            return json.loads(raw)
    except urllib.error.HTTPError as error:
        raise GuardFailure("management_get_http_" + str(error.code)) from None


def validate_unauthorized(status: int, payload: object) -> None:
    if status != 401 or payload != {"error": "unauthorized"}:
        raise GuardFailure("unauthorized_probe_did_not_fail_at_dispatch_secret_boundary")


def negative_smoke(opener=None) -> list[dict]:
    opener = opener or urllib.request.build_opener(NoRedirect())
    observations = []
    for label, extra in (("no_dispatch_secret", {}),
                         ("wrong_dispatch_secret", {"x-bil-dispatch-secret": "public-negative-probe-not-a-secret"})):
        request = urllib.request.Request(
            "https://" + PROJECT + ".supabase.co/functions/v1/" + SLUG,
            data=b"{}", headers={"Content-Type": "application/json", **extra},
            method="POST")
        try:
            response = opener.open(request, timeout=20)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            raw = response.read(4097)
            if len(raw) > 4096:
                raise GuardFailure("unauthorized_probe_response_too_large")
            status = response.code
            try:
                payload = json.loads(raw)
            except ValueError:
                raise GuardFailure("unauthorized_probe_response_not_json") from None
        validate_unauthorized(status, payload)
        observations.append({"probe": label, "http_status": status,
                             "dispatch_authenticated": False,
                             "push_dispatch_path_entered": False})
    return observations


def run(mode: str, output: Path, source_root: Path | None = None) -> None:
    output.mkdir(parents=True, exist_ok=True)
    if mode == "preflight":
        current = management("/" + SLUG)
        validate_previous(current)
        rows = management("")
        raw, headers = management("/" + SLUG + "/body", binary=True)
        if not raw:
            raise GuardFailure("empty_previous_bundle")
        (output / "previous-function.bundle").write_bytes(raw)
        write_json(output / "before-function.json", sanitized_metadata(current))
        write_json(output / "before-other-functions.json", other_functions(rows))
        write_json(output / "previous-bundle.json", {"sha256": digest(raw), "bytes": len(raw), **headers})
        write_json(output / "before-negative-smoke.json", negative_smoke())
    elif mode == "recheck":
        current = management("/" + SLUG)
        validate_previous(current)
        before = json.loads((output / "before-other-functions.json").read_text())
        require_others_unchanged(before, other_functions(management("")))
        write_json(output / "immediate-pre-deploy.json", sanitized_metadata(current))
    elif mode in ("snapshot-source", "expected-source", "staged-source", "post-source"):
        if source_root is None:
            raise GuardFailure("source_root_required")
        manifest = source_manifest(source_root, allow_tests=mode == "expected-source")
        if mode in ("staged-source", "post-source"):
            require_same_source(manifest, json.loads((output / "expected-source.json").read_text()))
        write_json(output / ("previous-source.json" if mode == "snapshot-source" else
                             "expected-source.json" if mode == "expected-source" else
                             "staged-source.json" if mode == "staged-source" else
                             "deployed-source.json"), manifest)
    elif mode == "postverify":
        current = management("/" + SLUG)
        if (current.get("id") != FUNCTION_ID or current.get("slug") != SLUG
                or current.get("name") != SLUG or current.get("status") != "ACTIVE"
                or current.get("verify_jwt") is not False
                or current.get("import_map") is not False
                or not isinstance(current.get("version"), int)
                or current["version"] <= PREVIOUS_VERSION):
            raise GuardFailure("deployed_metadata_invalid")
        before = json.loads((output / "before-other-functions.json").read_text())
        after = other_functions(management(""))
        require_others_unchanged(before, after)
        write_json(output / "after-function.json", sanitized_metadata(current))
        write_json(output / "after-other-functions.json", after)
        write_json(output / "after-negative-smoke.json", negative_smoke())
        write_json(output / "deployment-result.json", {"status": "DEPLOYED_AND_NEGATIVE_AUTH_VERIFIED",
            "application_source": SOURCE, "project": PROJECT, "function": SLUG,
            "version": current["version"], "verify_jwt": False,
            "other_functions_unchanged": True, "schema_changed": False,
            "authorized_dispatch_invoked": False, "physical_push_delivery_proven": False})
    else:
        raise GuardFailure("unknown_mode")


if __name__ == "__main__":
    try:
        if len(sys.argv) not in (3, 4):
            raise GuardFailure("mode_output_and_optional_source_root_required")
        run(sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]) if len(sys.argv) == 4 else None)
    except Exception as error:
        # HTTP/CLI error bodies must never be included: they may contain secrets.
        reason = str(error) if isinstance(error, GuardFailure) else "deployment_evidence_internal_error"
        print(json.dumps({"status": "FAILED_OR_BLOCKED", "reason": reason}))
        sys.exit(1)
