// Genuine PostgreSQL17 cloud RPC/RLS regression, loopback empty database only.
// The app functions, schema, triggers, key ordering and original policies below
// are extracted unchanged from tracked migrations, not substituted behaviors.
// Auth JWT subject is the sole local gateway emulator; no provider/API traffic.
// PGHOST=127.0.0.1 PGDATABASE=bil_cloud_qa_<suffix> node this-file.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_cloud_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const here = dirname(fileURLToPath(import.meta.url));
const psql = process.env.BIL_QA_PSQL ?? process.env.PSQL_PATH ?? 'psql';
const args = ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'];
function run(sql) {
  const result = spawnSync(psql, args, {
    cwd: here, env: process.env, input: sql, encoding: 'utf8', timeout: 30000,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Isolated cloud SQL failed\n' + result.stderr);
  return result.stdout.trim();
}
function source(file) {
  return readFileSync(resolve(here, '../../supabase/migrations', file), 'utf8');
}
function exactFunction(file, name) {
  const match = source(file).match(new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+public\\.' +
    name + '\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;', 'i'));
  if (!match) throw new Error('Missing exact historical function: ' + name);
  return match[0].replaceAll('\r\n', '\n');
}
assert.equal(Number(run("select current_setting('server_version_num')::integer/10000;")), 17);
assert.equal(run("select count(*) from pg_tables where schemaname in('public','private','auth');"), '0');
const owner = '11111111-1111-4111-8111-111111111111';
const foreign = '22222222-2222-4222-8222-222222222222';
const device = 'cloud-qa-device-0001';
const auth = (id = owner) => "set local role authenticated; select set_config('request.jwt.claim.sub','" + id + "',true);";
const operation = (id, recordId = id, extra = {}) => JSON.stringify([{
  operation_id: id, mutation: 'upsert', record: {
    entity_kind: 'weight', record_id: recordId, revision_device_id: device,
    revision_sequence: 1, updated_at: '2026-10-04T00:00:00Z', deleted_at: null,
    schema_version: 1, payload: { fixture: 'synthetic-encrypted-envelope' }, ...extra,
  },
}]);
const sync = (id, recordId = id, extra = {}) =>
  "select public.bil_sync_records('" + device + "',0,'" + operation(id, recordId, extra) + "'::jsonb);";
const receipt = (version, granted) =>
  "select public.bil_record_consent('cloud_sync','" + version + "'," + granted + ');';

// Actual historical foundation + additive compatibility + latest RPC. The
// table order/constraints, touch trigger and owner ACLs match live catalog.
const foundation = source('202608020001_bil_cloud_foundation.sql');
const ledger = source('202608100002_bil_cloud_ledger_sync.sql');
const repair = source('202608130001_bil_remote_schema_lint_repair.sql')
  .split('create or replace function public.bil_register_push_token')[0] + '\ncommit;';
const consentTable = source('202608040003_bil_security_privacy_closure.sql')
  .match(/create table if not exists public\.bil_consent_receipts[\s\S]*?\n\);/i)[0];
const optimization = source('20260930014110_bil_rls_auth_initplan_optimization.sql');
const relevantPolicies = [...optimization.matchAll(/alter policy\s+(?:bil_consent_receipts_own_read|bil_cloud_[A-Za-z0-9_]+)[\s\S]*?;/gi)]
  .map(match => match[0]).join('\n');
