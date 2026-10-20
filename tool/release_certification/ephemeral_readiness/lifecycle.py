#!/usr/bin/env python3
"""OPTIONAL reviewed create/read/delete audit. Does not run without --execute."""
import argparse, json, os, pathlib, re, signal, subprocess, sys, tempfile, urllib.request, urllib.error, uuid
PROJECT="tgmanzhqulksykhslrzb"
EXPECTED_APP_ATTEST_ID="029befba-e782-4e28-a9c9-0269d39d1113"
EXPECTED_APP_ATTEST_VERSION=54
SOURCE="5775d082a1b4c7a29e4ed4d6e01693b31923dc31"
class Blocked(Exception):
    pass
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl): return None
def deadline(signum, frame): raise TimeoutError()
def inventory_rows(value):
    if isinstance(value,list): rows=value
    elif isinstance(value,dict) and isinstance(value.get("functions"),list):rows=value["functions"]
    else:raise Blocked("inventory_shape_invalid")
    for row in rows:
        if not isinstance(row,dict) or not isinstance(row.get("slug"),str) or not isinstance(row.get("id"),str) or not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",row["id"],re.I) or type(row.get("version")) is not int or row["version"]<1:
            raise Blocked("inventory_row_invalid")
    if len({r["id"] for r in rows})!=len(rows) or len({r["slug"] for r in rows})!=len(rows):raise Blocked("inventory_duplicate_identity")
    return rows
def bounded_cli(arguments, seconds, cwd=None):
    process=subprocess.Popen(arguments,cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    try:
        stdout,stderr=process.communicate(timeout=seconds)
        return process.returncode,stdout
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGKILL)
        process.communicate(timeout=5)
        raise Blocked("cli_process_group_timed_out")
def signatures(rows):
    return sorted((r["slug"],r["id"],r["version"]) for r in rows)
