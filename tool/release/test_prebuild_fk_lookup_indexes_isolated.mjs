// Isolated PostgreSQL17 catalog/index capability proof, not Production latency.
// No app RPCs, real identities, provider traffic, Flutter or app builds.
// PGHOST=127.0.0.1 PGDATABASE=bil_fk_qa_<suffix> node this-file.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_fk_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const here = dirname(fileURLToPath(import.meta.url));
const migrationPath = '../../supabase/migrations/20261004170130_prebuild_remaining_fk_lookup_indexes_v1.sql';
const migration = readFileSync(resolve(here, migrationPath));
console.log('FK_LOOKUP_MIGRATION_SHA256:' + createHash('sha256').update(migration).digest('hex'));
const psql = process.env.BIL_QA_PSQL ?? process.env.PSQL_PATH ?? 'psql';
function run(sql, expectedFailure = false) {
  const result = spawnSync(psql, ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'], {
    input: sql, encoding: 'utf8', env: process.env, cwd: here, timeout: 45000,
  });
  if (result.error) throw result.error;
  if (expectedFailure) {
    assert.notEqual(result.status, 0, 'Expected genuine migration precondition failure');
    assert.match(result.stderr, /55000: fk_lookup_/);
  } else if (result.status !== 0) {
    throw new Error('Isolated FK SQL failed\n' + result.stderr);
  }
  return result.stdout.trim();
}
assert.equal(Number(run("select current_setting('server_version_num')::integer/10000;")), 17);
assert.equal(run("select count(*) from pg_tables where schemaname in ('public','auth','private');"), '0');

