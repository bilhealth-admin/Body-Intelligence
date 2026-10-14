"""Real PostgreSQL sessions on loopback, captured current message catalog.

No Production connection, real accounts, SDK or store artifact claim. The
catalog fixture has original RLS/ACL and all message triggers; auth.users keys
are synthetic. Root launches this in a visible terminal only.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--psql', required=True)
parser.add_argument('--port', type=int, default=55432)
parser.add_argument('--case')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
fixture = root / 'supabase/tests/fixtures/community_message_baseline'
stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
database = 'bil_qa_message_' + stamp
assert re.fullmatch(r'bil_qa_message_[0-9]+', database)
base = [args.psql, '-X', '-qAt', '-P', 'null=null', '-v', 'ON_ERROR_STOP=1',
        '-h', '127.0.0.1', '-p', str(args.port), '-U', 'bil_test_superuser']
out = root / 'build/stage1-closure' / ('postgres-message-v2-' + stamp)
out.mkdir(parents=True, exist_ok=False)
records = []


def execute(sql, actor=None, db=None, expected=None):
    if actor is not None:
        claims = json.dumps({'sub': actor, 'role': 'authenticated'})
        sql = ("begin; set local role authenticated; select set_config('request.jwt.claims','"
               + claims + "',true); select set_config('request.jwt.claim.sub','"
               + actor + "',true); " + sql + '\ncommit;')
    result = subprocess.run(base + ['-d', db or database], input=sql,
                            text=True, encoding='utf-8', capture_output=True, timeout=20)
    if expected:
        assert result.returncode != 0 and expected in result.stderr, result.stderr
        return result.stderr
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip().splitlines()


def scalar(sql, actor=None):
    return execute(sql, actor)[-1]


def value(sql, actor=None):
    return json.loads(scalar(sql, actor))


def user(number):
    return f'12000000-0000-4000-8000-{number:012d}'


A, B, C = user(1), user(2), user(3)


def send(key, text='Synthetic message', actor=A, recipient=B):
    assert re.fullmatch(r'[0-9a-f-]{36}', key)
    assert "'" not in text
    return value(f"select public.bil_send_community_message_v2('{recipient}','{text}','{key}');", actor)


def count(key):
    return int(scalar(f"select count(*) from private.bil_community_message_deliveries_v2 where request_id='{key}';"))


def check(name, action):
    if args.case and args.case != name:
        return
    try:
        action()
        records.append({'name': name, 'result': 'PASS'})
        print('PASS: ' + name, flush=True)
    except Exception as error:
        records.append({'name': name, 'result': 'FAIL', 'error': str(error)})
        print('FAIL: ' + name + ': ' + str(error), flush=True)


def legacy_current():
    execute(f"insert into public.bil_messages(sender_id,recipient_id,body) values('{A}','{B}','Legacy current');", A)
    execute(f"insert into public.bil_messages(id,sender_id,recipient_id,body) values(gen_random_uuid(),'{A}','{B}','Forged identifier');", A, expected='permission denied')
    before = int(scalar('select count(*) from public.bil_messages;'))
    # The captured BEFORE trigger rejects forged actors before the RLS check.
    execute(f"insert into public.bil_messages(sender_id,recipient_id,body) values('{A}','{B}','Forged actor');", C, expected='community_message_sender_required')
    assert int(scalar('select count(*) from public.bil_messages;')) == before
    assert scalar('select count(*) from public.bil_messages;', C) == '0'


def missing_new_server():
    execute(f"select public.bil_send_community_message_v2('{B}','Body','{uuid.uuid4()}');", A, expected='does not exist')


def legacy_proposed():
    execute(f"insert into public.bil_messages(sender_id,recipient_id,body) values('{A}','{B}','Legacy proposed');", A)
    assert scalar("select has_column_privilege('authenticated','public.bil_messages','id','INSERT');") == 'f'


def concurrent_same_request():
    key = str(uuid.uuid4())
    before = int(scalar('select count(*) from public.bil_push_outbox;'))
    audit = int(scalar("select count(*) from public.bil_community_audit_events where target_kind='messages' and event_kind='INSERT';"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        first, second = list(pool.map(lambda _: send(key, 'Concurrent synthetic'), range(2)))
    assert first == second and first['owner_id'] == A and first['recipient_id'] == B
    assert count(key) == 1
    assert int(scalar('select count(*) from public.bil_push_outbox;')) == before + 1
    assert int(scalar("select count(*) from public.bil_community_audit_events where target_kind='messages' and event_kind='INSERT';")) == audit + 1


def legacy_insert_and_v2_lock_order():
    """Two real write sessions reach the old pair -> member lock barrier."""
    key = str(uuid.uuid4())
    before_messages = int(scalar('select count(*) from public.bil_messages;'))
    before_push = int(scalar('select count(*) from public.bil_push_outbox;'))
    before_audit = int(scalar("select count(*) from public.bil_community_audit_events where target_kind='messages' and event_kind='INSERT';"))
    claims = json.dumps({'sub': A, 'role': 'authenticated'})
    legacy = subprocess.Popen(base + ['-d', database], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, encoding='utf-8')
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=2)
    try:
        # This is the precise lock held by the retained BEFORE INSERT trigger.
        # The INSERT below still runs the complete original trigger/RLS stack.
        legacy.stdin.write("begin; set local statement_timeout='12s'; set local lock_timeout='10s'; "
            "set local role authenticated; select set_config('request.jwt.claims','" + claims + "',true); "
            "select set_config('request.jwt.claim.sub','" + A + "',true); "
            "select pg_advisory_xact_lock(hashtextextended('community_block_pair:' || least('" + A + "','" + B + "') || ':' || greatest('" + A + "','" + B + "'),0)); "
            "select 'MESSAGE_PAIR_READY:'||pg_backend_pid();\n")
        legacy.stdin.flush()
        def ready():
            while True:
                line = legacy.stdout.readline()
                if not line:
                    raise AssertionError('Legacy pair-lock session exited before barrier')
                if line.startswith('MESSAGE_PAIR_READY:'):
                    return int(line.strip().split(':')[1])
        legacy_pid = pool.submit(ready).result(timeout=8)
        current = pool.submit(execute,
            "set local application_name='bil_message_new_lock_order'; "
            f"select public.bil_send_community_message_v2('{B}','New lock-order message','{key}');", A)
        deadline = time.monotonic() + 8
        while True:
            waiting = scalar("select exists(select 1 from pg_stat_activity where datname='" + database + "' "
                "and application_name='bil_message_new_lock_order' and wait_event_type='Lock' "
                f"and {legacy_pid}=any(pg_blocking_pids(pid)));")
            if waiting == 't':
                break
            if current.done() or time.monotonic() >= deadline:
                raise AssertionError('New RPC did not wait on the actual legacy pair lock')
            time.sleep(.01)
        legacy_output, legacy_error = legacy.communicate(
            f"insert into public.bil_messages(sender_id,recipient_id,body) values('{A}','{B}','Legacy lock-order message') returning id; commit;\n",
            timeout=15)
        assert legacy.returncode == 0, legacy_error
        assert any(re.fullmatch(r'[0-9a-f-]{36}', line) for line in legacy_output.splitlines()), legacy_output
        receipt = json.loads(current.result(timeout=15)[-1])
        assert receipt['owner_id'] == A and receipt['recipient_id'] == B
        assert count(key) == 1
        assert int(scalar('select count(*) from public.bil_messages;')) == before_messages + 2
        assert int(scalar('select count(*) from public.bil_push_outbox;')) == before_push + 2
        assert int(scalar("select count(*) from public.bil_community_audit_events where target_kind='messages' and event_kind='INSERT';")) == before_audit + 2
    finally:
        if legacy.poll() is None:
            legacy.terminate()
            legacy.communicate(timeout=10)
        pool.shutdown(wait=True)


def verify_owned_replay(key, original):
    messages = int(scalar('select count(*) from public.bil_messages;'))
    pushes = int(scalar('select count(*) from public.bil_push_outbox;'))
    audits = int(scalar("select count(*) from public.bil_community_audit_events where target_kind='messages' and event_kind='INSERT';"))
    assert send(key, original['body']) == original
    assert value(f"select public.bil_get_community_message_delivery_v2('{key}');", A) == original
    assert value(f"select public.bil_get_community_message_delivery_v2('{key}');", C) is None
    execute('select * from private.bil_community_message_deliveries_v2;', C, expected='permission denied')
    assert count(key) == 1
    assert int(scalar('select count(*) from public.bil_messages;')) == messages
    assert int(scalar('select count(*) from public.bil_push_outbox;')) == pushes
    assert int(scalar("select count(*) from public.bil_community_audit_events where target_kind='messages' and event_kind='INSERT';")) == audits


def replay_after_block():
    key = str(uuid.uuid4())
    original = send(key, 'Delivered before block')
    execute(f"insert into public.bil_blocks(blocker_id,blocked_id) values('{B}','{A}');", B)
    try:
        verify_owned_replay(key, original)
    finally:
        execute(f"delete from public.bil_blocks where blocker_id='{B}' and blocked_id='{A}';", B)


def replay_after_suspension():
    key = str(uuid.uuid4())
    original = send(key, 'Delivered before suspension')
    execute(f"insert into private.bil_community_member_access(user_id,suspended,reason,suspended_by) values('{A}',true,'Synthetic suspension','{C}');")
    try:
        verify_owned_replay(key, original)
    finally:
        execute(f"delete from private.bil_community_member_access where user_id='{A}';")


def replay_after_consent_withdrawal():
    key = str(uuid.uuid4())
    original = send(key, 'Delivered before consent withdrawal')
    execute(f"delete from public.bil_content_policy_acceptances where user_id='{A}';")
    try:
        verify_owned_replay(key, original)
    finally:
        execute(f"insert into public.bil_content_policy_acceptances(user_id,policy_version) values('{A}','synthetic-community-v1');", A)


def commit_then_retry():
    key = str(uuid.uuid4())
    committed = send(key, 'Lost response synthetic')
    # Ignore the first response, then reconcile in a new OS/database session.
    retried = send(key, 'Lost response synthetic')
    assert committed == retried and count(key) == 1
    assert value(f"select public.bil_get_community_message_delivery_v2('{key}');", A) == committed


def distinct_identical_intents():
    first, second = str(uuid.uuid4()), str(uuid.uuid4())
    left, right = send(first, 'Identical legitimate body'), send(second, 'Identical legitimate body')
    assert left['message_id'] != right['message_id']
    assert count(first) == count(second) == 1


def mismatch_and_owner():
    key = str(uuid.uuid4())
    send(key)
    execute(f"select public.bil_send_community_message_v2('{B}','Changed body','{key}');", A, expected='message_request_conflict')
    execute(f"select public.bil_send_community_message_v2('{C}','Synthetic message','{key}');", A, expected='message_request_conflict')
    assert value(f"select public.bil_get_community_message_delivery_v2('{key}');", C) is None
    execute('select * from private.bil_community_message_deliveries_v2;', A, expected='permission denied')
    assert count(key) == 1


def rejected_without_friendship():
    key = str(uuid.uuid4())
    execute(f"select public.bil_send_community_message_v2('{C}','Unrelated member','{key}');", A, expected='community_message_recipient_unavailable')
    assert count(key) == 0


def bilateral_block():
    key = str(uuid.uuid4())
    execute(f"insert into public.bil_blocks(blocker_id,blocked_id) values('{B}','{A}');", B)
    try:
        execute(f"select public.bil_send_community_message_v2('{B}','Blocked message','{key}');", A, expected='community_relationship_blocked')
        assert count(key) == 0
    finally:
        execute(f"delete from public.bil_blocks where blocker_id='{B}' and blocked_id='{A}';", B)


def suspended_actor():
    key = str(uuid.uuid4())
    execute(f"insert into private.bil_community_member_access(user_id,suspended,reason,suspended_by) values('{A}',true,'Synthetic suspension','{C}');")
    try:
        execute(f"select public.bil_send_community_message_v2('{B}','Suspended actor','{key}');", A, expected='community_access_suspended')
        assert count(key) == 0
    finally:
        execute(f"delete from private.bil_community_member_access where user_id='{A}';")


def policy_required():
    key = str(uuid.uuid4())
    execute(f"delete from public.bil_content_policy_acceptances where user_id='{A}';")
    try:
        execute(f"select public.bil_send_community_message_v2('{B}','No consent','{key}');", A, expected='community_policy_acceptance_required')
        assert count(key) == 0
    finally:
        execute(f"insert into public.bil_content_policy_acceptances(user_id,policy_version) values('{A}','synthetic-community-v1');", A)


def deleted_delivery_stays_deleted():
    key = str(uuid.uuid4())
    receipt = send(key, 'Tombstone synthetic')
    identity = receipt['message_id']
    execute(f"update public.bil_messages set deleted_by_sender_at=clock_timestamp() where id='{identity}';")
    retried = send(key, 'Tombstone synthetic')
    assert retried['status'] == 'removed' and retried['body'] is None
    assert retried['message_id'] == identity and count(key) == 1
    assert int(scalar(f"select count(*) from public.bil_messages where id='{identity}';")) == 1


try:
    execute('create database ' + database + ';', db='postgres')
    # Auth extension ACL has this real role name; it is an inert NOLOGIN
    # scaffold in the loopback cluster, never a Production Auth principal.
    execute("do $$begin if not exists(select 1 from pg_roles where rolname='supabase_auth_admin') then create role supabase_auth_admin nologin;end if;if not exists(select 1 from pg_roles where rolname='dashboard_user') then create role dashboard_user nologin;end if;end $$;")
    for name in ['schema.sql', 'functions.sql', 'contracts.sql']:
        execute((fixture / name).read_text(encoding='utf-8'))
    for actor in [A, B, C]:
        execute(f"insert into auth.users(id,email) values('{actor}','synthetic-{actor[-1]}@example.invalid');")
        execute(f"insert into public.bil_public_profiles(user_id,display_name) values('{actor}','Synthetic member');")
    execute("insert into public.bil_content_policies(version,document_url,effective_at,active) values('synthetic-community-v1','https://example.invalid/community','2020-01-01T00:00:00Z',true);")
    for actor in [A, B, C]:
        execute(f"insert into public.bil_content_policy_acceptances(user_id,policy_version) values('{actor}','synthetic-community-v1');", actor)
    execute(f"insert into public.bil_friendships(requester_id,addressee_id,status,responded_at) values('{A}','{B}','accepted',clock_timestamp());")
    check('legacy client current catalog and ACL', legacy_current)
    check('new client current catalog unavailable', missing_new_server)
    execute((root / 'supabase/migrations/20261013062209_community_message_delivery_v2.sql').read_text(encoding='utf-8'))
    check('legacy client proposed catalog and unchanged ACL', legacy_proposed)
    check('concurrent v2 delivery one message push and audit', concurrent_same_request)
    check('legacy INSERT and new RPC preserve pair then member lock order', legacy_insert_and_v2_lock_order)
    check('owned receipt replay after bilateral block has no repeated effect', replay_after_block)
    check('owned receipt replay after suspension has no repeated effect', replay_after_suspension)
    check('owned receipt replay after consent withdrawal has no repeated effect', replay_after_consent_withdrawal)
    check('committed response loss new session same receipt', commit_then_retry)
    check('two identical legitimate intents remain distinct', distinct_identical_intents)
    check('payload binding recipient mismatch and owner isolation', mismatch_and_owner)
    check('nonfriend rejected with no delivery', rejected_without_friendship)
    check('bilateral block rejects without delivery', bilateral_block)
    check('suspended actor rejected without delivery', suspended_actor)
    check('current consent is required without delivery', policy_required)
    check('deleted delivery remains tombstoned on retry', deleted_delivery_stays_deleted)
    if not records:
        raise RuntimeError('No matching case; refused empty success')
finally:
    payload = {'scope': 'Synthetic native PostgreSQL isolated database; not Production or device',
               'catalog_provenance': json.loads((fixture / 'provenance.json').read_text(encoding='utf-8')),
               'cases': records, 'accepted': bool(records) and all(x['result'] == 'PASS' for x in records),
               'migration_sha256': hashlib.sha256((root / 'supabase/migrations/20261013062209_community_message_delivery_v2.sql').read_bytes()).hexdigest()}
    (out / 'result.json').write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
    execute('drop database if exists ' + database + ';', db='postgres')
if not payload['accepted']:
    raise SystemExit(1)
