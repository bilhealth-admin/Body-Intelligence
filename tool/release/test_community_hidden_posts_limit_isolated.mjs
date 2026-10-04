// Genuine hidden-posts RPC bound proof in an EMPTY loopback PG17 database.
// Auth UID is only a local JWT-subject emulator. No Auth/login, Production,
// native build, moderation-write pipeline or provider/network proof is claimed.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_hidden_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const here = dirname(fileURLToPath(import.meta.url));
const psql = process.env.BIL_QA_PSQL ?? process.env.PSQL_PATH ?? 'psql';
function run(sql) {
  const result = spawnSync(psql, ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], {
    cwd: here, env: process.env, input: sql, encoding: 'utf8', timeout: 30000,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Isolated hidden-posts SQL failed\n' + result.stderr);
  return result.stdout.trim();
}
function exactFunction(sql, name) {
  const match = sql.match(new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+' +
    name.replaceAll('.', '\\.') +
    '\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;', 'i'));
  if (!match) throw new Error('Missing genuine source function: ' + name);
  return match[0].replaceAll('\r\n', '\n');
}
assert.equal(run("select current_setting('server_version_num')::integer/10000;"), '17');
assert.equal(run("select count(*) from pg_tables where schemaname in('public','private','auth','storage');"), '0');
const baseline = readFileSync(resolve(here, 'community_atomic_publish_live_baseline.sql'), 'utf8');
const historical = readFileSync(resolve(here,
  '../../supabase/migrations/20260924223453_community_admin_moderation_visibility.sql'), 'utf8');
const tables = ['private.bil_ai_coach_admins', 'public.bil_community_moderators',
  'public.bil_community_posts', 'public.bil_public_profiles'];
const tableSql = tables.map(name => {
  const table = baseline.match(new RegExp('create table ' + name.replaceAll('.', '\\.') + '\\([\\s\\S]*?\\n\\);', 'i'));
  if (!table) throw new Error('Missing genuine live table: ' + name);
  const constraints = baseline.split(/\r?\n/).filter(line =>
    line.startsWith('alter table ' + name + ' add constraint ')).join('\n');
  return table[0] + '\n' + constraints + '\n' +
    `alter table ${name} owner to postgres;alter table ${name} enable row level security;
    revoke all on ${name} from public,anon,authenticated,service_role;`;
}).join('\n');
// Only the query dependency schema is extracted, with its actual constraints.
// Controller seeds already-moderated rows; no moderation trigger/write proof.
run(`begin;
create schema auth;create schema private;
create table auth.users(id uuid primary key);
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
grant usage on schema public,auth to anon,authenticated,service_role,postgres;
grant usage on schema private to postgres;
${exactFunction(baseline, 'auth.uid')}
grant execute on function auth.uid() to authenticated,postgres;
${tableSql}
${exactFunction(historical, 'private.bil_resolve_community_moderation_authority')}
alter function private.bil_resolve_community_moderation_authority(uuid) owner to postgres;
revoke all on function private.bil_resolve_community_moderation_authority(uuid) from public,anon,authenticated,service_role;
${exactFunction(historical, 'public.bil_list_hidden_community_posts')}
alter function public.bil_list_hidden_community_posts(integer) owner to postgres;
revoke all on function public.bil_list_hidden_community_posts(integer) from public,anon,authenticated,service_role;
grant execute on function public.bil_list_hidden_community_posts(integer) to authenticated;
commit;`);
for (const [signature, expected] of [
  ['public.bil_list_hidden_community_posts(integer)', '7bbe39e1f8484ce8d0282ab6cc805374'],
  ['private.bil_resolve_community_moderation_authority(uuid)', 'fa473bfe2a2a2cba6170f782232b189a'],
]) {
  assert.equal(run(`select md5(pg_get_functiondef('${signature}'::regprocedure));`), expected);
}
const moderator = '66666666-6666-4666-8666-666666666666';
const foreign = '77777777-7777-4777-8777-777777777777';
const query = (id, argument) => `begin;set local role authenticated;
 select set_config('request.jwt.claim.sub','${id}',true);
 select count(*) from public.bil_list_hidden_community_posts(${argument});rollback;`;
function count(id, argument) { return Number(run(query(id, argument)).split('\n').at(-1)); }
function error(id, argument, state, message) {
  run(`begin;set local role authenticated;select set_config('request.jwt.claim.sub','${id}',true);
  do $assert$ declare actual_state text;actual_message text;begin
   begin perform * from public.bil_list_hidden_community_posts(${argument});
   exception when others then get stacked diagnostics actual_state=returned_sqlstate,actual_message=message_text;end;
   if actual_state is distinct from '${state}' or actual_message is distinct from '${message}' then
    raise exception 'Unexpected error: %/%',actual_state,actual_message;
   end if;
  end $assert$;rollback;`);
}
run(`insert into auth.users values('${moderator}'),('${foreign}');
 insert into public.bil_public_profiles(user_id,display_name) values('${moderator}','Local moderator');
 insert into public.bil_community_moderators(user_id) values('${moderator}');
 insert into public.bil_community_posts(author_id,body,moderation_status,moderation_visibility)
 select '${moderator}','Local hidden post '||g,'approved','hidden_by_moderator' from generate_series(1,125) g;
 insert into public.bil_community_posts(author_id,body,moderation_status,moderation_visibility,deleted_at)
 values('${moderator}','Visible exclusion','approved','visible',null),
 ('${moderator}','Deleted exclusion','approved','hidden_by_moderator',now());`);
