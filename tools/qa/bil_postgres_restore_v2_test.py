"""Real PostgreSQL V2 CAS/consent/RLS/concurrency + unchanged V1 proof.

SQL fixtures use synthetic cipher-shaped bytes. Real Flutter AES + independent
SQLite A->HTTP->PostgreSQL->HTTP->SQLite B is verified by the companion Flutter
integration test, not inferred from this script.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime
import hashlib
import json
import subprocess
import time

from bil_cloud_restore_v2_server import Fixture, MIGRATION, OWNER_A, OWNER_B, ROOT, SqlFailure, sql_literal


def sealed(seed="x"):
    return {"_bil_cipher_v": 1, "alg": "A256GCM", "nonce": "AAAAAAAAAAAAAAAA",
            "ciphertext": (seed * 32)[:32]}


def operation(identifier, record="test-meal", revision=0, mutation="upsert", *, record_type="meal"):
    return {"operation_id": identifier, "record_type": record_type, "record_id": record,
            "expected_revision": revision, "mutation": mutation, "payload_version": 2,
            "payload": sealed(identifier)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--psql", required=True)
    parser.add_argument("--port", type=int, default=55432)
    args = parser.parse_args()
    current = Fixture(args.psql, args.port, proposed=False)
    proposed = Fixture(args.psql, args.port)
    old_source_sha = "3f0085e6e6686f2e87e9cf14789e9e578ea64159"
    old_transport_path = "lib/features/cloud_platform/services/supabase_cloud_transport.dart"
    old_transport = subprocess.run(["git", "show", old_source_sha + ":" + old_transport_path],
                                   cwd=ROOT, capture_output=True, check=True).stdout
    results = []
    output = ROOT / "build/cloud-restore-v2" / ("postgres-" + datetime.datetime.now().strftime("%Y%m%d%H%M%S"))
    output.mkdir(parents=True)

    def check(name, run):
        try:
            run()
            results.append({"name": name, "result": "PASS"})
            print("PASS: " + name, flush=True)
        except Exception as error:
            results.append({"name": name, "result": "FAIL", "error": str(error)})
            print("FAIL: " + name + ": " + str(error), flush=True)

    def deny(run, message):
        try:
            run()
        except SqlFailure as error:
            assert message in str(error), str(error)
        else:
            raise AssertionError("SQL unexpectedly accepted " + message)

    def sync(ops=None, *, owner=OWNER_A, device="synthetic-device-A", scope="nutrition", cursor=0, limit=100):
        return proposed.rpc("bil_sync_records_v2", {"p_device_id": device, "p_scope": scope,
                    "p_cursor": cursor, "p_operations": ops or [], "p_limit": limit}, owner)

    def consent(scope="nutrition", granted=True, owner=OWNER_A, version="1"):
        return proposed.rpc("bil_record_cloud_restore_consent_v2",
                            {"p_scope": scope, "p_granted": granted, "p_policy_version": version}, owner)

    def old_roundtrip(fixture, suffix):
        op = {"operation_id": "v1-" + suffix, "mutation": "upsert", "record": {
            "entity_kind": "nutrition", "record_id": "v1-" + suffix,
            "revision_device_id": "legacy-device-32", "revision_sequence": 1,
            "updated_at": "2026-10-11T00:00:00Z", "deleted_at": None,
            "schema_version": 1, "payload": sealed()}}
        body = fixture.rpc("bil_sync_records", {"p_device_id": "legacy-device-32", "p_operations": [op]})
        assert set(body) == {"records", "acknowledged", "cursor", "has_more"}
        assert body["acknowledged"] == [op["operation_id"]]
        assert all(row["entity_kind"] in {"nutrition"} for row in body["records"])
        expected = {"owner_id", "entity_kind", "record_id", "revision_device_id", "revision_sequence",
                    "updated_at", "deleted_at", "schema_version", "payload"}
        assert all(set(row) == expected for row in body["records"])
        replay = fixture.rpc("bil_sync_records", {"p_device_id": "legacy-device-32", "p_operations": [op]})
        assert replay == body

    try:
        check("old32/35 exact V1 request/strict response on current schema", lambda: old_roundtrip(current, "current"))
        check("new V2 capability honestly unavailable on current schema", lambda: deny(
            lambda: current.rpc("bil_cloud_restore_capabilities_v2"), "does not exist"))
        check("old32/35 exact V1 request/strict response after additive V2", lambda: old_roundtrip(proposed, "proposed"))
        check("V1 function definition is unchanged by V2 migration", lambda: assert_equal(
            proposed.execute("select md5(pg_get_functiondef('public.bil_sync_records(text,bigint,jsonb)'::regprocedure));")[-1],
            current.v1_hash_before))
        check("new capability advertises exact version and supported scopes", lambda: assert_equal(
            proposed.rpc("bil_cloud_restore_capabilities_v2"), {"protocol_version": 2, "scopes": ["nutrition", "goals"],
            "consent_policy_version": "1", "max_batch_size": 100, "max_page_size": 100}))

        def no_inferred_consent():
            choices = proposed.rpc("bil_cloud_restore_consent_v2")
            assert not choices["nutrition"]["granted"] and not choices["goals"]["granted"]
            deny(lambda: sync([operation("before-opt-in")]), "cloud_restore_scope_consent_required")
            assert consent()["granted"]
            deny(lambda: sync(scope="goals"), "cloud_restore_scope_consent_required")
        check("old base consent does not silently enable either new scope", no_inferred_consent)

        created = {}
        def create_pull():
            body = sync([operation("create-first")])
            assert body["receipts"][0]["outcome"] == "accepted"
            assert body["receipts"][0]["server_revision"] == 1
            fresh = sync(device="synthetic-device-B")
            assert body["records"] == fresh["records"]
            assert fresh["records"][0]["owner_id"] == OWNER_A
            created.update(body)
        check("independent device pulls server-authored revision and exact encrypted bytes", create_pull)
        check("identical retry returns one durable receipt without second revision", lambda: replay_check(sync, created))

        def changed_request():
            changed = operation("create-first")
            changed["payload"] = sealed("changed")
            deny(lambda: sync([changed]), "restore_idempotency_conflict")
            deny(lambda: sync([operation("create-first")], device="synthetic-device-B"), "restore_idempotency_conflict")
        check("same operation cannot be rebound to altered ciphertext or a different device", changed_request)

        def stale_cas():
            body = sync([operation("stale-update", revision=0)], device="synthetic-device-B")
            receipt = body["receipts"][0]
            assert receipt["outcome"] == "conflict" and receipt["server_revision"] == 1
            assert receipt["current_record"]["payload"] == created["records"][0]["payload"]
            retry = sync([operation("stale-update", revision=0)], device="synthetic-device-B")
            assert retry["receipts"][0] == receipt | {"replayed": True}
        check("stale CAS preserves trusted current record and stable conflict receipt", stale_cas)

        def deletion():
            deleted = sync([operation("delete-first", revision=1, mutation="delete")])
            assert deleted["receipts"][0]["server_revision"] == 2
            stale = sync([operation("late-stale-create")], device="synthetic-device-B")
            assert stale["receipts"][0]["outcome"] == "conflict"
            recreate = sync([operation("late-resurrect", revision=2)], device="synthetic-device-B")
            assert recreate["receipts"][0]["outcome"] == "conflict"
            row = next(row for row in sync()["records"] if row["record_id"] == "test-meal")
            assert row["deleted"] and row["server_revision"] == 2
            copied = sync([operation("explicit-new-identity", record="copied-meal")])
            assert copied["receipts"][0]["outcome"] == "accepted"
        check("durable tombstone blocks stale replay and resurrection; explicit new identity remains possible", deletion)

        def rollback():
            good = operation("rolled-back-good", record="rollback-meal")
            bad = operation("rolled-back-bad", record="bad-meal")
            bad["owner_id"] = OWNER_B
            deny(lambda: sync([good, bad]), "invalid_restore_operation")
            assert not any(row["record_id"] == "rollback-meal" for row in sync()["records"])
            accepted = sync([good])
            assert not accepted["receipts"][0]["replayed"]
        check("invalid/forged member rolls back the entire SQL request including prior receipt", rollback)

        def globals_and_scopes():
            consent("goals")
            body = sync([operation("goals-bundle", "nutrition-goals", record_type="goals")], scope="goals")
            assert len(body["records"]) == 1 and body["records"][0]["record_type"] == "goals"
            deny(lambda: sync([operation("wrong-type", "nutrition-goals", record_type="goals")]), "invalid_restore_record")
            deny(lambda: sync([operation("wrong-goal-id", "other-goals", record_type="goals")], scope="goals"), "invalid_restore_record")
            assert sync([operation("recipe-text-id", "saved:recipe/legacy-A", record_type="recipe")])["receipts"][0]["outcome"] == "accepted"
        check("atomic goals identity and nutrition types are scope checked; existing text recipe IDs survive", globals_and_scopes)

        def pages():
            ops = [operation("page-" + str(i), "page-meal-" + str(i)) for i in range(5)]
            sync(ops)
            cursor = 0
            identities = []
            while True:
                page = sync(device="synthetic-device-B", cursor=cursor, limit=1)
                assert len(page["records"]) <= 1
                if page["records"]:
                    assert page["cursor"] > cursor
                    identities.extend(row["record_id"] for row in page["records"])
                cursor = page["cursor"]
                if not page["has_more"]:
                    break
            assert len(identities) == len(set(identities))
            assert set("page-meal-" + str(i) for i in range(5)) <= set(identities)
            assert sync(cursor=cursor)["records"] == []
        check("independent pull pages advance durably without duplicate identities or cursor stalls", pages)

        def concurrent_cas():
            sync([operation("race-base", "racing-meal")])
            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(sync, [operation("race-" + suffix, "racing-meal", 1)], device="synthetic-device-" + suffix)
                           for suffix in ("A", "B")]
                outcomes = sorted(f.result()["receipts"][0]["outcome"] for f in futures)
            assert outcomes == ["accepted", "conflict"]
            assert next(row for row in sync()["records"] if row["record_id"] == "racing-meal")["server_revision"] == 2
        check("two real concurrent sessions with the same base have one accepted writer and one conflict", concurrent_cas)

        def concurrent_repeat():
            op = operation("double-click", "double-click-meal")
            with ThreadPoolExecutor(max_workers=2) as pool:
                answers = [f.result()["receipts"][0] for f in [pool.submit(sync, [op]), pool.submit(sync, [op])]]
            assert sorted(answer["replayed"] for answer in answers) == [False, True]
            assert all(answer["server_revision"] == 1 for answer in answers)
        check("concurrent double request and retry execute one financial-free record mutation", concurrent_repeat)

        def access():
            consent(owner=OWNER_B)
            assert sync(owner=OWNER_B)["records"] == []
            sync([operation("other-owner-same-id")], owner=OWNER_B)
            assert len(sync(owner=OWNER_B)["records"]) == 1
            assert all(row["owner_id"] == OWNER_A for row in sync()["records"])
            for table in ("consents", "records", "operations"):
                name = "public.bil_cloud_restore_" + table + "_v2"
                deny(lambda n=name: proposed.execute("select * from " + n + ";", OWNER_A), "permission denied")
                deny(lambda n=name: proposed.execute("insert into " + n + " default values;", OWNER_A), "permission denied")
                deny(lambda n=name: proposed.execute("update " + n + " set owner_id=" + sql_literal(OWNER_B) + ";", OWNER_A), "permission denied")
                deny(lambda n=name: proposed.execute("delete from " + n + ";", OWNER_A), "permission denied")
            deny(lambda: proposed.execute("select public.bil_cloud_restore_capabilities_v2();", role="anon"), "permission denied")
            # Temporary grant exists only inside this isolated transaction and
            # rolls back. This exercises real RLS independently of the ACL.
            data = proposed.execute("begin; grant select on public.bil_cloud_restore_records_v2 to authenticated;"
                "set local role authenticated;select set_config('request.jwt.claim.sub'," + sql_literal(OWNER_B) + ",true);"
                "select jsonb_agg(distinct owner_id) from public.bil_cloud_restore_records_v2;rollback;")
            assert json.loads(data[-1]) == [OWNER_B]
        check("owner isolation, forged identity rejection, anon/direct ACL and actual RLS all enforce boundaries", access)

        def bad_inputs():
            for patch in ({"payload_version": 3}, {"expected_revision": -1}, {"mutation": "restore"},
                          {"payload": {"calories": 123}}, {"record_type": "coach"}):
                op = operation("bad-input-" + next(iter(patch))) | patch
                deny(lambda x=op: sync([x]), "invalid_restore_record")
            deny(lambda: sync(limit=0), "invalid_restore_batch")
            deny(lambda: sync(cursor=-1), "invalid_restore_batch")
            deny(lambda: sync(ops=[operation("overflow-" + str(i)) for i in range(101)]), "invalid_restore_batch")
        check("version/plaintext/negative revision/unsupported type and page bounds reject atomically", bad_inputs)

        def withdrawal():
            consent(granted=False)
            deny(lambda: sync(), "cloud_restore_scope_consent_required")
            assert sync(scope="goals")["records"]
            proposed.rpc("bil_record_consent", {"p_purpose": "cloud_sync", "p_policy_version": "1", "p_granted": False})
            deny(lambda: consent(), "cloud_sync_consent_required")
            deny(lambda: sync(scope="goals"), "cloud_sync_consent_required")
            assert not consent("goals", False)["granted"]
            proposed.rpc("bil_record_consent", {"p_purpose": "cloud_sync", "p_policy_version": "1", "p_granted": True})
            consent()
            deny(lambda: consent(version="2"), "invalid_restore_consent")
            consent(granted=False, version="2")
            deny(lambda: sync(), "cloud_restore_scope_consent_required")
            consent()
        check("scope/base withdrawal and unfamiliar policies stop access without deleting records", withdrawal)

        def revoked():
            proposed.rpc("bil_revoke_cloud_restore_device_v2", {"p_device_id": "synthetic-device-B"})
            deny(lambda: sync(device="synthetic-device-B"), "device_revoked")
            deny(lambda: proposed.rpc("bil_sync_records", {"p_device_id": "synthetic-device-B"}), "device_revoked")
            assert sync()["records"]
        check("revoked device cannot silently reregister through V2 or the unchanged V1 API", revoked)

        def after_lock_revocation():
            sync(device="synthetic-device-direct-revoke")
            with ThreadPoolExecutor(max_workers=2) as pool:
                revoke = pool.submit(proposed.execute,
                    "begin;update public.bil_cloud_devices set revoked_at=clock_timestamp() where owner_id="
                    + sql_literal(OWNER_A) + " and device_id='synthetic-device-direct-revoke';select pg_sleep(1);commit;")
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    active = proposed.value("select count(*) from pg_stat_activity where datname=current_database() and wait_event='PgSleep';")
                    if active:
                        break
                    time.sleep(0.02)
                else:
                    raise AssertionError("revocation transaction did not reach held row")
                deny(lambda: sync(device="synthetic-device-direct-revoke"), "device_revoked")
                revoke.result()
        check("direct device revocation committed during row wait is rechecked before receipt creation", after_lock_revocation)

        def revoke_waiting_request():
            with ThreadPoolExecutor(max_workers=2) as pool:
                revoke = pool.submit(proposed.execute,
                    "begin;select pg_advisory_xact_lock(hashtextextended('bil.sync.'||" + sql_literal(OWNER_A)
                    + ",0));update public.bil_consent_receipts set granted=false,recorded_at=clock_timestamp() where user_id="
                    + sql_literal(OWNER_A) + " and purpose='cloud_sync';select pg_sleep(1);commit;")
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if proposed.value("select count(*) from pg_stat_activity where datname=current_database() and wait_event='PgSleep';"):
                        break
                    time.sleep(0.02)
                else:
                    raise AssertionError("base withdrawal did not acquire owner lock")
                deny(lambda: sync([operation("cannot-cross-withdrawal", "revocation-meal")]), "cloud_sync_consent_required")
                revoke.result()
            proposed.rpc("bil_record_consent", {"p_purpose": "cloud_sync", "p_policy_version": "1", "p_granted": True})
            assert not any(row["record_id"] == "revocation-meal" for row in sync()["records"])
        check("base consent withdrawal committed while sync waits prevents data and receipt creation", revoke_waiting_request)

        def old_cannot_touch_v2():
            old_roundtrip(proposed, "after-v2-data")
            before = next(row for row in sync()["records"] if row["record_id"] == "copied-meal")
            op = {"operation_id": "v1-delete-v2-identity", "mutation": "delete", "record": {
                "entity_kind": "nutrition", "record_id": "copied-meal",
                "revision_device_id": "legacy-device-32", "revision_sequence": 999,
                "updated_at": "2026-10-11T00:00:00Z", "deleted_at": "2026-10-11T00:00:00Z",
                "schema_version": 1, "payload": sealed("old-delete")}}
            response = proposed.rpc("bil_sync_records", {"p_device_id": "legacy-device-32", "p_operations": [op]})
            assert response["acknowledged"] == [op["operation_id"]]
            after = next(row for row in sync()["records"] if row["record_id"] == "copied-meal")
            assert after == before and not after["deleted"]
        check("old client sees only V1; actual old deletion cannot corrupt same-ID V2 record", old_cannot_touch_v2)
    finally:
        evidence = {"environment": "PostgreSQL17.6 native loopback; synthetic accounts; no Production",
                    "cases": results, "passed": sum(row["result"] == "PASS" for row in results),
                    "failed": sum(row["result"] == "FAIL" for row in results),
                    "source_files": proposed.evidence(), "v1_rpc_md5_before": current.v1_hash_before,
                    "legacy_wire_provenance": {"source_commit": old_source_sha,
                                               "path": old_transport_path,
                                               "sha256": hashlib.sha256(old_transport).hexdigest(),
                                               "proof": "exact wire contract; not executing an Android32 or iOS35 binary"},
                    "v1_rpc_md5_after": proposed.execute("select md5(pg_get_functiondef('public.bil_sync_records(text,bigint,jsonb)'::regprocedure));")[-1]}
        (output / "result.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
        proposed.close()
        current.close()
        print(str(output / "result.json"), flush=True)
    if not results or any(row["result"] != "PASS" for row in results):
        raise SystemExit(1)


def assert_equal(actual, expected):
    assert actual == expected, (actual, expected)


def replay_check(sync, original):
    replay = sync([operation("create-first")])
    assert replay["receipts"][0] == original["receipts"][0] | {"replayed": True}
    assert replay["cursor"] == original["cursor"] and replay["records"] == original["records"]


if __name__ == "__main__":
    main()
