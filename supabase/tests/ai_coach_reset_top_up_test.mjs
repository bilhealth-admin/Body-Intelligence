// Actual migration/RPC/trigger execution in local in-memory PostgreSQL only.
// Uses the pinned PGlite installation documented in admin_subscription_grants_test.mjs.
// PGlite serializes queries; this proves queued duplicate submissions, not
// contention between independent production database sessions.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const read = (name) => readFileSync(name, 'utf8');
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const fixture = 'supabase/tests/fixtures/admin_subscription_baseline';
const migration = 'supabase/migrations/20260910035353_ai_coach_reset_balance_top_up.sql';
let sequence = 0;
let checks = 0;
const scalar = async (sql, args = []) => (await db.query(sql, args)).rows[0].value;
async function check(name, run) { await run(); console.log(`PASS ${++checks}: ${name}`); }
async function role(name) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify({ role: name, sub: uid(1) })]);
  if (name !== 'postgres') await db.exec(`set role ${name}`);
}
async function reset(owner, key = `reset-balance-request-${++sequence}`) {
  return scalar('select public.bil_individual_reset_ai_coach($1,$2,$3,$4,$5) as value',
    [uid(1), uid(owner), 'Balance refill test', key, 'Your balance has been reviewed.']);
}
async function globalReset() {
  return scalar('select public.bil_global_reset_ai_coach($1,$2,$3) as value',
    [uid(1), `global-balance-request-${++sequence}`, 'Your balance has been reviewed.']);
}
async function balance(owner) {
  await role('postgres');
  return (await db.query('select granted,used,reserved,granted-used as remaining from public.bil_ai_credit_balances where owner_id=$1', [uid(owner)])).rows[0];
}
async function ledger(resetId, owner) {
  await role('postgres');
  return scalar('select tokens as value from private.bil_ai_coach_reset_token_grants where reset_id=$1 and owner_id=$2', [resetId, uid(owner)]);
}

