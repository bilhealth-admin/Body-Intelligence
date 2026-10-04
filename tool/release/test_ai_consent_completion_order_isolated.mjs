// Genuine PG17 receipt-completion regression. No Flutter/native/provider build.
// PGHOST=127.0.0.1 PGDATABASE=bil_ai_consent_qa_<suffix> node this-file.mjs
// All production functions are loaded verbatim from tracked source. Auth UID
// is the local JWT-subject emulator only, NOT an Auth/login/integrity proof.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_ai_consent_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const here = dirname(fileURLToPath(import.meta.url));
const psql = process.env.BIL_QA_PSQL ?? process.env.PSQL_PATH ?? 'psql';
const args = ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'];
function run(sql) {
  const r = spawnSync(psql, args, { cwd: here, env: process.env,
    input: sql, encoding: 'utf8', timeout: 30000 });
  if (r.error) throw r.error;
  if (r.status !== 0) throw new Error('Isolated AI consent SQL failed\n' + r.stderr);
  return r.stdout.trim();
}
function source(file) {
  return readFileSync(resolve(here, '../../supabase/migrations', file), 'utf8');
}
function exactFunction(file, name) {
  const match = source(file).match(new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+public\\.' +
    name + '\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;', 'i'));
  if (!match) throw new Error('Missing genuine source function: ' + name);
  return match[0].replaceAll('\r\n', '\n');
}
assert.equal(run("select current_setting('server_version_num')::integer/10000;"), '17');
assert.equal(run("select count(*) from pg_tables where schemaname in('public','auth','private');"), '0');
const owner = '44444444-4444-4444-8444-444444444444';
const foreign = '55555555-5555-4555-8555-555555555555';
const identity = id => "set local role authenticated;select set_config('request.jwt.claim.sub','" + id + "',true);";
const call = (purpose, version, granted) =>
  "select public.bil_record_consent('" + purpose + "','" + version + "'," + granted + ');';
const authority = id => run(`begin;set local role service_role;
  select public.bil_has_remote_ai_consent('${id}');rollback;`) === 't';
const readback = id => JSON.parse(run(`begin;${identity(id)}
  select public.bil_get_remote_ai_consent();rollback;`).split('\n').at(-1));
const consentTable = source('202608040003_bil_security_privacy_closure.sql')
  .match(/create table if not exists public\.bil_consent_receipts[\s\S]*?\n\);/i)[0];
const repair = source('202608130001_bil_remote_schema_lint_repair.sql')
  .split('create or replace function public.bil_register_push_token')[0] + '\ncommit;';
