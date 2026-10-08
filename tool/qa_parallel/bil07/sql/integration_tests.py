#!/usr/bin/env python3
"""Ordinary-role SQL/RLS and real multi-connection tests, local fixtures only."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
A = "11111111-1111-4111-8111-111111111111"
B = "22222222-2222-4222-8222-222222222222"
C = "33333333-3333-4333-8333-333333333333"
D = "44444444-4444-4444-8444-444444444444"
E = "55555555-5555-4555-8555-555555555555"
F = "66666666-6666-4666-8666-666666666666"
HIDDEN = "77777777-7777-4777-8777-777777777777"
GENERAL = "10000000-0000-4000-8000-000000000001"
NUTRITION = "10000000-0000-4000-8000-000000000002"
WORKOUTS = "10000000-0000-4000-8000-000000000003"
DISABLED = "10000000-0000-4000-8000-000000000005"
RESULTS: list[dict] = []
TRANSCRIPT: list[dict] = []


def sql_text(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def ids_sql(ids: list[str]) -> str:
    return "array[" + ",".join(sql_text(i) for i in ids) + "]::uuid[]"


def check(condition: bool, label: str) -> None:
    if not condition:
        raise AssertionError(label)
    RESULTS.append({"name": label, "status": "PASS"})
    print("PASS: " + label, flush=True)


def environment() -> dict[str, str]:
    host = os.environ.get("PGHOST", "")
    db = os.environ.get("PGDATABASE", "")
    port = os.environ.get("PGPORT", "")
    if host != "127.0.0.1" or not re.fullmatch(r"bil07_local_[a-z0-9_]+", db):
        raise RuntimeError("Refusing a non-loopback/non-disposable database")
    if not port.isdigit() or not 1024 <= int(port) <= 65535:
        raise RuntimeError("Invalid disposable port")
    # Do not inherit connection services, hostaddr, passwords or psql startup.
    env = {k: v for k, v in os.environ.items() if not k.startswith("PG")}
    env.update(
        PGHOST="127.0.0.1", PGHOSTADDR="127.0.0.1", PGPORT=port,
        PGDATABASE=db, PGUSER="postgres", PGSSLMODE="disable",
        PGCONNECT_TIMEOUT="5", PGAPPNAME="bil07-local-tests",
        PGOPTIONS="-c statement_timeout=10000 -c lock_timeout=5000",
    )
    return env


ENV = environment()
PSQL = os.environ.get("BIL07_PSQL", "psql")
ARGS = [
    PSQL, "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=verbose",
    "-h", "127.0.0.1", "-p", ENV["PGPORT"], "-U", "postgres",
    "-d", ENV["PGDATABASE"],
]


def identity(owner: str | None, role: str = "authenticated") -> str:
    if role not in ("authenticated", "anon", "service_role"):
        raise ValueError(role)
    return (
        f"set local role {role};"
        f"select set_config('request.jwt.claim.sub',{sql_text(owner or '')},true);"
    )


def run(sql: str, *, owner: str | None = None, role: str = "authenticated",
        authenticated: bool = False, error: str | None = None) -> str:
    script = "begin;" + identity(owner, role) + sql + ";commit;" if authenticated else sql
    start = time.monotonic()
    result = subprocess.run(
        ARGS, input=script, text=True, capture_output=True, env=ENV,
        timeout=15, check=False,
    )
    TRANSCRIPT.append({
        "command": ARGS, "sql": script, "exit_code": result.returncode,
        "stdout": result.stdout, "stderr": result.stderr,
        "elapsed_seconds": round(time.monotonic() - start, 4),
    })
    if error:
        if result.returncode == 0 or error not in result.stderr:
            raise AssertionError(f"Expected SQL failure {error}: {result.stdout}\n{result.stderr}")
        return result.stderr
    if result.returncode:
        raise AssertionError(f"SQL failed ({result.returncode}): {result.stderr}")
    return result.stdout.strip()


def rpc(name: str, args: str = "", owner: str | None = A) -> dict:
    output = run(
        f"select public.bil07_channel_{name}_v1({args})",
        owner=owner, authenticated=True,
    )
    value = json.loads(output.splitlines()[-1])
    if value["owner_id"] != owner or value["contract_version"] != 1:
        raise AssertionError("RPC scope or contract envelope mismatch")
    return value


def send(owner: str, channel: str, text: str, key: str | None = None) -> dict:
    return rpc("send", f"{sql_text(channel)},{sql_text(key or str(uuid.uuid4()))},{sql_text(text)}", owner)


def page(owner: str, channel: str, before: int | None = None,
         after: int | None = None, limit: int = 50) -> dict:
    args = f"{sql_text(channel)},{before if before is not None else 'null'},"
    args += f"{after if after is not None else 'null'},{limit}"
    return rpc("messages", args, owner)


def deny(label: str, sql: str, owner: str | None = A,
         error: str = "42501", role: str = "authenticated") -> None:
    run(sql, owner=owner, role=role, authenticated=True, error=error)
    check(True, label)


class Session:
    def __init__(self, name: str):
        self.name = "bil07-concurrent-" + name
        self.output: list[str] = []
        self.errors: list[str] = []
        self.scripts: list[str] = []
        self.process = subprocess.Popen(
            ARGS, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, bufsize=1,
            env={**ENV, "PGAPPNAME": self.name},
        )
        self.readers = [
            threading.Thread(target=self._read, args=(self.process.stdout, self.output), daemon=True),
            threading.Thread(target=self._read, args=(self.process.stderr, self.errors), daemon=True),
        ]
        for reader in self.readers:
            reader.start()

    @staticmethod
    def _read(stream, destination):
        for line in iter(stream.readline, ""):
            destination.append(line)

    def write(self, script: str) -> None:
        self.scripts.append(script)
        assert self.process.stdin
        self.process.stdin.write(script + "\n")
        self.process.stdin.flush()

    def wait_for(self, marker: str) -> None:
        deadline = time.monotonic() + 5
        while marker not in "".join(self.output):
            if self.process.poll() is not None or time.monotonic() >= deadline:
                raise AssertionError(f"Session {self.name} did not reach {marker}: {''.join(self.errors)}")
            time.sleep(0.02)

    def finish(self, suffix: str = "commit;", expect_error: str | None = None) -> str:
        if self.process.poll() is None:
            self.write(suffix)
            assert self.process.stdin
            self.process.stdin.close()
        code = self.process.wait(timeout=12)
        for reader in self.readers:
            reader.join(timeout=1)
        output, errors = "".join(self.output), "".join(self.errors)
        TRANSCRIPT.append({
            "command": ARGS, "application_name": self.name, "concurrent": True,
            "sql": "\n".join(self.scripts), "exit_code": code,
            "stdout": output, "stderr": errors,
        })
        if expect_error:
            if code == 0 or expect_error not in errors:
                raise AssertionError(f"Expected concurrent failure {expect_error}: {errors}")
        elif code:
            raise AssertionError(f"Concurrent SQL failed: {errors}")
        return output

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)


def wait_for_lock(session: Session) -> None:
    deadline = time.monotonic() + 5
    while True:
        count = run(
            "select count(*) from pg_catalog.pg_stat_activity "
            f"where application_name={sql_text(session.name)} and wait_event_type='Lock';"
        )
        if count == "1":
            return
        if session.process.poll() is not None or time.monotonic() >= deadline:
            raise AssertionError("Concurrent RPC did not observably wait for a database lock")
        time.sleep(0.02)


def new_channel(label: str) -> str:
    channel = str(uuid.uuid4())
    run(
        "insert into public.bil07_channels_v1(id,slug,title) values "
        f"({sql_text(channel)},{sql_text(label)},{sql_text(label)});"
        "insert into public.bil07_channel_memberships_v1(channel_id,owner_id,status) values "
        f"({sql_text(channel)},{sql_text(A)},'active'),"
        f"({sql_text(channel)},{sql_text(B)},'active');"
    )
    return channel


def send_sql(owner: str, channel: str, body: str, key: str) -> str:
    return (
        "begin;" + identity(owner) +
        "select public.bil07_channel_send_v1("
        f"{sql_text(channel)},{sql_text(key)},{sql_text(body)});"
    )


def concurrency() -> None:
    for rollback in (False, True):
        channel = new_channel("overlap-rollback" if rollback else "overlap-commit")
        first = send(A, channel, "committed initial")["message"]
        alpha, beta = Session("alpha"), Session("beta")
        try:
            alpha.write(send_sql(A, channel, "held transaction", str(uuid.uuid4())) + "select 'A_READY';")
            alpha.wait_for("A_READY")
            beta.write(send_sql(B, channel, "following transaction", str(uuid.uuid4())))
            wait_for_lock(beta)
            check(
                run(f"select max(sequence) from public.bil07_channel_messages_v1 where channel_id={sql_text(channel)};")
                == str(first["sequence"]),
                f"Uncommitted sequence is invisible while later sender blocks (rollback={rollback})",
            )
            alpha.finish("rollback;" if rollback else "commit;")
            beta.finish()
            found = page(C, channel, after=first["sequence"])["messages"]
            expected = ["following transaction"] if rollback else ["held transaction", "following transaction"]
            check(
                [m["text"] for m in found] == expected
                and [m["sequence"] for m in found] == list(range(2, 2 + len(expected))),
                f"Catchup has no late-commit gap and counter rollback is transactional (rollback={rollback})",
            )
        finally:
            alpha.close()
            beta.close()

    channel = new_channel("concurrent-idempotency")
    key = str(uuid.uuid4())
    alpha, beta = Session("same-key-a"), Session("same-key-b")
    try:
        alpha.write(send_sql(A, channel, "same explicit request", key) + "select 'A_READY';")
        alpha.wait_for("A_READY")
        beta.write(send_sql(A, channel, "same explicit request", key))
        wait_for_lock(beta)
        alpha.finish()
        response = beta.finish()
        check('"idempotent_replay": true' in response, "Concurrent same-owner retry returns replay")
        check(len(page(A, channel)["messages"]) == 1, "Concurrent idempotency stores exactly one message")
    finally:
        alpha.close()
        beta.close()

    for change, expected_error in (
        ("disabled", "channel_unavailable"),
        ("banned", "channel_unavailable"),
        ("policy", "community_policy_acceptance_required"),
        ("suspended", "community_access_suspended"),
    ):
        channel = new_channel("race-" + change)
        admin, client = Session("admin-" + change), Session("client-" + change)
        try:
            if change == "suspended":
                admin.write(
                    "begin;select pg_advisory_xact_lock(hashtextextended("
                    f"'community_member_state:'||{sql_text(B)},0));"
                    "insert into private.bil_community_member_access values "
                    f"({sql_text(B)},true) on conflict(user_id) do update set suspended=true;"
                    "select 'ADMIN_READY';"
                )
            else:
                admin.write(
                    "begin;select id from public.bil07_channels_v1 "
                    f"where id={sql_text(channel)} for update;select 'ADMIN_READY';"
                )
            admin.wait_for("ADMIN_READY")
            client.write(send_sql(B, channel, "must fail after state change", str(uuid.uuid4())))
            wait_for_lock(client)
            if change == "disabled":
                admin.write(f"update public.bil07_channels_v1 set enabled=false where id={sql_text(channel)};")
            elif change == "banned":
                admin.write(
                    "update public.bil07_channel_memberships_v1 set status='banned' "
                    f"where channel_id={sql_text(channel)} and owner_id={sql_text(B)};"
                )
            elif change == "policy":
                admin.write(f"delete from public.bil_content_policy_acceptances where user_id={sql_text(B)};")
            admin.finish()
            client.finish(expect_error=expected_error)
            check(
                run(f"select count(*) from public.bil07_channel_messages_v1 where channel_id={sql_text(channel)};") == "0",
                f"Waiting send rechecks {change} after administrator commit",
            )
        finally:
            admin.close()
            client.close()
            run(
                f"delete from private.bil_community_member_access where user_id={sql_text(B)};"
                "insert into public.bil_content_policy_acceptances values "
                f"({sql_text(B)},'fixture-policy-v1',clock_timestamp()) on conflict do nothing;"
            )


def main() -> None:
    version = int(run("select current_setting('server_version_num');"))
    if version < 150000:
        raise RuntimeError("PostgreSQL 15 or newer is required")
    for filename in (
        "bootstrap_fixture.sql", "base_helpers_fixture.sql",
        "channel_contract_v1.sql", "channels_fixture.sql",
    ):
        run((HERE / filename).read_text())
    private_before = run("select md5(jsonb_agg(to_jsonb(m) order by id)::text) from public.bil_messages m;")
    membership_before = run("select count(*) from public.bil07_channel_memberships_v1;")
    caps = rpc("capabilities")
    check(
        caps["max_text_code_points"] == 2000 and caps["max_page_size"] == 100
        and caps["max_receipt_ids"] == 100 and caps["presence_ttl_seconds"] == 90
        and caps["heartbeat_seconds"] == 30 and caps["realtime_available"] is False,
        "Capability v1 returns explicit code-point, paging, receipts and presence contract",
    )
    check(
        run("select count(*) from pg_catalog.pg_class where relnamespace='public'::regnamespace "
            "and relname like 'bil07_%' and relkind='r' and relrowsecurity;") == "5",
        "All five channel tables enable RLS",
    )
    check(
        run("select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n "
            "on n.oid=p.pronamespace where n.nspname='public' "
            "and p.proname like 'bil07_%' and p.prosecdef;") == "0",
        "Exposed channel RPCs are invokers, not public SECURITY DEFINER endpoints",
    )
    check(
        run("select count(*) from pg_catalog.pg_publication_tables where tablename like 'bil07_%';") == "0",
        "Contract does not create or mutate realtime publications",
    )
    check(
        run("select count(*) from pg_catalog.pg_proc p "
            "cross join lateral pg_catalog.aclexplode(coalesce(p.proacl,pg_catalog.acldefault('f',p.proowner))) a "
            "where p.proname like 'bil07_%' and a.grantee=0 and a.privilege_type='EXECUTE';") == "0",
        "Every new function explicitly revokes PUBLIC EXECUTE",
    )
    for name in ("capabilities", "directory"):
        deny(f"Anonymous cannot execute {name}", f"select public.bil07_channel_{name}_v1()", role="anon", owner=None)
    deny("Service-role client API access is not granted", "select public.bil07_channel_capabilities_v1()", role="service_role")
    deny("Authenticated role without auth.uid is rejected", "select public.bil07_channel_capabilities_v1()", owner=None, error="authentication_required")
    for table in ("channels", "channel_memberships", "channel_messages", "channel_reads", "channel_presence"):
        full = "public.bil07_" + table + "_v1"
        deny(f"Direct client SELECT denied: {table}", f"select * from {full}")
        deny(f"Direct client DELETE denied: {table}", f"delete from {full}")
        # Temporarily add SELECT/INSERT in a rollback-only transaction to show
        # RLS independently denies rows, rather than merely testing SQL grants.
        output = run(
            f"begin;grant select,insert on {full} to authenticated;" + identity(A) +
            f"select count(*) from {full};rollback;"
        )
        check(output.splitlines()[-1] == "0", f"Default-deny RLS remains closed even with temporary SELECT grant: {table}")
    deny(
        "Owner spoof via direct message insert denied",
        "insert into public.bil07_channel_messages_v1(channel_id,sequence,author_id,client_message_id,body) "
        f"values({sql_text(GENERAL)},1,{sql_text(B)},'{uuid.uuid4()}','spoof')",
    )
    deny(
        "RPC does not accept caller-provided owner_id",
        "select public.bil07_channel_send_v1("
        f"p_channel_id=>{sql_text(GENERAL)},p_client_message_id=>'{uuid.uuid4()}',"
        f"p_text=>'spoof',p_owner_id=>{sql_text(B)})",
        error="42883",
    )
    run(
        "begin;grant insert on public.bil07_channel_messages_v1 to authenticated;" +
        identity(A) + "insert into public.bil07_channel_messages_v1("
        "channel_id,sequence,author_id,client_message_id,body) "
        f"values({sql_text(GENERAL)},1,{sql_text(A)},'{uuid.uuid4()}','own direct insert');",
        error="row-level security",
    )
    check(True, "RLS rejects own direct write even when INSERT grant is temporarily widened")
    directory_a = rpc("directory")["channels"]
    directory_c = rpc("directory", owner=C)["channels"]
    check([c["slug"] for c in directory_a] == ["general", "nutrition", "workouts", "mindset"], "Directory hides disabled and reveals member-only channel to active member")
    check([c["slug"] for c in directory_c] == ["general", "nutrition", "mindset"], "Nonmember sees only permitted public channels")
    check(all(c["can_send"] is False for c in directory_c), "Public visibility never grants send membership")
    check(GENERAL not in [c["id"] for c in rpc("directory", owner=D)["channels"]], "Banned channel is absent even if public")
    deny("Suspended member directory denied", "select public.bil07_channel_directory_v1()", owner=E, error="community_access_suspended")
    deny("Nonmember cannot read member-only messages", f"select public.bil07_channel_messages_v1('{WORKOUTS}')", owner=C, error="channel_unavailable")
    deny("Banned channel read denied", f"select public.bil07_channel_messages_v1('{GENERAL}')", owner=D, error="channel_unavailable")
    deny("Disabled channel read denied", f"select public.bil07_channel_messages_v1('{DISABLED}')", error="channel_unavailable")
    deny("Public nonmember cannot send", f"select public.bil07_channel_send_v1('{GENERAL}','{uuid.uuid4()}','hello')", owner=C, error="channel_membership_required")
    deny("Unaccepted current policy cannot send", f"select public.bil07_channel_send_v1('{GENERAL}','{uuid.uuid4()}','hello')", owner=F, error="community_policy_acceptance_required")
    check(rpc("directory", owner=F)["channels"][0]["can_send"] is False, "Directory policy status prevents send without automatically accepting")
    first_dir = rpc("directory", "null,2")
    second_dir = rpc("directory", sql_text(first_dir["next_after_id"]) + ",2")
    check(
        [c["id"] for c in first_dir["channels"] + second_dir["channels"]]
        == [c["id"] for c in directory_a] and second_dir["next_after_id"] is None,
        "Directory keyset paging has no duplicates",
    )
    check(run("select count(*) from public.bil07_channel_memberships_v1;") == membership_before, "Directory, reads and rejected sends never auto-join")
    for name, value in (
        ("empty", ""), ("unicode whitespace", "\t\n\r \u00a0\u1680\u2000\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"),
        ("overlength emoji", "😀" * 2001), ("DEL", "text\x7f"), ("bell", "text\x07"),
    ):
        deny(
            "Text rejects " + name,
            f"select public.bil07_channel_send_v1('{GENERAL}','{uuid.uuid4()}',{sql_text(value)})",
            error="channel_invalid_text",
        )
    for value in ("fixture@example.com", "https://example.org", "@fixture_member", "+20 100 123 4567", "راسلني على واتساب"):
        deny(
            "BASE contact policy rejects " + value,
            f"select public.bil07_channel_send_v1('{GENERAL}','{uuid.uuid4()}',{sql_text(value)})",
            error="community_contact_exchange_not_allowed",
        )
    text = " \tتمرين 😀\nراحة\r "
    preserved = send(A, GENERAL, text)["message"]
    check(preserved["text"] == text and preserved["is_read"] is True, "Send preserves whitespace, tabs, CR/LF and emoji exactly")
    boundary = send(A, GENERAL, "😀" * 2000)["message"]
    check(len(boundary["text"]) == 2000, "Exactly 2000 supplementary Unicode code points accepted")
    check(send(A, GENERAL, "Logged on 2026-10-07")["message"]["text"] == "Logged on 2026-10-07", "BASE contact policy date exception remains usable")
    key = str(uuid.uuid4())
    send(A, GENERAL, "response deliberately discarded", key)
    retried = send(A, GENERAL, "response deliberately discarded", key)
    check(retried["idempotent_replay"] is True, "Committed send with lost response retries idempotently")
    check(
        run(f"select count(*) from public.bil07_channel_messages_v1 where channel_id='{GENERAL}' and author_id='{A}' and client_message_id='{key}';") == "1",
        "Response-loss retry stored only one owner/channel/client-key row",
    )
    deny("Retry key rejects changed payload", f"select public.bil07_channel_send_v1('{GENERAL}','{key}','different')", error="channel_idempotency_payload_mismatch")
    other_owner = send(B, GENERAL, "same key different owner", key)
    other_channel = send(A, NUTRITION, "same key different channel", key)
    check(
        other_owner["message"]["id"] != retried["message"]["id"]
        and other_channel["message"]["id"] != retried["message"]["id"],
        "Idempotency key is scoped to owner and channel",
    )
    overlap_channel = new_channel("page-overlap")
    original = [send(B, overlap_channel, "row " + chr(97 + n))["message"] for n in range(6)]
    newest = page(A, overlap_channel, limit=2)
    appended = send(B, overlap_channel, "arrived during earlier paging")["message"]
    older = page(A, overlap_channel, before=newest["next_before_sequence"], limit=2)
    oldest = page(A, overlap_channel, before=older["next_before_sequence"], limit=2)
    catchup = page(A, overlap_channel, after=newest["next_after_sequence"], limit=2)
    merged = oldest["messages"] + older["messages"] + newest["messages"] + catchup["messages"]
    check(
        [m["id"] for m in merged] == [m["id"] for m in original] + [appended["id"]],
        "New-message overlap with older paging loses no row and duplicates none",
    )
    check(all(m["client_message_id"] is None and m["is_read"] is False for m in merged), "Foreign retry keys stay private and unread comes from server receipt state")
    deny("Before and after cursors together rejected", f"select public.bil07_channel_messages_v1('{GENERAL}',4,1,10)", error="channel_invalid_page")
    deny("Zero page size rejected", f"select public.bil07_channel_messages_v1('{GENERAL}',null,null,0)", error="channel_invalid_page")
    initial_readback = rpc("readback", f"'{overlap_channel}',{ids_sql([original[0]['id']])}")
    check(initial_readback["acknowledged_message_ids"] == [] and initial_readback["unread_count"] == 7, "Reading directory/messages alone does not mark receipts")
    offered = [original[0]["id"], original[0]["id"], other_channel["message"]["id"], str(uuid.uuid4())]
    rpc("read", f"'{overlap_channel}',{ids_sql(offered)}")
    arrived_after_read = send(B, overlap_channel, "arrived before readback")["message"]
    confirmed = rpc("readback", f"'{overlap_channel}',{ids_sql(offered)}")
    check(
        confirmed["acknowledged_message_ids"] == [original[0]["id"]]
        and confirmed["unread_count"] == 7,
        "Exact receipt intersection excludes duplicate, foreign and unknown IDs; concurrent arrival stays unread",
    )
    visible_rows = page(A, overlap_channel)["messages"]
    check(
        [m["id"] for m in visible_rows if m["is_read"]] == [original[0]["id"]]
        and arrived_after_read["id"] in [m["id"] for m in visible_rows if not m["is_read"]],
        "Message is_read is authoritative per-owner receipt projection",
    )
    check(
        rpc("readback", f"'{overlap_channel}',{ids_sql([original[0]['id']])}", B)["acknowledged_message_ids"] == [],
        "Owner B cannot receive owner A read acknowledgement (including own-message shortcut)",
    )
    deny("Null receipt array rejected", f"select public.bil07_channel_read_v1('{GENERAL}',null)", error="channel_invalid_receipts")
    deny("Null element receipt rejected", f"select public.bil07_channel_read_v1('{GENERAL}',array[null]::uuid[])", error="channel_invalid_receipts")
    deny("Excessive receipts rejected", f"select public.bil07_channel_read_v1('{GENERAL}',array_fill('{uuid.uuid4()}'::uuid,array[101]))", error="channel_invalid_receipts")
    hidden_message = send(HIDDEN, GENERAL, "contribution with hidden profile")["message"]
    hidden_projection = next(m for m in page(A, GENERAL)["messages"] if m["id"] == hidden_message["id"])
    check(hidden_projection["author_display_name"] is None, "Hidden profile display name is not leaked by channel projection")
    for blocker, blocked in ((A, B), (B, A)):
        run(f"insert into public.bil_blocks values('{blocker}','{blocked}');")
        check(page(A, overlap_channel)["messages"] == [], f"Bilateral block hides channel messages (blocker={blocker[0]})")
        check(
            rpc("readback", f"'{overlap_channel}',{ids_sql([original[0]['id']])}")["acknowledged_message_ids"] == [],
            f"Blocked messages never leak through readback (blocker={blocker[0]})",
        )
        run(f"delete from public.bil_blocks where blocker_id='{blocker}' and blocked_id='{blocked}';")
    run(f"update public.bil07_channel_messages_v1 set removed_at=clock_timestamp() where id='{original[1]['id']}';")
    check(original[1]["id"] not in [m["id"] for m in page(A, overlap_channel)["messages"]], "Removed message is absent from paging")
    rpc("presence", f"'{GENERAL}',true", A)
    second_heartbeat = rpc("presence", f"'{GENERAL}',true", A)
    check(
        second_heartbeat["online_count"] == 1
        and run(f"select count(*) from public.bil07_channel_presence_v1 where channel_id='{GENERAL}' and owner_id='{A}';") == "1",
        "Repeated heartbeats count unique owner/channel, not sessions or member total",
    )
    rpc("presence", f"'{GENERAL}',true", B)
    snapshot = rpc("presence", f"'{GENERAL}',false", C)
    check(
        snapshot["online_count"] == 2 and snapshot["expires_at"] is None
        and snapshot["valid_until"] > snapshot["server_time"],
        "Presence snapshot separates verified count validity from own expiry",
    )
    deny("Nonmember heartbeat cannot create presence", f"select public.bil07_channel_presence_v1('{GENERAL}',true)", owner=C, error="channel_membership_required")
    run(f"insert into public.bil_blocks values('{B}','{A}');")
    check(rpc("presence", f"'{GENERAL}',false", A)["online_count"] == 1, "Online count applies bilateral block visibility")
    run(f"delete from public.bil_blocks where blocker_id='{B}' and blocked_id='{A}';")
    run(f"update public.bil07_channel_presence_v1 set heartbeat_at=statement_timestamp()-interval '91 seconds',expires_at=statement_timestamp()-interval '1 second' where channel_id='{GENERAL}';")
    check(rpc("presence", f"'{GENERAL}',false")["online_count"] == 0, "Expired heartbeat is excluded without counting all memberships")
    concurrency()
    for table in ("channels", "channel_memberships", "channel_messages", "channel_reads", "channel_presence"):
        full = "public.bil07_" + table + "_v1"
        actual = int(run(f"select count(*) from {full};"))
        visible = run(
            f"begin;grant select on {full} to authenticated;" + identity(A) +
            f"select count(*) from {full};rollback;"
        ).splitlines()[-1]
        check(actual > 0 and visible == "0", f"RLS independently hides populated rows with temporary SELECT grant: {table}")
    check(
        run("select md5(jsonb_agg(to_jsonb(m) order by id)::text) from public.bil_messages m;") == private_before
        and run("select count(*) from public.bil_messages where read_at is null;", owner=A, authenticated=True).splitlines()[-1] == "1",
        "All channel operations leave private messages and private unread unchanged",
    )
    print("BIL07_SQL_ALL_ASSERTIONS_PASSED", flush=True)


if __name__ == "__main__":
    output = Path(os.environ["BIL07_SQL_OUTPUT_DIR"]).resolve()
    output.mkdir(parents=True, exist_ok=True)
    status, error = "PASS", None
    try:
        main()
    except Exception as exc:
        status, error = "FAIL", f"{type(exc).__name__}: {exc}"
        RESULTS.append({"name": "execution", "status": "FAIL", "reason": error})
        print(error, file=sys.stderr, flush=True)
    sources = {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(HERE.iterdir()) if p.is_file()
    }
    evidence = {
        "status": status, "base_sha": "1744788e6bfbdffc3a168bbaf36b3abf3e2c698a",
        "scope": "disposable PostgreSQL with declared synthetic identities/tables and exact BASE helper bodies",
        "production_connected": False, "production_deployed": False,
        "device_e2e": False, "live_supabase_e2e": False,
        "assertions": RESULTS, "pass_count": sum(r["status"] == "PASS" for r in RESULTS),
        "fail_count": sum(r["status"] == "FAIL" for r in RESULTS),
        "error": error, "source_sha256": sources,
        "source_digest": hashlib.sha256(json.dumps(sources, sort_keys=True).encode()).hexdigest(),
    }
    (output / "sql_results.json").write_text(json.dumps(evidence, indent=2) + "\n")
    (output / "sql_commands.json").write_text(json.dumps(TRANSCRIPT, indent=2) + "\n")
    sys.exit(0 if status == "PASS" else 1)
