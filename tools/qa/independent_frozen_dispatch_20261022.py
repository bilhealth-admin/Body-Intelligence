#!/usr/bin/env python3
"""Run original BIL CI profiles independently against an immutable source.

No release branch writes, TestFlight workflow, signing submission, or silent
retry. Every POST has one preceding durable intent; every run is identified
by its new run ID, exact Git SHA, branch, event and workflow ID.
"""
import json
import os
import pathlib
import subprocess
import time
from datetime import datetime, timezone

REPO = "bilhealth-admin/Body-Intelligence"
REF = "integration/bil-qa-media-policy-20261011"
SHA = "31554b3e078667a38bd3c53aa105f5f1d2a4dc96"
OUT = pathlib.Path(os.environ["RUNNER_TEMP"]) / "bil-frozen-ci"
OUT.mkdir(parents=True, exist_ok=True)
REQUIRED = [
    ("owner_full_and_supplemental", 386117761, {}, ["Full analysis then one unsharded root suite", "Supplemental source and dependency audits"]),
    ("coach_focused", 357323507, {"focused_repair_only": "true"}, ["flutter"]),
    ("codeql_source", 384948928, {"source_audit_only": "true"}, ["CodeQL (actions)", "CodeQL (javascript-typescript)", "CodeQL (python)", "Isolated Semgrep source audit", "Bounded macro editor generated checks, mutants and VM coverage"]),
    ("supabase_isolated", 384948928, {"supabase_only": "true"}, ["Local Supabase migrations, SQL, Auth and RLS"]),
    ("android_native", 384948928, {"android_native_only": "true", "android_native_target": "all"}, ["Android API 33 native integration without CodeQL tracing"]),
    ("ios_native", 384948928, {"ios_native_only": "true", "native_target": "all"}, ["iPhone and iPad native tests from exact simulator bundles"]),
    ("unsigned_mobile_builds", 371818189, {"notification_api33_only": "false"}, ["Android APK/AAB + emulator evidence", "iOS simulator + unsigned IPA evidence", "Android API 33 local notification permission states", "Android API 36 local notification permission states"]),
    ("apple_google_policy", 385995260, {"evidence_scope": "full-with-android-lint", "certify_release": "false"}, ["Source and affected regressions; certification remains separate", "Seven exact plan goldens on their Windows reference platform"]),
    ("live_service_contracts", 390900526, {}, ["live-contracts", "Transactional live cloud roundtrip", "Guarded policy and cloud SQL E2E with independent residue"]),
    ("store_adversarial", 374438846, {}, ["remaining-store-contracts"]),
    ("native_codeql", 384948928, {"android_only": "true", "ios_only": "true"}, ["CodeQL (java-kotlin)", "CodeQL (swift)"]),
    ("healthkit_simulator", 334769308, {}, ["healthkit-native-sheet"]),
    ("independent_admin_e2e", 390900524, {}, ["isolated-web-contracts", "Approved admin synthetic browser E2E"]),
    ("android_startup_all_six", 384967897, {"api36_only": "false"}, ["Android 26 offline-config startup", "Android 29 offline-config startup", "Android 33 offline-config startup", "Android 34 offline-config startup", "Android 35 offline-config startup", "Android 36 offline-config startup"]),
]
MOBSF = ("offline_mobsf", 384948928, {"mobsf_only": "true", "android_artifact_run": ""}, ["Offline MobSF static debug APK audit"])
assert all(x[1] != 346770575 for x in REQUIRED + [MOBSF])
states = {}
def utc():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()
def save():
    dest=OUT/"state.json"
    tmp=OUT/"state.tmp"
    tmp.write_text(json.dumps({"source_sha": SHA, "source_ref": REF,
        "runner_sha": os.environ.get("GITHUB_SHA", ""), "testflight_excluded": True,
        "updated": utc(), "lanes": states}, indent=2)+"\n")
    tmp.replace(dest)
