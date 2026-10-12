"""Real loopback PostgreSQL transactions against existing admin RPC bodies.

Synthetic identities only. Installs a current catalog slice plus the additive
role lock. No Production credentials, store operation or external notification.
The period resolvers, RPCs, credit triggers and ledger constraints are actual
repository SQL; the HTTP/JWT signature verifier and push provider are outside
this test's scope. Distinguish these results from mobile or Production proof.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--psql', required=True)
    parser.add_argument('--port', type=int, default=55432)
    parser.add_argument('--case')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
    database = 'bil_qa_admin_credit_' + stamp
    assert re.fullmatch(r'bil_qa_admin_credit_[0-9]+', database)
    base = [args.psql, '-X', '-qAt', '-P', 'null=null', '-v', 'ON_ERROR_STOP=1',
            '-h', '127.0.0.1', '-p', str(args.port), '-U', 'bil_test_superuser']
    out = root / 'build/stage1-closure' / ('postgres-admin-credit-' + stamp)
    out.mkdir(parents=True, exist_ok=False)
    cases, inputs = [], {}
    actor, target, ordinary = [f'71000000-0000-4000-8000-{n:012d}' for n in [1, 2, 3]]
    migration = root / 'supabase/migrations/20261012202029_admin_credit_authority_transaction_lock.sql'

    def execute(sql, role=None, db=database, error=None):
        if role:
            claims = json.dumps({'role': role, 'sub': ordinary})
            sql = (f"begin; set local role {role}; "
                   f"select set_config('request.jwt.claims','{claims}',true); "
                   f"select set_config('request.jwt.claim.sub','{ordinary}',true); "
                   + sql + '\ncommit;')
        result = subprocess.run(base + ['-d', db], input=sql, text=True,
                                encoding='utf-8', capture_output=True, timeout=20)
        if error:
            assert result.returncode and error in result.stderr, result.stderr
            return result.stderr
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout.strip().splitlines()

    def scalar(sql, **kwargs):
        return execute(sql, **kwargs)[-1]

    def install(relative):
        file = root / relative
        inputs[relative] = hashlib.sha256(file.read_bytes()).hexdigest()
        execute(file.read_text(encoding='utf-8'))

    def check(name, run):
        if args.case and args.case != name:
            return
        try:
            detail = run()
            cases.append({'name': name, 'result': 'PASS', 'detail': detail})
            print('PASS: ' + name, flush=True)
        except Exception as failure:
            cases.append({'name': name, 'result': 'FAIL', 'error': str(failure)})
            print('FAIL: ' + name + ': ' + str(failure), flush=True)

    def wait_for(sql):
        deadline = time.monotonic() + 6
        while time.monotonic() < deadline:
            if scalar(sql) == 't':
                return
            time.sleep(.03)
        raise AssertionError('Independent SQL session did not reach its barrier')

    def call(kind, key, identity=actor, role='service_role'):
        if kind in ['gift', 'compensation']:
            rpc = (f"public.bil_enqueue_admin_notification_with_message('{identity}',"
                   f"'{kind}','email','{target}','TEST exact authored message','{key}')")
        elif kind == 'custom':
            rpc = (f"public.bil_enqueue_admin_notification('{identity}',"
                   f"'custom','email','{target}','TEST exact authored message','{key}')")
        elif kind == 'global':
            rpc = f"public.bil_global_reset_ai_coach('{identity}','{key}','TEST exact authored message')"
        elif kind == 'individual':
            rpc = (f"public.bil_individual_reset_ai_coach('{identity}','{target}',"
                   f"'TEST reason','{key}','TEST exact authored message')")
        else:
            raise ValueError(kind)
        return json.loads(scalar('select ' + rpc + ';', role=role))

    def rejected(kind, identity=actor, role='service_role'):
        try:
            call(kind, str(uuid.uuid4()), identity=identity, role=role)
        except RuntimeError as failure:
            assert any(word in str(failure) for word in [
                'permission denied', 'ai_coach_admin_required', 'service_role_required']), str(failure)
            return
        raise AssertionError('Sensitive RPC accepted an unauthorized identity')

    def balance():
        return int(scalar(f"select coalesce((select granted from public.bil_ai_credit_balances where owner_id='{target}'),0);"))

    def store_rights():
        return scalar("select coalesce(jsonb_agg(to_jsonb(s) order by owner_id),'[]')::text from public.bil_subscriptions s;")

    def catalog():
        return json.loads(scalar("""select jsonb_object_agg(p.oid::regprocedure::text,
          jsonb_build_object('definition',pg_get_functiondef(p.oid),'acl',p.proacl::text,
                             'owner',p.proowner,'arguments',pg_get_function_arguments(p.oid),
                             'result',pg_get_function_result(p.oid)))
          from pg_proc p join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname in ('bil_enqueue_admin_notification',
          'bil_enqueue_admin_notification_with_message','bil_global_reset_ai_coach',
          'bil_individual_reset_ai_coach');"""))

    def race(kind, expected_block):
        execute(f"update private.bil_ai_coach_admins set active=true where user_id='{actor}';")
        key = str(uuid.uuid4())
        before, rights = balance(), store_rights()
        # This synthetic trigger waits after the real RPC's admission check.
        # It does not grant anything or modify the administrator allow-list.
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            holder = pool.submit(execute,
                "begin; select pg_advisory_xact_lock(710711); select pg_sleep(2); commit;")
            wait_for("select exists(select 1 from pg_stat_activity where datname=current_database() and wait_event='PgSleep');")
            pending = pool.submit(call, kind, key)
            wait_for("select exists(select 1 from pg_locks l join pg_stat_activity a on a.pid=l.pid "
                     "where a.datname=current_database() and l.locktype='advisory' and not l.granted);")
            withdrawal = pool.submit(execute,
                f"update private.bil_ai_coach_admins set active=false where user_id='{actor}';")
            time.sleep(.12)
            withdrawn_before_effect = scalar(
                f"select not active from private.bil_ai_coach_admins where user_id='{actor}';") == 't'
            if expected_block:
                wait_for("select exists(select 1 from pg_locks l join pg_stat_activity a on a.pid=l.pid "
                         "where a.datname=current_database() and l.locktype='transactionid' and not l.granted);")
            else:
                withdrawal.result()
                withdrawn_before_effect = True
            receipt = pending.result()
            withdrawal.result()
            holder.result()
        assert withdrawn_before_effect is (not expected_block), (
            'Role withdrawal must wait for an admitted credit/reset transaction', receipt)
        expected_credit = 0 if kind == 'custom' else 2500
        assert balance() == before + expected_credit
        assert store_rights() == rights, 'A courtesy grant/reset changed store subscription rights'
        rejected(kind)
        # Restore only this synthetic administrator, then retry the same key.
        execute(f"update private.bil_ai_coach_admins set active=true where user_id='{actor}';")
        replay = call(kind, key)
        assert replay['duplicate'] is True
        assert balance() == before + expected_credit
        assert store_rights() == rights
        return {'role_withdrawn_before_effect': withdrawn_before_effect,
                'credit_delta': expected_credit, 'duplicate_credit_delta': 0,
                'store_rights_preserved': True}

    try:
        execute(f'create database "{database}";', db='postgres')
        execute("""do $$begin
          if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
          if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
          if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
        end $$;
        create schema auth; create schema private; create schema extensions;
        create extension pgcrypto with schema extensions;
        create table auth.users(id uuid primary key,email text,
          raw_app_meta_data jsonb not null default '{}',raw_user_meta_data jsonb not null default '{}');
        create function auth.jwt() returns jsonb language sql stable as
          $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
        create function auth.uid() returns uuid language sql stable as
          $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
        grant usage on schema auth,public to anon,authenticated,service_role;
        create table public.bil_public_profiles(user_id uuid primary key,locale_code text);
        create table public.bil_push_outbox(id uuid primary key default gen_random_uuid(),
          recipient_id uuid,category text,title text,body text,deep_link text,copy_key text,
          source_key text,created_at timestamptz,unique(recipient_id,source_key));
        """)
        fixture = 'supabase/tests/fixtures/admin_subscription_baseline/'
        for name in ['tables.sql','bil_resolve_ai_allowance_plan.sql','bil_resolve_ai_trial_anchor.sql']:
            install(fixture + name)
        for relative in [
            'supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql',
            'supabase/migrations/20260831192412_admin_notification_controls.sql',
            'supabase/migrations/20260901010000_admin_ai_boost_gifts.sql',
            'supabase/migrations/20260904010000_ai_coach_reset_token_grants.sql',
        ]:
            install(relative)
        for identity in [actor, target, ordinary]:
            execute(f"insert into auth.users(id,email) values('{identity}','{identity}@example.test');")
        execute(f"insert into private.bil_ai_coach_admins(user_id,active) values('{actor}',true);")
        execute(f"insert into public.bil_subscriptions(owner_id,provider,product_id,plan_id,lifecycle,"
                f"original_transaction_id,latest_transaction_id,environment,started_at,expires_at,verified_at) "
                f"values('{target}','apple','bil_premium_annual','premium','active','TEST original',"
                "'TEST latest','sandbox',now(),now()+interval '30 days',now());")
        execute("""create function private.bil_qa_wait_after_admission() returns trigger
          language plpgsql as $$begin perform pg_advisory_xact_lock(710711); return new; end$$;
          create trigger bil_qa_hold_notice before insert on private.bil_admin_notification_audit
            for each row execute function private.bil_qa_wait_after_admission();
          create trigger bil_qa_hold_global before insert on private.bil_ai_coach_global_reset_audit
            for each row execute function private.bil_qa_wait_after_admission();
          create trigger bil_qa_hold_individual before insert on private.bil_ai_coach_individual_reset_audit
            for each row execute function private.bil_qa_wait_after_admission();""")
        check('baseline observes gift admitted before withdrawal but credited after it',
              lambda: race('gift', False))
        before = catalog()
        install(str(migration.relative_to(root)))
        after = catalog()
        predicate = 'where a.user_id = p_actor_id and a.active'
        locked = predicate + ' for share'

        def contracts():
            changed = 0
            assert set(before) == set(after)
            for name, original in before.items():
                current = after[name]
                for key in ['acl', 'owner', 'arguments', 'result']:
                    assert current[key] == original[key], (name, key)
                expected = original['definition'].replace(predicate, locked)
                assert current['definition'] == expected, name
                changed += int(current['definition'] != original['definition'])
            assert changed == 4
            install(str(migration.relative_to(root)))
            assert catalog() == after, 'Migration reapplication changed the preserved contract'
            return {'changed_function_bodies': changed, 'changed_acl_signatures_results': 0}
        check('additive lock preserves old RPC signatures ACL and bodies and reapplies once', contracts)
        for kind in ['gift', 'compensation', 'custom', 'global', 'individual']:
            check(kind + ' role withdrawal waits for atomic admitted transaction',
                  lambda k=kind: race(k, True))

        def access():
            before_balance, rights = balance(), store_rights()
            for kind in ['gift', 'compensation', 'custom', 'global', 'individual']:
                rejected(kind, identity=ordinary)
                for role in ['anon', 'authenticated']:
                    rejected(kind, role=role)
            assert balance() == before_balance
            assert store_rights() == rights
            return {'unauthorized_calls_rejected': 15}
        check('ordinary direct API cannot grant reset or notify and has no financial effect', access)

        def rollback():
            before_balance, rights = balance(), store_rights()
            before_notices = scalar('select count(*) from public.bil_admin_notices;')
            key = str(uuid.uuid4())
            claims = json.dumps({'role': 'service_role'})
            execute(f"begin; set local role service_role; select set_config('request.jwt.claims','{claims}',true); "
                    f"select public.bil_enqueue_admin_notification_with_message('{actor}','gift','email',"
                    f"'{target}','TEST rollback','{key}'); rollback;")
            assert balance() == before_balance
            assert scalar('select count(*) from public.bil_admin_notices;') == before_notices
            assert scalar(f"select count(*) from private.bil_admin_notification_audit where idempotency_key='{key}';") == '0'
            assert store_rights() == rights
            return {'audit_notice_credit_outbox_rolled_back_together': True}
        check('failed transaction rolls back grant receipt notice credit and outbox together', rollback)
    finally:
        execute(f'drop database if exists "{database}" with (force);', db='postgres')
        result = {'host': '127.0.0.1', 'port': args.port, 'database': database,
                  'production_tested': False, 'cases': cases, 'input_sha256': inputs}
        (out / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        print(str(out / 'result.json'), flush=True)
    expected = 1 if args.case else 9
    if len(cases) != expected or any(case['result'] != 'PASS' for case in cases):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