def deletion_target(before,current,slug,target=None):
    matches=[r for r in current if r["slug"]==slug]
    if not matches:return None
    if len(matches)!=1:raise Blocked("cleanup_duplicate_slug")
    row=matches[0]
    if row["id"] in {r["id"] for r in before}:raise Blocked("cleanup_original_identity_forbidden")
    if target is not None and (row["id"],row["version"])!=(target["id"],target["version"]):raise Blocked("cleanup_identity_or_version_changed")
    return {"slug":slug,"id":row["id"],"version":row["version"]}
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--execute",action="store_true");args=parser.parse_args()
    if not args.execute:
        print(json.dumps({"executionAuthorizedByFlag":False,"deploymentPerformed":False}));return 0
    signal.signal(signal.SIGALRM,deadline)
    opener=urllib.request.build_opener(NoRedirect())
    folder=pathlib.Path(__file__).resolve().parent
    out=pathlib.Path(os.environ["READINESS_OUT"]);out.mkdir(parents=True,exist_ok=True)
    report={"source":SOURCE,"deploymentPerformed":False,"dataOrStoreWrites":False,"runtimeAttestationOrDeliveryProven":False,"cleanup":"NOT_NEEDED"}
    token=os.environ.get("SUPABASE_ACCESS_TOKEN","").strip()
    service=os.environ.get("BIL_SUPABASE_SERVICE_ROLE_KEY","").strip()
    team=os.environ.get("APPLE_TEAM_ID","").strip()
    anon=os.environ.get("BIL_SUPABASE_ANON_KEY","").strip()
    before=None;target=None;attempted=False;deployment_completed=False
    slug="bil-readiness-20261020-"+uuid.uuid4().hex[:20]
    report["temporarySlug"]=slug
    def http(url,method="GET",headers=None,body=None):
        request=urllib.request.Request(url,method=method,headers=headers or {},data=body)
        try:
            signal.alarm(30)
            with opener.open(request,timeout=25) as response:
                raw=response.read(3000001)
                if len(raw)>3000000:raise Blocked("response_too_large")
                return response.status,raw
        except urllib.error.HTTPError as error:
            # Never read/persist raw error bodies or headers.
            return error.code,b""
        except (TimeoutError,OSError):raise Blocked("transport_timeout_or_failure")
        finally:signal.alarm(0)
    def management(path,method="GET"):
        allowed=(path=="/functions" or path=="/functions/"+slug)
        if not allowed:raise Blocked("management_route_forbidden")
        status,raw=http("https://api.supabase.com/v1/projects/"+PROJECT+path,method,{"Authorization":"Bearer "+token})
        if status not in (200,201):raise Blocked("management_http_"+str(status))
        if method=="DELETE":return None
        try:return json.loads(raw)
        except ValueError:raise Blocked("management_json_invalid")
    def current_inventory():
        return inventory_rows(management("/functions"))
    try:
        if not token or not service or not re.fullmatch(r"[A-Z0-9]{10}",team):raise Blocked("required_existing_credentials_missing")
        if service.count(".")!=2:raise Blocked("legacy_service_role_jwt_required")
        template=(folder/"index.ts").read_text()
        marker="__REPLACE_SECURELY_FROM_GITHUB_APPLE_TEAM_ID__"
        if template.count(marker)!=1:raise Blocked("reviewed_template_marker_invalid")
        # Help discovery occurs before any deployment, bounded and suppressed.
        try:
            help_status,help_text=bounded_cli(["npx","--yes","supabase@2.121.0","functions","deploy","--help"],45)
        except (subprocess.SubprocessError,OSError):raise Blocked("cli_help_failed_or_timeout")
        if help_status or "--use-api" not in help_text or "--project-ref" not in help_text:raise Blocked("required_cli_flags_not_supported")
        before=current_inventory()
        (out/"function-inventory-before.json").write_text(json.dumps([{"slug":r["slug"],"id":r["id"],"version":r["version"]} for r in before],indent=2)+"\n")
        if any(r["slug"]==slug for r in before):raise Blocked("temporary_slug_already_exists")
        app=[r for r in before if r["slug"]=="app-attest"]
        if len(app)!=1 or app[0]["id"]!=EXPECTED_APP_ATTEST_ID or app[0]["version"]!=EXPECTED_APP_ATTEST_VERSION:raise Blocked("app_attest_source_proof_stale")
        report["appAttestSourceProofStillCurrent"]=True
        with tempfile.TemporaryDirectory(prefix="bil-readiness-") as tmp:
            root=pathlib.Path(tmp);fn=root/"supabase"/"functions"/slug;fn.mkdir(parents=True)
            (root/"supabase"/"config.toml").write_text('project_id = "body-intelligence-log"\n[functions.'+slug+']\nverify_jwt = true\n')
            (fn/"index.ts").write_text(template.replace(marker,team))
            # Recheck absence immediately before deploying this unguessable name.
            if any(r["slug"]==slug for r in current_inventory()):raise Blocked("temporary_slug_raced")
            attempted=True;report["cleanup"]="REQUIRED"
            try:
                deploy_status,_=bounded_cli(["npx","--yes","supabase@2.121.0","functions","deploy",slug,"--project-ref",PROJECT,"--use-api"],50,cwd=root)
            except (subprocess.SubprocessError,OSError):raise Blocked("deploy_unknown_or_timeout")
            if deploy_status:raise Blocked("deployment_failed")
            deployment_completed=True
        rows=current_inventory();target=deletion_target(before,rows,slug)
        if target is None:raise Blocked("deployed_identity_not_observed")
        report["deploymentPerformed"]=True;report["temporaryIdentity"]=target
        match=next(r for r in rows if r["slug"]==slug)
        if match.get("verify_jwt") is not True:raise Blocked("gateway_jwt_not_enabled")
        endpoint="https://"+PROJECT+".supabase.co/functions/v1/"+slug
        probes=[("noAuthorization",{}),("invalidAuthorization",{"Authorization":"Bearer invalid-review-control"})]
        if anon:probes.append(("configuredAnonAuthorization",{"Authorization":"Bearer "+anon}))
        report["denialControls"]={}
        for label,headers in probes:
            status,_=http(endpoint,headers=headers)
            report["denialControls"][label]=status==401
            if status!=401:raise Blocked("negative_control_not_401")
        status,raw=http(endpoint,headers={"Authorization":"Bearer "+service})
        if status!=200:raise Blocked("admin_probe_http_"+str(status))
        try:booleans=json.loads(raw)
        except ValueError:raise Blocked("admin_probe_json_invalid")
        required={"ios37Allowed","productionAppAttestAllowed","appIDMatchesExpected","apnsTopicMatchesExpected","apnsTeamMatchesExpected","apnsCredentialsWellFormed","fcmCredentialsWellFormed","configValid","expectedTeamConfigured"}
        if not isinstance(booleans,dict) or not required<=set(booleans) or not all(type(v) is bool for v in booleans.values()):raise Blocked("admin_probe_not_boolean_schema")
        report["configurationBooleans"]=booleans
        report["state"]="CONFIGURATION_READ_COMPLETED"
    except Blocked as error:
        report["state"]="BLOCKED";report["failureCode"]=str(error)
    except Exception:
        report["state"]="BLOCKED";report["failureCode"]="internal_audit_failure"
    finally:
        if before is not None and attempted:
            try:
                current=current_inventory()
                target=deletion_target(before,current,slug,target)
                if target is not None:
                    # Management delete identifies byslug; guarded exact UUID/version is
                    # checked immediately before it. Never delete an original identity.
                    checked=deletion_target(before,current_inventory(),slug,target)
                    if checked is None:raise Blocked("cleanup_target_disappeared")
                    management("/functions/"+slug,"DELETE")
                after=current_inventory()
                (out/"function-inventory-after.json").write_text(json.dumps([{"slug":r["slug"],"id":r["id"],"version":r["version"]} for r in after],indent=2)+"\n")
                report["originalInventoryUnchanged"]=signatures(before)==signatures(after)
                report["temporaryFunctionAbsent"]=not any(r["slug"]==slug for r in after)
                report["cleanup"]="CONFIRMED" if report["originalInventoryUnchanged"] and report["temporaryFunctionAbsent"] else "BLOCKED_INVENTORY_CHANGED"
                if target is None and not deployment_completed:
                    report["cleanup"]="BLOCKED_DEPLOY_OUTCOME_UNCONFIRMED"
            except Exception:
                report["cleanup"]="BLOCKED_IDENTITY_OR_TRANSPORT"
        (out/"ephemeral-readiness-result.json").write_text(json.dumps(report,indent=2)+"\n")
        print(json.dumps({"state":report.get("state"),"cleanup":report["cleanup"],"runtimeAttestationOrDeliveryProven":False}))
    return 0 if report.get("state")=="CONFIGURATION_READ_COMPLETED" and report["cleanup"]=="CONFIRMED" else 1
if __name__=="__main__":sys.exit(main())

