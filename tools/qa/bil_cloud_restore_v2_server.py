"""Loopback-only test RPC bridge to real, isolated PostgreSQL transactions.

This is not PostgREST, Supabase Auth, a deployed service, or a phone test. It
accepts only synthetic JWT subjects listed in its configuration, executes the
actual migration as an authenticated SQL role, and never logs request bodies,
tokens, keys, or ciphertext. No third-party runtime/dependency is installed.
"""

from __future__ import annotations

import argparse
import base64
import datetime
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import subprocess
import threading
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
MIGRATION = "supabase/migrations/20261012052335_cloud_nutrition_goals_restore_v2.sql"
OWNER_A = "51000000-0000-4000-8000-000000000001"
OWNER_B = "51000000-0000-4000-8000-000000000002"
OWNERS = (OWNER_A, OWNER_B)
RPC_ARGUMENTS = {
    "bil_cloud_restore_capabilities_v2": (),
    "bil_cloud_restore_consent_v2": (),
    "bil_record_cloud_restore_consent_v2": ("p_scope", "p_granted", "p_policy_version"),
    "bil_revoke_cloud_restore_device_v2": ("p_device_id",),
    "bil_sync_records_v2": ("p_device_id", "p_scope", "p_cursor", "p_operations", "p_limit"),
    "bil_sync_records": ("p_device_id", "p_cursor", "p_operations"),
    "bil_record_consent": ("p_purpose", "p_policy_version", "p_granted"),
    "bil_get_existing_cloud_key": (),
    "bil_get_or_create_cloud_key": (),
}


def sql_literal(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, (list, dict)):
        return "'" + json.dumps(value, ensure_ascii=False).replace("'", "''") + "'::jsonb"
    if isinstance(value, str):
        return "'" + value.replace("'", "''") + "'"
    raise ValueError("unsupported synthetic SQL argument")


class SqlFailure(RuntimeError):
    pass