run(`begin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable set search_path='' as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
do $roles$ declare r text; begin
 foreach r in array array['anon','authenticated','service_role','postgres'] loop
  if not exists(select 1 from pg_roles where rolname=r) then
   execute format('create role %I nologin nosuperuser nobypassrls',r);
  end if;
 end loop;
 if exists(select 1 from pg_roles where rolname in('anon','authenticated') and (rolsuper or rolbypassrls)) then
  raise exception 'Ordinary API roles required';
 end if;
end $roles$;
grant usage on schema public,auth to anon,authenticated,service_role;
grant usage on schema auth to postgres;
grant execute on function auth.uid() to anon,authenticated,service_role,postgres;
revoke create on schema public from public,anon,authenticated;
commit;
${source('202608020001_bil_cloud_foundation.sql')}
${source('202608100002_bil_cloud_ledger_sync.sql')}
${repair}
begin;
${consentTable}
alter table public.bil_consent_receipts enable row level security;
create policy bil_consent_receipts_own_read on public.bil_consent_receipts
 for select to authenticated using(user_id=(select auth.uid()));
alter table public.bil_consent_receipts drop constraint bil_consent_receipts_purpose_check;
alter table public.bil_consent_receipts add constraint bil_consent_receipts_purpose_check
 check(purpose in('health','camera','microphone','photos','notifications','devices','remote_ai','cloud_sync','meal_vision_ai'));
revoke all on public.bil_consent_receipts from public,anon,authenticated,service_role;
grant select on public.bil_consent_receipts to authenticated;
grant select(user_id,purpose,policy_version,granted,recorded_at) on public.bil_consent_receipts to service_role;
${exactFunction('20260924200207_allow_meal_vision_ai_consent.sql', 'bil_record_consent')}
${exactFunction('202609240001_apple_ai_consent_policy_enforcement.sql', 'bil_has_remote_ai_consent')}
${exactFunction('20260820115847_ai_coach_closed_test_feedback_and_consent.sql', 'bil_get_remote_ai_consent')}
alter function public.bil_get_remote_ai_consent() security invoker;
revoke all on function public.bil_record_consent(text,text,boolean) from public,anon;
grant execute on function public.bil_record_consent(text,text,boolean) to authenticated,service_role;
revoke all on function public.bil_has_remote_ai_consent(uuid) from public,anon,authenticated;
grant execute on function public.bil_has_remote_ai_consent(uuid) to service_role;
revoke all on function public.bil_get_remote_ai_consent() from public,anon,service_role;
grant execute on function public.bil_get_remote_ai_consent() to authenticated;
commit;
${source('20260927064227_cloud_sync_cursor_and_page_hardening.sql')}
begin;
alter schema public owner to postgres;
alter table public.bil_consent_receipts owner to postgres;
alter table public.bil_cloud_records owner to postgres;
alter table public.bil_cloud_operations owner to postgres;
alter table public.bil_cloud_devices owner to postgres;
alter function public.bil_record_consent(text,text,boolean) owner to postgres;
alter function public.bil_sync_records(text,bigint,jsonb) owner to postgres;
alter function public.bil_has_remote_ai_consent(uuid) owner to postgres;
alter function public.bil_get_remote_ai_consent() owner to postgres;
insert into auth.users values('${owner}'),('${foreign}');
commit;
begin;
${source('20261004171137_cloud_sync_authoritative_consent_boundary_v1.sql')}
commit;`);
assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_record_consent(text,text,boolean)'::regprocedure;"),
  '7c99240c0acfa473bc2765cee540e609', 'Source-approved POST-cloud writer');
const untouchedReaders = `select jsonb_agg(jsonb_build_object('name',p.proname,'body',md5(p.prosrc),'acl',p.proacl,
 'owner',p.proowner,'config',p.proconfig,'secdef',p.prosecdef) order by p.proname)
 from pg_proc p where p.oid in('public.bil_get_remote_ai_consent()'::regprocedure,
 'public.bil_has_remote_ai_consent(uuid)'::regprocedure);`;
assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_get_remote_ai_consent()'::regprocedure;"), '518c8175d8908dd89e8a5323a5e89d1e');
assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_has_remote_ai_consent(uuid)'::regprocedure;"), '9f6245b81ab1f40e2bb7ddc5d05ff748');
const readersBefore = run(untouchedReaders);
const privilegeSql = `select jsonb_build_object('tables',(select jsonb_agg(jsonb_build_object('name',c.relname,
 'acl',c.relacl,'owner',c.relowner,'rls',c.relrowsecurity) order by c.relname) from pg_class c
 where c.relnamespace='public'::regnamespace and c.relkind='r'),
 'writer',(select jsonb_build_object('acl',p.proacl,'owner',p.proowner,'config',p.proconfig,'secdef',p.prosecdef)
 from pg_proc p where p.oid='public.bil_record_consent(text,text,boolean)'::regprocedure),
 'policies',(select jsonb_agg(to_jsonb(p) order by p.tablename,p.policyname) from pg_policies p where p.schemaname='public'));`;