run(`begin;
create schema auth;
create schema private;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable set search_path='' as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
do $roles$ declare r text; begin
 foreach r in array array['anon','authenticated','service_role'] loop
  if not exists(select 1 from pg_roles where rolname=r) then
   execute format('create role %I nologin nosuperuser nobypassrls',r);
  end if;
 end loop;
 if exists(select 1 from pg_roles where rolname in('anon','authenticated') and (rolsuper or rolbypassrls)) then
  raise exception 'ordinary API roles required';
 end if;
end $roles$;
grant usage on schema public,auth to anon,authenticated,service_role;
grant execute on function auth.uid() to anon,authenticated,service_role;
revoke create on schema public from public,anon,authenticated;
commit;
${foundation}
${ledger}
${repair}
begin;
${consentTable}
alter table public.bil_consent_receipts enable row level security;
create policy bil_consent_receipts_own_read on public.bil_consent_receipts
 for select to authenticated using(user_id=auth.uid());
revoke all on public.bil_consent_receipts from public,anon,authenticated,service_role;
grant select on public.bil_consent_receipts to authenticated;
${exactFunction('20260924200207_allow_meal_vision_ai_consent.sql', 'bil_record_consent')}
alter table public.bil_consent_receipts drop constraint bil_consent_receipts_purpose_check;
alter table public.bil_consent_receipts add constraint bil_consent_receipts_purpose_check
 check(purpose in('health','camera','microphone','photos','notifications','devices','remote_ai','cloud_sync','meal_vision_ai'));
revoke all on function public.bil_record_consent(text,text,boolean) from public,anon;
grant execute on function public.bil_record_consent(text,text,boolean) to authenticated,service_role;
${relevantPolicies}
drop policy bil_records_select_own on public.bil_cloud_records;
drop policy bil_records_insert_own on public.bil_cloud_records;
drop policy bil_records_update_own on public.bil_cloud_records;
commit;
${source('20260927064227_cloud_sync_cursor_and_page_hardening.sql')}
begin;
-- The local cluster administrator has a different name from Production's
-- owner. A nonlogin, nonbypass local postgres OWNER reproduces the actual
-- security-definer/table-owner semantics without empowering either API role.
do $owner_role$ begin
 if not exists(select 1 from pg_roles where rolname='postgres') then
  create role postgres nologin nosuperuser nobypassrls;
 end if;
end $owner_role$;
alter schema public owner to postgres;
grant usage on schema auth to postgres;
alter table public.bil_cloud_devices owner to postgres;
alter table public.bil_cloud_records owner to postgres;
alter table public.bil_cloud_operations owner to postgres;
alter table public.bil_consent_receipts owner to postgres;
alter sequence public.bil_cloud_change_sequence owner to postgres;
alter function public.bil_sync_records(text,bigint,jsonb) owner to postgres;
alter function public.bil_record_consent(text,text,boolean) owner to postgres;
alter function public.bil_set_server_updated_at() owner to postgres;
create function public.qa_cloud_assert(value boolean,label text) returns void
 language plpgsql security invoker set search_path='' as $$ begin
 if value is distinct from true then raise exception 'QA cloud assertion: %',label; end if;
end $$;
insert into auth.users(id) values('${owner}'),('${foreign}');
commit;`);
assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_sync_records(text,bigint,jsonb)'::regprocedure;"),
  'd3237c2b3beac0ba7adbdd8f15f3d71f', 'Genuine current LIVE sync body');
assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_record_consent(text,text,boolean)'::regprocedure;"),
  'f24db8e42092990a5d01e16df26ec165', 'Genuine current LIVE consent body');
assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_set_server_updated_at()'::regprocedure;"),
  '45a2952c812f8141f848aebe6b79ef45', 'Genuine current LIVE touch trigger');
assert.equal(run("select has_table_privilege('authenticated','public.bil_cloud_records','SELECT') and not has_table_privilege('authenticated','public.bil_cloud_records','INSERT,UPDATE,DELETE');"), 't');

// BEFORE: ordinary owner uses real authenticated RPC, no receipt, then latest
// explicit denial; both remote writes and record reads are incorrectly allowed.
run(`begin; ${auth()}
select qa_cloud_assert((select count(*)=0 from public.bil_consent_receipts),'no receipt at baseline');
${sync('before-no-consent')}
select qa_cloud_assert((select count(*)=1 from public.bil_cloud_records),'no-consent RPC actually wrote');
${receipt('1', false)}
${sync('before-denied')}
select qa_cloud_assert(jsonb_array_length(public.bil_sync_records('${device}',0,'[]')->'records')=2,'denied RPC returns health envelopes');
select qa_cloud_assert((select count(*)=2 from public.bil_cloud_records),'denied direct SELECT returns health envelopes');
${receipt('other-policy', false)}
${sync('before-latest-denied')}
select qa_cloud_assert((select count(*)=3 from public.bil_cloud_operations),'latest other-version denial still accepts operation');
rollback;`);
console.log('BEFORE_PROVED_PRODUCT_BYPASS: ordinary authenticated no-consent/latest-denied writes, RPC return and direct owner SELECT accepted; transaction rolled back');

