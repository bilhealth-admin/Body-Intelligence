// Disposable PostgreSQL17 regression. No network SDK, Production URI or build.
// Usage: PGHOST=127.0.0.1 PGDATABASE=bil_prebuild_qa_<id> node this-file.mjs
// PGUSER/PGPASSWORD are supplied by the disposable CI PostgreSQL service.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
if (!['127.0.0.1', 'localhost', '::1'].includes(process.env.PGHOST ?? '') ||
    !/^bil_prebuild_qa_[a-z0-9_]+$/.test(process.env.PGDATABASE ?? '')) {
  throw new Error('Refusing non-loopback/non-disposable PostgreSQL target');
}
const psql = process.env.BIL_QA_PSQL ?? 'psql';
const migration = readFileSync(resolve(here,
  '../../supabase/migrations/20261004073453_community_prebuild_privacy_write_hardening_v1.sql'));
console.log('AUDITED_MIGRATION_SHA256:' + createHash('sha256').update(migration).digest('hex'));
const draftConstraintMigration = readFileSync(resolve(here,
  '../../supabase/migrations/20261004131411_community_draft_body_whitespace_contract_v1.sql'));
console.log('DRAFT_CONSTRAINT_MIGRATION_SHA256:' + createHash('sha256').update(draftConstraintMigration).digest('hex'));
const args = ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1'];
function run(sql) {
  const result = spawnSync(psql, args, {
    cwd: here, env: process.env, input: sql, encoding: 'utf8', timeout: 30000,
  });
  if (result.error) throw new Error('psql process failed: ' + result.error.message);
  if (result.status !== 0) {
    throw new Error('isolated SQL failed\n' + result.stderr);
  }
  return result;
}
const version = Number(run("select current_setting('server_version_num');").stdout.trim());
if (version < 170000 || version >= 180000) throw new Error('PostgreSQL17 required');
if (run("select count(*) from pg_tables where schemaname in ('public','private','auth');").stdout.trim() !== '0') {
  throw new Error('Fixture requires an empty disposable database');
}
function exactFunction(file, name) {
  const sql = readFileSync(resolve(here, '../../supabase/migrations', file), 'utf8');
  const qualified = name.includes('.') ? name : 'public.' + name;
  const pattern = new RegExp('create(?:\\s+or\\s+replace)?\\s+function\\s+' +
    qualified.replaceAll('.', '\\.') +
    '\\s*\\([\\s\\S]*?\\bas\\s+(\\$[A-Za-z0-9_]*\\$)[\\s\\S]*?\\1\\s*;', 'i');
  const match = sql.match(pattern);
  if (!match) throw new Error('Exact unchanged function not found: ' + name);
  return match[0];
}
const helpers = [
  exactFunction('20260905160000_admin_community_access_control.sql', 'bil_can_use_community'),
  exactFunction('20260908013800_bil_community_social_v2.sql', 'bil_social_member_visible_v2'),
  exactFunction('20260908013800_bil_community_social_v2.sql', 'bil_social_profile_visible_v2'),
  exactFunction('20260924223453_community_admin_moderation_visibility.sql', 'bil_social_post_visible_v2'),
  exactFunction('20261003141000_community_mention_rate_limit_contract_v1.sql', 'bil_consume_rate_limit'),
  exactFunction('20260908032057_community_policy_v1_activation.sql', 'private.bil_assert_current_community_policy'),
  exactFunction('20260908132433_community_policy_client_status_rpc.sql', 'bil_assert_community_publish_ready'),
  readFileSync(resolve(here, 'community_prebuild_suspend_live_baseline.sql'), 'utf8'),
  'revoke all on function public.bil_suspend_community_member_by_email(uuid,text,text,text) from public,anon,authenticated,service_role;',
  'grant execute on function public.bil_suspend_community_member_by_email(uuid,text,text,text) to service_role;',
  'revoke all on function public.bil_social_member_visible_v2(uuid),public.bil_social_profile_visible_v2(uuid),public.bil_social_post_visible_v2(uuid),private.bil_assert_current_community_policy() from public,anon,authenticated,service_role;',
  'revoke all on function public.bil_can_use_community(),public.bil_consume_rate_limit(text,integer,integer),public.bil_assert_community_publish_ready() from public,anon,authenticated,service_role;',
  'grant execute on function public.bil_can_use_community(),public.bil_consume_rate_limit(text,integer,integer),public.bil_assert_community_publish_ready() to authenticated;',
  'grant execute on function public.bil_consume_rate_limit(text,integer,integer) to service_role;',
].join('\n');
const transports = [
  exactFunction('20261003211000_community_reference_composer_persistence_v1.sql', 'bil_delete_my_community_post_draft_v1'),
  exactFunction('20261003211500_community_draft_work_in_progress_v1.sql', 'bil_consume_my_community_post_draft_v1'),
  exactFunction('20261003110122_community_post_context_location_bridge_v1.sql', 'bil_delete_community_post'),
  'revoke all on function public.bil_delete_my_community_post_draft_v1(uuid) from public,anon,service_role;',
  'grant execute on function public.bil_delete_my_community_post_draft_v1(uuid) to authenticated;',
  'revoke all on function public.bil_consume_my_community_post_draft_v1(uuid,uuid) from public,anon,service_role;',
  'grant execute on function public.bil_consume_my_community_post_draft_v1(uuid,uuid) to authenticated;',
  'revoke all on function public.bil_delete_community_post(uuid) from public,anon,service_role;',
  'grant execute on function public.bil_delete_community_post(uuid) to authenticated;',
].join('\n');
const fixture = readFileSync(resolve(here, 'test_community_prebuild_hardening_isolated.sql'), 'utf8');
if (!fixture.includes('-- PREBUILD_EXACT_TRANSPORT') || !fixture.includes('-- PREBUILD_EXACT_HELPERS') ||
    !fixture.includes('-- PREBUILD_EXACT_DRAFT_BODY_CONSTRAINT_FORWARD')) {
  throw new Error('Missing exact function load marker');
}
// Callback replacements preserve literal SQL dollar quotes. A replacement
// string would interpret $$ as $, corrupting the exact function definition.
const initial = run(fixture.replace('-- PREBUILD_EXACT_HELPERS', () => helpers)
  .replace('-- PREBUILD_EXACT_TRANSPORT', () => transports)
  .replace('-- PREBUILD_EXACT_DRAFT_BODY_CONSTRAINT_FORWARD', () => draftConstraintMigration.toString('utf8')));
