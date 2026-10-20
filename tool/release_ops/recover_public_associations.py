"""Read public association caches and already-enabled known Worker previews only."""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys
from urllib.parse import urlencode

from public_site_diagnosis import cf_get, classify, fetch, json_write, object_rows, sha, shape

# Bound to the prior GET-only report and Oct18 deploy logs; never resolve a
# different project or accept arbitrary account/version/input URLs.
ACCOUNT = "992830d7894ba09161ff0a411fe4154b"
VERSIONS = {"last_good_20261018": "7e894d19-6b82-44d3-bac2-9e41e087cdb0",
            "active_observed_20261019": "6a7dab10-616e-455c-9345-61afad429750"}
PATHS = {"aasa": "/.well-known/apple-app-site-association", "assetlinks": "/.well-known/assetlinks.json"}


def candidate_document(kind, raw):
    """Keep public document bytes, but never arbitrary error/debug payloads."""
    try:
        value = json.loads(raw)
    except (ValueError, TypeError):
        return None
    if kind == "aasa" and isinstance(value, dict) and isinstance(value.get("applinks"), dict):
        details = value["applinks"].get("details")
        return raw if isinstance(details, list) and bool(details) else None
    if kind == "assetlinks" and isinstance(value, list) and value:
        return raw if all(isinstance(row, dict) for row in value) else None
    if kind == "dal" and isinstance(value, dict) and isinstance(value.get("statements"), list) and value["statements"]:
        # DAL's debugString may quote an origin error body. It is deliberately
        # excluded; raw response hash is still retained separately.
        safe = {"statements": value["statements"], "maxAge": value.get("maxAge")}
        return (json.dumps(safe, indent=2, ensure_ascii=False) + "\n").encode()
    return None


def version_summary(value):
    if not isinstance(value, dict):
        return {"result_shape": shape(value)}
    result = {key: value.get(key) for key in ("id", "number")}
    metadata = value.get("metadata")
    if isinstance(metadata, dict):
        result["metadata"] = {key: metadata.get(key) for key in ("created_on", "source")}
    resources = value.get("resources")
    if isinstance(resources, dict):
        result["binding_names_and_types_only"] = [{"name": row.get("name"), "type": row.get("type")}
            for row in object_rows(resources.get("bindings"), "bindings", result)]
        script = resources.get("script")
        if isinstance(script, dict):
            result["script"] = {key: script.get(key) for key in ("etag", "handlers", "last_deployed_from")}
    return result


def preview_base(subdomain, enabled, version):
    if enabled is not True or not isinstance(subdomain, str) or not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", subdomain):
        return None
    if version not in VERSIONS.values():
        return None
    # Cloudflare's documented immutable version URL uses the UUID's first
    # eight characters. Only the two already-observed version IDs are allowed.
    return f"https://{version[:8]}-bilhealth.{subdomain}.workers.dev"


def collect(output):
    report = {"mode": "READ_ONLY_ASSOCIATION_RECOVERY_CANDIDATES", "mutations": 0,
              "origin_repaired": False, "identities_independently_verified": False,
              "public_sources": {}, "cloudflare_reads": {}, "phase": "initial"}
    output.mkdir(parents=True, exist_ok=True)

    def checkpoint(phase):
        report["phase"] = phase
        json_write(output / "association-recovery-report.json", report)

    def public(label, url, kind):
        checkpoint(label)
        record, raw = fetch(url, {"User-Agent": "BIL-owner-association-recovery/1.0", "Accept": "application/json"})
        if record.get("http_status") is not None:
            classify(record, raw)
        candidate = candidate_document(kind, raw) if record.get("http_status") == 200 and not record.get("body_truncated") else None
        if candidate is not None:
            name = label + ".json"
            (output / name).write_bytes(candidate)
            record.update(candidate_file=name, candidate_sha256=sha(candidate), candidate_kind=kind,
                          candidate_status="UNVERIFIED_RECOVERY_SOURCE_ONLY")
        report["public_sources"][label] = record
        checkpoint(label + "_complete")

    def cf(label, path):
        checkpoint(label)
        safe, value, _ = cf_get(path)
        report["cloudflare_reads"][label] = safe
        checkpoint(label + "_complete")
        return safe, value

    try:
        for host, label in (("www.bilhealth.com", "www"), ("bilhealth.com", "apex")):
            public("apple_cdn_" + label, "https://app-site-association.cdn-apple.com/a/v1/" + host, "aasa")
            query = urlencode({"source.web.site": "https://" + host,
                               "relation": "delegate_permission/common.handle_all_urls"})
            public("google_dal_" + label, "https://digitalassetlinks.googleapis.com/v1/statements:list?" + query, "dal")
        account_safe, account_domain = cf("account_subdomain", f"/accounts/{ACCOUNT}/workers/subdomain")
        script_safe, script_domain = cf("script_subdomain", f"/accounts/{ACCOUNT}/workers/scripts/bilhealth/subdomain")
        subdomain = account_domain.get("subdomain") if isinstance(account_domain, dict) else None
        enabled = script_domain.get("previews_enabled") if isinstance(script_domain, dict) else None
        report["existing_preview_configuration"] = {"account_subdomain": subdomain if isinstance(subdomain, str) and re.fullmatch(r"[a-z0-9-]{1,63}", subdomain) else None,
            "previews_enabled": enabled if isinstance(enabled, bool) else None,
            "configuration_changed": False}
        for label, version in VERSIONS.items():
            safe, value = cf("version_" + label, f"/accounts/{ACCOUNT}/workers/scripts/bilhealth/versions/{version}")
            safe["version_summary"] = version_summary(value)
            safe["version_id_matches_requested"] = isinstance(value, dict) and value.get("id") == version
            base = preview_base(subdomain, enabled, version) if account_safe.get("success") and script_safe.get("success") and safe.get("success") and safe["version_id_matches_requested"] else None
            if base is not None:
                for kind, path in PATHS.items():
                    public(label + "_" + kind, base + path, kind)
        report.update(collection_status="COMPLETE", candidate_count=sum("candidate_file" in row for row in report["public_sources"].values()))
        checkpoint("complete")
        print(json.dumps({"collection_status": "COMPLETE", "candidate_count": report["candidate_count"], "origin_repaired": False, "mutations": 0}))
        return True
    except Exception as exception:
        report.update(collection_status="FAILED_WITH_PARTIAL_EVIDENCE", error_type=type(exception).__name__)
        json_write(output / "association-recovery-report.json", report)
        return False


if __name__ == "__main__":
    raise SystemExit(0 if collect(Path(sys.argv[1])) else 1)