function connection(name) {
  const child = spawn(psql, args, {
    cwd: here, env: { ...process.env, PGAPPNAME: 'bil-cloud-' + name },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let stdout = '', stderr = '';
  child.stdout.on('data', chunk => { stdout += chunk.toString(); });
  child.stderr.on('data', chunk => { stderr += chunk.toString(); });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => resolve({ code, stdout, stderr }));
  });
  done.catch(() => {});
  return { child, done, output: () => stdout };
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(predicate, label) {
  const deadline = Date.now() + 5000;
  while (!predicate()) {
    if (Date.now() > deadline) throw new Error('Timeout: ' + label);
    await delay(20);
  }
}
function assertSession(result, error) {
  if (error) {
    assert.notEqual(result.code, 0, 'Expected genuine failed RPC session');
    assert.match(result.stderr, error);
  } else {
    assert.equal(result.code, 0, result.stderr);
  }
}
// Transaction A starts earlier, but its cross-version revoke commits after a
// newer-started grant B. Old now() stamps A older and incorrectly keeps B active.
async function laterRevokeFromEarlierTransaction(before) {
  run(`delete from public.bil_consent_receipts where user_id='${owner}';`);
  const a = connection((before ? 'before' : 'after') + '-old-revoke');
  const deadline = setTimeout(() => a.child.kill(), 12000);
  try {
    a.child.stdin.write(`begin; ${auth()} select 'OLDER_TX_READY';\n`);
    await waitFor(() => a.output().includes('OLDER_TX_READY'), 'earlier transaction started');
    run(`begin; ${auth()} ${receipt('1', true)} commit;`);
    a.child.stdin.end(receipt('other-policy', false) + 'commit;\n');
    assertSession(await a.done);
    const latest = run(`select granted from public.bil_consent_receipts
      where user_id='${owner}' and purpose='cloud_sync'
      order by recorded_at desc,granted asc,policy_version desc limit 1;`);
    assert.equal(latest, before ? 't' : 'f');
    console.log((before ? 'BEFORE_PROVED' : 'PASS') + ': genuine earlier-started/later-committed cross-version revocation timestamp ordering');
  } finally {
    clearTimeout(deadline);
    if (!a.child.killed) a.child.kill();
  }
}
await laterRevokeFromEarlierTransaction(true);
if (process.argv.includes('--before-only')) process.exit(0);

const migration = readFileSync(resolve(here,
  '../../supabase/migrations/20261004171137_cloud_sync_authoritative_consent_boundary_v1.sql'));
console.log('CLOUD_CONSENT_MIGRATION_SHA256:' + createHash('sha256').update(migration).digest('hex'));
const aclSnapshot = `select jsonb_build_object('tables',(select jsonb_agg(jsonb_build_object(
 'name',c.relname,'acl',c.relacl,'owner',c.relowner,'rls',c.relrowsecurity,
 'force_rls',c.relforcerowsecurity) order by c.relname) from pg_class c
 where c.relnamespace='public'::regnamespace and c.relname in
 ('bil_cloud_records','bil_cloud_operations','bil_cloud_devices','bil_consent_receipts')),
 'functions',(select jsonb_agg(jsonb_build_object('name',p.oid::regprocedure::text,
 'acl',p.proacl,'owner',p.proowner,'secdef',p.prosecdef,'config',p.proconfig) order by p.proname)
 from pg_proc p where p.oid in('public.bil_sync_records(text,bigint,jsonb)'::regprocedure,
 'public.bil_record_consent(text,text,boolean)'::regprocedure)));`;
const policiesSnapshot = `select jsonb_agg(to_jsonb(p) order by p.tablename,p.policyname)
 from pg_policies p where p.schemaname='public' and p.tablename in
 ('bil_cloud_records','bil_cloud_operations','bil_cloud_devices','bil_consent_receipts')
 and p.policyname not in('bil_cloud_records_current_consent_select_v1','bil_cloud_operations_current_consent_select_v1');`;
