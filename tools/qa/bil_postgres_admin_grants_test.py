"""Real local PostgreSQL sessions, synthetic identities, never Production.

The catalog slice preserves deployed subscription RPCs and financial policy.
It does not emulate signature validation, a payment provider, or all schemas.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import pathlib
import subprocess
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--psql', required=True)
parser.add_argument('--port', type=int, default=55432)
parser.add_argument('--case')
parser.add_argument('--baseline', action='store_true')
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
database = 'bil_qa_admin_' + stamp
base = [args.psql, '-X', '-qAt', '-P', 'null=null', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
        '-p', str(args.port), '-U', 'bil_test_superuser']
out = root / 'build/stage1-closure' / ('postgres-admin-' + stamp)
out.mkdir(parents=True, exist_ok=False)
records = []


def uid(n):
    return f'21000000-0000-4000-8000-{n:012d}'


def execute(sql, role=None, owner=None, db=database, error=None):
    if role:
        claims = json.dumps({'role': role, 'sub': owner})
        sql = (f"begin; set local role {role}; "
               f"select set_config('request.jwt.claims','{claims}',true); "
               f"select set_config('request.jwt.claim.sub','{owner or ''}',true); "
               + sql + '\ncommit;')
    result = subprocess.run(base + ['-d', db], input=sql, text=True,
                            encoding='utf-8', capture_output=True, timeout=15)
    if error:
        assert result.returncode != 0 and error in result.stderr, result.stderr
        return None
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip().splitlines()


def value(sql, **kwargs):
    return json.loads(execute(sql, **kwargs)[-1])


def grant(n, actor=1, key=None, days=30, plan='premium', email=None):
    key = key or str(uuid.uuid4())
    return value(f"select public.bil_manage_admin_subscription('{uid(actor)}','grant',"
                 f"'{key}','{email or f'qa{n}@example.test'}','{plan}',{days},'QA synthetic',null);",
                 role='service_role')


def reject(call, error):
    try:
        call()
    except RuntimeError as failure:
        assert error in str(failure), str(failure)
        return
    raise AssertionError('Sensitive operation unexpectedly succeeded')


def check(name, action):
    if args.case and args.case != name:
        return
    try:
        action()
        records.append({'name': name, 'result': 'PASS'})
        print('PASS: ' + name, flush=True)
    except Exception as failure:
        records.append({'name': name, 'result': 'FAIL', 'error': str(failure)})
        print('FAIL: ' + name + ': ' + str(failure), flush=True)


def wait_for(sql):
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        if execute(sql)[-1] == 't':
            return
        time.sleep(.04)
    raise AssertionError('Independent PostgreSQL session never reached expected lock')


try:
    execute(f'create database "{database}";', db='postgres')
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
    create table private.bil_ai_coach_admins(user_id uuid primary key references auth.users(id),active boolean not null);
    grant usage on schema public,auth to authenticated,service_role,anon;
    """)
    fixture = root / 'supabase/tests/fixtures/admin_subscription_baseline'
    for name in ['schema.sql', 'store_subscription_table.sql', 'functions.sql', 'public_functions.sql']:
        execute((fixture / name).read_text(encoding='utf-8'))
    for n in range(1, 20):
        execute(f"insert into auth.users values('{uid(n)}','qa{n}@example.test',null);")
    execute(f"insert into private.bil_ai_coach_admins values('{uid(1)}',true),('{uid(2)}',true);")
    before = value("select jsonb_object_agg(proname,md5(pg_get_functiondef(p.oid))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and proname in ('bil_manage_admin_subscription','bil_list_admin_subscriptions','bil_get_my_admin_subscription');")
    migration = root / 'supabase/migrations/20261011211500_admin_authority_transaction_lock.sql'
    if not args.baseline:
        execute(migration.read_text(encoding='utf-8'))

    def role_withdrawal():
        # Hold the existing financial-owner lock in a separate SQL session.
        # The real grant RPC must wait, so role withdrawal has a real race.
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            lock = pool.submit(execute, f"begin; select pg_advisory_xact_lock(hashtextextended('{uid(3)}',711)); select pg_sleep(3); commit;")
            wait_for("select exists(select 1 from pg_stat_activity where datname=current_database() and wait_event='PgSleep');")
            pending = pool.submit(grant, 3)
            wait_for("select exists(select 1 from pg_locks l join pg_stat_activity a on a.pid=l.pid where a.datname=current_database() and l.locktype='advisory' and not l.granted);")
            withdrawal = pool.submit(execute, f"update private.bil_ai_coach_admins set active=false where user_id='{uid(1)}';")
            time.sleep(.25)
            revoked_before_effect = execute(f"select not active from private.bil_ai_coach_admins where user_id='{uid(1)}';")[-1] == 't'
            receipt = pending.result()
            withdrawal.result()
            lock.result()
        assert receipt['changed'] is True
        assert not revoked_before_effect, 'Role withdrawal committed while an already-authorized financial operation was waiting'
        reject(lambda: grant(4), 'administrator_required')
        execute(f"update private.bil_ai_coach_admins set active=true where user_id='{uid(1)}';")
    check('role withdrawal is serialized with an admitted financial operation', role_withdrawal)

    def roles():
        for role in ['anon', 'authenticated']:
            execute(f"select public.bil_manage_admin_subscription('{uid(1)}','grant','synthetic-key-1234','qa5@example.test','premium',30,'',null);", role=role, owner=uid(5), error='permission denied')
        reject(lambda: grant(5, actor=5), 'administrator_required')
        execute('select * from bil_admin_private.subscription_grants;', role='authenticated', owner=uid(5), error='permission denied')
    check('ordinary and content-only identities cannot invoke the financial API', roles)

    def concurrency():
        key = str(uuid.uuid4())
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            receipts = list(pool.map(lambda _: grant(6, key=key), range(2)))
        assert receipts[0] == receipts[1] and receipts[0]['changed']
        assert grant(6, key=key) == receipts[0]  # timeout/retry same receipt
        assert execute(f"select count(*) from bil_admin_private.subscription_grants where owner_id='{uid(6)}';")[-1] == '1'
        reject(lambda: grant(7, key=key), 'idempotency_conflict')
    check('simultaneous same-key grants and timeout replay create one receipt', concurrency)

    def beneficiary():
        assert grant(7, email=' QA7@EXAMPLE.TEST ')['matched']
        assert value(f"select public.bil_get_my_admin_subscription();", role='authenticated', owner=uid(7))['owner_id'] == uid(7)
        execute(f"update auth.users set email='changed7@example.test' where id='{uid(7)}';")
        assert grant(7)['matched'] is False
        assert grant(7, email='changed7@example.test')['changed'] is False
        assert grant(8, email='missing@example.test')['matched'] is False
        execute(f"update auth.users set email='changed7@example.test' where id='{uid(8)}';")
        assert grant(8, email='changed7@example.test')['matched'] is False
    check('email lookup resolves a stable owner and ambiguous or changed emails cannot retarget', beneficiary)

    def policy():
        reject(lambda: grant(9, days=1), 'invalid_subscription_request')
        reject(lambda: grant(9, plan='owner'), 'invalid_subscription_request')
        grant(9)
        reject(lambda: grant(9, plan='premium_ai_coach'), 'existing_admin_subscription')
        before = execute(f"select row_to_json(g)::text from bil_admin_private.subscription_grants g where owner_id='{uid(9)}';")[-1]
        assert grant(9)['changed'] is False
        assert execute(f"select row_to_json(g)::text from bil_admin_private.subscription_grants g where owner_id='{uid(9)}';")[-1] == before
    check('existing durations and plans are enforced with no renewal or downgrade on repeated grants', policy)

    def revoke_and_store():
        execute(f"insert into public.bil_subscriptions(owner_id,provider,product_id,plan_id,lifecycle,original_transaction_id,latest_transaction_id,environment,expires_at,verified_at) values('{uid(10)}','apple','synthetic.test.product','premium','active','synthetic-original','synthetic-latest','sandbox',now()+interval '30 days',now());")
        store_before = execute(f"select row_to_json(s)::text from public.bil_subscriptions s where owner_id='{uid(10)}';")[-1]
        receipt = grant(10)
        result = value(f"select public.bil_manage_admin_subscription('{uid(1)}','revoke','{uuid.uuid4()}',null,null,null,'','{receipt['grant_id']}');", role='service_role')
        assert result['changed']
        assert value('select public.bil_get_my_admin_subscription();', role='authenticated', owner=uid(10)) is None
        assert execute(f"select row_to_json(s)::text from public.bil_subscriptions s where owner_id='{uid(10)}';")[-1] == store_before
        grant(11)
        execute(f"update bil_admin_private.subscription_grants set created_at=now()-interval '31 days',expires_at=now()-interval '1 day' where owner_id='{uid(11)}';")
        assert value('select public.bil_get_my_admin_subscription();', role='authenticated', owner=uid(11)) is None
    check('revoking or expiring an admin grant cannot change an existing store purchase', revoke_and_store)

    def compatibility():
        after = value("select jsonb_object_agg(proname,md5(pg_get_functiondef(p.oid))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and proname in ('bil_manage_admin_subscription','bil_list_admin_subscriptions','bil_get_my_admin_subscription');")
        assert before == after
        rows = value(f"select public.bil_list_admin_subscriptions('{uid(2)}',0);", role='service_role')
        assert set(rows) == {'rows', 'has_more'}
        own = value('select public.bil_get_my_admin_subscription();', role='authenticated', owner=uid(6))
        assert set(own) == {'id', 'owner_id', 'plan_id', 'created_at', 'expires_at', 'access_until'}
        assert value('select public.bil_get_my_admin_subscription();', role='authenticated', owner=uid(19)) is None
    check('old 32/35 RPC signatures and response keys are unchanged and owner scoped', compatibility)
finally:
    execute(f'drop database if exists "{database}" with (force);', db='postgres')
    files = list((root / 'supabase/tests/fixtures/admin_subscription_baseline').glob('*.sql'))
    if not args.baseline:
        files.append(migration)
    manifest = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (out / 'result.json').write_text(json.dumps({'baseline': args.baseline,
        'postgres': '17.6', 'host': '127.0.0.1', 'database': database,
        'files': manifest, 'cases': records}, indent=2), encoding='utf-8')
    print(str(out / 'result.json'), flush=True)
if not records or any(r['result'] != 'PASS' for r in records):
    raise SystemExit(1)
