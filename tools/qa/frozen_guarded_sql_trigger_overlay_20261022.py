#!/usr/bin/env python3
"""Current-schema QA-only rollback test overlay for ONE exact reviewed Auth trigger.

Original BIL product, migrations, and all five original rollback SQL files stay
byte-for-byte unchanged. Existing failure is preserved. The narrowed overlay
requires ONE exact deployed Circle-deletion trigger by both function and trigger
hashes and rejects all other unexpected hooks. Assertions and independent
residue verification remain the original unmodified checker.
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

FROZEN="31554b3e078667a38bd3c53aa105f5f1d2a4dc96"
SQL_RUNNER_BLOB="35b5127dcde75339e56d1940d8653673e2ae81c7"
MIGRATION="supabase/migrations/20261019073511_community_circle_owner_deletion_cleanup_v1.sql"
MIGRATION_BLOB="0b3d242da2e0d737bea8dd1028045e3b5856dd69"
NAME="bil_remove_owned_circles_before_account_delete_v1"
TRIGGER_MD5="8e49f7b56a76260df01a0484b99feb30"
FUNCTION_MD5="b78b4aa2ab0840c7aab089abc81f15f1"
BLOBS={
 "ai_consent_receipt":"a5c234c3a771a2d891b3952bb082ef4ece7ae7e9",
 "cloud_sync_consent":"eca6b368f8883184330044dace9ac01e289a9702",
 "community_collaborator_privacy":"65465d1aae9b23a84932c0757378abd63d57b57e",
 "community_policy_20261019":"67c2d04f5c77d950f6580579fce5fdc8cd3f064a",
 "community_prebuild":"44ad62ad2f3d2e6da3721bea11f731b170d103b5",
}
COMMON_PIN=f"""select 1 from pg_trigger t
 where t.tgrelid='auth.users'::regclass
 and not t.tgisinternal
 and t.tgname='{NAME}'
 and t.tgenabled='O'
 and t.tgfoid='private.{NAME}()'::regprocedure
 and md5(pg_get_triggerdef(t.oid))='{TRIGGER_MD5}'
 and md5(pg_get_functiondef(t.tgfoid))='{FUNCTION_MD5}'"""
PIN="exists("+COMMON_PIN+")"
RULES={
 "ai_consent_receipt":r"if exists\(select 1 from pg_trigger where tgrelid in\s*\('auth\.users'::regclass,'public\.bil_consent_receipts'::regclass\) and not tgisinternal\) then",
 "cloud_sync_consent":r"if exists\(select 1 from pg_trigger where tgrelid='auth\.users'::regclass and not tgisinternal\)",
 "community_collaborator_privacy":r"if exists\(select 1 from pg_trigger where not tgisinternal and tgrelid in\(\s*'auth\.users'::regclass,'public\.bil_community_notifications'::regclass,\s*'public\.bil_push_outbox'::regclass\)\) then",
 "community_prebuild":r"if exists\(select 1 from pg_trigger where not tgisinternal and tgrelid in\(\s*'auth\.users'::regclass,'public\.bil_community_notifications'::regclass,\s*'public\.bil_push_outbox'::regclass\)\) then",
 "community_policy_20261019":r"with expected\(relation, name, trigger_hash, function_hash\) as \(values\s*\n\s*\('public\.bil_community_notifications'::regclass",
}

def path_of(name):
    return "tool/release/"+name+"_production_rollback_e2e.sql"

def git(root,*args):
    return subprocess.check_output(["git",*args],cwd=root,text=True).strip()

def replace_once(src,pattern,func):
    hits=list(re.finditer(pattern,src,flags=re.MULTILINE))
    if len(hits)!=1:raise ValueError("Expected exactly one original guarded trigger check")
    m=hits[0]
    return src[:m.start()]+func(m.group(0))+src[m.end():]

def reviewed_overlay(src,scope):
    if scope in ("ai_consent_receipt","cloud_sync_consent"):
        if scope=="ai_consent_receipt":
            replacement=f"""if (select count(*) from pg_trigger where tgrelid in
      ('auth.users'::regclass,'public.bil_consent_receipts'::regclass) and not tgisinternal)<>1
    or not {PIN} then"""
        else:
            replacement=f"""if (select count(*) from pg_trigger
     where tgrelid='auth.users'::regclass and not tgisinternal)<>1
    or not {PIN}"""
        src=replace_once(src,RULES[scope],lambda _:replacement)
        if scope=="ai_consent_receipt":
            if src.count("'zero_external_auth_receipt_triggers'")!=1:
                raise ValueError("Exact original assertion marker changed")
            src=src.replace("'zero_external_auth_receipt_triggers'",
                "'only_reviewed_auth_circle_cleanup_trigger'")
        return src
    if scope in ("community_collaborator_privacy","community_prebuild"):
        match_start="if exists(select 1 from pg_trigger"
        def substitute(match):
            condition=match[match.index("(")+1:-len(" then")]
            # Original was EXISTS(SELECT...), so COUNT(*) in the same exact
            # three tables must now be 1, not 0 or an unbounded allowlist.
            inner=condition.removeprefix("select 1 from pg_trigger")
            if not inner.startswith(" where not tgisinternal"):raise ValueError("Original 3-table scope changed")
            return f"if (select count(*) from pg_trigger{inner})<>1 or not {PIN} then"
        return replace_once(src,RULES[scope],substitute)
    if scope=="community_policy_20261019":
        original=r"with expected(relation, name, trigger_hash, function_hash) as (values"
        entry=(f"('auth.users'::regclass,'{NAME}',"
               f"'{TRIGGER_MD5}','{FUNCTION_MD5}'),")
        src=replace_once(src,RULES[scope],
            lambda m:m.replace(original,original+"\n      "+entry+"\n     ",1))
        start="if exists (\n    with expected("
        if src.count(start)!=1:raise ValueError("Exact policy expected/actual guard changed")
        src=src.replace(start,"if not "+PIN+" or exists (\n    with expected(",1)
        return src
    raise ValueError("Unknown guarded scope")

def audit_module(source):
    spec=importlib.util.spec_from_file_location(
       "bil_sql_frozen_original",source/"tools/qa/bil_release_cloud_e2e.py")
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def prepare(source,scope):
    source=source.resolve()
    if git(source,"rev-parse","HEAD")!=FROZEN:
        raise ValueError("Frozen source HEAD differs")
    for path,blob in ((MIGRATION,MIGRATION_BLOB),
        ("tools/qa/bil_release_cloud_e2e.py",SQL_RUNNER_BLOB),
        (path_of(scope),BLOBS[scope])):
        if git(source,"hash-object",str(source/path))!=blob:
            raise ValueError("Exact original blob or reviewed migration changed: "+path)
    original=(source/path_of(scope)).read_text(encoding="utf-8-sig").replace("\r\n","\n")
    revised=reviewed_overlay(original,scope)
    if revised==original or NAME not in revised or TRIGGER_MD5 not in revised or FUNCTION_MD5 not in revised:
        raise ValueError("QA overlay cannot prove strict new trigger review")
    module=audit_module(source)
    module.segments(revised)  # Keep unchanged BEGIN, ROLLBACK and no DDL checks.
    return revised, original, module

def sanitized(row):
    failure=row.get("exact_failure")
    if isinstance(failure,str):
        try:failure=json.loads(failure)
        except ValueError:failure=None
    checks=row.get("completed_assertions")
    if isinstance(checks,str):
        try:checks=json.loads(checks)
        except ValueError:checks=None
    why=failure.get("error") if isinstance(failure,dict) else None
    if not isinstance(why,str) or not why.startswith("AUDIT "):why=None
    if why:
        why=re.sub(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}\b","[ID]",why)
        why=re.sub(r"(?i)\b[A-Z0-9_.+%-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b","[EMAIL]",why)
        why=why[:140]
    state=failure.get("sqlstate") if isinstance(failure,dict) else None
    return {"transaction_result":row.get("transaction_result"),
        "failure_sqlstate":state if isinstance(state,str) and re.fullmatch("[A-Z0-9]{5}",state) else None,
        "audit_reason":why,"assertions_count":row.get("completed_assertion_count")
            if type(row.get("completed_assertion_count")) is int else None,
        "assertions_true":sum(x is True for x in checks.values()) if isinstance(checks,dict) else None,
        "assertions_false":sum(x is not True for x in checks.values()) if isinstance(checks,dict) else None,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    ap.add_argument("--scope",required=True,choices=tuple(BLOBS))
    ap.add_argument("--self-test",action="store_true")
    args=ap.parse_args()
    src=args.source.resolve()
    out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=True)
    revised,original,mod=prepare(src,args.scope)
    manifest={
       "source_sha":FROZEN,"scope":args.scope,"original_sql_blob":BLOBS[args.scope],
       "reviewed_circle_migration_blob":MIGRATION_BLOB,
       "original_sql_sha256":hashlib.sha256(original.encode()).hexdigest(),
       "updated_guard_sql_sha256":hashlib.sha256(revised.encode()).hexdigest(),
       "reviewed_trigger_md5":TRIGGER_MD5,"reviewed_function_md5":FUNCTION_MD5,
       "status":"NOT_RUN","release_certification":False,
       "previous_unmodified_sql_audit_remains_failed":True,
       "testflight_invoked":False,"production_ddl_or_grants":False,
       "scope_note":"Original SQL assertion/residue code runs. Only known Auth circle cleanup trigger allowlisted exactly, any unknown hook blocked."
    }
    if args.self_test:
        manifest["status"]="OVERLAY_PREFLIGHT_PASS"
        (out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
        print("REVIEWED_TRIGGER_OVERLAY_PREFLIGHT_PASS",args.scope)
        return 0
    if not os.environ.get("SUPABASE_ACCESS_TOKEN"):raise RuntimeError("Missing linked SQL testing token")
    mod.SQL_FILES=(path_of(args.scope),)
    old_segments=mod.segments
    old_assertions=mod.assertions
    def patched(original_input):
        if original_input!=original:
            raise ValueError("Original source SQL bytes changed at test time")
        return old_segments(revised)
    def checked(row):
        manifest["transaction"]=sanitized(row)
        return old_assertions(row)
    mod.segments=patched
    mod.assertions=checked
    old_argv=sys.argv[:]
    try:
        sys.argv=["reviewed-trigger-qa","--output",str(out/"original-checker")]
        try:
            mod.main()
            manifest["status"]="PASS_REVIEWED_TRIGGER_OVERLAY"
        except SystemExit:
            manifest["status"]="FAIL_REVIEWED_TRIGGER_OVERLAY"
    finally:
        sys.argv=old_argv
        if git(src,"rev-parse","HEAD")!=FROZEN or git(src,"diff","--name-only","HEAD"):
            manifest["status"]="FROZEN_SOURCE_CHANGED"
        (out/"manifest.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n")
    print(json.dumps(manifest,ensure_ascii=False))
    return 0 if manifest["status"]=="PASS_REVIEWED_TRIGGER_OVERLAY" else 3

if __name__=="__main__":raise SystemExit(main())
