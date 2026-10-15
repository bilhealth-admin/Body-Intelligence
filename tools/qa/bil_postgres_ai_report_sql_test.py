"""Run the checked-in AI report SQL suite on disposable loopback PostgreSQL.

Uses real repository migration/function bodies and synthetic Auth settings.
This is not a Supabase Auth/PostgREST/Storage or device test. The cluster is
stopped on every exit and retained below build/ for diagnosis.
"""

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--postgres-bin", required=True, type=pathlib.Path)
    parser.add_argument("--port", type=int, default=55434)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9-]+", args.label):
        parser.error("label must contain lowercase letters, digits or hyphens")
    if not 1024 <= args.port <= 65535:
        parser.error("port must be an unprivileged TCP port")
    root = pathlib.Path(__file__).resolve().parents[2]
    out = root / "build/qa/text7-18-reconciliation-20261015" / args.label
    out.mkdir(parents=True, exist_ok=False)
    data = out / "data"
    suffix = ".exe" if sys.platform == "win32" else ""
    binary = lambda name: str(args.postgres_bin / (name + suffix))
    inputs = {}
    result = {
        "environment": "native PostgreSQL, loopback, synthetic Auth settings",
        "source_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True
        ).strip(),
        "port": args.port,
        "started_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "result": "FAIL",
    }
    started = False

    def run(command, sql=None, timeout=60):
        return subprocess.run(
            command, input=sql, capture_output=True, text=True,
            encoding="utf-8", errors="replace", timeout=timeout,
        )

    def control(*command):
        # PostgreSQL is a persistent child on Windows. Pipe capture can keep
        # communicate() open after pg_ctl exits; use a file and closed stdin.
        with (out / "pg_ctl.log").open("a", encoding="utf-8") as log:
            return subprocess.run(
                [binary("pg_ctl"), "-D", str(data), *command],
                stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                close_fds=True, timeout=60,
            )

    def source(path):
        payload = (root / path).read_bytes()
        inputs[path] = hashlib.sha256(payload).hexdigest()
        return payload.decode("utf-8-sig")

    def function(sql, name):
        match = re.search(
            r"(create(?:\s+or\s+replace)?\s+function\s+" + re.escape(name)
            + r"\s*\(.*?\bas\s+(\$[a-zA-Z_]*\$).*?\2\s*;)",
            sql, re.I | re.S,
        )
        if not match:
            raise AssertionError("Missing repository function: " + name)
        return match.group(1)

    psql = [binary("psql"), "-X", "-qAt", "-v", "ON_ERROR_STOP=1",
            "-h", "127.0.0.1", "-p", str(args.port),
            "-U", "bil_test_superuser", "-d", "postgres"]

    def execute(sql):
        completed = run(psql, sql)
        if completed.returncode:
            raise RuntimeError(completed.stderr)
        return completed.stdout.strip()

    try:
        initialized = run([binary("initdb"), "-D", str(data), "-U",
                           "bil_test_superuser", "-A", "trust", "--no-locale",
                           "--encoding=UTF8"])
        (out / "initdb.log").write_text(
            initialized.stdout + initialized.stderr, encoding="utf-8"
        )
        if initialized.returncode:
            raise RuntimeError("isolated initdb failed; see initdb.log")
        started = True
        launched = control("-l", str(out / "postgres.log"), "-o",
                           "-h 127.0.0.1 -p " + str(args.port), "-w", "start")
        if launched.returncode:
            raise RuntimeError("isolated PostgreSQL start failed; see pg_ctl.log")
        result["postgres_version"] = execute("select version();")
        execute("""
          create role anon; create role authenticated; create role service_role;
          create schema auth; create schema private;
          create table auth.users(
            id uuid primary key, aud text, role text, email text,
            encrypted_password text, email_confirmed_at timestamptz,
            raw_app_meta_data jsonb, raw_user_meta_data jsonb,
            created_at timestamptz, updated_at timestamptz
          );
          create table public.bil_community_moderators(user_id uuid primary key);
          create table private.bil_ai_coach_admins(
            user_id uuid primary key, active boolean not null
          );
          create table private.bil_community_member_access(
            user_id uuid primary key, suspended boolean not null
          );
          create table public.bil_ai_usage_events(
            owner_id uuid, request_id text, capability text, state text
          );
          create function auth.uid() returns uuid language sql stable as $$
            select coalesce(
              nullif(current_setting('request.jwt.claim.sub',true),''),
              nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub'
            )::uuid
          $$;
          grant usage on schema auth,public to anon,authenticated,service_role;
        """)
        member = source("supabase/migrations/20260905160000_admin_community_access_control.sql")
        authority = source("supabase/migrations/20261013062221_community_safety_report_review_v1.sql")
        execute(function(member, "public.bil_can_use_community"))
        execute(function(authority, "private.bil_lock_community_authority_v1"))
        execute("revoke all on function private.bil_lock_community_authority_v1() "
                "from public,anon,authenticated,service_role;")
        execute(source("supabase/migrations/20261014100000_ai_coach_safety_reports_v1.sql"))
        test = source("supabase/tests/ai_coach_safety_reports_v1_test.sql")
        tested = run(psql, test)
        (out / "sql.stdout.log").write_text(tested.stdout, encoding="utf-8")
        (out / "sql.stderr.log").write_text(tested.stderr, encoding="utf-8")
        result["sql_exit_code"] = tested.returncode
        result["rollback_preserved_empty_fixture"] = execute(
            "select (select count(*) from auth.users)=0 and "
            "(select count(*) from private.bil_ai_coach_safety_reports_v1)=0;"
        ) == "t"
        if tested.returncode:
            raise RuntimeError(tested.stderr.strip())
        if not result["rollback_preserved_empty_fixture"]:
            raise AssertionError("SQL test did not roll back synthetic data")
        result["result"] = "PASS"
        print("PASS: exact AI report SQL suite, real repository functions, rollback")
    except Exception as error:
        result["error"] = str(error)
        print("FAIL: " + str(error), flush=True)
    finally:
        if started:
            try:
                stopped = control("-m", "fast", "-w", "stop")
                result["cluster_stopped"] = stopped.returncode == 0
            except Exception as error:
                result["cluster_stopped"] = False
                result["stop_error"] = str(error)
            if not result["cluster_stopped"]:
                result["result"] = "FAIL"
                result.setdefault("stop_error", "see pg_ctl.log")
        result["inputs_sha256"] = inputs
        result["finished_at_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (out / "result.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print("Evidence: " + str(out / "result.json"), flush=True)
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
