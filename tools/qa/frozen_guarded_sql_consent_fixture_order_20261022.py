#!/usr/bin/env python3
"""QA-only fix for three stale synthetic community SQL fixtures.

The frozen original SQL puts synthetic profile INSERT before current-policy
acceptance, which the 2026-10-19 production profile consent guard rejects.
Move *only* the original synthetic acceptance SQL statement before the original
synthetic profile statement. Retain every original SQL assertion, RLS role,
trigger checksum, exact reviewed migration pin, BEGIN, ROLLBACK, and independent
68-table residue readback. No production changes, GRANT, DDL or TestFlight.
"""
import argparse
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import frozen_guarded_sql_trigger_overlay_20261022 as baseline

SCOPES = ("community_prebuild", "community_collaborator_privacy",
          "community_policy_20261019")
PROFILE = "insert into public.bil_public_profiles(user_id,"
ACCEPT = "insert into public.bil_content_policy_acceptances(user_id,policy_version)"
ACCEPT_END = "set user_id=excluded.user_id,policy_version=excluded.policy_version;"
COMMENT = "    -- SDK omits onConflict: PostgREST uses the complete composite primary key.\n"
PREVIOUS = baseline.reviewed_overlay
PREVIOUS_SANITIZED = baseline.sanitized


def exact_fixture_order_only(original, scope):
    reviewed = PREVIOUS(original, scope)
    if scope not in SCOPES:
        return reviewed
    if (reviewed.count(PROFILE) != 1 or reviewed.count(ACCEPT) != 1
            or reviewed.count(ACCEPT_END) != 1):
        raise ValueError("Exactly one frozen policy and profile fixture required")
    profile_at, acceptance_at = reviewed.index(PROFILE), reviewed.index(ACCEPT)
    if profile_at >= acceptance_at:
        raise ValueError("Original fixture order changed; reject unknown overlay")
    profile_line = reviewed.rfind("\n", 0, profile_at) + 1
    acceptance_line = reviewed.rfind("\n", 0, acceptance_at) + 1
    acceptance_end_at = reviewed.index(ACCEPT_END, acceptance_at) + len(ACCEPT_END)
    end_line = reviewed.find("\n", acceptance_end_at)
    if end_line < 0:
        raise ValueError("Incomplete acceptance statement")
    end_line += 1
    start = acceptance_line
    if scope != "community_collaborator_privacy":
        if reviewed.count(COMMENT) != 1:
            raise ValueError("Exact original canonical consent fixture comment missing")
        start = reviewed.index(COMMENT)
        if not profile_line < start <= acceptance_line:
            raise ValueError("Consent fixture comment drifted")
    block = reviewed[start:end_line]
    if (block.count("insert into ") != 1 or block.count("on conflict(") != 1
            or block.count(ACCEPT_END) != 1 or block.count(";") != 1
            or "values(v_uid,v_policy)" not in block):
        raise ValueError("Unexpected consent fixture content; refuse modification")
    stripped = reviewed[:start] + reviewed[end_line:]
    # No app, migration, role, assertion or SQL text modification: only a move.
    transformed = stripped[:profile_line] + block + stripped[profile_line:]
    if (transformed[:profile_line] + transformed[profile_line + len(block):]
            != stripped or len(transformed) != len(reviewed)):
        raise ValueError("Changed anything besides exact consent fixture position")
    if not (transformed.index(ACCEPT) < transformed.index(PROFILE)
            < transformed.index("bil_current_community_policy_status()",
                                transformed.index(PROFILE))):
        raise ValueError("Policy acceptance must precede profile and readback")
    # The actor is still a genuine JWT authenticated principal, never a service bypass.
    if "execute 'set local role authenticated';" not in transformed[:profile_line]:
        raise ValueError("Authenticated owner fixture missing")
    return transformed


def sanitized_error_location(row):
    result = PREVIOUS_SANITIZED(row)
    failure = row.get("exact_failure")
    if isinstance(failure, str):
        try:
            failure = json.loads(failure)
        except ValueError:
            failure = None
    if not isinstance(failure, dict):
        return result
    message = failure.get("error")
    if isinstance(message, str):
        # Only static policy markers and metadata-only permission errors.
        known = ("community_policy_acceptance_required",
                 "community_profile_owner_required",
                 "community_access_suspended",
                 "community_policy_unavailable")
        acceptable = re.fullmatch(
            r"permission denied for (?:relation|table|schema|function|sequence) "
            r"[a-zA-Z_][a-zA-Z0-9_.()]*", message)
        result["safe_failure_marker"] = (
            message if message in known or acceptable
            else "REDACTED_UNRECOGNIZED_FAILURE"
        )
    stack = failure.get("stack_context")
    if isinstance(stack, str):
        frames = re.findall(
            r"PL/pgSQL function ([a-zA-Z0-9_.]+)\([^\n\"']{0,150}\) "
            r"line ([0-9]{1,5}) at ([a-zA-Z ]{1,45})", stack)
        result["safe_plpgsql_frames"] = [
            {"function": f, "line": int(line), "stage": stage.strip()}
            for f, line, stage in frames[:8]]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--scope", choices=SCOPES)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    baseline.reviewed_overlay = exact_fixture_order_only
    baseline.sanitized = sanitized_error_location
    if args.self_test:
        # Includes exact upstream blob/migration/trigger validations.
        for scope in SCOPES:
            candidate, original, checker = baseline.prepare(args.source, scope)
            assert original != candidate
            assert candidate.index(ACCEPT) < candidate.index(PROFILE)
            checker.segments(candidate)  # validates BEGIN/ROLLBACK/no-DDL.
            print("EXACT_FIXTURE_ORDER_ONLY_OFFLINE_PASS", scope)
        return 0
    if args.scope is None:
        parser.error("--scope required for actual live check")
    args.output.mkdir(parents=True, exist_ok=True)
    old_argv = sys.argv[:]
    try:
        sys.argv = ["source-pinned-frozen-sql",
                    "--source", str(args.source), "--scope", args.scope,
                    "--output", str(args.output)]
        rc = baseline.main()  # unchanged assert(), live queries + residue.
    finally:
        sys.argv = old_argv
    out = args.output / "manifest.json"
    if out.exists():
        record = json.loads(out.read_text(encoding="utf-8"))
        record["qa_only_fixture_order"] = "genuine_authenticated_acceptance_before_profile"
        record["original_transaction_assertions"] = "UNCHANGED"
        record["original_rollback_and_residue"] = "UNCHANGED"
        record["no_app_migration_ddl_grants_or_testflight"] = True
        out.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n",
                       encoding="utf-8")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
