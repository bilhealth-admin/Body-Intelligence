"""Real PostgreSQL/GCM contract slice. Never a complete mobile/store/cloud audit."""
import argparse
import datetime
import hashlib
import json
import pathlib
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--psql', required=True)
parser.add_argument('--pwsh', required=True)
parser.add_argument('--port', type=int, default=55432)
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[2]
stamp = datetime.datetime.now().strftime('%Y%m%d%H%M%S%f')
database = 'bil_qa_cloud_' + stamp
base = [args.psql, '-X', '-qAt', '-P', 'null=null', '-v', 'ON_ERROR_STOP=1',
        '-h', '127.0.0.1', '-p', str(args.port), '-U', 'bil_test_superuser']
out = root / 'build/stage1-closure' / ('postgres-cloud-' + stamp)
out.mkdir(parents=True, exist_ok=False)
records, responses = [], []
owner_a, owner_b = '31000000-0000-4000-8000-000000000001', '31000000-0000-4000-8000-000000000002'
fixture_files = []


def execute(sql, actor=None, db=database, error=None):
    if actor:
        claims = json.dumps({'role': 'authenticated', 'sub': actor})
        sql = ("begin; set local role authenticated; "
               f"select set_config('request.jwt.claims','{claims}',true); "
               f"select set_config('request.jwt.claim.sub','{actor}',true); " + sql + '\ncommit;')
    result = subprocess.run(base + ['-d', db], input=sql, text=True,
                            encoding='utf-8', capture_output=True, timeout=20)
    if error:
        assert result.returncode and error in result.stderr, result.stderr
        return None
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip().splitlines()


def value(sql, actor=None):
    return json.loads(execute(sql, actor=actor)[-1])


def install(relative):
    path = root / relative
    fixture_files.append(path)
    execute(path.read_text(encoding='utf-8'))


def crypto(mode, payload):
    result = subprocess.run([args.pwsh, '-NoProfile', '-File', str(root / 'tools/qa/bil_synthetic_gcm_fixture.ps1'), mode],
                            input=json.dumps(payload, ensure_ascii=False), encoding='utf-8',
                            text=True, capture_output=True, timeout=15)
    assert result.returncode == 0, result.stderr
    return json.loads(result.stdout)


def check(name, run):
    try:
        run()
        records.append({'name': name, 'result': 'PASS'})
        print('PASS: ' + name, flush=True)
    except Exception as failure:
        records.append({'name': name, 'result': 'FAIL', 'error': str(failure)})
        print('FAIL: ' + name + ': ' + str(failure), flush=True)


def sync(operations, actor=owner_a):
    data = json.dumps(operations).replace("'", "''")
    return value(f"select public.bil_sync_records('synthetic-device-01',0,'{data}'::jsonb);", actor)


