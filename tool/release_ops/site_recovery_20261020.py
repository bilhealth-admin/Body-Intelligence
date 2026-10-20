"""One-time guarded site recovery; preflight is read-only, deploy is explicit."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from email import policy
from email.parser import BytesParser
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import time
from urllib import error, request
from urllib.parse import urljoin, urlparse
import zipfile

from public_site_diagnosis import HEADERS, NoRedirect, POLICIES, cf_get, json_write, settings_summary, sha

REPO = "bilhealth-admin/Body-Intelligence"
SOURCE = "6bf23994712ffbdcb2d8179defec5852e5d08ae1"
ACCOUNT = "992830d7894ba09161ff0a411fe4154b"
ZONE = "e708fe2da78d3ce527d80624331c5adb"
DEPLOYMENT = "27daaf4f-b504-4070-8c9c-056868a71ce8"
VERSION = "6a7dab10-616e-455c-9345-61afad429750"
ACTIVE_CODE = "a25d4ea87e151c8ed943454860eb4641aab82c55de73e9a026fb75d544634112"
ARTIFACT = 12261612694
RECOVERY_RUN = 39416437646
RECOVERY_CONTROLLER = "b081b72ad424c73d1f08c3c9d71646c3f207cb6b"
ZIP_SHA = "0ad78706c67504d8a62abce22745d8da6bab47bcf74c1db897038219e41571ad"
ASSOCIATIONS = {
    "apple-app-site-association": {"member": "last_good_20261018_aasa.json", "label": "last_good_20261018_aasa", "sha256": "f5b4e673f08264b75cf635b1a87da96ee85c96395f6b4979a33e8185b79cb455"},
    "assetlinks.json": {"member": "last_good_20261018_assetlinks.json", "label": "last_good_20261018_assetlinks", "sha256": "5c6ae8e11182a7b60a5264a793e81cf8fd3cc69cd581ba4ad66f61e263786143"},
}
IGNORED = {".assetsignore", "_headers", "_redirects", "README.md", "tmp_index_current.txt"}
BASE = "https://www.bilhealth.com"
PUBLIC_CONFIG_HEADERS = {"content-language", "content-security-policy", "strict-transport-security", "permissions-policy", "referrer-policy", "x-frame-options"}


def require(condition, code):
    if not condition:
        raise ValueError(code)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def command(args, cwd=None):
    completed = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(completed.returncode == 0, "COMMAND_FAILED:" + args[0])
    return completed.stdout


def gh(path):
    return json.loads(command(["gh", "api", f"repos/{REPO}/" + path]))


def artifact_documents(metadata, raw, report):
    require(metadata.get("id") == ARTIFACT and metadata.get("expired") is False and
        metadata.get("name") == f"association-recovery-candidates-{RECOVERY_RUN}" and
        metadata.get("workflow_run", {}).get("id") == RECOVERY_RUN and
        metadata["workflow_run"].get("head_sha") == RECOVERY_CONTROLLER,
        "RECOVERY_ARTIFACT_BINDING_MISMATCH")
    require(0 < len(raw) <= 2 * 1024 * 1024 and sha(raw) == ZIP_SHA and metadata.get("digest") == "sha256:" + ZIP_SHA,
        "RECOVERY_ARTIFACT_DIGEST_MISMATCH")
    members = {}
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        for entry in archive.infolist():
            path = PurePosixPath(entry.filename)
            require(not path.is_absolute() and ".." not in path.parts and "\\" not in entry.filename,
                "RECOVERY_ARTIFACT_UNSAFE_MEMBER")
            if entry.is_dir():
                continue
            require(path.name not in members and entry.file_size <= 2 * 1024 * 1024, "RECOVERY_ARTIFACT_AMBIGUOUS_OR_LARGE")
            members[path.name] = archive.read(entry)
    receipt = json.loads(members["association-recovery-report.json"])
    require(receipt.get("collection_status") == "COMPLETE" and receipt.get("mutations") == 0 and receipt.get("origin_repaired") is False,
        "RECOVERY_RECEIPT_NOT_READ_ONLY_COMPLETE")
    documents = {}
    for name, spec in ASSOCIATIONS.items():
        body = members[spec["member"]]
        source = receipt["public_sources"][spec["label"]]
        require(sha(body) == spec["sha256"] and source.get("http_status") == 200 and
            source.get("body_sha256") == spec["sha256"] and source.get("candidate_sha256") == spec["sha256"] and
            source.get("url") == "https://7e894d19-bilhealth.bilhealth-app.workers.dev/.well-known/" + name,
            "RECOVERED_DOCUMENT_HASH_OR_PROVENANCE_MISMATCH")
        json.loads(body)
        documents[name] = body
    report["recovery_artifact"] = {"id": ARTIFACT, "run_id": RECOVERY_RUN, "controller_sha": RECOVERY_CONTROLLER, "zip_sha256": ZIP_SHA}
    return documents


def probe(url, method="GET"):
    req = request.Request(url, method=method, headers={"User-Agent": "BIL-site-recovery/1.0", "Accept": "*/*"})
    try:
        response = request.build_opener(NoRedirect()).open(req, timeout=30)
    except error.HTTPError as failure:
        response = failure
    except Exception as failure:
        return {"url": url, "method": method, "status": None, "transport_error": type(failure).__name__}, b""
    with response:
        body = response.read(2 * 1024 * 1024 + 1)
        return {"url": url, "method": method, "status": response.code, "body_sha256": sha(body), "body_bytes": len(body),
            "truncated": len(body) > 2 * 1024 * 1024,
            "headers": {key.lower(): value for key, value in response.headers.items() if key.lower() in HEADERS | PUBLIC_CONFIG_HEADERS}}, body


def modules(raw, content_type):
    if (content_type or "").startswith("multipart/"):
        mail = BytesParser(policy=policy.default).parsebytes(("Content-Type: " + content_type + "\r\nMIME-Version: 1.0\r\n\r\n").encode() + raw)
        found = []
        for part in mail.iter_parts():
            name = part.get_filename() or part.get_param("name", header="content-disposition")
            if name == "metadata":
                continue  # Never preserve API binding values.
            require(isinstance(name, str) and PurePosixPath(name).name == name and name.endswith((".js", ".mjs")), "UNEXPECTED_ROLLBACK_MODULE")
            found.append((name, part.get_payload(decode=True) or b""))
        return found
    require("javascript" in (content_type or ""), "ROLLBACK_RESPONSE_NOT_JAVASCRIPT")
    return [("active-worker.js", raw)]


def snapshot(output, label, enforce_observed=True):
    resources = {}

    def read(name, path):
        safe, value, raw = cf_get(path)
        require(safe.get("success") and not safe.get("body_truncated"), "CF_READ_REQUIRED:" + name)
        resources[name] = safe
        return value, raw, safe

    deployments, _, _ = read("deployments", f"/accounts/{ACCOUNT}/workers/scripts/bilhealth/deployments")
    rows = deployments.get("deployments") if isinstance(deployments, dict) else None
    require(isinstance(rows, list) and bool(rows) and isinstance(rows[0], dict), "DEPLOYMENT_LIST_INVALID")
    latest = rows[0]
    traffic = latest.get("versions")
    require(isinstance(traffic, list) and len(traffic) == 1 and traffic[0].get("percentage") == 100, "TRAFFIC_NOT_SINGLE_VERSION")
    if enforce_observed:
        require(latest.get("id") == DEPLOYMENT and traffic[0].get("version_id") == VERSION, "ACTIVE_VERSION_DRIFT")
    settings, _, _ = read("settings", f"/accounts/{ACCOUNT}/workers/scripts/bilhealth/settings")
    require(isinstance(settings, dict), "SETTINGS_NOT_OBJECT")
    require(isinstance(settings.get("bindings"), list), "BINDING_INVENTORY_NOT_ARRAY")
    _, source, code_safe = read("source", f"/accounts/{ACCOUNT}/workers/scripts/bilhealth")
    code = modules(source, code_safe.get("content_type"))
    code_inventory = [{"name": name, "sha256": sha(body), "bytes": len(body)} for name, body in code]
    require(len(code) == 1, "ACTIVE_MODULE_INVENTORY_CHANGED")
    if enforce_observed:
        require(sha(code[0][1]) == ACTIVE_CODE, "ACTIVE_WORKER_SOURCE_DRIFT")
    domains, _, _ = read("domains", f"/accounts/{ACCOUNT}/workers/domains")
    routes, _, _ = read("routes", f"/zones/{ZONE}/workers/routes")
    subdomain, _, _ = read("subdomain", f"/accounts/{ACCOUNT}/workers/scripts/bilhealth/subdomain")
    require(isinstance(domains, list) and isinstance(routes, list) and isinstance(subdomain, dict), "ROUTING_SHAPE_INVALID")
    safe_domains = [{key: row.get(key) for key in ("hostname", "service", "environment", "zone_id")} for row in domains if isinstance(row, dict) and row.get("service") == "bilhealth"]
    safe_routes = [{key: row.get(key) for key in ("id", "pattern", "script")} for row in routes if isinstance(row, dict)]
    protected = {"settings": settings_summary(settings), "non_asset_binding_value_fingerprint": sha(canonical([
        row for row in settings.get("bindings", []) if isinstance(row, dict) and row.get("type") != "assets"])),
        "domains": sorted(safe_domains, key=lambda row: row.get("hostname") or ""), "routes": sorted(safe_routes, key=lambda row: row.get("id") or ""),
        "subdomain": {key: subdomain.get(key) for key in ("enabled", "previews_enabled")}}
    result = {"deployment_id": latest.get("id"), "version_id": traffic[0].get("version_id"), "traffic_percentage": 100,
        "modules": code_inventory, "protected_configuration": protected, "api_reads": resources}
    if output is not None:
        root = output / label
        for name, body in code:
            (root / "rollback-code").mkdir(parents=True, exist_ok=True)
            (root / "rollback-code" / name).write_bytes(body)
        json_write(root / "snapshot.json", result)
        json_write(root / "rollback-info.json", {"automatic_rollback": False, "target_version": VERSION,
            "warning": "Roll back only if no other actor has changed traffic; the target restores the prechange Oct19 asset bundle.",
            "command": ["npx", "--yes", "wrangler@4.125.0", "rollback", VERSION, "--name", "bilhealth"]})
    return result


def asset_manifest(root):
    site = root / "public_site"
    require(site.is_dir(), "STATIC_SITE_MISSING")
    ignore = [line.strip() for line in (site / ".assetsignore").read_text().splitlines() if line.strip() and not line.lstrip().startswith("#")]
    require(set(ignore) == {"README.md", "tmp_index_current.txt"}, "ASSET_IGNORE_RULES_CHANGED")
    entries = []
    for path in sorted(site.rglob("*")):
        require(not path.is_symlink(), "ASSET_SYMLINK_NOT_ALLOWED")
        if not path.is_file() or path.relative_to(site).as_posix() in IGNORED:
            continue
        relative = path.relative_to(site).as_posix()
        body = path.read_bytes()
        entries.append({"path": "/" + relative, "sha256": sha(body), "bytes": len(body)})
    indexed = {row["path"]: row for row in entries}
    for name, spec in ASSOCIATIONS.items():
        require(indexed.get("/.well-known/" + name, {}).get("sha256") == spec["sha256"], "RESTORED_ASSET_MANIFEST_MISMATCH")
    return entries


def expected_public(root, entries):
    specs = []
    for path in POLICIES:
        for language in ("en", "ar"):
            file = root / "public_site/policy-pages" / (path[1:] + "." + language + ".html")
            specs.append({"url": BASE + path + "?lang=" + language, "local": file, "language": language, "label": "policy-" + path[1:] + "-" + language})
    for entry in entries:
        path = entry["path"]
        if path.startswith(("/.well-known/", "/policy-pages/")):
            continue
        require(not path.endswith(".html") or path == "/index.html", "UNMAPPED_HTML_ASSET")
        specs.append({"url": BASE + ("/" if path == "/index.html" else path), "local": root / "public_site" / path[1:], "label": "asset-" + path[1:].replace("/", "_")})
    return specs


def header_rules(root):
    rules = {}
    current = None
    for line in (root / "public_site/_headers").read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line[0].isspace():
            require(line.startswith("/") and line not in rules, "UNREVIEWED_HEADER_RULE")
            current = line.strip()
            rules[current] = {}
        else:
            require(current is not None and ":" in line, "INVALID_HEADER_RULE")
            name, value = line.strip().split(":", 1)
            rules[current][name.lower()] = value.strip()
    require(set(rules) == {"/*", "/app.js", "/styles.css", "/.well-known/apple-app-site-association", "/.well-known/assetlinks.json"}, "UNREVIEWED_HEADER_PATHS")
    return rules


def compare_public(root, entries, output=None):
    specs = expected_public(root, entries)
    rules = header_rules(root)

    def one(spec):
        row, body = probe(spec["url"])
        row.update(label=spec["label"], expected_sha256=sha(spec["local"].read_bytes()))
        row["matches_candidate"] = row.get("status") == 200 and not row.get("truncated") and row.get("body_sha256") == row["expected_sha256"]
        expected_headers = {**rules["/*"], **rules.get(urlparse(spec["url"]).path, {})}
        row["candidate_header_behavior_match"] = all(row.get("headers", {}).get(key) == value for key, value in expected_headers.items())
        row["matches_candidate"] = row["matches_candidate"] and row["candidate_header_behavior_match"]
        if "language" in spec:
            row["policy_mime_and_language_match"] = row.get("headers", {}).get("content-type", "").lower().startswith("text/html") and row.get("headers", {}).get("content-language") == spec["language"]
            row["matches_candidate"] = row["matches_candidate"] and row["policy_mime_and_language_match"]
        if output is not None:
            target = output / "original-public-files" / (spec["label"] + ".body")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(body)
        return row
    with ThreadPoolExecutor(max_workers=5) as executor:
        return list(executor.map(one, specs))


def require_public_match(rows):
    require(bool(rows) and all(row.get("matches_candidate") is True for row in rows), "CURRENT_PUBLIC_ASSETS_DIFFER_FROM_FROZEN_SOURCE")
    require(len([row for row in rows if row["label"].startswith("policy-")]) == len(POLICIES) * 2, "POLICY_COMPARISON_INCOMPLETE")


def config_behavior(root):
    rows = []
    redirects = []
    for line in (root / "public_site/_redirects").read_text().splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            parts = line.split()
            require(len(parts) == 3 and parts[2] == "301" and parts[1] == "/account-deletion", "UNREVIEWED_REDIRECT_RULE")
            redirects.append(parts)
    require({row[0] for row in redirects} == {"/delete-account", "/delete-account/"}, "UNREVIEWED_REDIRECT_PATHS")
    for source, target, status in redirects:
        for method in ("GET", "HEAD"):
            row, _ = probe(BASE + source, method)
            row["passed"] = row.get("status") == int(status) and urljoin(BASE + source, row.get("headers", {}).get("location", "")) == BASE + target
            rows.append(row)
    index_sha = sha((root / "public_site/index.html").read_bytes())
    row, _ = probe(BASE + "/bil-recovery-spa-behavior-probe")
    row["passed"] = row.get("status") == 200 and row.get("body_sha256") == index_sha and row.get("headers", {}).get("content-type", "").startswith("text/html")
    rows.append(row)
    for method in ("GET", "HEAD"):
        row, _ = probe(BASE + "/.well-known/bil-recovery-unknown", method)
        row["passed"] = row.get("status") == 404
        rows.append(row)
    return rows


def prepare(root, output):
    require(command(["git", "rev-parse", "HEAD"], root).decode().strip() == SOURCE, "CANDIDATE_SOURCE_MISMATCH")
    require(not command(["git", "status", "--porcelain=v1", "--untracked-files=no"], root).strip(), "CANDIDATE_TRACKED_FILES_DIRTY")
    output.mkdir(parents=True, exist_ok=True)
    report = {"mode": "ONE_TIME_ASSOCIATION_RECOVERY_PREFLIGHT", "source_sha": SOURCE, "production_changed": False,
        "full_remote_asset_inventory_available": False, "unlisted_remote_assets_scope": "Not enumerable with documented read API; review this limit before a full static redeploy"}
    metadata = gh(f"actions/artifacts/{ARTIFACT}")
    run = gh(f"actions/runs/{RECOVERY_RUN}")
    require(run.get("head_sha") == RECOVERY_CONTROLLER and run.get("status") == "completed" and run.get("conclusion") == "success", "RECOVERY_RUN_NOT_BOUND_SUCCESS")
    raw = command(["gh", "api", f"repos/{REPO}/actions/artifacts/{ARTIFACT}/zip"])
    documents = artifact_documents(metadata, raw, report)
    (output / "recovery-original.zip").write_bytes(raw)
    for name, body in documents.items():
        target = root / "public_site/.well-known" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
        original = output / "recovered-originals" / name
        original.parent.mkdir(parents=True, exist_ok=True)
        original.write_bytes(body)
    report["before"] = snapshot(output, "before")
    # Protect all existing non-asset binding values by hashing, never printing.
    require(report["before"]["protected_configuration"]["settings"]["binding_names_and_types_only"] == [{"name": "ASSETS", "type": "assets"}], "UNREVIEWED_BINDINGS_EXIST")
    cfg = json.loads((root / "wrangler.site.jsonc").read_text())
    require(cfg.get("name") == "bilhealth" and not any(key in cfg for key in ("routes", "route", "vars", "workers_dev", "preview_urls")), "UNREVIEWED_DEPLOY_ROUTING_OR_VARIABLE_CONFIG")
    observed = report["before"]["protected_configuration"]["settings"]["configuration"]
    require(cfg.get("compatibility_date") == observed.get("compatibility_date"), "COMPATIBILITY_DATE_WOULD_CHANGE")
    require((cfg.get("compatibility_flags") or []) == (observed.get("compatibility_flags") or []), "COMPATIBILITY_FLAGS_WOULD_CHANGE")
    require((cfg.get("limits") or {}) == (observed.get("limits") or {}), "LIMITS_WOULD_CHANGE")
    require(cfg.get("main") == "./tool/release/bilhealth_site_worker.mjs" and cfg.get("assets", {}).get("directory") == "./public_site" and cfg["assets"].get("binding") == "ASSETS", "UNREVIEWED_WORKER_OR_ASSET_BINDING")
    report["proposed_worker_and_asset_configuration"] = cfg
    report["proposed_config_sha256"] = sha((root / "wrangler.site.jsonc").read_bytes())
    report["remote_asset_configuration_status"] = "UNKNOWN_NOT_PROVEN_EQUIVALENT_WHEN_API_ASSETS_IS_NULL"
    report["apply_review_scope"] = "execute_recovery=true reasserts the visible frozen6bf asset/SPA configuration after known behavior matches; it does not certify unknown prior asset metadata equivalence"
    report["asset_manifest"] = asset_manifest(root)
    json_write(output / "proposed-static-asset-manifest.json", report["asset_manifest"])
    report["public_comparison"] = compare_public(root, report["asset_manifest"], output)
    report["header_and_redirect_config_files"] = {name: sha((root / "public_site" / name).read_bytes()) for name in ("_headers", "_redirects")}
    report["config_behavior"] = config_behavior(root)
    # Snapshot the currently failing public responses as well as recovered originals.
    report["original_association_responses"] = {}
    for name in ASSOCIATIONS:
        row, body = probe(BASE + "/.well-known/" + name)
        report["original_association_responses"][name] = row
        (output / "original-public-files" / (name + ".body")).write_bytes(body)
    report["status"] = "READY_FOR_SOURCE_TESTS" if all(row["matches_candidate"] for row in report["public_comparison"]) and all(row["passed"] for row in report["config_behavior"]) else "BLOCKED_PUBLIC_SOURCE_DIFFERENCES"
    json_write(output / "preflight.json", report)
    require_public_match(report["public_comparison"])
    require(all(row["passed"] for row in report["config_behavior"]), "CURRENT_REDIRECT_OR_ASSET_ROUTING_BEHAVIOR_DIFFERS")
    print(json.dumps({"status": report["status"], "compared_public_files": len(report["public_comparison"]), "production_changed": False}))


def backup_bound():
    artifact_id = os.environ.get("BIL_BACKUP_ARTIFACT_ID", "")
    digest = os.environ.get("BIL_BACKUP_ARTIFACT_DIGEST", "")
    require(artifact_id.isdigit() and len(digest) == 64 and all(c in "0123456789abcdef" for c in digest), "PRECHANGE_BACKUP_UPLOAD_NOT_PROVEN")
    item = gh("actions/artifacts/" + artifact_id)
    require(item.get("expired") is False and item.get("digest") == "sha256:" + digest and
        str(item.get("workflow_run", {}).get("id")) == os.environ.get("GITHUB_RUN_ID") and
        item["workflow_run"].get("head_sha") == os.environ.get("GITHUB_SHA") and
        item.get("name") == "bil-site-recovery-backup-" + os.environ.get("GITHUB_RUN_ID", ""), "PRECHANGE_BACKUP_ARTIFACT_BINDING_MISMATCH")
    return {"id": int(artifact_id), "sha256": digest}


def assert_unchanged(before, current):
    require(before["deployment_id"] == current["deployment_id"] and before["version_id"] == current["version_id"] and
        before["modules"] == current["modules"] and before["protected_configuration"] == current["protected_configuration"], "ANOTHER_ACTOR_CHANGED_PRODUCTION")


def postcheck(root, manifest, before, output):
    rows = compare_public(root, manifest)
    associations = []
    for name, spec in ASSOCIATIONS.items():
        for method in ("GET", "HEAD"):
            row, body = probe(BASE + "/.well-known/" + name, method)
            row["passed"] = row.get("status") == 200 and row.get("headers", {}).get("content-type", "").lower().startswith("application/json") and (
                row.get("body_sha256") == spec["sha256"] if method == "GET" else len(body) == 0)
            if method == "GET" and row["passed"]:
                json.loads(body)
            associations.append(row)
    extras = []
    for method in ("GET", "HEAD"):
        row, body = probe(BASE + "/.well-known/bil-recovery-unknown", method)
        row["passed"] = row.get("status") == 404 and (method != "HEAD" or len(body) == 0)
        extras.append(row)
        for name in ASSOCIATIONS:
            path = "/.well-known/" + name
            row, _ = probe("https://bilhealth.com" + path, method)
            row["passed"] = row.get("status") == 301 and row.get("headers", {}).get("location") == BASE + path
            extras.append(row)
    after = snapshot(output, "after", enforce_observed=False)
    official = json.loads((output / "official-wrangler-inventory.json").read_text())
    behavior = config_behavior(root)
    result = {"public_files": rows, "associations": associations, "unknown_and_apex": extras, "config_behavior": behavior, "after": after,
        "routes_domains_bindings_preserved": after["protected_configuration"] == before["protected_configuration"],
        "candidate_worker_source_present": any(item["sha256"] == official.get("dry_run_worker_sha256") for item in after["modules"])}
    result["status"] = "PASS" if all(row.get("matches_candidate") for row in rows) and all(row["passed"] for row in associations + extras + behavior) and result["routes_domains_bindings_preserved"] and result["candidate_worker_source_present"] else "FAIL_REQUIRES_REVIEW"
    json_write(output / "postcheck.json", result)
    require(result["status"] == "PASS", "DEPLOYED_SITE_POSTCHECK_FAILED_NO_AUTOMATIC_ROLLBACK")
    return result


def deploy(root, output):
    preflight = json.loads((output / "preflight.json").read_text())
    require(preflight.get("status") == "READY_FOR_SOURCE_TESTS", "PREFLIGHT_NOT_READY")
    contracts = json.loads((output / "contracts.json").read_text())
    require(contracts.get("status") == "PASS" and contracts.get("source_sha") == SOURCE, "ACTUAL_SOURCE_CONTRACT_TESTS_NOT_PASS")
    official = json.loads((output / "official-wrangler-inventory.json").read_text())
    require(official.get("status") == "PASS" and official.get("source_sha") == SOURCE and official.get("wrangler_version") == "4.125.0" and official.get("deploy_helpers_version") == "0.8.0", "OFFICIAL_WRANGLER_UPLOAD_INVENTORY_NOT_VERIFIED")
    require(asset_manifest(root) == preflight["asset_manifest"], "ASSETS_CHANGED_AFTER_PREFLIGHT")
    require(command(["git", "rev-parse", "HEAD"], root).decode().strip() == SOURCE and not command(["git", "status", "--porcelain=v1", "--untracked-files=no"], root).strip(), "SOURCE_CHANGED_BEFORE_DEPLOY")
    backup = backup_bound()
    # All comparisons are repeated immediately before the only mutation.
    require_public_match(compare_public(root, preflight["asset_manifest"]))
    require(all(row["passed"] for row in config_behavior(root)), "PUBLIC_CONFIGURATION_CHANGED_BEFORE_DEPLOY")
    require({name: sha((root / "public_site" / name).read_bytes()) for name in ("_headers", "_redirects")} == preflight["header_and_redirect_config_files"], "LOCAL_CONFIGURATION_CHANGED_BEFORE_DEPLOY")
    current = snapshot(output, "immediately-before-deploy")
    assert_unchanged(preflight["before"], current)
    json_write(output / "deployment-intent.json", {"source_sha": SOURCE, "backup_artifact": backup, "restore_exact_hashes": ASSOCIATIONS,
        "race_limit": "No Cloudflare compare-and-swap; final GET guards and shared GitHub concurrency do not exclude a dashboard write after the guard", "rollback_target": VERSION})
    log = output / "wrangler-deploy.log"
    with log.open("wb") as handle:
        wrangler = Path(os.environ["RUNNER_TEMP"]) / "bil-site-toolchain/node_modules/wrangler/bin/wrangler.js"
        require(wrangler.is_file(), "PINNED_WRANGLER_BINARY_MISSING")
        completed = subprocess.run(["node", str(wrangler), "deploy", "--config", "wrangler.site.jsonc", "--no-bundle", "--keep-vars"], cwd=root, stdout=handle, stderr=subprocess.STDOUT)
    require(completed.returncode == 0, "WRANGLER_DEPLOY_FAILED_REVIEW_SNAPSHOT")
    postcheck(root, preflight["asset_manifest"], preflight["before"], output)
    print(json.dumps({"status": "SITE_ASSOCIATION_RECOVERY_POSTCHECK_PASS", "store_submission_approved": False}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("prepare", "deploy"))
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        (prepare if args.mode == "prepare" else deploy)(args.candidate.resolve(), args.output.resolve())
    except Exception as failure:
        json_write(args.output / "failure.json", {"mode": args.mode, "error_type": type(failure).__name__,
            "safe_guard_code": str(failure) if isinstance(failure, ValueError) and str(failure).isupper() else "UNEXPECTED_FAILURE_SEE_PARTIAL_EVIDENCE"})
        raise SystemExit(1)
