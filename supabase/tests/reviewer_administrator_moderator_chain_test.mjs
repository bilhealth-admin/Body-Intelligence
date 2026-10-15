// Isolated PostgreSQL/PGlite role-chain regression, with synthetic identities.
// Execute role migrations intact and the verbatim historical reviewer DO block.
// The unrelated privacy functions/policy are excluded; no real Auth/store proof.
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
const mistakenRestore = 'supabase/migrations/20261015090000_restore_single_owner_administrator.sql';
const repair = 'supabase/migrations/20261015230655_restore_owner_approved_secondary_admin_identity_correction.sql';
const reviewerBootstrapPath = 'supabase/migrations/20260906100000_community_moderation_reviewer_and_message_privacy.sql';
const reviewerCleanup = 'supabase/migrations/20261015231333_remove_legacy_store_reviewer_moderator_bootstrap.sql';
const ownerBaseline = 'supabase/migrations/20260905160000_admin_community_access_control.sql';
const tables = [
  ['private.bil_ai_coach_admins', 'supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql'],
  ['public.bil_community_moderators', 'supabase/migrations/202608020004_bil_community_hardening.sql'],
  ['public.bil_entitlements', 'supabase/migrations/202608020003_bil_commerce_foundation.sql'],
  ['public.bil_ai_credit_balances', 'supabase/migrations/20260821080542_ai_coach_unified_weekly_tokens.sql'],
];
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const sha = (value) => createHash('sha256').update(value).digest('hex');
const source = new Map([self, legacy, mistakenRestore, repair, reviewerBootstrapPath, reviewerCleanup, ownerBaseline, ...tables.map(([, path]) => path)]
  .map((path) => [path, read(path)]));