def api(endpoint, payload=None):
    argv=["gh","api",f"repos/{REPO}/{endpoint}"]
    if payload is not None:
        argv += ["--method", "POST", "--input", "-"]
    result=subprocess.run(argv, input=json.dumps(payload) if payload is not None else None,
        capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError(f"GitHub API error: {endpoint}: {result.stderr[:350]}")
    return json.loads(result.stdout) if result.stdout.strip() else {}
def runs(wid):
    return api(f"actions/workflows/{wid}/runs?per_page=100")["workflow_runs"]
def dispatch(item):
    name,wid,inputs,required=item
    current=runs(wid)
    floor=max((int(r["id"]) for r in current), default=0)
    boundary=utc()
    states[name]={"workflow_id":wid,"inputs":inputs,"required_jobs":required,
        "status":"DISPATCH_INTENT","after_run_id":floor,"created_after":boundary}
    save()
    try:
        api(f"actions/workflows/{wid}/dispatches", {"ref":REF,"inputs":inputs})
    except Exception as e:
        # An unknown POST outcome is never retried.
        states[name].update(status="DISPATCH_UNKNOWN", error=str(e))
        save()
        return
    states[name]["status"]="DISCOVERING"
    save()
    until=time.monotonic()+180
    while time.monotonic()<until:
        candidates=[r for r in runs(wid)
            if int(r["id"])>floor and r["head_sha"]==SHA
            and r["head_branch"]==REF and r["event"]=="workflow_dispatch"
            and r.get("created_at","")>=boundary.replace("+00:00","Z")]
        if len(candidates)>1:
            states[name].update(status="AMBIGUOUS_RUN", error="Multiple new runs match exact source and workflow")
            save(); return
        if candidates:
            r=candidates[0]
            states[name].update(status="RUNNING", run_id=r["id"], run_attempt=r.get("run_attempt",1), url=r["html_url"])
            save(); return
        time.sleep(7)
    states[name].update(status="DISPATCH_NOT_IDENTIFIED", error="A POST was sent; no automatic repeat")
    save()
def inspect(item):
    name,wid,inputs,required=item
    info=states[name]
    if info.get("status")!="RUNNING": return
    run=api(f"actions/runs/{info['run_id']}")
    if (run["head_sha"]!=SHA or run["head_branch"]!=REF or
            run["workflow_id"]!=wid or run["event"]!="workflow_dispatch" or
            run.get("run_attempt",1)!=info["run_attempt"]):
        info.update(status="IDENTITY_FAILURE",error="GitHub run changed identity");save();return
    if run["status"]!="completed": return
    jobs=[]
    for page in range(1,15):
        rows=api(f"actions/runs/{run['id']}/jobs?per_page=100&page={page}")["jobs"]
        jobs.extend(rows)
        if len(rows)<100:break
    (OUT/f"{name}-{run['id']}.json").write_text(json.dumps({"run":run,"jobs":jobs},indent=2))
    observed={}
    for job in jobs: observed.setdefault(job["name"],[]).append(job)
    missing=[key for key in required if key not in observed]
    failed=[{"name":j["name"],"conclusion":j.get("conclusion"),"url":j.get("html_url")}
       for j in jobs if j.get("conclusion")=="failure"]
    required_red=[key for key in required
      if any(j.get("conclusion")!="success" for j in observed.get(key,[]))]
    accepted=run["conclusion"]=="success" and not missing and not required_red
    info.update(status="PASS" if accepted else "FAIL", conclusion=run.get("conclusion"),
      missing_jobs=missing, not_green_jobs=required_red, failed_jobs=failed)
    save()
def update_main():
    for item in REQUIRED:
        if states.get(item[0],{}).get("status")=="RUNNING":
            try: inspect(item)
            except Exception as e:
                states[item[0]]["observation_error"]=str(e);save()
def main():
    # The source's remote SHA is read before any dispatch, and remains unchanged.
    source=api("branches/"+REF)["commit"]["sha"]
    if source!=SHA: raise RuntimeError("Release source moved; refuse to run")
    for item in REQUIRED:
        # A failed profile must not prevent unrelated profiles from running.
        try: dispatch(item)
        except Exception as e:
            states[item[0]]={"status":"OBSERVATION_FAILURE","error":str(e)};save()
    deadline=time.monotonic()+17800
    while time.monotonic()<deadline:
        update_main()
        native=states.get("native_codeql",{})
        if "offline_mobsf" not in states and native.get("status") in ("PASS","FAIL","IDENTITY_FAILURE"):
            if native.get("status")=="PASS":
                mob=(MOBSF[0],MOBSF[1],{"mobsf_only":"true","android_artifact_run":str(native["run_id"])},MOBSF[3])
                try: dispatch(mob)
                except Exception as e: states[MOBSF[0]]={"status":"OBSERVATION_FAILURE","error":str(e)};save()
            else:
                states["offline_mobsf"]={"status":"BLOCKED_DEPENDENCY","reason":"The exact native CodeQL producer did not pass"};save()
        if states.get("offline_mobsf",{}).get("status")=="RUNNING":
            try:
                item=(MOBSF[0],MOBSF[1],states[MOBSF[0]]["inputs"],MOBSF[3])
                inspect(item)
            except Exception as e: states["offline_mobsf"]["observation_error"]=str(e);save()
        active=[s for s in states.values() if s["status"] in ("RUNNING","DISCOVERING","DISPATCH_INTENT")]
        if len(states)==len(REQUIRED)+1 and not active:break
        time.sleep(60)
    save()
    total=len(states)
    passed=sum(v["status"]=="PASS" for v in states.values())
    print(json.dumps({"source":SHA,"profiles_recorded":total,"passed":passed,
      "testflight_invoked":False,"states":{k:v["status"] for k,v in states.items()}},indent=2))
    return 0 if total==len(REQUIRED)+1 and passed==total else 2
if __name__=="__main__":
    try: raise SystemExit(main())
    except BaseException as error:
        states.setdefault("controller",{}).update(status="FAIL",error=str(error))
        save()
        raise