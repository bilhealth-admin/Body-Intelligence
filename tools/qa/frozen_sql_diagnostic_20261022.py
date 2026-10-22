#!/usr/bin/env python3
"""One original rollback-only SQL program with strict validation + safe failure diagnostics.

This harness does NOT repair or accept failed SQL. It records a short sanitized
classification while the original fail-closed assertions and residue checks run.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

FROZEN = "31554b3e078667a38bd3c53aa105f5f1d2a4dc96"
ORIGINAL_RUNNER_BLOB = "35b5127dcde75339e56d1940d8653673e2ae81c7"
SQL_BLOB = "a5c234c3a771a2d891b3952bb082ef4ece7ae7e9"
SQL_FILE = "tool/release/ai_consent_receipt_production_rollback_e2e.sql"

def git(root, *args):
    return subprocess.check_output(["git",*args],cwd=root,text=True).strip()

def scrub(message):
    if not isinstance(message,str):return None
    s = message.replace("\n"," ")
    s = re.sub(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}\b","[ID]",s)
    s = re.sub(r"(?i)\b[A-Z0-9_.+%-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b","[EMAIL]",s)
    s = re.sub(r"(?i)\bhttps?://\S+","[URL]",s)
    s = re.sub(r"(?i)(token|password|secret|authorization|apikey)\s*[=:]\s*\S+",r"\1=[REDACTED]",s)
    s = re.sub(r"\s+"," ",s)
    return s[:160] if re.match(r"(?i)^AUDIT\b",s) else None

def summary(row):
    # No raw SQL, values, user IDs, credentials, JWT, or stack_context leave this function.
    failure=row.get("exact_failure")
    decoded=failure
    if isinstance(failure,str):
        try:decoded=json.loads(failure)
        except (TypeError,ValueError): pass
    checks=row.get("completed_assertions")
    if isinstance(checks,str):
        try:checks=json.loads(checks)
        except (TypeError,ValueError):pass
    return {
      "transaction_result":row.get("transaction_result")
         if row.get("transaction_result") in ("PASS","FAIL","UNKNOWN") else "UNRECOGNIZED",
      "failure_raw_kind":type(failure).__name__,
      "failure_json_kind":type(decoded).__name__,
      "failure_sqlstate":decoded.get("sqlstate") if isinstance(decoded,dict)
         and re.fullmatch(r"[A-Za-z0-9]{5}",str(decoded.get("sqlstate",""))) else None,
      "failure_short_audit_reason":scrub(decoded.get("error")) if isinstance(decoded,dict) else None,
      "failure_message_sha256":hashlib.sha256(str(decoded.get("error","")).encode()).hexdigest()
         if isinstance(decoded,dict) else None,
      "assertions_kind":type(row.get("completed_assertions")).__name__,
      "decoded_assertions_kind":type(checks).__name__,
      "assertions_count_type":type(row.get("completed_assertion_count")).__name__,
      "assertions_count":row.get("completed_assertion_count")
         if type(row.get("completed_assertion_count")) is int else None,
      "assertions_actual_count":len(checks) if isinstance(checks,dict) else None,
      "assertions_false_count":sum(v is not True for v in checks.values()) if isinstance(checks,dict) else None,
    }

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--self-test",action="store_true")
    args=p.parse_args()
    if args.self_test:
        fixture={"transaction_result":"FAIL","exact_failure":{
            "sqlstate":"P0001","error":"AUDIT user alice@example.com with ID 00000000-0000-0000-0000-000000000000 failed"},
            "completed_assertions":{},"completed_assertion_count":0}
        s=summary(fixture)
        assert s["transaction_result"]=="FAIL" and s["assertions_actual_count"]==0
        assert "[EMAIL]" in (s["failure_short_audit_reason"] or "")
        assert "alice@example.com" not in json.dumps(s)
        print("SAFE_DIAGNOSTIC_SELF_TEST_PASS")
        return 0
    src=args.source.resolve()
    out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=True)
    if not os.environ.get("SUPABASE_ACCESS_TOKEN"):
        raise RuntimeError("Linked CLI test credentials absent")
    if git(src,"rev-parse","HEAD") != FROZEN:raise ValueError("Frozen BIL commit moved")
    if git(src,"hash-object",str(src/"tools/qa/bil_release_cloud_e2e.py"))!=ORIGINAL_RUNNER_BLOB:
        raise ValueError("Original SQL audit runner no longer pinned")
    if git(src,"hash-object",str(src/SQL_FILE))!=SQL_BLOB:
        raise ValueError("Original rollback-only SQL differs")
    spec=importlib.util.spec_from_file_location("frozen_bil_sql_audit",src/"tools/qa/bil_release_cloud_e2e.py")
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.SQL_FILES = (SQL_FILE,)
    original=mod.assertions
    result={"source_sha":FROZEN,"sql_source_blob":SQL_BLOB,
        "scope":"One original guarded rollback SQL program, strict original checks",
        "receipt":"NOT_RUN","testflight_invoked":False}
    def checked(row):
        result["safe_diagnostic"]=summary(row)
        return original(row)  # Never lower or bypass the original gate.
    mod.assertions=checked
    args_before=sys.argv[:]
    try:
        sys.argv=["original-guarded-runner","--output",str(out/"original")]
        try:
            mod.main()
            result["receipt"]="PASS_ORIGINAL_STRICT"
        except SystemExit as error:
            result["receipt"]="FAIL_ORIGINAL_STRICT"
            result["original_exit"]=str(error.code)[:160]
    except Exception as error:
        result["receipt"]="ERROR"
        result["error_type"]=type(error).__name__
    finally:
        sys.argv=args_before
        if git(src,"rev-parse","HEAD")!=FROZEN or git(src,"diff","--name-only","HEAD"):
            result["receipt"]="SOURCE_CHANGED"
        (out/"safe-diagnostic.json").write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n")
    print(json.dumps(result,ensure_ascii=False))
    return 0 if result["receipt"]=="PASS_ORIGINAL_STRICT" else 3

if __name__=="__main__":
    raise SystemExit(main())
