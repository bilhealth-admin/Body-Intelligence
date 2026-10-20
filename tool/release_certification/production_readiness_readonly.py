#!/usr/bin/env python3
"""Bounded, read-only metadata audit; never persist raw CLI output or secrets."""
import json, os, pathlib, signal, subprocess, sys, urllib.request, urllib.error
PROJECT = "tgmanzhqulksykhslrzb"
APP_SOURCE = "5775d082a1b4c7a29e4ed4d6e01693b31923dc31"
APP_TREE = "7ea15defb433ad134ee5066f538d8e790c45f809"
OUT = pathlib.Path(os.environ["READINESS_OUT"]); OUT.mkdir(parents=True, exist_ok=True)
ORIGIN = "https://api.supabase.com"
report = {"appSource": APP_SOURCE, "appTree": APP_TREE, "sourceCheckoutVerified": False, "controllerSource": os.environ.get("GITHUB_SHA"), "mode": "READ_ONLY_METADATA", "databaseWrites": False, "storeTransactions": False, "runtimeAcceptanceVerified": False}
report["githubBackendReleaseMarkerPresent"] = bool(os.environ.get("BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID", "").strip())
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl): return None
def deadline(signum, frame): raise TimeoutError()
signal.signal(signal.SIGALRM, deadline)
opener = urllib.request.build_opener(NoRedirect())
def request(path, data=None):
    allowed = {"/secrets", "/functions", "/database/query/read-only"}
    if path not in allowed: return {"state": "REQUEST_NOT_ALLOWLISTED"}, None
    body = None if data is None else json.dumps({"query": data}).encode()
    try:
        req = urllib.request.Request(ORIGIN + "/v1/projects/" + PROJECT + path, data=body, headers={"Authorization": "Bearer " + os.environ["SUPABASE_ACCESS_TOKEN"], "Content-Type": "application/json"}, method="GET" if body is None else "POST")
        signal.alarm(30)
        with opener.open(req, timeout=25) as response:
            raw = response.read(3000001)
            if len(raw) > 3000000: return {"state": "RESPONSE_TOO_LARGE"}, None
            value = json.loads(raw)
        return {"state": "READ_OK"}, value
    except urllib.error.HTTPError as error:
        return {"state": "HTTP_DENIED_OR_FAILED", "httpStatus": error.code}, None
    except (TimeoutError, OSError): return {"state": "TIMEOUT_OR_TRANSPORT_FAILED"}, None
    except (ValueError, TypeError): return {"state": "INVALID_JSON"}, None
    finally: signal.alarm(0)
def entries(value, envelope):
    if isinstance(value, list): result = value
    elif isinstance(value, dict) and isinstance(value.get(envelope), list): result = value[envelope]
    else: raise ValueError("unrecognized_shape")
    if not all(isinstance(row, dict) for row in result): raise ValueError("invalid_row")
    return result
def source_checkout_verified():
    root = os.environ.get("APP_CHECKOUT")
    if not root: return False
    try:
        def git(*arguments):
            result = subprocess.run(["git", "-C", root, *arguments], capture_output=True, check=True, timeout=10)
            if len(result.stdout) > 2048: raise ValueError("source_receipt_too_large")
            return result.stdout.decode().strip()
        return git("rev-parse", "HEAD") == APP_SOURCE and git("rev-parse", "HEAD^{tree}") == APP_TREE and not git("status", "--porcelain", "--untracked-files=no")
    except (OSError, ValueError, subprocess.SubprocessError): return False