// Only index-relevant columns/FKs are reconstructed from current catalog. This
// is NOT a substitute app schema or a behavior mock: no app function is loaded.
// Existing index key order/predicates below are the exact inspected definitions.
run(`begin;
create schema auth;
create table auth.users(id uuid primary key);
do $roles$ declare r text; begin
  foreach r in array array['anon','authenticated','service_role'] loop
    if not exists(select 1 from pg_roles where rolname=r) then
      execute format('create role %I nologin nosuperuser nobypassrls',r);
    end if;
  end loop;
  if exists(select 1 from pg_roles where rolname in('anon','authenticated')
    and (rolsuper or rolbypassrls)) then raise exception 'API role bypass'; end if;
end $roles$;
create table public.bil_account_deletion_requests(id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,status text);
create unique index bil_account_deletion_one_active_per_user
  on public.bil_account_deletion_requests(user_id)
  where status=any(array['pending'::text,'processing'::text]);
create table public.bil_community_food_submissions(id uuid primary key,
  contributor_id uuid not null references auth.users(id) on delete cascade,
  client_food_id text,status text,created_at timestamptz);
create index bil_food_status_idx on public.bil_community_food_submissions(status,created_at desc);
create unique index bil_food_contributor_client_id_uq
  on public.bil_community_food_submissions(contributor_id,client_food_id)
  where client_food_id is not null;
create table public.bil_friendships(id uuid primary key,
  requester_id uuid not null references auth.users(id) on delete cascade,
  addressee_id uuid not null references auth.users(id) on delete cascade,
  status text,created_at timestamptz,unique(requester_id,addressee_id));
create unique index bil_friendships_unordered_pair_idx on public.bil_friendships
  (least(requester_id::text,addressee_id::text),greatest(requester_id::text,addressee_id::text));
create index bil_friendships_incoming_pending_v1_idx on public.bil_friendships(addressee_id,requester_id)
  where status='pending';
create index bil_friendships_requester_accepted_history_idx
  on public.bil_friendships(requester_id,created_at desc,addressee_id desc) where status='accepted';
create index bil_friendships_addressee_accepted_history_idx
  on public.bil_friendships(addressee_id,created_at desc,requester_id desc) where status='accepted';
create table public.bil_messages(id uuid primary key,
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz,read_at timestamptz,deleted_by_recipient_at timestamptz);
create index bil_messages_parties_idx on public.bil_messages(sender_id,recipient_id,created_at desc);
create index bil_messages_recipient_unread_v1_idx on public.bil_messages(recipient_id,sender_id)
  where read_at is null and deleted_by_recipient_at is null;
create table public.bil_push_outbox(id uuid primary key,
  recipient_id uuid not null references auth.users(id) on delete cascade,source_key text);
create unique index bil_push_outbox_recipient_source_uidx on public.bil_push_outbox(recipient_id,source_key)
  where source_key is not null;
create table public.bil_community_referral_attributions(id uuid primary key,
  friendship_id uuid references public.bil_friendships(id));
create index bil_community_referral_friendship_idx on public.bil_community_referral_attributions(friendship_id)
  where friendship_id is not null;
create table public.bil_community_xp_ledger(id bigint primary key,
  reverses_entry_id bigint references public.bil_community_xp_ledger(id));
create unique index bil_community_xp_single_reversal_idx on public.bil_community_xp_ledger(reverses_entry_id)
  where reverses_entry_id is not null;
create table public.bil_gold_ledger(id bigint primary key,
  reverses_entry_id bigint references public.bil_gold_ledger(id));
create unique index bil_gold_ledger_single_reversal_idx on public.bil_gold_ledger(reverses_entry_id)
  where reverses_entry_id is not null;
create table public.bil_social_comment_reports_v2(id uuid primary key,
  reviewed_by uuid references auth.users(id));
create index bil_social_reports_reviewer_v2 on public.bil_social_comment_reports_v2(reviewed_by)
  where reviewed_by is not null;
create table public.bil_social_comments_v2(id uuid primary key,
  removed_by uuid references auth.users(id));
create index bil_social_comments_removed_by_v2 on public.bil_social_comments_v2(removed_by)
  where removed_by is not null;
do $rls$ declare t record; begin
 for t in select tablename from pg_tables where schemaname='public' loop
  execute format('alter table public.%I enable row level security',t.tablename);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t.tablename);
 end loop;
end $rls$;
commit;`);
const targets = [
  ['bil_account_deletion_requests', 'user_id', 'bil_account_deletion_user_fk_lookup_idx'],
  ['bil_community_food_submissions', 'contributor_id', 'bil_food_contributor_fk_lookup_idx'],
  ['bil_friendships', 'addressee_id', 'bil_friendships_addressee_fk_lookup_idx'],
  ['bil_messages', 'recipient_id', 'bil_messages_recipient_fk_lookup_idx'],
  ['bil_push_outbox', 'recipient_id', 'bil_push_outbox_recipient_fk_lookup_idx'],
];
const coveredPartials = [
  ['bil_community_referral_attributions', 'friendship_id', 'bil_community_referral_friendship_idx'],
  ['bil_community_xp_ledger', 'reverses_entry_id', 'bil_community_xp_single_reversal_idx'],
  ['bil_gold_ledger', 'reverses_entry_id', 'bil_gold_ledger_single_reversal_idx'],
  ['bil_social_comment_reports_v2', 'reviewed_by', 'bil_social_reports_reviewer_v2'],
  ['bil_social_comments_v2', 'removed_by', 'bil_social_comments_removed_by_v2'],
];
const all = [...targets, ...coveredPartials];
function coverage() {
  return JSON.parse(run(`with targets(table_name,column_name) as (values
    ${all.map(([table, column]) => `('${table}','${column}')`).join(',')})
    select jsonb_agg(jsonb_build_object('table',t.table_name,'column',t.column_name,
      'covered',exists(select 1 from pg_index i join pg_class ci on ci.oid=i.indexrelid
        join pg_am am on am.oid=ci.relam where i.indrelid=a.attrelid and i.indkey[0]=a.attnum
          and i.indisvalid and i.indisready and am.amname='btree'
          and (i.indpred is null or pg_get_expr(i.indpred,i.indrelid)=format('(%I IS NOT NULL)',t.column_name))))
      order by t.table_name,t.column_name)
    from targets t join pg_attribute a on a.attrelid=('public.'||t.table_name)::regclass
      and a.attname=t.column_name and not a.attisdropped;`));
}
const securitySnapshotSql = `select jsonb_agg(jsonb_build_object('table',c.relname,
  'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,'owner',c.relowner,'acl',c.relacl,
  'policies',(select jsonb_agg(to_jsonb(p) order by p.policyname) from pg_policies p
    where p.schemaname='public' and p.tablename=c.relname),
  'constraints',(select jsonb_agg(jsonb_build_object('name',co.conname,'def',pg_get_constraintdef(co.oid))
    order by co.conname) from pg_constraint co where co.conrelid=c.oid)) order by c.relname)
  from pg_class c where c.relnamespace='public'::regnamespace and c.relkind='r';`;
