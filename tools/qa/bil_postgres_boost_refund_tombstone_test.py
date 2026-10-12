"""Real loopback SQL/RLS tests for the existing Boost ledger and narrow read grant.

No Production connection or credentials. Uses synthetic identities in a fresh
independent database; applies the actual historical refund migration unchanged.
The caller's JWT signature/store verification is exercised separately in Deno.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--psql', required=True)
    parser.add_argument('--port', type=int, default=55432)
    parser.add_argument('--case')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
    database = 'bil_qa_boost_refund_' + stamp
    assert re.fullmatch(r'bil_qa_boost_refund_[0-9]+', database)
    base = [args.psql, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
            '-p', str(args.port), '-U', 'bil_test_superuser']
    out = root / 'build/stage1-closure' / ('postgres-boost-refund-' + stamp)
    out.mkdir(parents=True, exist_ok=False)
    inputs, cases = {}, []
    owner = '72000000-0000-4000-8000-000000000001'
    other = '72000000-0000-4000-8000-000000000002'
    migration = 'supabase/migrations/20261012204610_boost_refund_tombstone_service_read.sql'
    credit = ("public.bil_credit_ai_boost_verified('%s','google_play','TEST transaction 001',"
              "'bil_ai_boost',now(),repeat('a',64),'sandbox')")
    event = ("public.bil_apply_ai_boost_store_event('google_play','TEST transaction 001',"
             "'bil_ai_boost','%s','%s','%s',now() + interval '%s',repeat('b',64))")

    def execute(sql, db=database, error=None):
        result = subprocess.run(base + ['-d', db], input=sql, text=True,
                                encoding='utf-8', capture_output=True, timeout=25)
        if error:
            assert result.returncode and error in result.stderr, result.stderr
            return result.stderr
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout.strip().splitlines()

    def scalar(sql):
        return execute(sql)[-1]

    def install(relative):
        source = root / relative
        inputs[relative] = hashlib.sha256(source.read_bytes()).hexdigest()
        execute(source.read_text(encoding='utf-8'))

    def check(name, run):
        if args.case and name != args.case:
            return
        try:
            detail = run()
            cases.append({'name': name, 'result': 'PASS', 'detail': detail})
            print('PASS: ' + name, flush=True)
        except Exception as failure:
            cases.append({'name': name, 'result': 'FAIL', 'error': str(failure)})
            print('FAIL: ' + name + ': ' + str(failure), flush=True)

    def service(sql, role='service_role'):
        return (f"begin; set local role {role}; "
                f"select set_config('request.jwt.claims','{{\"role\":\"{role}\"}}',true); "
                + sql + '\nrollback;')

    def mutation(sql):
        # RPC is SECURITY DEFINER and must still reject unauthorized JWT roles.
        # Query assertions run as fixture owner, not as a fake client bypass.
        return execute("begin; select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true); "
                       + sql + '\nrollback;')

    def assert_sql(condition, message):
        return f"if not ({condition}) then raise exception '{message}'; end if;"

    def credit_call(identity=owner):
        return credit % identity

    def refund_call(key='TEST refund 001', kind='refunded', offset='0 seconds', environment='sandbox'):
        return event % (environment, key, kind, offset)

    def do_body(sql):
        return 'do $test$ declare v jsonb; begin ' + sql + ' end $test$;'

    original_bypass = None
    created_database = False
    try:
        execute("do $$begin "
                "if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if; "
                "if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if; "
                "if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if; end$$;",
                db='postgres')
        original_bypass = execute("select rolbypassrls from pg_roles where rolname='service_role';", db='postgres')[-1] == 't'
        # Supabase's service role bypasses RLS; use that actual role property in
        # the isolated local harness, restoring its pre-test property afterward.
        if not original_bypass:
            execute('alter role service_role bypassrls;', db='postgres')
        execute(f'create database "{database}";', db='postgres')
        created_database = True
        install('supabase/tests/fixtures/boost_refund_baseline/schema.sql')
        install('supabase/migrations/20260916104000_verified_boost_refund_ledger.sql')
        before = scalar("select md5(string_agg(pg_get_functiondef(oid),'|' order by oid)) from pg_proc "
                        "where pronamespace='public'::regnamespace and proname in "
                        "('bil_credit_ai_boost_verified','bil_apply_ai_boost_store_event');")

        def missing_read():
            execute(service('select * from public.bil_ai_boost_store_state;'), error='permission denied')
            return {'baseline_missing_explicit_service_select': True}
        check('baseline missing tombstone read is reproduced', missing_read)
        install(migration)
        after = scalar("select md5(string_agg(pg_get_functiondef(oid),'|' order by oid)) from pg_proc "
                       "where pronamespace='public'::regnamespace and proname in "
                       "('bil_credit_ai_boost_verified','bil_apply_ai_boost_store_event');")

        def acl():
            assert before == after, 'Narrow grant changed existing financial RPC contracts'
            execute(service('select * from public.bil_ai_boost_store_state;'))
            for role in ['anon', 'authenticated']:
                execute(service('select * from public.bil_ai_boost_store_state;', role), error='permission denied')
                execute(service('select ' + credit_call() + ';', role), error='permission denied')
                execute(service('select ' + refund_call() + ';', role), error='permission denied')
            assert scalar("select relrowsecurity from pg_class where oid='public.bil_ai_boost_store_state'::regclass;") == 't'
            assert scalar("select has_table_privilege('service_role','public.bil_ai_boost_store_state','INSERT') "
                          "or has_table_privilege('service_role','public.bil_ai_boost_store_state','UPDATE') "
                          "or has_table_privilege('service_role','public.bil_ai_boost_store_state','DELETE');") == 'f'
            install(migration)
            return {'service_select_only': True, 'client_select_and_rpc_denied': True,
                    'rls_enabled': True, 'rpc_contracts_preserved': True, 'migration_repeatable': True}
        check('service read and client denial preserve RLS and RPC contracts', acl)

        def refund_once():
            mutation(do_body(
                'perform ' + credit_call() + '; perform ' + refund_call() + '; '
                'v := ' + refund_call() + '; '
                + assert_sql("v->>'duplicate'='true'", 'duplicate_missing')
                + assert_sql("(select granted=0 and refund_debt=0 from public.bil_ai_credit_balances where owner_id='" + owner + "')", 'refund_balance_wrong')
                + assert_sql("not exists(select 1 from public.bil_ai_credit_balances where owner_id='" + other + "')", 'foreign_balance_modified')
                + 'v := ' + credit_call() + '; '
                + assert_sql("v->>'refunded'='true' and v->>'credited'='false' and v->>'tokens_granted'='0'", 'refunded_recredited')
                + assert_sql("(select state='refunded' and purchase_credited and owner_id='" + owner + "' and environment='sandbox' and product_id='bil_ai_boost' from public.bil_ai_boost_store_state)", 'tombstone_identity_wrong')))
            return {'duplicate_debit': 0, 'replay_credit': 0, 'other_owner_unchanged': True}
        check('credited refund replay is idempotent and owner bound', refund_once)

        def before_credit():
            mutation(do_body('perform ' + refund_call() + '; v := ' + credit_call() + '; '
                + assert_sql("v->>'refunded'='true' and v->>'tokens_granted'='0'", 'refund_before_credit_credited')
                + assert_sql("not exists(select 1 from public.bil_ai_credit_balances)", 'invented_refund_balance')
                + assert_sql("(select owner_id is null and not purchase_credited and state='refunded' from public.bil_ai_boost_store_state)", 'precredit_tombstone_wrong')))
            return {'credit_after_canonical_refund': 0, 'missing_owner_not_invented': True}
        check('refund before credit cannot grant later replay', before_credit)

        def ownership():
            execute("begin; select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true); "
                    'select ' + credit_call() + '; select ' + credit_call(other) + '; rollback;',
                    error='purchase_owned_by_another_account')
            execute("begin; select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true); "
                    'select ' + credit_call() + '; select ' + refund_call(environment='production') + '; rollback;',
                    error='wrong_environment')
            assert scalar('select count(*) from public.bil_ai_boost_store_state;') == '0'
            assert scalar('select count(*) from public.bil_ai_boost_purchases;') == '0'
            return {'foreign_owner_and_environment_rejected_atomically': True}
        check('foreign owner and environment fail without financial writes', ownership)

        def reversal():
            mutation(do_body('perform ' + credit_call() + '; perform ' + refund_call(offset='-3 seconds') + '; '
                + 'perform ' + refund_call('TEST reversal 001','refund_reversed','-1 seconds') + '; '
                + 'v := ' + refund_call('TEST stale refund','refunded','-2 seconds') + '; '
                + assert_sql("v->>'stale'='true' and v->>'applied'='false'", 'stale_refund_applied')
                + assert_sql("(select state='refund_reversed' from public.bil_ai_boost_store_state)", 'newer_reversal_lost')
                + assert_sql("(select granted=2500 from public.bil_ai_credit_balances where owner_id='" + owner + "')", 'reversal_balance_wrong')
                + 'perform ' + refund_call('TEST new refund','refunded','0 seconds') + '; '
                + 'perform ' + refund_call('TEST repeated refund','refunded','1 second') + '; '
                + assert_sql("(select granted=0 and refund_debt=0 from public.bil_ai_credit_balances where owner_id='" + owner + "')", 'double_refund_debit')))
            return {'stale_event_preserves_newer_state': True, 'newer_refund_debited_once': True}
        check('stale refunds cannot erase a newer reversal or debit twice', reversal)

        def unauthenticated_jwt():
            execute("begin; select set_config('request.jwt.claims','{\"role\":\"authenticated\"}',true); "
                    'select ' + refund_call() + '; rollback;', error='service_role_required')
            return {'security_definer_checks_jwt_role': True}
        check('privileged RPC body rejects a non-service JWT', unauthenticated_jwt)
    finally:
        if created_database:
            execute(f'drop database "{database}";', db='postgres')
        if original_bypass is False:
            execute('alter role service_role nobypassrls;', db='postgres')
        report = {'environment': 'isolated loopback PostgreSQL, synthetic accounts',
                  'production_tested': False, 'cases': cases, 'source_sha256': inputs,
                  'failed': sum(c['result'] == 'FAIL' for c in cases)}
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(out.as_posix(), flush=True)
    assert cases, 'No matching case selected'
    if any(c['result'] == 'FAIL' for c in cases):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