const privilegesBefore = run(privilegeSql);
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function connection(name) {
  const child = spawn(psql, args, { cwd: here, env: { ...process.env, PGAPPNAME: 'bil-ai-consent-' + name },
    stdio: ['pipe', 'pipe', 'pipe'] });
  let out = '', err = '';
  child.stdout.on('data', c => { out += c; }); child.stderr.on('data', c => { err += c; });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject); child.on('close', code => resolve({ code, out, err }));
  });
  done.catch(() => {});
  return { child, done, output: () => out };
}
async function waitFor(predicate, label) {
  const deadline = Date.now() + 5000;
  while (!predicate()) { if (Date.now() > deadline) throw new Error('Timeout: ' + label); await delay(20); }
}
let checks = 0;
async function race(purpose, refusalVersion, grantVersion, before) {
  run(`delete from public.bil_consent_receipts where user_id='${owner}';
   begin;${identity(owner)}${call(purpose, refusalVersion, true)}commit;`);
  const name = (before ? 'before-' : 'after-') + purpose + '-' + refusalVersion;
  const a = connection(name + '-A'), b = connection(name + '-B');
  const deadline = setTimeout(() => { a.child.kill(); b.child.kill(); }, 12000);
  try {
    a.child.stdin.write(`begin;set local statement_timeout='10s';${identity(owner)}select 'OLDER_TRANSACTION_READY';\n`);
    await waitFor(() => a.output().includes('OLDER_TRANSACTION_READY'), 'older transaction');
    b.child.stdin.write(`begin;set local statement_timeout='10s';${identity(owner)}
      ${call(purpose, refusalVersion, true)}${call(purpose, grantVersion, true)}select 'GRANT_RPC_LOCK_READY';\n`);
    await waitFor(() => b.output().includes('GRANT_RPC_LOCK_READY'), 'genuine grant holds lock');
    a.child.stdin.end(call(purpose, refusalVersion, false) + 'commit;\n');
    await waitFor(() => Number(run(`select count(*) from pg_stat_activity a
      where application_name='bil-ai-consent-${name}-A' and wait_event_type='Lock'
        and array_length(pg_blocking_pids(a.pid),1)>0;`)) > 0, 'genuine refusal blocked by grant');
    const event = run(`select wait_event from pg_stat_activity where application_name='bil-ai-consent-${name}-A';`);
    assert.equal(event, before ? 'transactionid' : 'advisory');
    b.child.stdin.end('commit;\n');
    const [ra, rb] = await Promise.all([a.done, b.done]);
    assert.equal(ra.code, 0, ra.err); assert.equal(rb.code, 0, rb.err);
    const rows = JSON.parse(run(`select jsonb_agg(jsonb_build_object('version',policy_version,'granted',granted,
      'stamp',recorded_at) order by recorded_at desc) from public.bil_consent_receipts
      where user_id='${owner}' and purpose='${purpose}';`));
    assert.equal(rows.find(row => row.version === refusalVersion).granted, false);
    // Vision is its actual SQL selection/version semantics, not an Edge HTTP,
    // provider request or an emulated substitute function. Fixture controller
    // reads synthetic rows; service-role-only Coach authority is the real RPC.
    const allowed = purpose === 'remote_ai' ? authority(owner) :
      run(`select granted and policy_version='1' from public.bil_consent_receipts
       where user_id='${owner}' and purpose='meal_vision_ai' order by recorded_at desc limit 1;`) === 't';
    assert.equal(allowed, before && refusalVersion !== grantVersion);
    if (!before) assert.equal(rows[0].version, refusalVersion);
    checks++;
    console.log((before ? 'BEFORE_PROVED' : 'PASS') + ': ' + purpose + ' refusal' + refusalVersion +
      ' versus grant' + grantVersion + ', real waiting=' + event + ', authority_allowed=' + allowed);
  } finally {
    clearTimeout(deadline); if (!a.child.killed) a.child.kill(); if (!b.child.killed) b.child.kill();
  }
}
await race('remote_ai', '2', '3', true);
await race('meal_vision_ai', '0', '1', true);
const migration = readFileSync(resolve(here,
  '../../supabase/migrations/20261004173646_ai_consent_receipt_completion_order_v1.sql'));