const aclBefore = run(aclSnapshot), policiesBefore = run(policiesSnapshot);
run('begin;\n' + migration.toString('utf8') + '\ncommit;');
const originalSync = exactFunction('20260927064227_cloud_sync_cursor_and_page_hardening.sql', 'bil_sync_records');
const replacementSync = exactFunction('20261004171137_cloud_sync_authoritative_consent_boundary_v1.sql', 'bil_sync_records');
const originalTailMarker = '  if exists (\n    select 1 from public.bil_cloud_devices';
assert.equal(replacementSync.slice(replacementSync.indexOf(originalTailMarker))
  .replace(/\$function\$;\s*$/, () => '$$;'),
  originalSync.slice(originalSync.indexOf(originalTailMarker)),
  'Exact legacy device/mutation/idempotency/cursor/page body unchanged');
assert.equal(run(aclSnapshot), aclBefore, 'No grants/owners/RLS or function privilege expansion');
assert.equal(run(policiesSnapshot), policiesBefore, 'All original policies unchanged');
assert.equal(run(`select count(*) from pg_policy where polname in
 ('bil_cloud_records_current_consent_select_v1','bil_cloud_operations_current_consent_select_v1')
 and not polpermissive and polcmd='r' and polroles=array['authenticated'::regrole::oid];`), '2');

let assertions = 0;
function check(sql, label) {
  const result = run(sql);
  assert.equal(result.split('\n').at(-1), 't', label);
  assertions++;
}
function mustReject(call, message, sqlstate = '42501', id = owner) {
  run(`begin; ${auth(id)} do $reject$ begin
    begin ${call.replace(/^select /, 'perform ')}
      raise exception 'QA expected rejection not received';
    exception when others then
      if sqlstate<>'${sqlstate}' or sqlerrm<>'${message}' then raise; end if;
    end;
  end $reject$; rollback;`);
  assertions++;
}
const countSql = "select jsonb_build_array((select count(*) from public.bil_cloud_devices),(select count(*) from public.bil_cloud_records),(select count(*) from public.bil_cloud_operations));";
run(`delete from public.bil_consent_receipts where user_id='${owner}';`);
const noConsentCounts = run(countSql);
mustReject(sync('after-no-consent'), 'cloud_sync_consent_required');
mustReject(`select public.bil_sync_records('${device}',0,'[]');`, 'cloud_sync_consent_required');
assert.equal(run(countSql), noConsentCounts, 'Denied RPC causes zero device/op/record mutations');
assertions++;
run(`begin; ${auth()} ${receipt('1', true)} ${sync('after-consented')} commit;`);
check(`begin; ${auth()} select count(*)=1 from public.bil_cloud_records; rollback;`, 'Current exact consent allows real owner direct SELECT');
check(`begin; ${auth()} select jsonb_array_length(public.bil_sync_records('${device}',0,'[]')->'records')=1; rollback;`, 'Current consent allows real RPC read');
run(`begin; ${auth(foreign)} ${receipt('1', true)} commit;`);
check(`begin; ${auth(foreign)} select count(*)=0 from public.bil_cloud_records; rollback;`, 'Foreign owner denied records');
check(`begin; ${auth(foreign)} select count(*)=0 from public.bil_cloud_operations; rollback;`, 'Foreign owner denied operation receipts');
check(`begin; ${auth(foreign)} select jsonb_array_length(public.bil_sync_records('${device}',0,'[]')->'records')=0; rollback;`,
  'Consented foreign owner real RPC returns no ownerA records');