assert.equal(count(moderator, 'null'), 125);
assert.equal(count(moderator, '100'), 100);
error(foreign, 'null', '42501', 'moderator_or_administrator_required');
console.log('BEFORE_REPRODUCED: authenticated genuine moderator NULL returns125; explicit100 returns100; foreign denied42501');
if (process.env.BIL_HIDDEN_BEFORE_ONLY === '1') {
  console.log('BEFORE_ONLY -- confirmed unbounded NULL, no repair applied');
} else {
  const preserved = run(`select jsonb_build_object('oid',p.oid,'owner',p.proowner,
   'acl',p.proacl,'config',p.proconfig,'default',pg_get_expr(p.proargdefaults,0),
   'table_state',(select jsonb_agg(jsonb_build_object('name',c.oid::regclass::text,
    'owner',c.relowner,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,'acl',c.relacl))
    from pg_class c where c.oid in('public.bil_community_posts'::regclass,'public.bil_public_profiles'::regclass,
    'private.bil_ai_coach_admins'::regclass,'public.bil_community_moderators'::regclass)))
   from pg_proc p where p.oid='public.bil_list_hidden_community_posts(integer)'::regprocedure;`);
  const forward = readFileSync(resolve(here,
    '../../supabase/migrations/20261004175339_community_hidden_posts_null_limit_guard_v1.sql'), 'utf8');
  console.log('HIDDEN_LIMIT_FORWARD_SHA256:' + createHash('sha256').update(forward).digest('hex'));
  run('begin;\n' + forward + '\ncommit;');
  const metadata = run(`select jsonb_build_object('oid',p.oid,'owner',p.proowner,
   'acl',p.proacl,'config',p.proconfig,'default',pg_get_expr(p.proargdefaults,0),
   'table_state',(select jsonb_agg(jsonb_build_object('name',c.oid::regclass::text,
    'owner',c.relowner,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,'acl',c.relacl))
    from pg_class c where c.oid in('public.bil_community_posts'::regclass,'public.bil_public_profiles'::regclass,
    'private.bil_ai_coach_admins'::regclass,'public.bil_community_moderators'::regclass)))
   from pg_proc p where p.oid='public.bil_list_hidden_community_posts(integer)'::regprocedure;`);
  assert.equal(metadata, preserved);
  // The only body delta is NULL rejection, not a query/authority rewrite.
  assert.equal(run("select md5(prosrc) from pg_proc where oid='private.bil_resolve_community_moderation_authority(uuid)'::regprocedure;"),
    'f28b6e4ee92d8aa59f3a5c9f982dfe9d');
  const beforeBody = exactFunction(historical, 'public.bil_list_hidden_community_posts')
    .match(/\bas\s+(\$[A-Za-z0-9_]*\$)([\s\S]*?)\1/i)[2];
  assert.equal(run("select md5(prosrc) from pg_proc where oid='public.bil_list_hidden_community_posts(integer)'::regprocedure;"),
    createHash('md5').update(beforeBody.replace('if p_limit not between 1 and 100 then',
      'if p_limit is null or p_limit not between 1 and 100 then')).digest('hex'));
  error(moderator, 'null', '22023', 'invalid_limit');
  error(moderator, '0', '22023', 'invalid_limit');
  error(moderator, '101', '22023', 'invalid_limit');
  error(foreign, 'null', '42501', 'moderator_or_administrator_required');
  error(foreign, '100', '42501', 'moderator_or_administrator_required');
  error('', '100', '42501', 'moderator_or_administrator_required');
  assert.equal(count(moderator, '1'), 1);
  assert.equal(count(moderator, '100'), 100);
  assert.equal(count(moderator, ''), 100);
  assert.equal(run("select has_function_privilege('anon','public.bil_list_hidden_community_posts(integer)','execute');"), 'f');
  assert.equal(run("select has_table_privilege('authenticated','public.bil_community_posts','select');"), 'f');
  assert.equal(run("select has_function_privilege('authenticated','private.bil_resolve_community_moderation_authority(uuid)','execute');"), 'f');
  console.log('AFTER_PASS: NULL/0/101 rejected22023; valid1/100/default bounded; nonmoderator/anonymous UID denied; ACL/owner/default/path/RLS unchanged');
}
// Fixture identity/row seeding is permanent only inside this disposable DB.
// Remove scoped synthetic rows through owner-controller cleanup, never remote.
run('delete from auth.users;');
assert.equal(run('select count(*) from public.bil_community_posts;'), '0');
assert.equal(run('select count(*) from public.bil_public_profiles;'), '0');
assert.equal(run('select count(*) from public.bil_community_moderators;'), '0');
console.log('ISOLATED_HIDDEN_POSTS_LIMIT_PASS -- exact SQL/ordinary roles only; NOT Production/runtime moderation proof');