console.log('AI_CONSENT_COMPLETION_MIGRATION_SHA256:' + createHash('sha256').update(migration).digest('hex'));
run('begin;\n' + migration.toString('utf8') + '\ncommit;');
assert.equal(run(untouchedReaders), readersBefore, 'Exact untouched reader bodies/ACL/path/SECDEF'); checks++;
assert.equal(run(privilegeSql), privilegesBefore, 'No table/function privileges/ownership/RLS/policy changes'); checks++;
const cloudWriter = exactFunction('20261004171137_cloud_sync_authoritative_consent_boundary_v1.sql', 'bil_record_consent');
const newWriter = exactFunction('20261004173646_ai_consent_receipt_completion_order_v1.sql', 'bil_record_consent');
const cloudStart = "  if p_purpose = 'cloud_sync' then";
const cloudEnd = '    v_recorded_at := pg_catalog.clock_timestamp();';
assert.equal(newWriter.slice(newWriter.indexOf(cloudStart), newWriter.indexOf(cloudEnd) + cloudEnd.length),
  cloudWriter.slice(cloudWriter.indexOf(cloudStart), cloudWriter.indexOf(cloudEnd) + cloudEnd.length),
  'Exact established cloud lock/timestamp branch preserved'); checks++;
await race('remote_ai', '2', '3', false);
await race('meal_vision_ai', '0', '1', false);
await race('remote_ai', '3', '3', false);
assert.deepEqual(readback(owner), { granted: false, policy_version: '3' }); checks++;
run(`begin;${identity(owner)}do $invalid$ begin
 begin perform public.bil_record_consent('remote_ai',' ',true);
  raise exception 'Expected invalid consent rejection';
 exception when others then if sqlstate<>'P0001' or sqlerrm<>'invalid_consent' then raise; end if; end;
end $invalid$;rollback;`);
assert.equal(authority(owner), false, 'Failed grant does not override decline'); checks++;
run(`begin;${identity(owner)}${call('remote_ai', '3', true)}commit;`);
assert.equal(authority(owner), true); checks++;
assert.deepEqual(readback(owner), { granted: true, policy_version: '3' }); checks++;
assert.deepEqual(readback(foreign), { granted: false, policy_version: '1' }, 'No foreign owner receipt leaks'); checks++;
assert.equal(authority(foreign), false); checks++;
run(`begin;${identity(foreign)}${call('remote_ai', '2', false)}commit;`);
assert.equal(authority(owner), true, 'Foreign denial cannot alter owner consent'); checks++;
run(`begin;${identity(owner)}${call('remote_ai', '4', true)}commit;`);
assert.equal(authority(owner), false, 'Unknown latest version never authorizes policy3'); checks++;
run(`begin;${identity(owner)}${call('remote_ai', '3', true)}commit;`);
assert.equal(authority(owner), true, 'Legitimate current-version regrant restores authorization'); checks++;
run(`begin;${identity(owner)}do $cloud$ begin
 begin perform public.bil_sync_records('ai-consent-cloud-negative',0,'[]');
  raise exception 'Expected cloud consent denial';
 exception when insufficient_privilege then if sqlerrm<>'cloud_sync_consent_required' then raise; end if; end;
end $cloud$;rollback;`);
assert.equal(run('select count(*) from public.bil_cloud_devices;'), '0', 'New writer never bypasses existing cloud guard'); checks++;
assert.equal(run(untouchedReaders), readersBefore); assert.equal(run(privilegeSql), privilegesBefore); checks++;
console.log('ISOLATED_PG17_AI_CONSENT_COMPLETION_PASS: ' + checks +
  ' scoped checks including2 genuine BEFORE and3 AFTER blocked-session races; unchanged readers/cloudbranch/ACLs. NOT Production/Edge/provider/native/build proof.');