run(`begin; ${auth()} ${receipt('1', false)} commit;`);
const deniedCounts = run(countSql);
mustReject(sync('after-denied'), 'cloud_sync_consent_required');
mustReject(`select public.bil_sync_records('${device}',0,'[]');`, 'cloud_sync_consent_required');
check(`begin; ${auth()} select count(*)=0 from public.bil_cloud_records; rollback;`, 'Declined direct SELECT exposes zero payloads');
check(`begin; ${auth()} select count(*)=0 from public.bil_cloud_operations; rollback;`, 'Declined direct operation SELECT exposes zero receipts');
check(`begin; ${auth()} select count(*)=1 from public.bil_cloud_devices; rollback;`, 'Device management read remains available while OFF');
assert.equal(run(countSql), deniedCounts, 'Revoked calls do not touch existing device last_seen or create mutations');
assertions++;
const deviceTime = run(`select last_seen_at from public.bil_cloud_devices where owner_id='${owner}';`);
mustReject(sync('after-denied-replay', 'after-consented'), 'cloud_sync_consent_required');
assert.equal(run(`select last_seen_at from public.bil_cloud_devices where owner_id='${owner}';`), deviceTime);
assertions++;
for (const [version, granted] of [['other-policy', false], ['other-policy', true], ['0', true]]) {
  run(`begin; ${auth()} ${receipt(version, granted)} commit;`);
  mustReject(sync('after-version-' + version), 'cloud_sync_consent_required');
}
run(`begin; ${auth()} select public.bil_record_consent('health','1',true); commit;`);
mustReject(sync('after-unrelated-purpose'), 'cloud_sync_consent_required');
run(`begin; ${auth()} ${receipt('1', true)} commit;`);
// Actual table rows may share a timestamp. Only synthetic receipt timestamps
// are set by the local fixture administrator to exercise deterministic ties.
run(`begin;
 update public.bil_consent_receipts set recorded_at='2026-10-04T12:00:00Z'
 where user_id='${owner}' and purpose='cloud_sync';
 update public.bil_consent_receipts set granted=false
 where user_id='${owner}' and purpose='cloud_sync' and policy_version='other-policy';
commit;`);
mustReject(sync('after-tied-denial'), 'cloud_sync_consent_required');
check(`begin; ${auth()} select count(*)=0 from public.bil_cloud_records; rollback;`, 'Tie denial wins direct read too');
run(`begin; ${auth()} ${receipt('1', true)} commit;`);
const beforeReplay = run(countSql);
check(`begin; ${auth()} select public.bil_sync_records('${device}',0,'${operation('after-consented')}'::jsonb)->'acknowledged'='["after-consented"]'::jsonb; commit;`, 'Original operation idempotency preserved');
assert.equal(run(countSql), beforeReplay);
assertions++;
mustReject("select public.bil_sync_records('short',0,'[]');", 'invalid_device_id', 'P0001');
mustReject(`select public.bil_sync_records('${device}',0,jsonb_build_object('not','array'));`, 'invalid_sync_batch', 'P0001');
mustReject(`select public.bil_sync_records('${device}',0,(select jsonb_agg('{}'::jsonb) from generate_series(1,101)));`, 'invalid_sync_batch', 'P0001');
mustReject(sync('after-wrong-device', undefined, { revision_device_id: 'alien-qa-device' }), 'device_revision_mismatch', 'P0001');
run(`update public.bil_cloud_devices set revoked_at=now() where owner_id='${owner}' and device_id='${device}';`);
mustReject(sync('after-revoked-device'), 'device_revoked', 'P0001');
run(`update public.bil_cloud_devices set revoked_at=null where owner_id='${owner}' and device_id='${device}';`);
mustReject(`select public.bil_sync_records('${device}',0,'[]');`, 'authentication_required', 'P0001', '');
check("select not has_function_privilege('anon','public.bil_sync_records(text,bigint,jsonb)','EXECUTE') and not has_function_privilege('anon','public.bil_record_consent(text,text,boolean)','EXECUTE');", 'Anon RPC execution remains denied');
check("select not has_table_privilege('authenticated','public.bil_cloud_records','INSERT,UPDATE,DELETE') and not has_table_privilege('authenticated','public.bil_cloud_operations','INSERT,UPDATE,DELETE');", 'No direct cloud mutation grant introduced');