try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema private;
    create table auth.users(id uuid primary key,email text,created_at timestamptz default now(),
      raw_app_meta_data jsonb default '{}',raw_user_meta_data jsonb default '{}');
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    create function auth.uid() returns uuid language sql stable as $$select (auth.jwt()->>'sub')::uuid$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create table public.bil_public_profiles(user_id uuid primary key,locale_code text);
    create table public.bil_push_outbox(recipient_id uuid,category text,title text,body text,deep_link text,created_at timestamptz);
  `);
  await db.exec(read(`${fixture}/tables.sql`));
  for (const name of ['bil_resolve_ai_allowance_plan', 'bil_resolve_ai_trial_anchor', 'bil_has_active_premium']) {
    await db.exec(read(`${fixture}/${name}.sql`));
  }
  await db.exec(read('supabase/migrations/20260831151527_ai_coach_admin_global_individual_reset.sql'));
  await db.exec(read('supabase/migrations/20260904010000_ai_coach_reset_token_grants.sql'));
  for (let n = 1; n <= 8; n++) await db.query('insert into auth.users(id,email) values($1,$2)', [uid(n), `user${n}@example.test`]);
  await db.query('insert into private.bil_ai_coach_admins(user_id) values($1)', [uid(1)]);
  await db.exec("insert into public.bil_ai_credit_config(plan_id,weekly_limit,monthly_limit) values('free',0,0),('trial',1000,1000),('ai_coach',2500,10000)");
  // Actual constraints and a non-empty paid subscription protect the high balance case.
  await db.query(`insert into public.bil_subscriptions(owner_id,provider,product_id,plan_id,lifecycle,original_transaction_id,
    latest_transaction_id,environment,started_at,expires_at,verified_at)
    values($1,'apple','bil_premium_ai_coach','premium_ai_coach','active','paid-receipt','paid-receipt','production',now(),now()+interval '30 days',now())`, [uid(5)]);
  for (const [owner, granted, used, reserved] of [[3,2500,1000,0],[4,2500,0,0],[5,9000,1500,0],[6,2500,1000,400],[7,2500,15,0]]) {
    await db.query('insert into public.bil_ai_credit_balances(owner_id,granted,used,reserved) values($1,$2,$3,$4)', [uid(owner),granted,used,reserved]);
  }
  const beforeStore = (await db.query('select * from public.bil_subscriptions')).rows;
  const beforeConfig = (await db.query('select * from public.bil_ai_credit_config order by plan_id')).rows;
  const beforeBalances = (await db.query('select * from public.bil_ai_credit_balances order by owner_id')).rows;
  await db.exec(read(migration));
  await check('migration neither clamps historical balances nor changes paid subscription/limits', async () => {
    assert.deepEqual((await db.query('select * from public.bil_ai_credit_balances order by owner_id')).rows, beforeBalances);
    assert.deepEqual((await db.query('select * from public.bil_subscriptions')).rows, beforeStore);
    assert.deepEqual((await db.query('select * from public.bil_ai_credit_config order by plan_id')).rows, beforeConfig);
  });
  await check('1,500 remaining is filled to 2,500 by adding exactly 1,000', async () => {
    await role('service_role');
    const result = await reset(3);
    assert.deepEqual(await balance(3), {granted:3500,used:1000,reserved:0,remaining:2500});
    assert.equal(await ledger(result.reset_id,3),1000);
  });
  await check('empty account receives 2,500 once and new reset IDs do not stack', async () => {
    await role('service_role');
    const first = await reset(2);
    const again = await reset(2);
    assert.equal((await balance(2)).remaining,2500);
    assert.equal(await ledger(first.reset_id,2),2500);
    assert.equal(await ledger(again.reset_id,2),0);
  });
  await check('2,485 adds only 15 and a full account adds zero', async () => {
    await role('service_role');
    const partial = await reset(7);
    const full = await reset(4);
    assert.equal((await balance(7)).remaining,2500);
    assert.equal(await ledger(partial.reset_id,7),15);
    assert.equal(await ledger(full.reset_id,4),0);
    assert.equal((await balance(4)).granted,2500);
  });
  await check('balance above 2,500 and purchased subscription are preserved exactly', async () => {
    const before = await balance(5);
    await role('service_role');
    const result = await reset(5);
    assert.deepEqual(await balance(5),before);
    assert.equal(await ledger(result.reset_id,5),0);
    assert.deepEqual((await db.query('select * from public.bil_subscriptions')).rows,beforeStore);
  });
  await check('reserved credit remains owned: release cannot inflate a refilled balance', async () => {
    await role('service_role');
    const result = await reset(6);
    assert.deepEqual(await balance(6), {granted:3500,used:1000,reserved:400,remaining:2500});
    assert.equal(await ledger(result.reset_id,6),1000);
    await db.query('update public.bil_ai_credit_balances set reserved=0 where owner_id=$1',[uid(6)]);
    assert.equal((await balance(6)).remaining,2500);
  });
  await check('replaying the same operation after consumption adds nothing; a new reset fills only the gap', async () => {
    await role('service_role');
    await reset(3,'same-reset-after-spend-000001');
    await role('postgres');
    await db.query('update public.bil_ai_credit_balances set used=used+1000 where owner_id=$1',[uid(3)]);
    await role('service_role');
    assert.equal((await reset(3,'same-reset-after-spend-000001')).duplicate,true);
    assert.equal((await balance(3)).remaining,1500);
    await role('service_role');
    const next = await reset(3);
    assert.equal((await balance(3)).remaining,2500);
    assert.equal(await ledger(next.reset_id,3),1000);
  });
  await check('queued independent reset submissions never multiply the top-up', async () => {
    await role('postgres');
    await db.query('update public.bil_ai_credit_balances set used=used+500 where owner_id=$1',[uid(3)]);
    await role('service_role');
    const results = await Promise.all([reset(3),reset(3),reset(3)]);
    assert.equal((await balance(3)).remaining,2500);
    const tokens = await Promise.all(results.map(r => scalar('select tokens as value from private.bil_ai_coach_reset_token_grants where reset_id=$1',[r.reset_id])));
    assert.equal(tokens.reduce((a,b)=>a+b,0),500);
    assert.match(await scalar("select pg_get_functiondef('private.bil_grant_ai_coach_reset_tokens()'::regprocedure) as value"),/for update/i);
  });
  await check('global reset shares the same top-up rule and preserves period/reservation/paid authority', async () => {
    await role('postgres');
    await db.query('update public.bil_ai_credit_balances set used=used+600 where owner_id=$1',[uid(4)]);
    await db.query(`insert into public.bil_ai_credit_weekly_usage(owner_id,week_start,used,reserved)
      values($1,private.bil_current_ai_week_start($1,now()),300,20)`,[uid(4)]);
    await db.query(`insert into public.bil_ai_credit_monthly_usage(owner_id,month_start,used,reserved)
      values($1,private.bil_current_ai_month_start($1,now()),700,20)`,[uid(4)]);
    const beforeWeek = (await db.query('select * from public.bil_ai_credit_weekly_usage')).rows[0];
    const beforeMonth = (await db.query('select * from public.bil_ai_credit_monthly_usage')).rows[0];
    await role('service_role');
    const result = await globalReset();
    await globalReset();
    assert.equal((await balance(4)).remaining,2500);
    assert.equal(await ledger(result.reset_id,4),600);
    assert.equal((await balance(5)).remaining,7500);
    for (const [table,before,period] of [['bil_ai_credit_weekly_usage',beforeWeek,'week_start'],['bil_ai_credit_monthly_usage',beforeMonth,'month_start']]) {
      const after = (await db.query(`select * from public.${table}`)).rows[0];
      assert.equal(after.used,0); assert.equal(after.reserved,20); assert.deepEqual(after[period],before[period]);
    }
    assert.deepEqual((await db.query('select * from public.bil_subscriptions')).rows,beforeStore);
    assert.deepEqual((await db.query('select * from public.bil_ai_credit_config order by plan_id')).rows,beforeConfig);
  });
  await check('credit mutation and private grant ledger remain unavailable to application roles', async () => {
    await role('postgres');
    assert.equal(await scalar("select relrowsecurity as value from pg_class where oid='private.bil_ai_coach_reset_token_grants'::regclass"),true);
    for (const actor of ['anon','authenticated']) {
      await role(actor);
      await assert.rejects(() => reset(3),/permission denied/);
      await assert.rejects(() => db.exec('select * from private.bil_ai_coach_reset_token_grants'),/permission denied/);
      await assert.rejects(() => db.query('insert into public.bil_ai_coach_reset_notices(owner_id,reset_id) values($1,$2)',[uid(3),uid(999)]),/permission denied/);
    }
  });
  console.log(`PASS: ${checks} reset top-up PostgreSQL regression checks`);
} finally {
  await db.close();
}