class Fixture:
    def __init__(self, psql, port=55432, *, proposed=True):
        self.psql = str(psql)
        self.port = port
        self.database = "bil_qa_restore_" + datetime.datetime.now().strftime("%Y%m%d%H%M%S%f")
        self.files = []
        self.base = [self.psql, "-X", "-qAt", "-P", "null=null", "-v", "ON_ERROR_STOP=1",
                     "-h", "127.0.0.1", "-p", str(port), "-U", "bil_test_superuser"]
        self.execute(f'create database "{self.database}";', database="postgres")
        self.execute("""
          do $$begin
            if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
            if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
            if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
          end $$;
          create schema auth; create schema private;
          create table auth.users(id uuid primary key,email text,deleted_at timestamptz);
          create function auth.jwt() returns jsonb language sql stable as
            $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
          create function auth.uid() returns uuid language sql stable as
            $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
          grant usage on schema public,auth to authenticated,anon,service_role;
        """)
        self.install("supabase/tests/fixtures/cloud_ledger_baseline/schema.sql")
        self.install("supabase/tests/fixtures/cloud_ledger_baseline/function.sql")
        # Exact existing consent writer body from the checked-in approved
        # migration, excluding its live-catalog drift guard. This is a fixture.
        consent = ROOT / "supabase/migrations/20261004173646_ai_consent_receipt_completion_order_v1.sql"
        source = consent.read_text(encoding="utf-8")
        start = source.index("CREATE OR REPLACE FUNCTION public.bil_record_consent")
        end = source.index("$function$;", start) + len("$function$;")
        self.execute(source[start:end])
        self.files.append(consent)
        self.execute("revoke all on function public.bil_record_consent(text,text,boolean) from public,anon;"
                     "grant execute on function public.bil_record_consent(text,text,boolean) to authenticated;")
        # Vault is deliberately not simulated as real custody. These known
        # synthetic keys let Flutter exercise its real AES envelope interface.
        self.execute("""
          create function public.bil_get_existing_cloud_key() returns text
          language plpgsql security definer set search_path=pg_catalog,public as $$
          begin
            if auth.uid() is null then raise exception 'authentication_required'; end if;
            return encode(decode(repeat(case when right(auth.uid()::text,1)='1' then '01' else '02' end,32),'hex'),'base64');
          end $$;
          create function public.bil_get_or_create_cloud_key() returns text language sql security definer
          set search_path=pg_catalog,public as $$select public.bil_get_existing_cloud_key()$$;
          revoke all on function public.bil_get_existing_cloud_key(),public.bil_get_or_create_cloud_key() from public,anon;
          grant execute on function public.bil_get_existing_cloud_key(),public.bil_get_or_create_cloud_key() to authenticated;
        """)
        for owner in OWNERS:
            self.execute(f"insert into auth.users values('{owner}','synthetic-{owner[-1]}@example.test',null);")
            self.rpc("bil_record_consent", {"p_purpose": "cloud_sync", "p_policy_version": "1", "p_granted": True}, owner)
        self.v1_hash_before = self.execute(
            "select md5(pg_get_functiondef('public.bil_sync_records(text,bigint,jsonb)'::regprocedure));"
        )[-1]
        if proposed:
            self.install(MIGRATION)
        self.proposed = proposed

    def execute(self, sql, owner=None, *, database=None, role=None, timeout=30):
        if owner is not None:
            claims = json.dumps({"role": "authenticated", "sub": owner})
            sql = ("begin; set local role authenticated; "
                   f"select set_config('request.jwt.claims',{sql_literal(claims)},true); "
                   f"select set_config('request.jwt.claim.sub',{sql_literal(owner)},true); " + sql + "\ncommit;")
        elif role:
            assert role in ("anon", "authenticated")
            sql = "begin; set local role " + role + "; " + sql + "\ncommit;"
        result = subprocess.run(self.base + ["-d", database or self.database], input=sql,
                                text=True, encoding="utf-8", capture_output=True, timeout=timeout)
        if result.returncode:
            raise SqlFailure(result.stderr.strip())
        return result.stdout.strip().splitlines()

    def value(self, sql, owner=None, **kwargs):
        return json.loads(self.execute(sql, owner, **kwargs)[-1])

    def rpc(self, name, arguments=None, owner=OWNER_A):
        allowed = RPC_ARGUMENTS.get(name)
        arguments = arguments or {}
        if allowed is None or set(arguments) - set(allowed):
            raise ValueError("unknown RPC or argument")
        actual = ",".join(key + "=>" + sql_literal(arguments[key]) for key in allowed if key in arguments)
        return self.value("select to_jsonb(public." + name + "(" + actual + "));", owner)

    def install(self, relative):
        path = ROOT / relative
        self.execute(path.read_text(encoding="utf-8"))
        self.files.append(path)

    def close(self):
        assert re.fullmatch(r"bil_qa_restore_[0-9]+", self.database)
        self.execute(f'drop database if exists "{self.database}" with (force);', database="postgres")

    def evidence(self):
        return {str(path.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in self.files}


class Handler(BaseHTTPRequestHandler):
    server_version = "BIL-Loopback-PG-Test/2"

    def log_message(self, fmt, *args):
        # URL/method/status only. Never headers or bodies containing JWT/data.
        print(fmt % args, flush=True)

    def send_json(self, code, body):
        encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"ready": True, "fixture": "isolated PostgreSQL, synthetic identity"})
        else:
            self.send_json(404, {"message": "unknown test route"})

    def do_POST(self):
        if self.path == "/__test__/shutdown":
            self.send_json(200, {"stopping": True})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return
        try:
            token = self.headers.get("Authorization", "")
            if not token.startswith("Bearer "):
                raise ValueError("synthetic bearer token required")
            pieces = token[7:].split(".")
            claims = json.loads(base64.urlsafe_b64decode(pieces[1] + "=" * (-len(pieces[1]) % 4)))
            owner = claims.get("sub")
            if owner not in OWNERS or claims.get("role") != "authenticated":
                raise ValueError("unregistered synthetic owner")
            path = urlparse(self.path).path
            prefix = "/rest/v1/rpc/"
            if not path.startswith(prefix):
                raise ValueError("unknown test route")
            name = path[len(prefix):]
            length = int(self.headers.get("Content-Length", "0"))
            if length < 0 or length > 16 * 1024 * 1024:
                raise ValueError("test request size rejected")
            arguments = json.loads(self.rfile.read(length) or b"{}")
            if arguments is None:
                arguments = {}  # SDK no-argument RPCs use JSON null.
            if not isinstance(arguments, dict):
                raise ValueError("RPC arguments must be an object")
            result = self.server.fixture.rpc(name, arguments, owner)
            self.send_json(200, result)
        except SqlFailure as error:
            # SQL fixture errors contain no interpolated payload in messages;
            # return only the first PostgreSQL message, not its SQL/context.
            message = str(error).splitlines()[0].removeprefix("ERROR:  ")
            unavailable = "does not exist" in message
            self.send_json(404 if unavailable else 400, {
                "code": "PGRST202" if unavailable else "P0001", "message": message,
                "details": None, "hint": None,
            })
        except (ValueError, IndexError, KeyError, TypeError):
            self.send_json(401, {"code": "TEST_AUTH", "message": "invalid synthetic request"})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--psql", required=True)
    parser.add_argument("--pg-port", type=int, default=55432)
    parser.add_argument("--http-port", type=int, default=55433)
    parser.add_argument("--current-schema", action="store_true")
    parser.add_argument("--config", default="build/cloud-restore-v2/server-config.json")
    args = parser.parse_args()
    fixture = Fixture(args.psql, args.pg_port, proposed=not args.current_schema)
    server = ThreadingHTTPServer(("127.0.0.1", args.http_port), Handler)
    server.fixture = fixture
    path = (ROOT / args.config).resolve()
    if not path.is_relative_to(ROOT / "build"):
        raise ValueError("test server config must stay in ignored build directory")
    path.parent.mkdir(parents=True, exist_ok=True)
    config = {"url": f"http://127.0.0.1:{server.server_address[1]}", "pid": os.getpid(),
              "database": fixture.database, "postgres_host": "127.0.0.1", "postgres_port": args.pg_port,
              "owner_a": OWNER_A, "owner_b": OWNER_B, "protocol_version": 1 if args.current_schema else 2,
              "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "sources": fixture.evidence(), "scope": "synthetic test only; not Supabase Auth or Production"}
    path.write_text(json.dumps(config, indent=2), encoding="utf-8")
    print(json.dumps({"ready": True, "url": config["url"], "config": str(path), "pid": os.getpid()}), flush=True)
    try:
        server.serve_forever(poll_interval=0.2)
    finally:
        server.server_close()
        fixture.close()
        config["stopped_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        path.write_text(json.dumps(config, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