const reviewerBootstrapMatch = source.get(reviewerBootstrapPath).match(/^do \$\$\r?\n[\s\S]*?^\$\$;/m);
assert.ok(reviewerBootstrapMatch, 'Historical reviewer bootstrap DO block must exist');
const reviewerBootstrap = reviewerBootstrapMatch[0];
const normalizedSha = (value) => sha(value.replace(/\r\n/g, '\n'));
const reviewerBootstrapPins = {
  source_lf_sha256: '0622057ac2edf50dd424c83af4ed36ca6dc57115411838913fd0394bee6b8bae',
  block_lf_sha256: 'dc6e30379a2c7093f00a540977d84bfb0eed277563b81fa9fa9c7103d6021dc4',
};
const uid = (n) => `15150000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const actors = {
  owner: uid(1), personalSecondary: uid(2), ordinaryFree: uid(3),
  independentModerator: uid(4), dedicatedReviewer: uid(5), personalPrimary: uid(6),
  historicalInactiveAdmin: uid(7),
};
const emails = {
  owner: 'kademcom@yahoo.com', personalSecondary: 'bilhealth.app@gmail.com',
  ordinaryFree: 'ordinary-free-fixture@example.invalid',
  independentModerator: 'moderator-fixture@example.invalid',
  dedicatedReviewer: 'play-review@bilhealth.com', personalPrimary: 'dr.kadem.nana@gmail.com',
  historicalInactiveAdmin: 'inactive-admin-fixture@example.invalid',
};
const indexName = 'private.bil_ai_coach_single_active_admin_uidx';
const createRestriction = `create unique index bil_ai_coach_single_active_admin_uidx
  on private.bil_ai_coach_admins ((active)) where active;`;
const receipt = resolve(root, 'build/qa/policy-gate-20261015/reviewer-bootstrap-forward-correction/reviewer-administrator-moderator-sql-result.json');
const report = {
  schema: 3,
  classification: 'isolated PostgreSQL/PGlite role-chain execution with synthetic rows',
  command: 'node supabase/tests/reviewer_administrator_moderator_chain_test.mjs',
  source_head: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
  branch: execFileSync('git', ['branch', '--show-current'], { cwd: root, encoding: 'utf8' }).trim(),
  source_files: [...source].map(([path, sql]) => ({ path, sha256: sha(sql) })),
  reviewer_bootstrap: {
    path: reviewerBootstrapPath, first_line: 6, last_line: 24,
    source_sha256: sha(source.get(reviewerBootstrapPath)), block_sha256: sha(reviewerBootstrap),
    pins: reviewerBootstrapPins, pin_normalization: 'CRLF to LF only; executed block is verbatim',
    scope: 'Historical reviewer membership DO block only; unrelated message privacy functions and policy excluded',
  },
  schema_sources: [], tests: [], production_access: false,
  finding: { status: 'NOT_ESTABLISHED', observed_in_isolated_source_chain: false },
  compliance_status: 'NOT_ASSESSED_ISOLATED_ROLE_CHAIN_ONLY',
  limits: [
    'Seven synthetic UUIDs; named emails resolve only projected auth.users(id,email) rows.',
    'The two named personal accounts and the dedicated store reviewer are separate identities.',
    'The personal-primary fixture role is synthetic and does not describe its live authority.',
    'Minimum original table DDL; financial sentinels cover entitlements and token balances only.',
    'Only the verbatim reviewer bootstrap DO block is executed from the mixed September 6 migration.',
    'The unrelated message-privacy functions and policy are not executed or validated here.',
    'No complete migration replay, RLS/RPC authorization, real Auth, store artifact, or reviewer journey.',
    'PGlite serializes queries; multi-session lock contention is not exercised.',
    'No claim about deployment, live accounts, purchases, or overall store compliance.',
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
async function catalog() {
  return {
    indexes: (await db.query(`select schemaname,tablename,indexname,indexdef from pg_indexes
      where schemaname in ('private','public') order by schemaname,tablename,indexname`)).rows,
    relations: (await db.query(`select n.nspname,c.relname,c.relkind,c.relrowsecurity
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('private','public') order by n.nspname,c.relname`)).rows,
    triggers: (await db.query(`select n.nspname,c.relname,t.tgname,pg_get_triggerdef(t.oid) as definition
      from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in ('private','public') and not t.tgisinternal order by n.nspname,c.relname,t.tgname`)).rows,
  };
}
async function snapshot() {
  return { identities: await rows('auth.users', 'id'), authority: await authority(), financial: await financial(), catalog: await catalog() };
}
async function restrictionExists() {
  return (await db.query('select to_regclass($1) is not null as present', [indexName])).rows[0].present;
}
async function rejectTransaction(sql, message) {
  let caught;
  try { await db.exec(sql); } catch (error) { caught = error; }
  finally { await db.exec('rollback'); }
  assert.ok(caught, `Migration must reject: ${message}`);
  assert.equal(caught.code, 'P0001');
  assert.ok(caught.message.includes(message), caught.message);
}
async function email(alias, value) {
  await db.query('update auth.users set email=$1 where id=$2', [value, actors[alias]]);
}
async function active(alias, value) {
  await db.query('update private.bil_ai_coach_admins set active=$1 where user_id=$2', [value, actors[alias]]);
}
async function noRoles(alias) {
  const state = await authority();
  assert.ok(!state.administrators.some((r) => r.user_id === actors[alias]));
  assert.ok(!state.moderators.some((r) => r.user_id === actors[alias]));
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
  await db.exec(`alter table public.bil_community_moderators enable row level security;
    alter table public.bil_entitlements enable row level security;
    alter table public.bil_ai_credit_balances enable row level security; ${createRestriction}`);
  for (const [alias, id] of Object.entries(actors)) {
    await db.query('insert into auth.users(id,email) values($1,$2)', [id, emails[alias]]);
  }
  // The earlier owner migration establishes this provenance before September 6.
  // Seed only that original row; the three migrations under test run in full.
  assert.match(source.get(ownerBaseline), /v_owner_id, true, v_owner_id, 'designated_operational_owner'/);
  await db.query(`insert into private.bil_ai_coach_admins(user_id,active,granted_by,reason,granted_at)
    values($1,true,$1,'designated_operational_owner','2026-08-31T15:15:39Z'),
      ($2,false,$1,'historical_disabled_admin','2026-08-25T09:00:00Z')`, [actors.owner, actors.historicalInactiveAdmin]);
  await db.query('insert into public.bil_community_moderators(user_id) values($1)', [actors.independentModerator]);
  // Pre-existing synthetic paid-right and balance rows, never real receipts.
  await db.query(`insert into public.bil_entitlements(owner_id,entitlement_id,product_id,provider,active,starts_at,expires_at,source_transaction_id)
    values($1,'premium','qa_fixture_premium','apple',true,'2026-01-01T00:00:00Z','2030-01-01T00:00:00Z','synthetic-row-not-a-store-receipt')`, [actors.personalSecondary]);
  for (const [alias, granted, used, reserved] of [
    ['owner', 0, 0, 0], ['personalSecondary', 700, 17, 3], ['ordinaryFree', 0, 0, 0],
    ['independentModerator', 50, 5, 0], ['dedicatedReviewer', 0, 0, 0],
    ['personalPrimary', 9, 1, 0], ['historicalInactiveAdmin', 14, 2, 1],
  ]) await db.query('insert into public.bil_ai_credit_balances(owner_id,granted,used,reserved) values($1,$2,$3,$4)', [actors[alias], granted, used, reserved]);
  const beforeFinancial = await financial();
  const seededBaseline = await snapshot();
  await check('original schemas and seven distinct personal reviewer Free and historical identities', async () => {
    assert.equal((await db.query('select count(*)::integer as n from auth.users')).rows[0].n, 7);
    assert.notEqual(actors.personalSecondary, actors.dedicatedReviewer);
    assert.notEqual(actors.personalPrimary, actors.dedicatedReviewer);
    report.schema_columns = (await db.query(`select table_schema,table_name,column_name,data_type,is_nullable,column_default
      from information_schema.columns where (table_schema,table_name) in
      (('auth','users'),('private','bil_ai_coach_admins'),('public','bil_community_moderators'),
       ('public','bil_entitlements'),('public','bil_ai_credit_balances')) order by table_schema,table_name,ordinal_position`)).rows;
  });
  await check('intact legacy migration grants the approved personal secondary Admin and Moderator', async () => {
    await db.exec(source.get(legacy));
    const state = await authority();
    assert.deepEqual(state.administrators.filter((r) => r.active).map((r) => r.user_id), [actors.owner, actors.personalSecondary]);
    assert.deepEqual(state.moderators.map((r) => r.user_id), [actors.personalSecondary, actors.independentModerator]);
    const secondary = state.administrators.find((r) => r.user_id === actors.personalSecondary);
    assert.equal(secondary.granted_by, actors.owner);
    assert.equal(secondary.reason, 'owner_approved_secondary_administrator');
    await noRoles('dedicatedReviewer');
    assert.deepEqual(await financial(), beforeFinancial);
  });
  const legacyState = await authority();
  await check('legacy migration rerun preserves complete roles provenance and financial rows', async () => {
    await db.exec(source.get(legacy));
    assert.deepEqual(await authority(), legacyState);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  const expectedMistakenState = structuredClone(legacyState);
  expectedMistakenState.administrators.find((r) => r.user_id === actors.personalSecondary).active = false;
  await check('intact mistaken restore disables the personal secondary but preserves its Moderator and provenance', async () => {
    await db.exec(source.get(mistakenRestore));
    assert.deepEqual(await authority(), expectedMistakenState);
    assert.equal(await restrictionExists(), true);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  const mistakenSnapshot = await snapshot();
  await check('historical mistaken restore rerun remains idempotent', async () => {
    await db.exec(source.get(mistakenRestore));
    assert.deepEqual(await snapshot(), mistakenSnapshot);
  });
  await check('historical restrictive index blocks reactivation before the repair', async () => {
    await assert.rejects(active('personalSecondary', true), (error) => error.code === '23505');
    assert.deepEqual(await snapshot(), mistakenSnapshot);
  });
  await check('forward repair restores the complete legacy role snapshot without changing provenance moderators or money', async () => {
    await db.exec(source.get(repair));
    assert.deepEqual(await authority(), legacyState);
    assert.equal(await restrictionExists(), false);
    assert.deepEqual(await financial(), beforeFinancial);
    report.complete_legacy_role_snapshot_restored = true;
  });
  const repairedSnapshot = await snapshot();
  await check('repair rerun with index absent is entirely idempotent', async () => {
    await db.exec(source.get(repair));
    assert.deepEqual(await snapshot(), repairedSnapshot);
  });
  await check('intact legacy mistaken restore and repair replay converges to the same full snapshot', async () => {
    for (const path of [legacy, mistakenRestore, repair]) await db.exec(source.get(path));
    assert.deepEqual(await snapshot(), repairedSnapshot);
  });
  await check('ordinary Free receives no Admin Moderator Premium or token increment', async () => {
    await noRoles('ordinaryFree');
    assert.ok(!beforeFinancial.entitlements.some((r) => r.owner_id === actors.ordinaryFree));
    assert.deepEqual(await financial(), beforeFinancial);
    const balance = (await financial()).tokens.find((r) => r.owner_id === actors.ordinaryFree);
    assert.equal(balance.granted, 0);
    assert.equal(balance.used, 0);
    assert.equal(balance.reserved, 0);
  });
  await check('dedicated reviewer receives neither Admin nor Moderator while personal accounts remain distinct', async () => {
    await noRoles('dedicatedReviewer');
    await noRoles('personalPrimary');
    assert.deepEqual(await snapshot(), repairedSnapshot);
  });
  await check('unique case-insensitive identities restore only the approved secondary', async () => {
    await email('owner', emails.owner.toUpperCase());
    await email('personalSecondary', emails.personalSecondary.toUpperCase());
    try {
      await db.exec(source.get(mistakenRestore));
      await db.exec(source.get(repair));
      assert.deepEqual(await authority(), legacyState);
      assert.deepEqual(await financial(), beforeFinancial);
    } finally {
      await email('owner', emails.owner);
      await email('personalSecondary', emails.personalSecondary);
    }
    assert.deepEqual(await snapshot(), repairedSnapshot);
  });

  // Each fault starts at the actual mistaken migration's result. Snapshot the
  // faulted state too, so rejection must roll back SQL DDL and row changes.
  await db.exec(source.get(mistakenRestore));
  const guardedBaseline = await snapshot();
  async function rejectsFault(name, setup, cleanup, message, path = repair) {
    await check(name, async () => {
      await setup();
      try {
        const faulted = await snapshot();
        await rejectTransaction(source.get(path), message);
        assert.deepEqual(await snapshot(), faulted, 'Rejected migration changed rows or catalog');
        assert.deepEqual(await financial(), beforeFinancial);
      } finally { await cleanup(); }
      assert.deepEqual(await snapshot(), guardedBaseline, 'Fixture failed to return to its baseline');
    });
  }
  for (const alias of ['owner', 'personalSecondary']) {
    await rejectsFault(`repair fails closed atomically when ${alias} identity is missing`,
      () => email(alias, `absent-${alias}@example.invalid`), () => email(alias, emails[alias]),
      'approved_secondary_admin_identity_preflight_failed');
    const duplicate = alias === 'owner' ? uid(91) : uid(92);
    await rejectsFault(`repair fails closed atomically on case-insensitive duplicate ${alias} identities`,
      () => db.query('insert into auth.users(id,email) values($1,$2)', [duplicate, emails[alias].toUpperCase()]),
      () => db.query('delete from auth.users where id=$1', [duplicate]),
      'approved_secondary_admin_identity_preflight_failed');
  }
  await rejectsFault('repair refuses an inactive designated owner',
    () => active('owner', false), () => active('owner', true), 'approved_secondary_admin_provenance_preflight_failed');
  const secondaryRow = expectedMistakenState.administrators.find((r) => r.user_id === actors.personalSecondary);
  await rejectsFault('repair refuses to invent a missing historical secondary grant',
    () => db.query('delete from private.bil_ai_coach_admins where user_id=$1', [actors.personalSecondary]),
    () => db.query(`insert into private.bil_ai_coach_admins(user_id,active,granted_at,granted_by,reason)
      values($1,$2,$3,$4,$5)`, [secondaryRow.user_id, secondaryRow.active, secondaryRow.granted_at, secondaryRow.granted_by, secondaryRow.reason]),
    'approved_secondary_admin_provenance_preflight_failed');
  for (const grantor of [actors.ordinaryFree, null]) {
    await rejectsFault(`repair rejects ${grantor === null ? 'missing' : 'wrong'} owner grant provenance`,
      () => db.query('update private.bil_ai_coach_admins set granted_by=$1 where user_id=$2', [grantor, actors.personalSecondary]),
      () => db.query('update private.bil_ai_coach_admins set granted_by=$1 where user_id=$2', [actors.owner, actors.personalSecondary]),
      'approved_secondary_admin_provenance_preflight_failed');
  }
  await rejectsFault('repair rejects a changed secondary approval reason',
    () => db.query('update private.bil_ai_coach_admins set reason=$1 where user_id=$2', ['not_owner_approved', actors.personalSecondary]),
    () => db.query('update private.bil_ai_coach_admins set reason=$1 where user_id=$2', [secondaryRow.reason, actors.personalSecondary]),
    'approved_secondary_admin_provenance_preflight_failed');
  await rejectsFault('repair refuses an unexpected third active administrator', async () => {
    await db.exec(`drop index ${indexName}`);
    await active('historicalInactiveAdmin', true);
  }, async () => {
    await active('historicalInactiveAdmin', false);
    await db.exec(createRestriction);
  }, 'approved_secondary_admin_provenance_preflight_failed');

  for (const [label, definition] of [
    ['nonunique', 'create index bil_ai_coach_single_active_admin_uidx on private.bil_ai_coach_admins (active) where active'],
    ['wrong key', 'create unique index bil_ai_coach_single_active_admin_uidx on private.bil_ai_coach_admins (user_id) where active'],
    ['expression key', 'create unique index bil_ai_coach_single_active_admin_uidx on private.bil_ai_coach_admins ((not active)) where active'],
    ['changed predicate', 'create unique index bil_ai_coach_single_active_admin_uidx on private.bil_ai_coach_admins (active) where active is true'],
    ['included column', 'create unique index bil_ai_coach_single_active_admin_uidx on private.bil_ai_coach_admins (active) include (user_id) where active'],
  ]) {
    await rejectsFault(`repair fails closed atomically on ${label} index drift`,
      () => db.exec(`drop index ${indexName}; ${definition};`),
      () => db.exec(`drop index ${indexName}; ${createRestriction}`),
      'approved_secondary_admin_index_preflight_failed');
  }
  await rejectsFault('repair rejects a same-named index attached to a different table',
    () => db.exec(`drop index ${indexName}; create table private.qa_wrong_index_target(active boolean);
      create unique index bil_ai_coach_single_active_admin_uidx on private.qa_wrong_index_target (active) where active;`),
    () => db.exec(`drop table private.qa_wrong_index_target; ${createRestriction}`),
    'approved_secondary_admin_index_preflight_failed');
  await rejectsFault('repair rejects a same-named non-index relation without deleting it',
    () => db.exec(`drop index ${indexName}; create table ${indexName}(id integer);`),
    () => db.exec(`drop table ${indexName}; ${createRestriction}`),
    'approved_secondary_admin_index_preflight_failed');
  await rejectsFault('failure after dropping the index rolls back the drop and secondary activation',
    () => db.exec(`create function private.qa_block_secondary_reactivation() returns trigger language plpgsql as $fault$
      begin if old.user_id='${actors.personalSecondary}'::uuid and not old.active and new.active then
        raise exception 'qa_secondary_update_forced_failure'; end if; return new; end $fault$;
      create trigger qa_block_secondary_reactivation before update of active on private.bil_ai_coach_admins
        for each row execute function private.qa_block_secondary_reactivation();`),
    () => db.exec('drop trigger qa_block_secondary_reactivation on private.bil_ai_coach_admins; drop function private.qa_block_secondary_reactivation();'),
    'qa_secondary_update_forced_failure');
  for (const [path, message] of [[legacy, 'secondary_administrator_preflight_failed'],
    [mistakenRestore, 'single_owner_administrator_preflight_failed']]) {
    await rejectsFault(`${path.split('/').at(-1)} retains its original missing-owner rejection`,
      () => email('owner', 'absent-owner@example.invalid'), () => email('owner', emails.owner), message, path);
  }
  await check('final repair returns to the exact legacy roles and unchanged financial sentinels after every rejection', async () => {
    await db.exec(source.get(repair));
    assert.deepEqual(await snapshot(), repairedSnapshot);
    await noRoles('ordinaryFree');
    await noRoles('dedicatedReviewer');
    report.entitlements_and_tokens_unchanged = true;
  });
  report.original_secondary_chain_checks = report.tests.length;
  assert.equal(report.original_secondary_chain_checks, 33);

  // Restore the pre-legacy synthetic authority fixture, then replay the actual
  // reviewer bootstrap before the personal-secondary migrations in source order.
  async function restoreModerators(saved) {
    await db.exec('delete from public.bil_community_moderators;');
    for (const row of saved) await db.query('insert into public.bil_community_moderators(user_id,created_at) values($1,$2)', [row.user_id, row.created_at]);
  }
  let canonicalLegacyState;
  let canonicalReviewerRow;
  let canonicalCorrectedSnapshot;
  await check('pinned historical reviewer bootstrap DO block executes verbatim on the pre-legacy fixture', async () => {
    assert.equal(normalizedSha(source.get(reviewerBootstrapPath)), reviewerBootstrapPins.source_lf_sha256);
    assert.equal(normalizedSha(reviewerBootstrap), reviewerBootstrapPins.block_lf_sha256);
    assert.equal(source.get(reviewerBootstrapPath).slice(0, reviewerBootstrapMatch.index).split('\n').length, 6);
    assert.equal(reviewerBootstrap.split('\n').length, 19);
    await restoreModerators(seededBaseline.authority.moderators);
    await db.exec('delete from private.bil_ai_coach_admins;');
    for (const row of seededBaseline.authority.administrators) await db.query(`insert into private.bil_ai_coach_admins
      (user_id,active,granted_at,granted_by,reason) values($1,$2,$3,$4,$5)`, [row.user_id, row.active, row.granted_at, row.granted_by, row.reason]);
    await db.exec(createRestriction);
    assert.deepEqual(await snapshot(), seededBaseline);
    await db.exec(reviewerBootstrap);
    const state = await authority();
    canonicalReviewerRow = state.moderators.find((row) => row.user_id === actors.dedicatedReviewer);
    assert.ok(canonicalReviewerRow, 'The historical bootstrap really grants the dedicated reviewer Moderator');
    assert.deepEqual(state.administrators, seededBaseline.authority.administrators);
    assert.deepEqual(state.moderators.filter((row) => row.user_id !== actors.dedicatedReviewer), seededBaseline.authority.moderators);
    assert.deepEqual(await financial(), beforeFinancial);
    report.reviewer_moderator_bootstrap_reproduced = true;
  });
  await check('canonical legacy secondary grant preserves the actual reviewer bootstrap and unrelated Moderator', async () => {
    await db.exec(source.get(legacy));
    canonicalLegacyState = await authority();
    assert.deepEqual(canonicalLegacyState.administrators.filter((row) => row.active).map((row) => row.user_id), [actors.owner, actors.personalSecondary]);
    assert.deepEqual(canonicalLegacyState.moderators.map((row) => row.user_id), [actors.personalSecondary, actors.independentModerator, actors.dedicatedReviewer]);
    assert.deepEqual(canonicalLegacyState.moderators.find((row) => row.user_id === actors.dedicatedReviewer), canonicalReviewerRow);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  await check('canonical mistaken restore then personal repair restores every legacy role and provenance with reviewer still Moderator', async () => {
    await db.exec(source.get(mistakenRestore));
    const disabled = structuredClone(canonicalLegacyState);
    disabled.administrators.find((row) => row.user_id === actors.personalSecondary).active = false;
    assert.deepEqual(await authority(), disabled);
    await db.exec(source.get(repair));
    assert.deepEqual(await authority(), canonicalLegacyState);
    assert.deepEqual(await financial(), beforeFinancial);
  });
  await check('forward reviewer cleanup removes only the actual dedicated reviewer and preserves both legitimate personal authorities', async () => {
    const expected = structuredClone(canonicalLegacyState);
    expected.moderators = expected.moderators.filter((row) => row.user_id !== actors.dedicatedReviewer);
    await db.exec(source.get(reviewerCleanup));
    assert.deepEqual(await authority(), expected);
    await noRoles('dedicatedReviewer');
    await noRoles('ordinaryFree');
    assert.deepEqual(await financial(), beforeFinancial);
    canonicalCorrectedSnapshot = await snapshot();
    report.reviewer_cleanup_removed_only_bootstrapped_membership = true;
    report.executed_role_chain = [reviewerBootstrapPath + ':DO-only', legacy, mistakenRestore, repair, reviewerCleanup];
  });
  await check('forward reviewer cleanup rerun is entirely idempotent', async () => {
    await db.exec(source.get(reviewerCleanup));
    assert.deepEqual(await snapshot(), canonicalCorrectedSnapshot);
  });
  await check('already-absent reviewer fixture is a no-op matching the reported live role shape only', async () => {
    await restoreModerators(canonicalLegacyState.moderators);
    await db.query('delete from public.bil_community_moderators where user_id=$1', [actors.dedicatedReviewer]);
    const before = await snapshot();
    await db.exec(source.get(reviewerCleanup));
    assert.deepEqual(await snapshot(), before);
    assert.deepEqual(before, canonicalCorrectedSnapshot);
    report.already_absent_reviewer_noop = true;
  });
  async function rejectsCleanupFault(name, setup, cleanup, message) {
    await check(name, async () => {
      const before = await snapshot();
      await setup();
      try {
        const faulted = await snapshot();
        await rejectTransaction(source.get(reviewerCleanup), message);
        assert.deepEqual(await snapshot(), faulted, 'Rejected reviewer cleanup changed rows or catalog');
        assert.deepEqual(await financial(), beforeFinancial);
      } finally { await cleanup(); }
      assert.deepEqual(await snapshot(), before, 'Reviewer fixture failed to return to its baseline');
    });
  }
  await rejectsCleanupFault('reviewer cleanup fails closed atomically when the actual reviewer identity is missing',
    () => email('dedicatedReviewer', 'absent-reviewer@example.invalid'),
    () => email('dedicatedReviewer', emails.dedicatedReviewer),
    'store_reviewer_moderator_identity_preflight_failed');
  await rejectsCleanupFault('reviewer cleanup fails closed atomically on duplicate actual-reviewer identities',
    () => db.query('insert into auth.users(id,email) values($1,$2)', [uid(93), emails.dedicatedReviewer.toUpperCase()]),
    () => db.query('delete from auth.users where id=$1', [uid(93)]),
    'store_reviewer_moderator_identity_preflight_failed');
  await rejectsCleanupFault('reviewer cleanup protects an active Admin target and leaves its Moderator membership unchanged', async () => {
    await db.query('insert into public.bil_community_moderators(user_id,created_at) values($1,$2)', [canonicalReviewerRow.user_id, canonicalReviewerRow.created_at]);
    await db.query(`insert into private.bil_ai_coach_admins(user_id,active,granted_by,reason)
      values($1,true,$2,'synthetic_protected_target')`, [actors.dedicatedReviewer, actors.owner]);
  }, async () => {
    await db.query('delete from private.bil_ai_coach_admins where user_id=$1', [actors.dedicatedReviewer]);
    await restoreModerators(canonicalCorrectedSnapshot.authority.moderators);
  }, 'store_reviewer_moderator_protected_identity');
  await rejectsCleanupFault('reviewer cleanup refuses the last Moderator and rolls back the entire transaction',
    () => restoreModerators([canonicalReviewerRow]),
    () => restoreModerators(canonicalCorrectedSnapshot.authority.moderators),
    'community_moderation_preflight_failed');
  await check('case-insensitive unique reviewer cleanup preserves full personal provenance and all financial sentinels', async () => {
    await email('dedicatedReviewer', emails.dedicatedReviewer.toUpperCase());
    await db.query('insert into public.bil_community_moderators(user_id,created_at) values($1,$2)', [canonicalReviewerRow.user_id, canonicalReviewerRow.created_at]);
    try { await db.exec(source.get(reviewerCleanup)); }
    finally { await email('dedicatedReviewer', emails.dedicatedReviewer); }
    assert.deepEqual(await snapshot(), canonicalCorrectedSnapshot);
    await noRoles('dedicatedReviewer');
    await noRoles('ordinaryFree');
  });
  const finalAuthority = await authority();
  report.roles_after_chain = Object.entries(actors).map(([alias, id]) => ({
    alias, fake_uuid: id,
    administrator_active: finalAuthority.administrators.some((r) => r.user_id === id && r.active),
    moderator_member: finalAuthority.moderators.some((r) => r.user_id === id),
    preexisting_synthetic_premium: beforeFinancial.entitlements.some((r) => r.owner_id === id && r.active),
  }));
  report.final_counts = {
    auth_users: (await db.query('select count(*)::integer as n from auth.users')).rows[0].n,
    administrator_history: finalAuthority.administrators.length,
    active_administrators: finalAuthority.administrators.filter((r) => r.active).length,
    moderators: finalAuthority.moderators.length,
    entitlements: beforeFinancial.entitlements.length, token_balances: beforeFinancial.tokens.length,
  };
  report.finding = {
    status: 'HISTORICAL_REVIEWER_BOOTSTRAP_REPRODUCED_AND_REMOVED_IN_ISOLATED_CHAIN',
    observed_in_isolated_source_chain: true,
    personal_secondary_admin_active: true, personal_secondary_moderator_preserved: true,
    dedicated_reviewer_admin_active: false, dedicated_reviewer_moderator_member: false,
    historical_roles_and_grant_provenance_preserved: true,
  };
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
