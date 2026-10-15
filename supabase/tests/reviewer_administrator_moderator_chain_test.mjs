// PostgreSQL/PGlite memory only. Runs the two original migration files intact.
// Assertions passing reproduce a known role gap; they do NOT certify compliance.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';

const root = fileURLToPath(new URL('../../', import.meta.url));
const self = 'supabase/tests/reviewer_administrator_moderator_chain_test.mjs';
const legacy = 'supabase/migrations/20260906120000_owner_approved_second_administrator.sql';
const restore = 'supabase/migrations/20261015090000_restore_single_owner_administrator.sql';
const tables = [
  ['private.bil_ai_coach_admins', 'supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql'],
  ['public.bil_community_moderators', 'supabase/migrations/202608020004_bil_community_hardening.sql'],
  ['public.bil_entitlements', 'supabase/migrations/202608020003_bil_commerce_foundation.sql'],
  ['public.bil_ai_credit_balances', 'supabase/migrations/20260821080542_ai_coach_unified_weekly_tokens.sql'],
];
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const sha = (value) => createHash('sha256').update(value).digest('hex');
const source = new Map([self, legacy, restore, ...tables.map(([, path]) => path)]
  .map((path) => [path, read(path)]));
const uid = (n) => `15150000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const actors = { owner: uid(1), reviewer: uid(2), ordinaryFree: uid(3), independentModerator: uid(4) };
const receipt = resolve(root, 'build/qa/policy-gate-20261015/reviewer-administrator-moderator-sql-result.json');
const report = {
  schema: 1,
  classification: 'isolated actual PostgreSQL migration execution, synthetic rows; not live/signed/device evidence',
  command: 'node supabase/tests/reviewer_administrator_moderator_chain_test.mjs',
  source_head: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
  branch: execFileSync('git', ['branch', '--show-current'], { cwd: root, encoding: 'utf8' }).trim(),
  source_files: [...source].map(([path, sql]) => ({ path, sha256: sha(sql) })),
  schema_sources: [],
  tests: [],
  finding: { status: 'NOT_ESTABLISHED', observed_in_isolated_source_chain: false },
  compliance_status: 'BLOCKED',
  production_access: false,
  limits: [
    'Four fake UUIDs; known emails resolve only synthetic auth.users rows.',
    'Minimum original table DDL, projected auth.users(id,email), no health data or live accounts.',
    'No complete migration replay, RLS/RPC authorization, store transaction, or real reviewer journey tested.',
    'No claim that either migration was deployed or that any live role matches the fixture.',
    'The wider play-review migration is not executed; this test proves only the bilhealth.app chain.',
  ],
};
const db = new PGlite();
let failed = false;
async function check(name, run) {
  try {
    await run();
    report.tests.push({ name, result: 'PASS' });
    console.log(`SQL_ASSERT_PASS ${report.tests.length}: ${name}`);
  } catch (error) {
    report.tests.push({ name, result: 'FAIL', error: String(error) });
    throw error;
  }
}
async function rows(table, key) {
  return (await db.query(`select to_jsonb(t) as row from ${table} t order by ${key}`)).rows.map((r) => r.row);
}
async function authority() {
  return {
    administrators: await rows('private.bil_ai_coach_admins', 'user_id'),
    moderators: await rows('public.bil_community_moderators', 'user_id'),
  };
}
async function financial() {
  return {
    entitlements: await rows('public.bil_entitlements', 'owner_id, entitlement_id'),
    tokens: await rows('public.bil_ai_credit_balances', 'owner_id'),
  };
}
async function rejectTransaction(sql, message) {
  let caught;
  try { await db.exec(sql); } catch (error) { caught = error; }
  finally { await db.exec('rollback'); }
  assert.ok(caught, 'Original SQL must reject the missing designated owner');
  assert.equal(caught.code, 'P0001');
  assert.ok(caught.message.includes(message));
}
try {
  const installed = JSON.parse(read('supabase/tests/node_modules/@electric-sql/pglite/package.json')).version;
  assert.equal(installed, JSON.parse(read('supabase/tests/package.json')).devDependencies['@electric-sql/pglite']);
  report.engine = { name: 'PGlite', installed_version: installed, storage: 'in-memory; no connection URL' };
  report.engine.postgres = (await db.query('select version() as version')).rows[0].version;
  await db.exec('create schema auth; create schema private; create table auth.users(id uuid primary key, email text);');
  for (const [table, path] of tables) {
    const pattern = new RegExp(`^create table if not exists ${table.replaceAll('.', '\\.')} \\([\\s\\S]*?^\\);`, 'mi');
    const match = source.get(path).match(pattern);
    assert.ok(match, `Original DDL must exist for ${table}`);
    await db.exec(match[0]);
    report.schema_sources.push({ table, path, ddl_sha256: sha(match[0]), line: source.get(path).slice(0, match.index).split('\n').length });
  }
  await db.exec(`
    alter table public.bil_community_moderators enable row level security;
    alter table public.bil_entitlements enable row level security;
    alter table public.bil_ai_credit_balances enable row level security;
    create unique index bil_ai_coach_single_active_admin_uidx on private.bil_ai_coach_admins ((active)) where active;
  `);
  for (const [id, email] of [
    [actors.owner, 'kademcom@yahoo.com'], [actors.reviewer, 'bilhealth.app@gmail.com'],
    [actors.ordinaryFree, 'ordinary-free-fixture@example.invalid'],
    [actors.independentModerator, 'moderator-fixture@example.invalid'],
  ]) await db.query('insert into auth.users(id,email) values($1,$2)', [id, email]);
  await db.query('insert into private.bil_ai_coach_admins(user_id,active,granted_by) values($1,true,$1)', [actors.owner]);
  await db.query('insert into public.bil_community_moderators(user_id) values($1)', [actors.independentModerator]);
  // Pre-existing synthetic Premium sentinel, not a receipt or grant operation.
  await db.query(`insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id)
    values($1,'premium','qa_fixture_premium','apple',true,'2026-01-01T00:00:00Z','2030-01-01T00:00:00Z','synthetic-row-not-a-store-receipt')`, [actors.reviewer]);
  for (const [id, granted, used, reserved] of [
    [actors.owner, 0, 0, 0], [actors.reviewer, 700, 17, 3],
    [actors.ordinaryFree, 0, 0, 0], [actors.independentModerator, 50, 5, 0],
  ]) await db.query('insert into public.bil_ai_credit_balances(owner_id,granted,used,reserved) values($1,$2,$3,$4)', [id, granted, used, reserved]);
  const beforeFinancial = await financial();
  await check('minimum original schemas and exactly four synthetic identities', async () => {
    assert.equal((await db.query('select count(*)::integer as n from auth.users')).rows[0].n, 4);
    report.schema_columns = (await db.query(`select table_schema,table_name,column_name,data_type,is_nullable,column_default
      from information_schema.columns where (table_schema,table_name) in
      (('auth','users'),('private','bil_ai_coach_admins'),('public','bil_community_moderators'),
       ('public','bil_entitlements'),('public','bil_ai_credit_balances')) order by table_schema,table_name,ordinal_position`)).rows;
  });
  await check('original legacy SQL grants secondary Admin and Moderator, preserves money', async () => {
    await db.exec(source.get(legacy));
    const state = await authority();
    assert.deepEqual(state.administrators.filter((r) => r.active).map((r) => r.user_id), [actors.owner, actors.reviewer]);
    assert.deepEqual(state.moderators.map((r) => r.user_id), [actors.reviewer, actors.independentModerator]);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  const legacyState = await authority();
  await check('legacy SQL rerun is idempotent for roles and all financial sentinels', async () => {
    await db.exec(source.get(legacy));
    assert.deepEqual(await authority(), legacyState);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  await check('original restore SQL leaves owner as sole active Admin but reviewer Moderator remains', async () => {
    await db.exec(source.get(restore));
    const state = await authority();
    assert.deepEqual(state.administrators.filter((r) => r.active).map((r) => r.user_id), [actors.owner]);
    assert.equal(state.administrators.find((r) => r.user_id === actors.reviewer).active, false);
    assert.deepEqual(state.moderators, legacyState.moderators);
    assert.deepEqual(await financial(), beforeFinancial);
    report.finding = {
      status: 'P0_BLOCKED_OWNER_APPROVAL_FOR_LIVE_READBACK/CHANGE',
      observed_in_isolated_source_chain: true,
      reviewer_admin_active: false,
      reviewer_moderator_membership_remains: true,
      financial_admin_claimed: false,
      action: 'Owner-authorized least-privilege live readback, then a separately approved exact-UUID role change if an unwanted moderator membership is confirmed. Preserve unrelated moderators and paid rights.',
    };
  });
  const restoredState = await authority();
  await check('ordinary Free acquires no Admin, Moderator, Premium or Tokens', async () => {
    assert.ok(!restoredState.administrators.some((r) => r.user_id === actors.ordinaryFree));
    assert.ok(!restoredState.moderators.some((r) => r.user_id === actors.ordinaryFree));
    const after = await financial();
    assert.ok(!after.entitlements.some((r) => r.owner_id === actors.ordinaryFree));
    assert.deepEqual(after.tokens.find((r) => r.owner_id === actors.ordinaryFree), beforeFinancial.tokens.find((r) => r.owner_id === actors.ordinaryFree));
  });
  await check('actual restored unique index rejects a second active administrator', async () => {
    await assert.rejects(db.query('update private.bil_ai_coach_admins set active=true where user_id=$1', [actors.reviewer]), (error) => error.code === '23505');
    assert.deepEqual(await authority(), restoredState);
  });
  await check('restore SQL rerun is idempotent without revoking bought-right sentinel or balance', async () => {
    await db.exec(source.get(restore));
    assert.deepEqual(await authority(), restoredState);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  await check('replaying original legacy then restore converges to the same owner-only Admin state', async () => {
    await db.exec(source.get(legacy));
    await db.exec(source.get(restore));
    assert.deepEqual(await authority(), restoredState);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  await db.query('update auth.users set email=$1 where id=$2', ['absent-owner-fixture@example.invalid', actors.owner]);
  for (const [path, message] of [[legacy, 'secondary_administrator_preflight_failed'], [restore, 'single_owner_administrator_preflight_failed']]) {
    await check(`${path.split('/').at(-1)} fails closed when owner is absent`, async () => {
      await rejectTransaction(source.get(path), message);
      assert.deepEqual(await authority(), restoredState);
      assert.deepEqual(await financial(), beforeFinancial);
    });
  }
  await db.query('update auth.users set email=$1 where id=$2', ['kademcom@yahoo.com', actors.owner]);
  report.roles_after_chain = Object.entries(actors).map(([alias, id]) => ({
    alias, fake_uuid: id,
    administrator_active: restoredState.administrators.some((r) => r.user_id === id && r.active),
    moderator_member: restoredState.moderators.some((r) => r.user_id === id),
    preexisting_synthetic_premium: beforeFinancial.entitlements.some((r) => r.owner_id === id && r.active),
  }));
  report.final_counts = {
    auth_users: (await db.query('select count(*)::integer as n from auth.users')).rows[0].n,
    administrator_history: restoredState.administrators.length,
    active_administrators: restoredState.administrators.filter((r) => r.active).length,
    moderators: restoredState.moderators.length,
    entitlements: beforeFinancial.entitlements.length, token_balances: beforeFinancial.tokens.length,
  };
  assert.deepEqual(await financial(), beforeFinancial);
  report.entitlements_and_tokens_unchanged = true;
  for (const [path, contents] of source) assert.equal(read(path), contents, `Tested source changed during execution: ${path}`);
} catch (error) {
  failed = true;
  report.execution_error = String(error);
  console.error(error);
} finally {
  await db.close();
  report.recorded_at_utc = new Date().toISOString();
  report.sql_regression_result = failed ? 'FAIL' : 'PASS';
  report.counts = { passed: report.tests.filter((t) => t.result === 'PASS').length, failed: report.tests.filter((t) => t.result === 'FAIL').length, execution_errors: report.execution_error ? 1 : 0 };
  mkdirSync(dirname(receipt), { recursive: true });
  writeFileSync(receipt, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`SQL_REGRESSION_RESULT ${report.sql_regression_result}: ${report.counts.passed} passed, ${report.counts.failed} failed`);
  console.log(`POLICY_FINDING ${report.finding.status}; COMPLIANCE ${report.compliance_status}`);
  console.log(`Receipt: ${receipt}`);
  if (failed) process.exitCode = 1;
}