secret_names = [
 "BIL_APP_ATTEST_APP_ID", "BIL_APP_ATTEST_ENVIRONMENTS", "BIL_APP_ATTEST_BUNDLE_VERSIONS", "BIL_APP_ATTEST_ALLOW_LEGACY",
 "BIL_MOBILE_INTEGRITY_ENFORCEMENT", "BIL_MOBILE_INTEGRITY_BACKEND_RELEASE_ID",
 "BIL_PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON", "BIL_PLAY_INTEGRITY_PACKAGE_NAME",
 "BIL_FCM_SERVICE_ACCOUNT_JSON", "BIL_FCM_PROJECT_ID", "BIL_APNS_AUTH_KEY_P8", "BIL_APNS_KEY_ID", "BIL_APNS_TEAM_ID", "BIL_APNS_BUNDLE_ID", "BIL_PUSH_GATEWAY_SECRET",
 "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "GOOGLE_PLAY_PACKAGE_NAME", "APPLE_ROOT_CA_SHA256", "APPLE_BUNDLE_ID", "APPLE_ISSUER_ID", "APPLE_KEY_ID", "APPLE_PRIVATE_KEY", "GOOGLE_PUBSUB_AUDIENCE", "GOOGLE_PUBSUB_SERVICE_ACCOUNT"
]
try:
    report["sourceCheckoutVerified"] = source_checkout_verified()
    if not report["sourceCheckoutVerified"]:
        report["state"] = "SOURCE_CHECKOUT_NOT_VERIFIED"
    elif not os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip():
        report["state"] = "MISSING_EXISTING_SUPABASE_ACCESS_TOKEN"
    else:
        state, value = request("/secrets")
        report["backendSecretNames"] = state
        if value is not None:
            try:
                rows = entries(value, "secrets")
                if not all(isinstance(x, dict) and isinstance(x.get("name"), str) for x in rows): raise ValueError()
                names = {x["name"] for x in rows}
                report["backendSecretPresence"] = {name: name in names for name in secret_names}
                report["secretValuesExported"] = False
            except ValueError: report["backendSecretNames"] = {"state": "INVALID_SHAPE"}
        state, value = request("/functions")
        report["functionMetadata"] = state
        if value is not None:
            try:
                rows = entries(value, "functions")
                report["functions"] = [
                    {k: row.get(k) for k in ("slug", "version", "status", "verify_jwt")}
                    for row in rows if isinstance(row, dict) and row.get("slug") in
                    {"app-attest", "play-integrity", "verify-platform-integrity", "verify-store-purchase", "push-provider-gateway", "ai-coach", "meal-vision"}
                ]
            except ValueError: report["functionMetadata"] = {"state": "INVALID_SHAPE"}
        sql = """set statement_timeout = '10s';
select pg_catalog.json_build_object(
 'grantTablePresent', pg_catalog.to_regclass('public.bil_mobile_integrity_grants') is not null,
 'challengeTablePresent', pg_catalog.to_regclass('public.bil_mobile_integrity_challenges') is not null,
 'attestKeyTablePresent', pg_catalog.to_regclass('public.bil_app_attest_keys') is not null,
 'consumeRpcPresent', pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)') is not null,
 'integrityRlsEnabled', (select coalesce(pg_catalog.bool_and(c.relrowsecurity),false) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('bil_mobile_integrity_grants','bil_mobile_integrity_challenges','bil_app_attest_keys')),
 'consumeAnonExecute', case when pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)') is null then null else pg_catalog.has_function_privilege('anon',pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)'),'EXECUTE') end,
 'consumeAuthenticatedExecute', case when pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)') is null then null else pg_catalog.has_function_privilege('authenticated',pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)'),'EXECUTE') end,
 'consumeServiceExecute', case when pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)') is null then null else pg_catalog.has_function_privilege('service_role',pg_catalog.to_regprocedure('public.bil_consume_mobile_integrity_grant(uuid,uuid,text,text)'),'EXECUTE') end
) as readiness;
"""
        state, value = request("/database/query/read-only", data=sql)
        report["sqlMetadata"] = state
        if value is not None:
            try:
                rows = entries(value, "rows")
                items = [row["readiness"] for row in rows if isinstance(row, dict) and "readiness" in row]
                if len(items) != 1 or not isinstance(items[0], dict) or not all(v is None or type(v) is bool for v in items[0].values()): raise ValueError()
                required = {"grantTablePresent", "challengeTablePresent", "attestKeyTablePresent", "consumeRpcPresent", "integrityRlsEnabled", "consumeAnonExecute", "consumeAuthenticatedExecute", "consumeServiceExecute"}
                if set(items[0]) != required: raise ValueError()
                report["schemaAndAclBooleans"] = items[0]
                b = items[0]
                report["grantSchemaAndAclPass"] = all(b[k] is True for k in ("grantTablePresent","challengeTablePresent","attestKeyTablePresent","consumeRpcPresent","integrityRlsEnabled","consumeServiceExecute")) and b["consumeAnonExecute"] is False and b["consumeAuthenticatedExecute"] is False
            except ValueError: report["sqlMetadata"] = {"state": "INVALID_SHAPE"}
        report["state"] = "METADATA_COLLECTED_RUNTIME_BINDING_STILL_UNVERIFIED"
finally:
    (OUT / "backend-readiness.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({"state": report.get("state"), "runtimeAcceptanceVerified": False, "artifact": "backend-readiness.json"}))
# Missing/failed metadata is preserved as blocked evidence, never success.
critical = [report.get("backendSecretNames",{}).get("state"), report.get("functionMetadata",{}).get("state"), report.get("sqlMetadata",{}).get("state")]
sys.exit(0 if all(x == "READ_OK" for x in critical) and report.get("grantSchemaAndAclPass") is True else 1)