process.stdout.write(initial.stderr);
if (!initial.stdout.includes('ISOLATED_FUNCTION_AND_ROLE_ASSERTIONS_PASSED')) throw new Error('Missing SQL completion marker');
console.log('PASS: exact forward migration + ordinary-role privacy/write assertions');

const owner = '11111111-1111-4111-8111-111111111111';
function connection(name) {
  const child = spawn(psql, args, {
    cwd: here, env: { ...process.env, PGAPPNAME: 'bil-prebuild-' + name },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  let stdout = '', stderr = '';
  child.stdout.on('data', chunk => { stdout += chunk.toString(); });
  child.stderr.on('data', chunk => { stderr += chunk.toString(); });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', code => code === 0 ? resolve(stdout) : reject(new Error('Session ' + name + ' failed\n' + stderr)));
  });
  // Install rejection handling before any concurrent polling awaits.
  done.catch(() => {});
  return { child, done, output: () => stdout, errors: () => stderr };
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(predicate, label) {
  const deadline = Date.now() + 5000;
  while (!predicate()) {
    if (Date.now() > deadline) throw new Error('Timeout: ' + label);
    await delay(20);
  }
}
async function overlap(kind, firstCall, secondCall, lockKey, verifySql) {
  const a = connection(kind + '-A');
  const b = connection(kind + '-B');
  const identity = "set local statement_timeout='10s'; set local lock_timeout='10s'; " +
    "set local role authenticated; select set_config('request.jwt.claim.sub','" + owner + "',true);";
  const deadline = setTimeout(() => { a.child.kill(); b.child.kill(); }, 15000);
  try {
    // A remains in its transaction until B is observably waiting for the
    // REAL RPC's advisory lock. No timed pg_sleep/barrier guess.
    a.child.stdin.write('begin; ' + identity +
      'select public.bil_can_use_community();' +
      "select pg_advisory_xact_lock(hashtextextended('" + lockKey + "',0));" +
      firstCall + "select 'QA_A_READY';\n");
    await waitFor(() => a.output().includes('QA_A_READY'), kind + ' first call ready');
    b.child.stdin.end('begin; ' + identity + secondCall + 'commit;\n');
    await waitFor(() => {
      const result = run("select count(*) from pg_locks l join pg_stat_activity a on a.pid=l.pid " +
        "where a.application_name='bil-prebuild-" + kind + "-B' and l.locktype='advisory' and not l.granted;");
      return Number(result.stdout.trim()) > 0;
    }, kind + ' second RPC waits instead of bypassing lock');
    a.child.stdin.end('commit;\n');
    const [outA, outB] = await Promise.all([a.done, b.done]);
    if (kind === 'invite' && (!outA.includes('active') || !outB.includes('rate_limited'))) {
      throw new Error('Concurrent invite outcomes violate cap');
    }
    run(verifySql);
    console.log('PASS: real overlapping ' + kind + ' RPCs serialize under ordinary authenticated role');
  } finally {
    clearTimeout(deadline);
    if (!a.child.killed) a.child.kill();
    if (!b.child.killed) b.child.kill();
  }
}
await overlap('invite',
  "select bil_create_community_invite_v1()->>'status';",
  "select bil_create_community_invite_v1()->>'status';",
  'bil.community.invite.owner:' + owner,
  "select qa_assert((select count(*)=1 from public.bil_community_invites where inviter_id='" + owner + "'),'concurrent daily cap remains exactly one');"
);
await overlap('poll',
  "select bil_vote_community_poll_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',array['dddddddd-dddd-4ddd-8ddd-ddddddddddd1'::uuid]);",
  "select bil_vote_community_poll_v1('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',array['dddddddd-dddd-4ddd-8ddd-ddddddddddd2'::uuid]);",
  'bil.community.poll.vote:aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1:' + owner,
  "select qa_assert((select count(*)=1 and bool_and(option_id='dddddddd-dddd-4ddd-8ddd-ddddddddddd2') from public.bil_community_poll_votes where voter_id='" + owner + "'),'concurrent single-choice replacement is one final option');"
);
// Administrator A holds the genuine member-state guard before the owner
// quota lock. Caller B must wait at authorization, not read an old allowed
// state and resume its INSERT after A's canonical suspension commits.
async function suspensionVersusWaitingInvite() {
  run("delete from public.bil_community_invites where inviter_id='" + owner + "';");
  const a = connection('suspension-A');
  const b = connection('suspension-B');
  const deadline = setTimeout(() => { a.child.kill(); b.child.kill(); }, 15000);
  try {
    a.child.stdin.write("begin; set local statement_timeout='10s'; set local lock_timeout='10s'; " +
      "select pg_advisory_xact_lock(hashtextextended('community_moderator_roster',0)); " +
      "set local role authenticated; select set_config('request.jwt.claim.sub','" + owner + "',true); " +
      "select public.bil_can_use_community(); reset role; set local role service_role; " +
      "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true); " +
      "select pg_advisory_xact_lock(hashtextextended('bil.community.invite.owner:" + owner + "',0)); " +
      "select 'QA_SUSPEND_READY';\n");
    await waitFor(() => a.output().includes('QA_SUSPEND_READY'), 'canonical member guard held');
    b.child.stdin.end("\\set VERBOSITY verbose\nbegin; set local statement_timeout='10s'; set local lock_timeout='10s'; " +
      "set local role authenticated; select set_config('request.jwt.claim.sub','" + owner + "',true); " +
      "select 'QA_INVITE_RESULT:' || (public.bil_create_community_invite_v1()->>'status'); commit;\n");
    await waitFor(() => Number(run("select count(*) from pg_locks l join pg_stat_activity a on a.pid=l.pid " +
      "where a.application_name='bil-prebuild-suspension-B' and l.locktype='advisory' and not l.granted;")
      .stdout.trim()) > 0, 'invite caller observably waiting');
    a.child.stdin.end("select public.bil_suspend_community_member_by_email(" +
      "'66666666-6666-4666-8666-666666666666','fixture-invite-owner@example.invalid'," +
      "'Concurrent fixture suspension','qa_suspend_waiting_invite_v1')->>'matched'; commit;\n");
    await a.done;
    let rejected = false;
    try { await b.done; } catch (error) {
      if (!b.errors().includes('42501: community_access_suspended')) throw error;
      rejected = true;
    }
    if (!rejected) {
      const observed = b.output().match(/QA_INVITE_RESULT:[a-z_]+/)?.[0] ?? 'missing_result';
      throw new Error('PRODUCT DEFECT: canonical suspension committed before waiting invite resumed; ' + observed);
    }
    run("select qa_assert((select suspended from private.bil_community_member_access where user_id='" + owner + "') " +
      "and not exists(select 1 from public.bil_community_invites where inviter_id='" + owner + "') " +
      "and (select count(*)=1 from private.bil_community_member_access_audit where idempotency_key='qa_suspend_waiting_invite_v1')," +
      "'committed canonical suspension rejects waiting invite with zero invite residue');");
    console.log('PASS: genuine administrator suspension serializes waiting ordinary-role invite authorization');
  } finally {
    clearTimeout(deadline);
    if (!a.child.killed) a.child.kill();
    if (!b.child.killed) b.child.kill();
  }
}
await suspensionVersusWaitingInvite();
console.log('ISOLATED_PG17_HARDENING_PASS -- no genuine StoreKit/Play/provider/Production/device boundary tested');

