"""Real multi-session PostgreSQL tests, synthetic data, loopback only.

Never uses Supabase credentials or a Production connection. The baseline is
a schema/function catalog slice, not evidence of a full Production rollout.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import uuid


parser = argparse.ArgumentParser()
parser.add_argument('--psql', required=True)
parser.add_argument('--port', type=int, default=55432)
parser.add_argument('--case')
parser.add_argument('--receipt-baseline', choices=('deployed', 'clean'), default='deployed')
args = parser.parse_args()
legacy_receipts = args.receipt_baseline == 'deployed'
root = pathlib.Path(__file__).resolve().parents[2]
stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
database = 'bil_qa_review_' + stamp
assert re.fullmatch(r'bil_qa_review_[0-9]+', database)
base = [args.psql, '-X', '-qAt', '-P', 'null=null', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
        '-p', str(args.port), '-U', 'bil_test_superuser']
out = root / 'build' / 'stage1-closure' / ('postgres-review-v2-' + stamp)
out.mkdir(parents=True, exist_ok=False)
records = []


def execute(sql, db=database, actor=None, expect_error=None):
    if actor is not None:
        claims = json.dumps({'sub': str(actor), 'role': 'authenticated'})
        sql = ("begin; set local role authenticated; "
               "select set_config('request.jwt.claims','" + claims + "',true); "
               "select set_config('request.jwt.claim.sub','" + str(actor) + "',true); "
               + sql + '\ncommit;')
    result = subprocess.run(base + ['-d', db], input=sql, text=True,
                            encoding='utf-8', capture_output=True, timeout=20)
    if expect_error:
        assert result.returncode != 0 and expect_error in result.stderr, result.stderr
        return result.stderr
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip().splitlines()


def scalar(sql, actor=None):
    return execute(sql, actor=actor)[-1]


def value(sql, actor=None):
    return json.loads(scalar(sql, actor))


def uid(number):
    return f'11000000-0000-4000-8000-{number:012d}'


def post(number, owner=3):
    identity = uid(1000 + number)
    # Seeding uses the local database owner with a synthetic author context;
    # all moderation/grant decisions below run as authenticated RPC callers.
    execute(f"begin; select set_config('request.jwt.claim.sub','{uid(owner)}',true);"
            f"insert into public.bil_community_posts(id,author_id,body,visibility) "
            f"values('{identity}','{uid(owner)}','Synthetic meal {number}','community'); commit;")
    return identity


def snapshot(identity, actor=2):
    return value(f"select public.bil_community_review_snapshots_v2(array['{identity}'::uuid]);", uid(actor))[0]


def decide(identity, revision, actor=2, decision='approved', key=None, mode='eligible', reason=''):
    key = key or str(uuid.uuid4())
    return value(f"select public.bil_moderate_community_post_v2('{identity}',"
                 f"'{revision}','{decision}','{key}','{reason}','{mode}');", uid(actor))



def activity_source(identity, tokens=5, event='review'):
    if legacy_receipts and tokens == 5:
        return f'post-ai-reward:{identity}'
    prefix = 'post-reward-result-v2:' if event == 'reward' else 'post-moderation-receipt-v2:'
    return prefix + identity


def push_source(identity, owner, decision='approved', event='review'):
    if legacy_receipts:
        return f'post-event:post_{decision}:{identity}:{uid(owner)}'
    prefix = 'post-reward-result-v2:' if event == 'reward' else 'post-moderation-receipt-v2:'
    return prefix + identity


def fanout(identity):
    events = (f"(select count(*) from private.bil_community_post_events_v1 "
              f"where entity_kind='post' and entity_id='{identity}')"
              if legacy_receipts else 'null')
    # Count ALL keys. Looking only for a newly invented source key concealed
    # the deployed V1 hooks and allowed duplicate author pushes to go unnoticed.
    return value(f"""select jsonb_build_object(
      'activities',(select count(*) from public.bil_community_notifications
        where entity_kind='post' and entity_id='{identity}'),
      'pushes',(select count(*) from public.bil_push_outbox
        where source_key like '%{identity}%'),
      'events',{events},
      'grants',(select count(*) from public.bil_community_post_approval_grants where post_id='{identity}'),
      'tokens',(select coalesce(sum(tokens),0) from public.bil_community_post_approval_grants where post_id='{identity}'));""")


def delivery_digest(identity):
    return scalar(f"""select md5(
      (select coalesce(jsonb_agg(to_jsonb(n) order by id),'[]'::jsonb)::text
       from public.bil_community_notifications n where entity_id='{identity}') || ':' ||
      (select coalesce(jsonb_agg(to_jsonb(o) order by id),'[]'::jsonb)::text
       from public.bil_push_outbox o where source_key like '%{identity}%'));""")


def assert_single_receipt(identity, tokens=5, decision='approved'):
    result = fanout(identity)
    assert result == {'activities': 1, 'pushes': 1,
                      'events': 1 if legacy_receipts else None,
                      'grants': 1 if decision == 'approved' else 0,
                      'tokens': tokens}, result


def check(name, run):
    if args.case and args.case != name:
        return
    try:
        run()
        records.append({'name': name, 'result': 'PASS'})
        print('PASS: ' + name, flush=True)
    except Exception as error:
        records.append({'name': name, 'result': 'FAIL', 'error': str(error)})
        print('FAIL: ' + name + ': ' + str(error), flush=True)


def blocked(call, pattern):
    try:
        call()
    except RuntimeError as error:
        assert pattern in str(error), str(error)
        return
    raise AssertionError('Sensitive operation unexpectedly succeeded')


source_paths = (
    'tools/qa/bil_postgres_review_v2_test.py',
    'tools/qa/bil_postgres_receipt_compat_cases.py',
    'supabase/tests/fixtures/community_review_baseline/schema.sql',
    'supabase/tests/fixtures/community_review_baseline/functions.sql',
    'supabase/tests/fixtures/community_review_baseline/moderator_population.sql',
    'supabase/tests/fixtures/community_review_baseline/legacy_delivery.sql',
    'supabase/tests/fixtures/community_review_baseline/legacy_delivery.provenance.json',
    'supabase/migrations/20261011193000_community_review_revision_v2.sql',
    'supabase/migrations/20261014113000_community_post_review_receipts_v2.sql',
)


def fingerprint_sources():
    result = {}
    for relative in source_paths:
        try:
            content = (root / relative).read_bytes()
            result[relative] = {'status': 'CAPTURED', 'bytes': len(content),
                                'sha256': hashlib.sha256(content).hexdigest()}
        except OSError as error:
            result[relative] = {'status': 'READ_FAILED', 'error_type': type(error).__name__}
    return result


source_fingerprints_before = fingerprint_sources()
runtime_info = {'status': 'NOT_QUERIED', 'version': None,
                'server_version': None, 'server_version_num': None}
fatal_error = None
startup_stage = 'runtime_probe'
try:
    # Query the actual loopback QA server exactly once, before database/role
    # setup. Never infer its version from Production or the binary directory.
    runtime_info['status'] = 'QUERYING'
    probe = json.loads(execute("""select jsonb_build_object(
      'version',pg_catalog.version(),
      'server_version',pg_catalog.current_setting('server_version'),
      'server_version_num',pg_catalog.current_setting('server_version_num'));""",
      db='postgres')[-1])
    if not isinstance(probe, dict) or any(
            not isinstance(probe.get(key), str) or not probe[key]
            for key in ('version', 'server_version', 'server_version_num')):
        raise RuntimeError('qa_runtime_version_probe_invalid')
    runtime_info.update(probe, status='CAPTURED', queried_database='postgres')
    startup_stage = 'test_setup'
    execute('create database "' + database + '";', db='postgres')
    # Roles belong to the isolated cluster. Existing names are reused only in
    # this dedicated QA runtime; no remote host is accepted by this runner.
    execute("""do $$begin
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
    grant usage on schema auth,public to anon,authenticated,service_role;
    """)
    fixture = root / 'supabase/tests/fixtures/community_review_baseline'
    schema = (fixture / 'schema.sql').read_text(encoding='utf-8')
    execute(schema)
    execute((fixture / 'functions.sql').read_text(encoding='utf-8'))
    common_delivery, marker, legacy_delivery = (fixture / 'legacy_delivery.sql').read_text(
        encoding='utf-8').partition('-- LEGACY ONLY BELOW')
    assert marker, 'Delivery fixture must separate common seen APIs from legacy extension'
    execute(common_delivery)
    if legacy_receipts:
        execute(legacy_delivery)
    else:
        # Model an installation without October5's remote-only extension.
        execute("""drop function private.bil_post_approval_receipt_trigger_v1(),
          private.bil_post_rejection_receipt_trigger_v1(),
          private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean);
          drop table private.bil_community_post_events_v1;""")

    execute((fixture / 'moderator_population.sql').read_text(encoding='utf-8'))
    execute("""revoke all on function public.bil_moderate_community_post(uuid,text)
      from public,anon,service_role;
      grant execute on function public.bil_moderate_community_post(uuid,text) to authenticated;
      create trigger bil_01_posts_moderation_guard before insert or update on public.bil_community_posts
        for each row execute function public.bil_guard_community_post_moderation();
      create trigger bil_02_posts_suspended_author_approval before update of moderation_status on public.bil_community_posts
        for each row execute function public.bil_guard_suspended_author_post_approval();
      insert into public.bil_community_post_reward_policy(singleton) values(true);
    """)
    execute("insert into auth.users(id,email) values " + ",".join(
        f"('{uid(n)}','synthetic{n}@example.test')" for n in range(1, 140)) + ";")
    execute(f"insert into private.bil_ai_coach_admins(user_id,active) values('{uid(1)}',true);"
            f"insert into public.bil_community_moderators(user_id) values('{uid(2)}');")

    baseline_post = post(0, owner=4)
    baseline = value(f"select public.bil_moderate_community_post('{baseline_post}','approved');", uid(2))
    assert baseline['tokens_granted'] == 5
    baseline_history = delivery_digest(baseline_post)
    contracts_before = scalar("select md5(pg_get_functiondef('public.bil_moderate_community_post(uuid,text)'::regprocedure));")
    migration = root / 'supabase/migrations/20261011193000_community_review_revision_v2.sql'
    execute(migration.read_text(encoding='utf-8'))
    receipt_migration = root / 'supabase/migrations/20261014113000_community_post_review_receipts_v2.sql'
    execute(receipt_migration.read_text(encoding='utf-8'))
    assert delivery_digest(baseline_post) == baseline_history, 'DDL changed historical receipts'

    startup_stage = 'test_execution'

    def legacy():
        identity = post(1, owner=5)
        receipt = value(f"select public.bil_moderate_community_post('{identity}','approved');", uid(2))
        assert receipt.keys() == baseline.keys()
        assert receipt['tokens_granted'] == 5
        assert_single_receipt(identity)
        assert scalar("select md5(pg_get_functiondef('public.bil_moderate_community_post(uuid,text)'::regprocedure));") == contracts_before
    check('legacy 32/35 moderation contract remains unchanged', legacy)

    def revised():
        identity = post(2)
        original = snapshot(identity)
        execute(f"update public.bil_community_posts set body='Changed after review' where id='{identity}';")
        blocked(lambda: decide(identity, original['revision']), 'community_review_content_changed')
        fresh = snapshot(identity)
        receipt = decide(identity, fresh['revision'])
        assert receipt['tokens_granted'] == 5
        assert scalar(f"select count(*) from public.bil_community_notifications where recipient_id='{uid(3)}' and source_key='{activity_source(identity)}';") == '1'
        assert scalar(f"select count(*) from public.bil_push_outbox where recipient_id='{uid(3)}' and source_key='{push_source(identity,3)}';") == '1'
        assert_single_receipt(identity)
    check('changed text rejects stale review and fresh revision succeeds', revised)

    def unauthorized():
        identity = post(3)
        original = snapshot(identity)
        blocked(lambda: decide(identity, original['revision'], actor=6), 'community_moderator_required')
        execute('select * from private.bil_community_review_operations_v2;', actor=uid(6), expect_error='permission denied')
        execute(f"delete from public.bil_community_moderators where user_id='{uid(2)}';")
        blocked(lambda: decide(identity, original['revision']), 'community_moderator_required')
        execute(f"insert into public.bil_community_moderators(user_id) values('{uid(2)}');")
    check('ordinary user direct API and revoked moderator are denied', unauthorized)

    def simultaneous():
        identity = post(4)
        original = snapshot(identity)
        operation = str(uuid.uuid4())
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            replies = list(pool.map(lambda _: decide(identity, original['revision'], key=operation), range(2)))
        assert sum(row['tokens_granted'] for row in replies) == 5
        assert sum(row['duplicate'] for row in replies) == 1
        assert scalar(f"select count(*) from public.bil_community_post_approval_grants where post_id='{identity}';") == '1'
        blocked(lambda: decide(identity, original['revision'], key=operation, decision='rejected', reason='spam'), 'idempotency_conflict')
    check('two independent sessions and response retry grant once', simultaneous)

    def default_policy():
        identity = post(5)
        original = snapshot(identity, actor=1)
        assert original['can_publish_only'] is False
        blocked(lambda: decide(identity, original['revision'], actor=1, mode='deferred'), 'community_publish_only_not_authorized')
        assert scalar(f"select moderation_status from public.bil_community_posts where id='{identity}';") == 'pending'
    check('publish only is denied until owner policy explicitly enables it', default_policy)

    def deferred_reward():
        execute('update private.bil_community_review_policy_v2 set allow_publish_only=true;')
        identity = post(6, owner=7)
        original = snapshot(identity, actor=1)
        receipt = decide(identity, original['revision'], actor=1, mode='deferred')
        assert receipt['tokens_granted'] == 0 and receipt['reward_reason'] == 'deferred'
        assert scalar(f"select count(*) from public.bil_community_notifications where recipient_id='{uid(7)}' and copy_key='post_approved_no_ai_tokens_v1' and metadata->>'reward_reason'='deferred' and entity_id='{identity}';") == '1'
        # The existing deferred RPC already queued its author push. The
        # additive receipt adds the durable in-app item without a duplicate.
        assert scalar(f"select count(*) from public.bil_push_outbox where recipient_id='{uid(7)}' and source_key='post-moderation-receipt-v2:{identity}';") == '0'
        assert scalar(f"select count(*) from public.bil_ai_credit_balances where owner_id='{uid(7)}';") == '0'
        request = value(f"select public.bil_request_community_post_reward_v2('{identity}','{original['revision']}');", uid(2))
        assert request['status'] == 'requested'
        blocked(lambda: value(f"select public.bil_decide_community_post_reward_v2('{request['request_id']}',true);", uid(2)), 'administrator_required')
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: value(f"select public.bil_decide_community_post_reward_v2('{request['request_id']}',true);", uid(1)), range(2)))
        assert sum(row['tokens_granted'] for row in results) == 5
        assert scalar(f"select granted from public.bil_ai_credit_balances where owner_id='{uid(7)}';") == '5'
        assert scalar(f"select count(*) from public.bil_community_post_approval_grants where post_id='{identity}';") == '1'
        assert scalar(f"select count(*) from public.bil_push_outbox where recipient_id='{uid(7)}';") == '2'
        assert scalar(f"select count(*) from public.bil_push_outbox where recipient_id='{uid(7)}' and source_key='post-published-only-v2:{identity}';") == '1'
        assert scalar(f"select count(*) from public.bil_community_notifications where recipient_id='{uid(7)}' and entity_id='{identity}' and copy_key in ('post_approved_no_ai_tokens_v1','post_approved_ai_tokens_v1','community_post_ai_reward_v1');") == '2'
        assert scalar(f"select count(*) from public.bil_push_outbox where recipient_id='{uid(7)}' and source_key='{push_source(identity,7,event='reward')}';") == '1'
        assert scalar(f"select count(*) from public.bil_ai_credit_balances where owner_id='{uid(7)}' and granted=5;") == '1'
        execute('update private.bil_community_review_policy_v2 set allow_publish_only=false;')
    check('publish only requests a separate administrator award and simultaneous retries credit once', deferred_reward)

    def media_revision():
        identity = post(7, owner=8)
        original = snapshot(identity)
        execute(f"insert into public.bil_community_post_media_v1(post_id,position,object_path,mime_type,bytes,width,height) "
                f"values('{identity}',0,'{uid(8)}/{identity}/first.jpg','image/jpeg',100,100,100);")
        blocked(lambda: decide(identity, original['revision']), 'community_review_content_changed')
        fresh = snapshot(identity)
        assert fresh['revision'] != original['revision']
        assert decide(identity, fresh['revision'])['tokens_granted'] == 5
        # The actual owner context cannot append changed images to an approved
        # parent, even if an earlier legacy precheck saw Pending.
        execute(f"begin; select set_config('request.jwt.claim.sub','{uid(8)}',true);"
                f"insert into public.bil_community_post_media_v1(post_id,position,object_path,mime_type,bytes,width,height) "
                f"values('{identity}',1,'{uid(8)}/{identity}/late.jpg','image/jpeg',100,100,100); commit;",
                expect_error='community_review_content_not_editable')
    check('media revision invalidates a decision and late owner edits cannot change an approved post', media_revision)

    def role_withdrawal():
        identity = post(8, owner=9)
        original = snapshot(identity)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            revoking = pool.submit(execute,
                "set application_name='bil_qa_revoke_role'; begin; "
                f"delete from public.bil_community_moderators where user_id='{uid(2)}'; "
                "select pg_sleep(2); commit;")
            for _ in range(20):
                if scalar("select count(*) from pg_stat_activity where application_name='bil_qa_revoke_role' and wait_event='PgSleep';") == '1':
                    break
            else:
                raise AssertionError('Revoking session did not hold the role row')
            blocked(lambda: decide(identity, original['revision']), 'community_moderator_required')
            revoking.result()
        assert scalar(f"select moderation_status from public.bil_community_posts where id='{identity}';") == 'pending'
        execute(f"insert into public.bil_community_moderators(user_id) values('{uid(2)}');")
    check('role withdrawn in a separate pending transaction prevents a decision', role_withdrawal)

    def rejection_and_identity():
        identity = post(9, owner=10)
        original = snapshot(identity)
        blocked(lambda: decide(identity, original['revision'], decision='rejected'), 'invalid_community_review_decision')
        assert decide(identity, original['revision'], decision='rejected', reason='Misleading health claim')['tokens_granted'] == 0
        assert scalar(f"select count(*) from public.bil_community_post_approval_grants where post_id='{identity}';") == '0'
        assert scalar(f"select count(*) from public.bil_community_notifications where recipient_id='{uid(10)}' and kind='comment' and copy_key='post_rejected_v1' and metadata->>'decision'='rejected' and entity_id='{identity}';") == '1'
        assert scalar(f"select count(*) from public.bil_push_outbox where recipient_id='{uid(10)}' and source_key='{push_source(identity,10,decision='rejected')}';") == '1'
        assert_single_receipt(identity,tokens=0,decision='rejected')
        identity = post(10, owner=11)
        original = snapshot(identity)
        execute(f"delete from public.bil_community_posts where id='{identity}';")
        post(10, owner=9)
        blocked(lambda: decide(identity, original['revision']), 'community_review_content_changed')
        execute(f"insert into public.bil_community_moderators(user_id) values('{uid(9)}');")
        blocked(lambda: decide(identity, snapshot(identity)['revision'], actor=9), 'cannot_review_own_post')
    check('rejection requires a reason and deleted recreated content cannot reuse a review', rejection_and_identity)

    def quota_and_delivery():
        execute('update private.bil_community_review_policy_v2 set allow_publish_only=true;')
        day = scalar("select (timezone('UTC',now())::date-1)::text;")
        identity = post(11, owner=11)
        original = snapshot(identity, actor=1)
        decide(identity, original['revision'], actor=1, mode='deferred')
        execute(f"update public.bil_community_posts set reviewed_at='{day} 12:00:00+00' where id='{identity}';"
                f"insert into public.bil_community_post_reward_usage(owner_id,reward_day,rewarded_posts,granted_tokens) values('{uid(11)}','{day}',5,25);")
        request = value(f"select public.bil_request_community_post_reward_v2('{identity}','{original['revision']}');", uid(2))
        result = value(f"select public.bil_decide_community_post_reward_v2('{request['request_id']}',true);", uid(1))
        assert result['status'] == 'not_eligible' and result['tokens_granted'] == 0
        assert scalar(f"select count(*) from public.bil_community_notifications where recipient_id='{uid(11)}' and source_key='post-reward-result-v2:{identity}' and metadata->>'reward_reason'='daily_cap_reached';") == '1'
        assert scalar(f"select reward_day from public.bil_community_post_approval_grants where post_id='{identity}';") == day
        assert scalar(f"select count(*) from public.bil_ai_credit_balances where owner_id='{uid(11)}';") == '0'
        # Delivery state is separate: a failed network send never re-runs a grant.
        identity = post(12, owner=10)
        original = snapshot(identity)
        key = str(uuid.uuid4())
        assert decide(identity, original['revision'], key=key)['tokens_granted'] == 5
        execute(f"update public.bil_push_outbox set failure_code='qa_network_failure' where recipient_id='{uid(10)}';")
        assert decide(identity, original['revision'], key=key)['tokens_granted'] == 0
        assert scalar(f"select granted from public.bil_ai_credit_balances where owner_id='{uid(10)}';") == '5'
        execute('update private.bil_community_review_policy_v2 set allow_publish_only=false;')
    check('late reward uses original approval day and notification failure cannot award twice', quota_and_delivery)

    def reward_queue():
        execute('update private.bil_community_review_policy_v2 set allow_publish_only=true;')
        identity = post(20, owner=8)
        original = snapshot(identity, actor=1)
        decide(identity, original['revision'], actor=1, mode='deferred')
        def item(actor):
            rows = value('select public.bil_community_reward_review_queue_v2();', uid(actor))
            return next(row for row in rows if row['post']['id'] == identity)
        assert item(2)['can_grant'] is False
        assert item(1)['can_grant'] is True
        assert item(2)['status'] == 'not_requested'
        request = value(f"select public.bil_request_community_post_reward_v2('{identity}','{original['revision']}');", uid(2))
        assert item(1)['request_id'] == request['request_id'] and item(1)['status'] == 'requested'
        blocked(lambda: value('select public.bil_community_reward_review_queue_v2();', uid(6)), 'community_moderator_required')
        # Request/audit identity must not prevent deleting the requesting actor.
        execute(f"delete from auth.users where id='{uid(2)}';")
        assert scalar(f"select count(*) from private.bil_community_post_reward_requests_v2 where id='{request['request_id']}';") == '1'
        assert scalar(f"select count(*) from private.bil_community_review_operations_v2 where post_id='{identity}';") == '1'
        execute('update private.bil_community_review_policy_v2 set allow_publish_only=false;')
    check('reward queue separates content authority and grants without blocking actor deletion', reward_queue)

    def author_reason():
        identity=post(30,owner=3)
        original=snapshot(identity,actor=1)
        decide(identity,original['revision'],actor=1,decision='rejected',reason='Please clarify the photo source')
        reply=value(f"select public.bil_get_my_post_review_v2('{identity}');",uid(3))
        assert reply['reason']=='Please clarify the photo source' and reply['owner_id']==uid(3)
        assert set(reply)=={'contract_version','post_id','owner_id','decision','reason','reviewed_revision','decided_at','post_body','post_created_at'}
        blocked(lambda:value(f"select public.bil_get_my_post_review_v2('{identity}');",uid(6)), 'community_post_not_found')
        execute(f"update public.bil_community_posts set body='Changed rejected content' where id='{identity}';")
        assert value(f"select public.bil_get_my_post_review_v2('{identity}');",uid(3)) is None
        execute(f"delete from public.bil_community_posts where id='{identity}';")
        blocked(lambda:value(f"select public.bil_get_my_post_review_v2('{identity}');",uid(3)), 'community_post_not_found')
    check('only the author receives a reason for the current rejected revision',author_reason)


    def receipt_idempotency():
        identity=post(131,owner=76)
        original=snapshot(identity,actor=1)
        operation=str(uuid.uuid4())
        decide(identity,original['revision'],actor=1,key=operation)
        assert_single_receipt(identity)
        before=delivery_digest(identity)
        duplicate=decide(identity,original['revision'],actor=1,key=operation)
        assert duplicate['duplicate'] is True
        # A different operation ID returns V1 duplicate_decision, not another
        # notification; retrying that new ID must also remain read-only.
        retry_key=str(uuid.uuid4())
        replay=decide(identity,original['revision'],actor=1,key=retry_key)
        assert replay['duplicate'] is True and replay['tokens_granted']==0
        assert decide(identity,original['revision'],actor=1,key=retry_key)['duplicate'] is True
        assert delivery_digest(identity)==before
        assert_single_receipt(identity)
    check('approval receipt is delivered once across same and new operation retries',receipt_idempotency)

    def v1_v2_receipt_matrix():
        for owner,decision,capped,old_first in (
            (60,'approved',False,True),(61,'approved',False,False),
            (62,'approved',True,True),(63,'approved',True,False),
            (64,'rejected',False,True),(65,'rejected',False,False)):
            identity=post(200+owner,owner=owner)
            original=snapshot(identity,actor=1)
            if capped:
                execute(f"""insert into public.bil_community_post_reward_usage
                  (owner_id,reward_day,rewarded_posts,granted_tokens)
                  values('{uid(owner)}',timezone('UTC',now())::date,5,25);""")
            tokens=5 if decision=='approved' and not capped else 0
            key=str(uuid.uuid4())
            if old_first:
                receipt=value(f"select public.bil_moderate_community_post('{identity}','{decision}');",uid(1))
            else:
                receipt=decide(identity,original['revision'],actor=1,decision=decision,
                               reason='Synthetic review reason',key=key)
            assert receipt['tokens_granted']==tokens
            assert_single_receipt(identity,tokens,decision)
            before=delivery_digest(identity)
            assert value(f"select public.bil_moderate_community_post('{identity}','{decision}');",uid(1))['duplicate'] is True
            replay=decide(identity,original['revision'],actor=1,decision=decision,
                          reason='Synthetic review reason',key=key)
            assert replay['duplicate'] is True and replay['tokens_granted']==0
            replay=decide(identity,original['revision'],actor=1,decision=decision,
                          reason='Synthetic review reason')
            assert replay['duplicate'] is True and replay['tokens_granted']==0
            assert_single_receipt(identity,tokens,decision)
            assert delivery_digest(identity)==before
    check('V1 and V2 positive daily-zero and rejected totals across all keys',v1_v2_receipt_matrix)

    def distinct_concurrent_operations():
        identity=post(280,owner=80)
        original=snapshot(identity,actor=1)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            replies=list(pool.map(lambda _:decide(identity,original['revision'],actor=1),range(2)))
        assert sum(row['tokens_granted'] for row in replies)==5
        assert sum(row['duplicate'] for row in replies)==1
        assert_single_receipt(identity)
        assert scalar(f"select granted from public.bil_ai_credit_balances where owner_id='{uid(80)}';")=='5'
        identity=post(281,owner=81)
        original=snapshot(identity,actor=1)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            old=pool.submit(value,f"select public.bil_moderate_community_post('{identity}','approved');",uid(1))
            new=pool.submit(decide,identity,original['revision'],actor=1)
            replies=[old.result(),new.result()]
        assert sum(row['tokens_granted'] for row in replies)==5
        assert_single_receipt(identity)
    check('different V2 operation IDs and mixed V1 V2 sessions fan out and credit once',distinct_concurrent_operations)

    def duplicate_grant_receipt():
        identity=post(282,owner=82)
        original=snapshot(identity,actor=1)
        # An immutable grant already exists, but the parent still says Pending.
        # Retrying review may reconcile status, never repeat the grant's fan-out.
        execute(f"""insert into public.bil_community_post_approval_grants
          (post_id,owner_id,approved_by,reward_day,tokens,reward_reason)
          values('{identity}','{uid(82)}','{uid(1)}',timezone('UTC',now())::date,5,'granted');""")
        before=delivery_digest(identity)
        result=decide(identity,original['revision'],actor=1)
        assert result['tokens_granted']==0 and result['reward_reason']=='duplicate_receipt'
        assert delivery_digest(identity)==before
        assert_single_receipt(identity)
        assert scalar(f"select count(*) from public.bil_ai_credit_balances where owner_id='{uid(82)}';")=='0'
    check('existing immutable grant receipt does not create another fan-out',duplicate_grant_receipt)

    if legacy_receipts:
        from bil_postgres_receipt_compat_cases import run_deployed_receipt_cases
        run_deployed_receipt_cases(locals())

except Exception as error:
    fatal_error = {'stage': startup_stage, 'error_type': type(error).__name__,
                   'message': str(error)}
    if startup_stage == 'runtime_probe':
        runtime_info['status'] = 'FAILED'
    records.append({'name': 'runner fatal error during ' + startup_stage,
                    'result': 'FAIL', 'error': str(error)})
    raise
finally:
    # A probe/setup failure still produces a truthful receipt. Neither Git nor
    # a missing input file may replace the original failure in this finally.
    try:
        git_result = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root,
                                    text=True, capture_output=True, timeout=10)
        head = git_result.stdout.strip() if git_result.returncode == 0 else None
        head_status = 'CAPTURED' if head else 'UNAVAILABLE'
    except (OSError, subprocess.TimeoutExpired):
        head = None
        head_status = 'UNAVAILABLE'
    source_fingerprints_after = fingerprint_sources()
    source_unchanged = source_fingerprints_before == source_fingerprints_after
    if not source_unchanged:
        records.append({'name': 'source inputs unchanged during isolated run',
                        'result': 'FAIL', 'error': 'source_fingerprint_changed'})
    receipt = {'database': database, 'host': '127.0.0.1', 'port': args.port,
               'head': head, 'head_status': head_status,
               'postgres': runtime_info.get('version'), 'runtime_probe': runtime_info,
               'session_model': 'native independent psql sessions',
               'fatal_error': fatal_error, 'records': records,
               'receipt_baseline': args.receipt_baseline,
               'seen_overlap_observations': globals().get('seen_overlap_observations', []),
               'source_fingerprints': {'before': source_fingerprints_before,
                                       'after': source_fingerprints_after,
                                       'unchanged': source_unchanged},
               'legacy_delivery_fixture_sha256': source_fingerprints_before[
                   'supabase/tests/fixtures/community_review_baseline/legacy_delivery.sql'].get('sha256'),
               'migration_sha256': source_fingerprints_before[
                   'supabase/migrations/20261011193000_community_review_revision_v2.sql'].get('sha256'),
               'receipt_migration_sha256': source_fingerprints_before[
                   'supabase/migrations/20261014113000_community_post_review_receipts_v2.sql'].get('sha256')}
    (out / 'result.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps({'evidence': str(out), 'pass': sum(r['result']=='PASS' for r in records),
                      'fail': sum(r['result']=='FAIL' for r in records)}), flush=True)
if not records or any(r['result'] != 'PASS' for r in records):
    raise SystemExit(1)
