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
args = parser.parse_args()
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


try:
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
    execute((fixture / 'moderator_population.sql').read_text(encoding='utf-8'))
    execute("""revoke all on function public.bil_moderate_community_post(uuid,text)
      from public,anon,service_role;
      grant execute on function public.bil_moderate_community_post(uuid,text) to authenticated;
      create trigger bil_post_approval_receipt_v1 after insert on public.bil_community_post_approval_grants
        for each row execute function private.bil_post_approval_receipt_trigger_v1();
      create trigger bil_post_rejection_receipt_v1 after update of moderation_status on public.bil_community_posts
        for each row execute function private.bil_post_rejection_receipt_trigger_v1();
      create trigger bil_01_posts_moderation_guard before insert or update on public.bil_community_posts
        for each row execute function public.bil_guard_community_post_moderation();
      create trigger bil_02_posts_suspended_author_approval before update of moderation_status on public.bil_community_posts
        for each row execute function public.bil_guard_suspended_author_post_approval();
      insert into public.bil_community_post_reward_policy(singleton) values(true);
    """)
    for n in range(1, 12):
        execute(f"insert into auth.users(id,email) values('{uid(n)}','synthetic{n}@example.test');")
    execute(f"insert into private.bil_ai_coach_admins(user_id,active) values('{uid(1)}',true);"
            f"insert into public.bil_community_moderators(user_id) values('{uid(2)}');")

    baseline_post = post(0, owner=4)
    baseline = value(f"select public.bil_moderate_community_post('{baseline_post}','approved');", uid(2))
    assert baseline['tokens_granted'] == 5
    contracts_before = scalar("select md5(pg_get_functiondef('public.bil_moderate_community_post(uuid,text)'::regprocedure));")
    migration = root / 'supabase/migrations/20261011193000_community_review_revision_v2.sql'
    execute(migration.read_text(encoding='utf-8'))

    def legacy():
        identity = post(1, owner=5)
        receipt = value(f"select public.bil_moderate_community_post('{identity}','approved');", uid(2))
        assert receipt.keys() == baseline.keys()
        assert receipt['tokens_granted'] == 5
        assert scalar("select md5(pg_get_functiondef('public.bil_moderate_community_post(uuid,text)'::regprocedure));") == contracts_before
    check('legacy 32/35 moderation contract remains unchanged', legacy)

    def revised():
        identity = post(2)
        original = snapshot(identity)
        execute(f"update public.bil_community_posts set body='Changed after review' where id='{identity}';")
        blocked(lambda: decide(identity, original['revision']), 'community_review_content_changed')
        fresh = snapshot(identity)
        assert decide(identity, fresh['revision'])['tokens_granted'] == 5
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

finally:
    receipt = {'database': database, 'host': '127.0.0.1', 'port': args.port,
               'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
               'postgres': '17.6 native, independent psql sessions', 'records': records,
               'migration_sha256': hashlib.sha256((root / 'supabase/migrations/20261011193000_community_review_revision_v2.sql').read_bytes()).hexdigest()}
    (out / 'result.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    print(json.dumps({'evidence': str(out), 'pass': sum(r['result']=='PASS' for r in records),
                      'fail': sum(r['result']=='FAIL' for r in records)}), flush=True)
if not records or any(r['result'] != 'PASS' for r in records):
    raise SystemExit(1)
