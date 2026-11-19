// In-memory PostgreSQL only. No hosted URL, credentials or production writes.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const relativeRoot = resolve(here, '../..');
const root = existsSync(resolve(relativeRoot, 'pubspec.yaml')) ? relativeRoot
  : 'G:/BIL_Project/worktrees/bil47-android39-review-integration-20261116';
const require = createRequire(resolve(root, 'supabase/tests/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
const purpose = 'meal_vision_nutrition_ai';
const oldMigration = readFileSync(resolve(root, 'supabase/migrations/20261004173646_ai_consent_receipt_completion_order_v1.sql'), 'utf8');
const oldFunction = oldMigration.slice(oldMigration.indexOf('CREATE OR REPLACE FUNCTION public.bil_record_consent('), oldMigration.indexOf('$function$;', oldMigration.indexOf('CREATE OR REPLACE FUNCTION public.bil_record_consent(')) + '$function$;'.length);
const stagedMigrations = resolve(here, 'post/supabase/migrations');
const migrations = existsSync(stagedMigrations) ? stagedMigrations : resolve(root, 'supabase/migrations');
const filename = readdirSync(migrations).find((name) => name.endsWith('_meal_vision_nutrition_estimate_consent_v2.sql'));
assert.ok(filename, 'Use the actual CLI-generated migration filename');
const migration = readFileSync(resolve(migrations, filename), 'utf8');
let passed = 0;
async function check(name, body) { await body(); console.log(`PASS ${++passed} ${name}`); }
async function actor(id, role = 'authenticated') {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id ?? '']);
  await db.exec(`set role ${role}`);
}
async function record(p, version, granted) {
  await db.query('select public.bil_record_consent($1,$2,$3)', [p, version, granted]);
}
async function rows() { return (await db.query('select purpose,policy_version,granted from public.bil_consent_receipts order by purpose,policy_version')).rows; }
async function fails(body, code) {
  let error;
  try { await body(); } catch (caught) { error = caught; }
  assert.ok(error, 'Operation must fail');
  if (code) assert.equal(error.code, code);
}

try {
  await db.exec(`
    create role anon; create role authenticated; create schema auth;
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,public to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;
    create table public.bil_consent_receipts(
      user_id uuid not null, purpose text not null, policy_version text not null,
      granted boolean not null, recorded_at timestamptz not null,
      primary key(user_id,purpose,policy_version),
      constraint bil_consent_receipts_purpose_check check(purpose in(
        'health','camera','microphone','photos','notifications','devices',
        'remote_ai','cloud_sync','meal_vision_ai')));
    alter table public.bil_consent_receipts enable row level security;
    create policy own_receipt on public.bil_consent_receipts for select
      to authenticated using(user_id=auth.uid());
    revoke all on public.bil_consent_receipts from public,anon,authenticated;
    grant select on public.bil_consent_receipts to authenticated;
    ${oldFunction}
    revoke all on function public.bil_record_consent(text,text,boolean) from public,anon;
    grant execute on function public.bil_record_consent(text,text,boolean) to authenticated;
  `);
  const beforeAcl = (await db.query("select proacl::text acl,proconfig,prosecdef,proowner from pg_proc where oid='public.bil_record_consent(text,text,boolean)'::regprocedure")).rows[0];
  if (!process.argv.includes('--baseline')) await db.exec(migration);

  await check('new exact purpose is recorded for the current authenticated owner', async () => {
    await actor(A); await record(purpose, '1', true);
    assert.deepEqual(await rows(), [{ purpose, policy_version: '1', granted: true }]);
  });
  await check('legacy photo consent remains independent, with no inferred grant', async () => {
    assert.equal((await rows()).some((row) => row.purpose === 'meal_vision_ai'), false);
    await record('meal_vision_ai', '1', true);
    assert.equal((await rows()).find((row) => row.purpose === 'meal_vision_ai').granted, true);
  });
  await check('other owner sees no receipts and cannot impersonate owner through direct writes', async () => {
    await actor(B); assert.deepEqual(await rows(), []);
    await fails(() => db.query('insert into public.bil_consent_receipts values($1,$2,$3,true,now())', [A, purpose, '1']), '42501');
    await record(purpose, '1', false);
    assert.deepEqual(await rows(), [{ purpose, policy_version: '1', granted: false }]);
    await actor(A); assert.equal((await rows()).find((row) => row.purpose === purpose).granted, true);
  });
  await check('supplemental refusal does not rewrite or revoke the original photo grant', async () => {
    await record(purpose, '1', false);
    const current = await rows();
    assert.equal(current.find((row) => row.purpose === purpose).granted, false);
    assert.equal(current.find((row) => row.purpose === 'meal_vision_ai').granted, true);
  });
  await check('base photo withdrawal remains authoritative and independent', async () => {
    await record(purpose, '1', true); await record('meal_vision_ai', '1', false);
    const current = await rows();
    assert.equal(current.find((row) => row.purpose === purpose).granted, true);
    assert.equal(current.find((row) => row.purpose === 'meal_vision_ai').granted, false);
  });
  await check('unsupported purposes and invalid policy versions still fail', async () => {
    await fails(() => record('arbitrary_privilege', '1', true), 'P0001');
    await fails(() => record(purpose, '', true), 'P0001');
    assert.equal((await rows()).some((row) => row.purpose === 'arbitrary_privilege'), false);
  });
  await check('anonymous and authenticated-without-owner cannot record consent', async () => {
    await actor(null, 'anon'); await fails(() => record(purpose, '1', true), '42501');
    await actor(null); await fails(() => record(purpose, '1', true), 'P0001');
  });
  await check('existing function ACL, definer ownership and search path stay exact', async () => {
    await db.exec('reset role');
    const after = (await db.query("select proacl::text acl,proconfig,prosecdef,proowner from pg_proc where oid='public.bil_record_consent(text,text,boolean)'::regprocedure")).rows[0];
    assert.deepEqual(after, beforeAcl);
  });
  await check('source guard rejects changed writers and preserves the table constraint', async () => {
    await db.exec(oldFunction.replace('v_recorded_at timestamptz;', 'v_recorded_at timestamptz; -- changed writer'));
    const before = (await db.query("select pg_get_constraintdef(oid) definition from pg_constraint where conrelid='public.bil_consent_receipts'::regclass and conname='bil_consent_receipts_purpose_check'")).rows[0];
    await fails(() => db.exec(migration), '55000');
    await db.exec('rollback');
    const after = (await db.query("select pg_get_constraintdef(oid) definition from pg_constraint where conrelid='public.bil_consent_receipts'::regclass and conname='bil_consent_receipts_purpose_check'")).rows[0];
    assert.deepEqual(after, before);
  });
  console.log(`ALL ${passed} local real-RLS consent cases passed`);
} finally { await db.close(); }