def roundtrip(client, schema):
    identifier = f'{client}-{schema}'
    # Real AES-256-GCM and the exact persisted v1 envelope. These are synthetic
    # contract values, not a meal calculation or a device-native crypto claim.
    clear = {'recordType': 'mealItem', 'foodName': 'TEST وجبة',
             'nutrients': {f'synthetic{i}': i for i in range(13 if client == '32-35' else 19)},
             'source': 'TEST source', 'quantity': 80, 'unit': 'g'}
    encrypted = crypto('encrypt', clear)
    operation = {'operation_id': identifier, 'mutation': 'upsert', 'record': {
        'entity_kind': 'nutrition', 'record_id': identifier,
        'revision_device_id': 'synthetic-device-01', 'revision_sequence': 1,
        'updated_at': '2026-10-11T00:00:00Z', 'deleted_at': None,
        'schema_version': 1, 'payload': encrypted}}
    response = sync([operation])
    assert set(response) == {'records', 'acknowledged', 'cursor', 'has_more'}
    assert response['acknowledged'] == [identifier]
    row = next(r for r in response['records'] if r['record_id'] == identifier)
    assert row['owner_id'] == owner_a and row['payload'] == encrypted
    assert crypto('decrypt', row['payload']) == clear
    replay = sync([operation])
    assert replay['cursor'] == response['cursor']
    assert len([r for r in replay['records'] if r['record_id'] == identifier]) == 1
    responses.append({'client': client, 'schema': schema, 'operation': operation, 'response': response})


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
    grant usage on schema public,auth to authenticated,anon,service_role;
    """)
    install('supabase/tests/fixtures/cloud_ledger_baseline/schema.sql')
    install('supabase/tests/fixtures/cloud_ledger_baseline/function.sql')
    execute(f"insert into auth.users values('{owner_a}','cloud-a@example.test',null),('{owner_b}','cloud-b@example.test',null);"
            f"insert into public.bil_consent_receipts values('{owner_a}','cloud_sync','1',true,now()),('{owner_b}','cloud_sync','1',true,now());")
    before = execute("select md5(pg_get_functiondef('public.bil_sync_records(text,bigint,jsonb)'::regprocedure));")[-1]
    for client in ['32-35', 'new']:
        check(f'{client} encrypted contract on current catalog schema', lambda c=client: roundtrip(c, 'current'))

    # Apply BOTH actual proposed migrations alongside their real dependency
    # slices, without replacing or editing the deployed cloud RPC.
    install('supabase/tests/fixtures/community_review_baseline/schema.sql')
    install('supabase/tests/fixtures/community_review_baseline/functions.sql')
    install('supabase/tests/fixtures/community_review_baseline/moderator_population.sql')
    install('supabase/tests/fixtures/admin_subscription_baseline/schema.sql')
    install('supabase/tests/fixtures/admin_subscription_baseline/functions.sql')
    install('supabase/migrations/20261011193000_community_review_revision_v2.sql')
    install('supabase/migrations/20261011211500_admin_authority_transaction_lock.sql')
    for client in ['32-35', 'new']:
        check(f'{client} encrypted contract after proposed review/admin migrations', lambda c=client: roundtrip(c, 'proposed'))
    assert execute("select md5(pg_get_functiondef('public.bil_sync_records(text,bigint,jsonb)'::regprocedure));")[-1] == before

    def rls():
        assert value('select count(*) from public.bil_cloud_records;', owner_b) == 0
        assert sync([], owner_b)['records'] == []
        execute("insert into public.bil_cloud_records(owner_id,entity_kind,record_id) values(null,'nutrition','forged');", actor=owner_b, error='permission denied')
    check('real RLS and direct RPC isolate two owners and deny direct ledger writes', rls)

    def consent():
        execute(f"update public.bil_consent_receipts set granted=false,recorded_at=now()+interval '1 second' where user_id='{owner_a}' and purpose='cloud_sync' and policy_version='1';")
        execute("select public.bil_sync_records('synthetic-device-01',0,'[]');", actor=owner_a, error='cloud_sync_consent_required')
        assert value('select count(*) from public.bil_cloud_records;', owner_a) == 0
    check('a newer consent denial blocks both RPC and direct RLS reads', consent)

    def revoked_device():
        execute(f"update public.bil_cloud_devices set revoked_at=now() where owner_id='{owner_b}' and device_id='synthetic-device-01';")
        execute("select public.bil_sync_records('synthetic-device-01',0,'[]');", actor=owner_b, error='device_revoked')
    check('a revoked device cannot silently be registered again', revoked_device)
finally:
    execute(f'drop database if exists "{database}" with (force);', db='postgres')
    (out / 'result.json').write_text(json.dumps({'host': '127.0.0.1', 'database': database,
        'postgres': '17.6', 'cases': records, 'files': {str(p.relative_to(root)):
        hashlib.sha256(p.read_bytes()).hexdigest() for p in fixture_files}}, indent=2), encoding='utf-8')
    (out / 'responses.json').write_text(json.dumps(responses, indent=2, ensure_ascii=False), encoding='utf-8')
    print(str(out / 'result.json'), flush=True)
if len(records) != 7 or any(r['result'] != 'PASS' for r in records):
    raise SystemExit(1)
