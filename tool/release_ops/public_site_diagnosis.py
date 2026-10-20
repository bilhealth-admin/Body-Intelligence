"""Read-only endpoint and Cloudflare evidence. No deployments or test retries."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from email import policy
from email.parser import BytesParser
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib import error, request

WORKOUT_MANIFEST = "https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json"
HEADERS = {"server", "date", "content-type", "content-length", "cache-control", "cf-ray",
           "cf-cache-status", "cf-mitigated", "retry-after", "location", "x-content-type-options"}
MARKERS = {"Association document is invalid.": "BIL_WORKER_ASSOCIATION_CONTRACT_REJECTION",
           "Association asset binding is unavailable.": "BIL_WORKER_ASSET_BINDING_MISSING",
           "Association document not found.": "BIL_WORKER_ASSET_NOT_FOUND_OR_HTML",
           "Policy document is temporarily unavailable.": "BIL_WORKER_POLICY_ASSET_REJECTION",
           "Sorry, you have been blocked": "CLOUDFLARE_BLOCK_PAGE",
           "Just a moment...": "CHALLENGE_PAGE",
           "Error 503": "GENERIC_ERROR_503", "Service Temporarily Unavailable": "GENERIC_503_TITLE",
           "DNS resolution error": "DNS_ERROR_PAGE"}
POLICIES = ("/privacy", "/terms", "/subscription-terms", "/health-disclaimer",
            "/account-deletion", "/data-deletion", "/support", "/community-guidelines", "/contact")


class NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def json_write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def fetch(url, headers=None, limit=2 * 1024 * 1024):
    started = time.time()
    req = request.Request(url, headers=headers or {}, method="GET")
    try:
        response = request.build_opener(NoRedirect()).open(req, timeout=25)
    except error.HTTPError as http_error:
        response = http_error
    except Exception as transport_error:
        return {"url": url, "started_unix": started, "http_status": None,
                "transport_error": type(transport_error).__name__, "elapsed_ms": round((time.time()-started)*1000)}, b""
    with response:
        raw = response.read(limit + 1)
        safe_headers = {key.lower(): value for key, value in response.headers.items() if key.lower() in HEADERS}
        record = {"url": url, "started_unix": started, "http_status": response.code,
                  "headers": safe_headers, "elapsed_ms": round((time.time()-started)*1000),
                  "body_bytes_observed": len(raw), "body_truncated": len(raw) > limit,
                  "body_sha256": sha(raw)}
        return record, raw


def classify(record, raw):
    text = raw[:8192].decode("utf-8", "replace")
    record["safe_body_markers"] = [value for key, value in MARKERS.items() if key in text]
    record["safe_error_excerpt"] = next((key for key in MARKERS if key in text), None)
    try:
        parsed = json.loads(raw)
        record["json_parsed"] = isinstance(parsed, (dict, list))
        if record["url"].endswith("apple-app-site-association") and isinstance(parsed, dict):
            applinks = parsed.get("applinks")
            details = applinks.get("details") if isinstance(applinks, dict) else []
            if not isinstance(details, list):
                details = []
            record["association_summary"] = [{"appIDs": row.get("appIDs", [row.get("appID")]),
                  "components": row.get("components"), "paths": row.get("paths")}
                  for row in details if isinstance(row, dict)]
        if record["url"].endswith("assetlinks.json") and isinstance(parsed, list):
            record["association_summary"] = [{"relation": row.get("relation"), "target": row.get("target")}
                  for row in parsed if isinstance(row, dict)]
    except (ValueError, TypeError):
        record["json_parsed"] = False
    if record["headers"].get("cf-mitigated") == "challenge":
        record["diagnostic_hint"] = "CLOUDFLARE_CHALLENGE_HEADER"
    elif any(value.startswith("BIL_WORKER_") for value in record["safe_body_markers"]):
        record["diagnostic_hint"] = "APPLICATION_WORKER_FAIL_CLOSED_RESPONSE"
    elif record["http_status"] == 503:
        record["diagnostic_hint"] = "503_SOURCE_UNRESOLVED_REQUIRES_CF_CONFIG_AND_SOURCE"
    return record


def endpoint_probe(spec):
    url, agent, required, window = spec
    record, raw = fetch(url, {"User-Agent": agent, "Accept": "*/*"})
    record.update(user_agent=agent, required_release_endpoint=required, sample_window=window)
    if record.get("http_status") is not None:
        classify(record, raw)
    return record


def public_endpoints(output, delay=20):
    specs = []
    release_agent = "BIL-release-verifier/1.0"
    for base in ("https://www.bilhealth.com", "https://bilhealth.com"):
        for path in ("/", "/.well-known/apple-app-site-association", "/.well-known/assetlinks.json", "/app-ads.txt", *POLICIES, "/privacy?lang=ar"):
            specs.append((base + path, release_agent, base.endswith("www.bilhealth.com"), "initial"))
    specs.append((WORKOUT_MANIFEST, release_agent, True, "initial"))
    # Separate diagnostic UA observations, not retries used to turn a test green.
    for agent in ("curl/8.14.1", "Mozilla/5.0 BIL-owner-diagnostic"):
        specs.append(("https://www.bilhealth.com/.well-known/apple-app-site-association", agent, False, "ua-comparison"))
    with ThreadPoolExecutor(max_workers=5) as executor:
        observations = list(executor.map(endpoint_probe, specs))
    json_write(output / "public-observations-initial.json", observations)
    # A second timestamped sample characterizes persistence; both outcomes stay
    # in the evidence and the original failure can never be erased by success.
    time.sleep(delay)
    follow = [("https://www.bilhealth.com/.well-known/apple-app-site-association", release_agent, False, "later-sample"),
              ("https://bilhealth.com/.well-known/apple-app-site-association", release_agent, False, "later-sample")]
    observations += [endpoint_probe(spec) for spec in follow]
    required = [row for row in observations if row["required_release_endpoint"]]
    report = {"mode": "READ_ONLY_DIAGNOSIS_NO_DEPLOYMENT", "requests_are_get_only": True,
              "retries_used_for_acceptance": False, "observations": observations,
              "collection_status": "COMPLETE", "release_transport_status":
              "ALL_INITIAL_REQUIRED_HTTP_200" if all(row["http_status"] == 200 for row in required) else "FAILED_OR_BLOCKED"}
    json_write(output / "public-endpoint-diagnosis.json", report)
    print(json.dumps({"collection_status": report["collection_status"], "release_transport_status": report["release_transport_status"], "observations": len(observations)}))
    return report["release_transport_status"] == "ALL_INITIAL_REQUIRED_HTTP_200"


def cf_get(resource):
    # Every path is fixed by this helper after validating API-returned IDs.
    token = os.environ.get("CLOUDFLARE_API_TOKEN")
    if not token:
        return {"http_status": None, "success": False, "error_codes": ["MISSING_EXISTING_TOKEN"]}, None, b""
    record, raw = fetch("https://api.cloudflare.com/client/v4" + resource,
                        {"Authorization": "Bearer " + token, "Accept": "application/json"}, 16*1024*1024)
    safe = {"http_status": record.get("http_status"), "response_sha256": record.get("body_sha256"),
            "content_type": record.get("headers", {}).get("content-type"),
            "body_truncated": record.get("body_truncated", False)}
    try:
        value = json.loads(raw)
        safe["success"] = value.get("success") is True and not safe["body_truncated"]
        safe["error_codes"] = [item.get("code") for item in value.get("errors", []) if isinstance(item, dict)]
        return safe, value.get("result"), raw
    except (ValueError, AttributeError):
        safe.update(success=record.get("http_status") == 200 and not safe["body_truncated"])
        return safe, None, raw


def valid_id(value):
    if not isinstance(value, str) or not re.fullmatch("[a-f0-9]{32}", value):
        raise ValueError("invalid_api_resource_id")
    return value


def worker_code_summary(raw, expected_hash, content_type=""):
    # Script responses may be JS directly or multipart. Never upload source or
    # secret binding values; only code/module hashes and known marker booleans.
    modules = []
    if (content_type or "").lower().startswith("multipart/"):
        message = BytesParser(policy=policy.default).parsebytes(
            ("Content-Type: " + content_type + "\r\nMIME-Version: 1.0\r\n\r\n").encode() + raw)
        for part in message.iter_parts():
            name = part.get_filename() or part.get_param("name", header="content-disposition") or "unnamed"
            if name.endswith((".mjs", ".js")) or part.get_content_type() in ("application/javascript", "text/javascript"):
                code = part.get_payload(decode=True) or b""
                modules.append((str(name)[:160], code))
    elif "javascript" in (content_type or "") or not (content_type or "").startswith("application/json"):
        modules.append(("plain-script-response", raw))
    text = b"\n".join(code for _, code in modules).decode("utf-8", "replace")
    return {"response_sha256": sha(raw), "response_bytes": len(raw),
            "modules": [{"name": name, "bytes": len(code), "sha256": sha(code),
                         "matches_candidate_worker": sha(code) == expected_hash} for name, code in modules],
            "candidate_worker_module_found": any(sha(code) == expected_hash for _, code in modules),
            "has_association_invalid_guard": "Association document is invalid." in text,
            "has_asset_binding_guard": "Association asset binding is unavailable." in text,
            "has_bounded_member_requirement": "repeat(32)" in text and "/download" in text,
            "requires_auth_return_paths": "/auth/callback" in text and "/auth/reset-password" in text}


def settings_summary(value):
    return {"configuration": {key: value.get(key) for key in
            ("compatibility_date", "compatibility_flags", "usage_model", "assets", "limits")},
            "binding_names_and_types_only": [{"name": item.get("name"), "type": item.get("type")}
            for item in value.get("bindings", []) if isinstance(item, dict)]}


def cloudflare(output, candidate_root):
    result = {"mode": "CLOUDFLARE_GET_ONLY_NO_MUTATION", "requests_are_get_only": True, "resources": {}}
    safe, accounts, _ = cf_get("/accounts?page=1&per_page=50")
    result["resources"]["accounts"] = safe
    if not safe["success"] or not isinstance(accounts, list) or len(accounts) != 1:
        result["status"] = "BLOCKED_ACCOUNT_RESOLUTION"
        json_write(output / "cloudflare-diagnosis.json", result)
        return False
    account = valid_id(accounts[0].get("id"))
    result["account_id"] = account
    expected = sha((candidate_root / "tool/release/bilhealth_site_worker.mjs").read_bytes())
    result["candidate_worker_sha256"] = expected
    settings, value, _ = cf_get(f"/accounts/{account}/workers/scripts/bilhealth/settings")
    if isinstance(value, dict):
        settings.update(settings_summary(value))
    result["resources"]["worker_settings"] = settings
    script, _, raw = cf_get(f"/accounts/{account}/workers/scripts/bilhealth")
    if script["success"]:
        script["source_fingerprints"] = worker_code_summary(raw, expected, script.get("content_type"))
    result["resources"]["worker_script"] = script
    deployments, value, _ = cf_get(f"/accounts/{account}/workers/scripts/bilhealth/deployments")
    if isinstance(value, dict):
        deployments["deployments"] = [{key: row.get(key) for key in ("id", "strategy", "created_on", "versions")} for row in value.get("deployments", [])]
    result["resources"]["worker_deployments"] = deployments
    domains, value, _ = cf_get(f"/accounts/{account}/workers/domains")
    if isinstance(value, list):
        domains["matching_public_domains"] = [{key: row.get(key) for key in ("hostname", "service", "environment", "zone_id")} for row in value if row.get("hostname") in ("bilhealth.com", "www.bilhealth.com", "workouts.bilhealth.com")]
    result["resources"]["worker_domains"] = domains
    zone, zones, _ = cf_get("/zones?name=bilhealth.com&per_page=50")
    result["resources"]["zone_lookup"] = zone
    if zone["success"] and isinstance(zones, list) and len(zones) == 1:
        zone_id = valid_id(zones[0].get("id"))
        result["zone"] = {"id": zone_id, "name": zones[0].get("name"), "status": zones[0].get("status")}
        routes, value, _ = cf_get(f"/zones/{zone_id}/workers/routes")
        if isinstance(value, list):
            routes["routes"] = [{key: row.get(key) for key in ("id", "pattern", "script")} for row in value]
        result["resources"]["worker_routes"] = routes
        rulesets, value, _ = cf_get(f"/zones/{zone_id}/rulesets")
        if isinstance(value, list):
            rulesets["ruleset_phases"] = [{key: row.get(key) for key in ("id", "kind", "phase", "version", "last_updated")} for row in value if isinstance(row, dict)]
        result["resources"]["zone_ruleset_inventory"] = rulesets
        for hostname in ("bilhealth.com", "www.bilhealth.com", "workouts.bilhealth.com"):
            dns, value, _ = cf_get(f"/zones/{zone_id}/dns_records?name={hostname}&per_page=50")
            if isinstance(value, list):
                dns["public_records"] = [{key: row.get(key) for key in ("type", "name", "content", "proxied", "ttl")} for row in value]
            result["resources"]["dns_" + hostname] = dns
    result["status"] = "READS_COMPLETE_WITH_EXPLICIT_PERMISSION_LIMITS"
    json_write(output / "cloudflare-diagnosis.json", result)
    print(json.dumps({"status": result["status"], "mutations": 0}))
    return True


if __name__ == "__main__":
    mode, output = sys.argv[1], Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    try:
        okay = public_endpoints(output) if mode == "public" else cloudflare(output, Path(sys.argv[3])) if mode == "cloudflare" else False
        raise SystemExit(0 if okay else 1)
    except SystemExit:
        raise
    except Exception as exception:
        json_write(output / "diagnostic-failure.json", {"status": "DIAGNOSTIC_FAILED", "error_type": type(exception).__name__, "mutations": 0})
        raise SystemExit(1)