// Genuine bounded paging: 205 real RPC operations, all through consent/device
// guards; no rows inserted by a fabricated repository or replaced RPC.
run(`begin; ${auth()}
do $paging$ declare batch jsonb; part integer; begin
 for part in 0..2 loop
  select jsonb_agg(jsonb_build_object('operation_id','page-'||n,'mutation','upsert',
    'record',jsonb_build_object('entity_kind','weight','record_id','page-'||n,
      'revision_device_id','${device}','revision_sequence',1,'updated_at','2026-10-04T00:00:00Z',
      'deleted_at',null,'schema_version',1,'payload',jsonb_build_object('fixture','synthetic'))))
  into batch from generate_series(part*100+1,least(part*100+100,205)) n;
  perform public.bil_sync_records('${device}',0,batch);
 end loop;
end $paging$; commit;`);
run(`begin; ${auth()}
do $pages$ declare page jsonb; cursor_value bigint:=0; total integer:=0; last_cursor bigint; begin
 loop
  page:=public.bil_sync_records('${device}',cursor_value,'[]');
  perform qa_cloud_assert(jsonb_array_length(page->'records')<=100,'page limit100 unchanged');
  total:=total+jsonb_array_length(page->'records');
  last_cursor:=cursor_value; cursor_value:=(page->>'cursor')::bigint;
  perform qa_cloud_assert(cursor_value>last_cursor,'committed cursor progresses');
  exit when not (page->>'has_more')::boolean;
 end loop;
 perform qa_cloud_assert(total=206,'all206 current owner records returned exactly once');
end $pages$; rollback;`);
assertions += 4;
console.log('PASS: ' + assertions + ' strict role/consent/version/tie/mutation/idempotency/device/paging assertions; original ACLs/policies preserved');

async function overlap(kind, firstCall, secondCall, secondError, finalGranted = false) {
  run(`begin; ${auth()} ${receipt('1', true)} commit;`);
  const a = connection(kind + '-A'), b = connection(kind + '-B');
  const deadline = setTimeout(() => { a.child.kill(); b.child.kill(); }, 15000);
  try {
    a.child.stdin.write(`begin; set local statement_timeout='10s'; ${auth()} ${firstCall} select 'FIRST_RPC_READY';\n`);
    await waitFor(() => a.output().includes('FIRST_RPC_READY'), kind + ' first genuine RPC completed');
    b.child.stdin.end(`begin; set local statement_timeout='10s'; ${auth()} ${secondCall} commit;\n`);
    await waitFor(() => Number(run(`select count(*) from pg_locks l join pg_stat_activity a on a.pid=l.pid
      where a.application_name='bil-cloud-${kind}-B' and l.locktype='advisory' and not l.granted;`)) > 0,
      kind + ' second real RPC blocked on shared owner lock');
    a.child.stdin.end('commit;\n');
    const [ra, rb] = await Promise.all([a.done, b.done]);
    assertSession(ra); assertSession(rb, secondError);
    check(`select granted=${finalGranted} from public.bil_consent_receipts where user_id='${owner}' and purpose='cloud_sync'
      order by recorded_at desc,granted asc,policy_version desc limit 1;`, kind + ' final authoritative receipt');
    if (finalGranted) {
      check(`begin; ${auth()} select jsonb_array_length(public.bil_sync_records('${device}',0,'[]')->'records')>0; rollback;`,
        kind + ' explicit later owner grant authorizes reads');
    } else {
      mustReject(`select public.bil_sync_records('${device}',0,'[]');`, 'cloud_sync_consent_required');
    }
    console.log('PASS: real two-session ' + kind + ' shared owner lock and authoritative final state');
  } finally {
    clearTimeout(deadline);
    if (!a.child.killed) a.child.kill();
    if (!b.child.killed) b.child.kill();
  }
}
const raceCounts = run(countSql);
await overlap('revoke-before-sync', receipt('other-policy', false), sync('race-blocked-write'), /cloud_sync_consent_required/);
assert.equal(run(countSql), raceCounts, 'Waiting sync after revoke produces no mutation');
await overlap('sync-before-revoke', sync('race-before-revoke'), receipt('other-policy', false));
assert.equal(Number(JSON.parse(run(countSql))[1]), Number(JSON.parse(raceCounts)[1]) + 1,
  'Sync before revocation commits exactly its one earlier-authorized record');
await overlap('grant-before-revoke', receipt('1', true), receipt('other-policy', false));
await overlap('revoke-before-grant', receipt('other-policy', false), receipt('1', true), undefined, true);
await laterRevokeFromEarlierTransaction(false);
assert.equal(run(aclSnapshot), aclBefore);
assert.equal(run(policiesSnapshot), policiesBefore);
console.log('ISOLATED_PG17_CLOUD_CONSENT_PASS: genuine before bypass + timestamp repro, after strict assertions +5 two-session races; NOT Production apply/device/native/build evidence');