const oldIndexesSql = `select jsonb_agg(jsonb_build_object('name',c.relname,'def',pg_get_indexdef(c.oid))
  order by c.relname) from pg_class c where c.relnamespace='public'::regnamespace and c.relkind='i'
  and c.relname not in (${targets.map(([, , index]) => `'${index}'`).join(',')});`;
const initialCoverage = coverage();
assert.equal(initialCoverage.length, 10);
assert.equal(initialCoverage.filter(row => !row.covered).length, 5);
for (const [table, column] of targets) {
  assert.equal(initialCoverage.find(row => row.table === table && row.column === column)?.covered, false);
}
for (const [table, column] of coveredPartials) {
  assert.equal(initialCoverage.find(row => row.table === table && row.column === column)?.covered, true);
}
console.log('CONFIRMED: exact five unfiltered FK gaps; five IS NOT NULL partials already cover equality');
const securityBefore = run(securitySnapshotSql);
const oldIndexesBefore = run(oldIndexesSql);

// Guard failures use the exact candidate migration inside rolled-back LOCAL
// transactions. Each failure must occur before any candidate index survives.
run(`\\set VERBOSITY verbose
begin; alter table public.bil_messages drop constraint bil_messages_recipient_id_fkey;
${migration.toString('utf8')}
rollback;`, true);
assert.equal(run(securitySnapshotSql), securityBefore, 'Failed guard leaves schema unchanged');
run(`\\set VERBOSITY verbose
begin; create index already_covered_fk_fixture on public.bil_messages(recipient_id);
${migration.toString('utf8')}
rollback;`, true);
assert.equal(run(oldIndexesSql), oldIndexesBefore, 'Already-covered guard rolls back extra index');
run('begin;\n' + migration.toString('utf8') + '\ncommit;');
assert.deepEqual(coverage().map(row => row.covered), Array(10).fill(true));
assert.equal(run(securitySnapshotSql), securityBefore, 'FK constraints/RLS/ACLs/owners unchanged');
assert.equal(run(oldIndexesSql), oldIndexesBefore, 'All historical and partial indexes unchanged');
for (const [table, column, index] of targets) {
  const metadata = JSON.parse(run(`select jsonb_build_object('table',i.indrelid::regclass::text,
    'column',a.attname,'valid',i.indisvalid,'ready',i.indisready,'unique',i.indisunique,
    'keys',i.indnkeyatts,'predicate',pg_get_expr(i.indpred,i.indrelid),
    'expression',pg_get_expr(i.indexprs,i.indrelid),'method',am.amname)
    from pg_index i join pg_class ci on ci.oid=i.indexrelid join pg_am am on am.oid=ci.relam
      join pg_attribute a on a.attrelid=i.indrelid and a.attnum=i.indkey[0]
    where ci.oid='public.${index}'::regclass;`));
  assert.deepEqual(metadata, { table, column, valid: true, ready: true, unique: false,
    keys: 1, predicate: null, expression: null, method: 'btree' });
  // Disabling seqscan proves this index supports the equality lookup; it is not
  // a claim about default cost choices, current Production latency or speedup.
  const plan = JSON.parse(run(`set enable_seqscan=off; explain(format json)
    select 1 from public.${table} where ${column}='00000000-0000-4000-8000-000000000000'::uuid;`));
  assert.match(JSON.stringify(plan), new RegExp(index));
  assert.match(JSON.stringify(plan), /Index Cond/);
}
run('\\set VERBOSITY verbose\nbegin;\n' + migration.toString('utf8') + '\nrollback;', true);
assert.equal(run(securitySnapshotSql), securityBefore);
console.log('ISOLATED_PG17_FK_LOOKUP_PASS: five exact indexes, ten FK coverage checks, three drift/replay guards, immutable original indexes/constraints/RLS/ACLs; NOT Production latency, app/device/build evidence');
