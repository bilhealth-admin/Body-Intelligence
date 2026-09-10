// Real PostgreSQL (PGlite), local memory only. Never connects to Supabase.
// npm ci --prefix supabase/tests --ignore-scripts
// node supabase/tests/admin_subscription_grants_test.mjs
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db = new PGlite();
const fixture = 'supabase/tests/fixtures/admin_subscription_baseline';
const read = (file) => readFileSync(file, 'utf8');
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
let checks = 0;
async function check(name, fn) { await fn(); checks++; console.log(`PASS ${checks}: ${name}`); }
async function value(sql, params = []) { return (await db.query(sql, params)).rows[0]?.value; }
async function role(name, owner = 1) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify({ role: name, sub: uid(owner) })]);
  if (name !== 'postgres') await db.exec(`set role ${name}`);
}
async function grant(owner, plan = 'premium_ai_coach', key = `grant-request-${owner}-0000001`, days = 30) {
  await role('service_role');
  return value('select public.bil_manage_admin_subscription($1, $2, $3, $4, $5, $6) as value',
    [uid(1), 'grant', key, `user${owner}@example.test`, plan, days]);
}
async function revoke(id, key = `revoke-${id}`) {
  await role('service_role');
  return value('select public.bil_manage_admin_subscription($1, $2, $3, p_grant_id => $4) as value', [uid(1), 'revoke', key, id]);
}
async function status(owner) { await role('authenticated', owner); return value('select public.bil_get_ai_usage_status() as value'); }
async function rows(table) { await role('postgres'); return (await db.query(`select * from public.${table} order by owner_id`)).rows; }
try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create schema private;
    create table auth.users(id uuid primary key, email text, deleted_at timestamptz);
    create table private.bil_ai_coach_admins(user_id uuid primary key, active boolean not null);
    create table public.bil_rate_limit_buckets(user_id uuid not null references auth.users(id) on delete cascade,
      action text not null, window_started_at timestamptz not null, hit_count integer not null default 1,
      primary key(user_id, action, window_started_at));
    alter table public.bil_rate_limit_buckets enable row level security;
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb$$;
    create function auth.uid() returns uuid language sql stable as $$select (auth.jwt()->>'sub')::uuid$$;
    grant usage on schema auth, public to authenticated, service_role, anon;
  `);
  await db.exec(read(`${fixture}/tables.sql`));
  const ordered = ['bil_resolve_ai_allowance_plan', 'bil_resolve_ai_trial_anchor', 'bil_has_active_premium'];
  for (const file of [...ordered.map(n => `${n}.sql`), ...readdirSync(fixture).filter(n => n.endsWith('.sql') && n !== 'tables.sql' && !ordered.some(x => n === `${x}.sql`))]) {
    await db.exec(read(`${fixture}/${file}`));
  }
  await db.exec(`create trigger bil_ai_credit_monthly_usage_sync after insert or update or delete
    on public.bil_ai_credit_weekly_usage for each row execute function public.bil_sync_ai_monthly_usage();
    insert into public.bil_ai_credit_config(plan_id,weekly_limit,monthly_limit) values('free',0,0),('trial',1000,1000),('ai_coach',2500,10000);`);
  for (let n = 1; n <= 8; n++) await db.query('insert into auth.users(id,email) values($1,$2)', [uid(n), `user${n}@example.test`]);
  await db.query('insert into private.bil_ai_coach_admins values($1,true)', [uid(1)]);
  for (const [n, provider, plan, lifecycle] of [[3,'apple','premium_ai_coach','active'],[4,'google','premium_ai_coach','active'],[5,'apple','premium','active'],[6,'apple','premium_ai_coach','trial']]) {
    await db.query(`insert into public.bil_subscriptions(owner_id,provider,product_id,plan_id,lifecycle,original_transaction_id,latest_transaction_id,environment,started_at,expires_at,verified_at)
      values($1,$2,$3,$4,$5,$6,$6,'production',now()-interval '1 day',now()+interval '20 days',now())`,
      [uid(n),provider,plan === 'premium' ? 'bil_premium' : 'bil_premium_ai_coach',plan,lifecycle,`store-${n}`]);
    if (plan === 'premium_ai_coach') await db.query(`insert into public.bil_ai_coach_subscriptions
      values($1,$2,'bil_premium_ai_coach',$3,$4,$4,now()+interval '20 days',now())`,[uid(n),provider,lifecycle,`store-${n}`]);
  }
  await db.query('insert into public.bil_ai_credit_balances(owner_id,granted,used) values($1,2500,15)', [uid(2)]);
  const beforeStore = await rows('bil_subscriptions');
  const beforeAi = await rows('bil_ai_coach_subscriptions');
  const beforeBoost = await rows('bil_ai_credit_balances');
  await db.exec(read('supabase/migrations/20260910014118_admin_subscription_grants.sql'));
  await check('new rate-limit tuples work, enforce their bounds, and preserve old contracts', async () => {
    await role('authenticated', 1);
    for (const [action, limit] of [['admin_subscription_list',120],['admin_subscription_grant',60],['admin_subscription_revoke',60]]) {
      await assert.rejects(() => value('select public.bil_consume_rate_limit($1,$2,3600) as value', [action, limit + 1]), /invalid_rate_limit_contract/);
      await assert.rejects(() => value('select public.bil_consume_rate_limit($1,$2,60) as value', [action, limit]), /invalid_rate_limit_contract/);
      for (let n = 0; n < limit; n++) await value('select public.bil_consume_rate_limit($1,$2,3600) as value', [action, limit]);
      await assert.rejects(() => value('select public.bil_consume_rate_limit($1,$2,3600) as value', [action, limit]), /rate limit exceeded/);
    }
    await value("select public.bil_consume_rate_limit('admin_ai_coach_global_reset',3,3600) as value");
    await value("select public.bil_consume_rate_limit('store_purchase_verification',20,3600) as value");
    await value("select public.bil_consume_rate_limit('shared_diary_locked_read',30,3600) as value");
    await assert.rejects(() => value("select public.bil_consume_rate_limit('invented_action',60,3600) as value"), /invalid_rate_limit_contract/);
  });
  await check('migration keeps every existing store, AI mirror and Boost value unchanged', async () => {
    assert.deepEqual(await rows('bil_subscriptions'), beforeStore);
    assert.deepEqual(await rows('bil_ai_coach_subscriptions'), beforeAi);
    assert.deepEqual(await rows('bil_ai_credit_balances'), beforeBoost);
  });
  await check('all new tables use RLS and public wrappers are invokers', async () => {
    assert.equal(await value("select bool_and(relrowsecurity) as value from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='bil_admin_private' and c.relkind='r'"), true);
    assert.equal(await value("select bool_and(not prosecdef) as value from pg_proc where proname in ('bil_manage_admin_subscription','bil_get_my_admin_subscription','bil_list_admin_subscriptions')"), true);
  });
  await check('anonymous and ordinary users cannot list, grant, revoke or access private audit data', async () => {
    for (const actor of ['anon','authenticated']) {
      await role(actor, 2);
      for (const sql of ["select * from bil_admin_private.subscription_grants", "select public.bil_list_admin_subscriptions('"+uid(1)+"')", "select public.bil_manage_admin_subscription('"+uid(1)+"','revoke','reject-request-00000001',p_grant_id=>'"+uid(2)+"')"]) {
        await assert.rejects(db.exec(sql), /permission denied/);
      }
    }
  });
  await check('service role cannot impersonate a non-admin actor', async () => {
    await role('service_role');
    await assert.rejects(value('select public.bil_list_admin_subscriptions($1) as value',[uid(2)]), /administrator_required/);
  });
  let gifted;
  await check('registered email receives an independent AI grant and real quota', async () => {
    gifted = await grant(2);
    assert.equal(gifted.changed, true);
    const credits = (await status(2)).credits;
    assert.equal(credits.weekly_limit,2500); assert.equal(credits.total_remaining,4985);
  });
  await check('same request replays identically and re-grant neither extends duration nor resets usage', async () => {
    assert.deepEqual(await grant(2),gifted);
    assert.equal((await grant(2,'premium_ai_coach','second-request-0000001',365)).changed,false);
    await role('postgres');
    assert.equal(await value("select count(*)::int as value from bil_admin_private.subscription_grants where owner_id=$1",[uid(2)]),1);
  });
  await check('idempotency mismatch and silent tier replacement are rejected', async () => {
    await assert.rejects(grant(2,'premium'),/idempotency_conflict/);
    await assert.rejects(grant(2,'premium','different-plan-0000001'),/existing_admin_subscription/);
  });
  await check('unknown email and invalid duration do not create grants', async () => {
    assert.equal((await grant(999)).matched,false);
    await assert.rejects(grant(7,'premium','bad-duration-000000001',-1),/invalid_subscription_request/);
  });
  await check('own snapshot is leased and isolated from another account', async () => {
    await role('authenticated',2);
    const own = await value('select public.bil_get_my_admin_subscription() as value');
    assert.equal(own.owner_id,uid(2)); assert.equal(own.plan_id,'premium_ai_coach');
    assert.ok(new Date(own.access_until)-Date.now() <= 301000);
    await role('authenticated',7);
    assert.equal(await value('select public.bil_get_my_admin_subscription() as value'),null);
  });
  await check('production reserve/settle consumes actual gift quota without consuming independent Boost', async () => {
    await role('service_role');
    const reserved = await value('select public.bil_reserve_ai_usage($1,$2,$3,1) as value',[uid(2),'real-reserve-request-0001','text']);
    assert.equal(reserved.weekly_tokens_reserved,100); assert.equal(reserved.paid_tokens_reserved,0);
    await value("select public.bil_settle_ai_usage($1,$2,'text',true,'gemini','test',1,1,1,0.001) as value",[uid(2),'real-reserve-request-0001']);
    const credits = (await status(2)).credits;
    assert.equal(credits.weekly_used,10); assert.equal(credits.monthly_used,10); assert.equal(credits.paid_remaining,2485);
  });
  await check('revocation stops included access, preserves Boost, and retries do not affect other grants', async () => {
    const first = await revoke(gifted.grant_id);
    assert.equal(first.changed,true); assert.deepEqual(await revoke(gifted.grant_id),first);
    const after = await status(2); assert.equal(after.plan,'free'); assert.equal(after.credits.total_remaining,2485);
  });
  await check('revoking grants leaves Apple and Google paid subscribers subscribed with their quota', async () => {
    for (const n of [3,4]) {
      const g = await grant(n); await revoke(g.grant_id);
      const s = await status(n); assert.equal(s.plan,'ai_coach'); assert.equal(s.credits.weekly_limit,2500);
    }
    assert.deepEqual(await rows('bil_subscriptions'), beforeStore);
    assert.deepEqual(await rows('bil_ai_coach_subscriptions'), beforeAi);
  });
  await check('ordinary Premium grant has no AI allowance; revoke returns to the purchased Premium', async () => {
    const g = await grant(5,'premium');
    assert.equal((await status(5)).plan,'free');
    await revoke(g.grant_id);
    await role('postgres');
    assert.equal(await value('select public.bil_has_active_premium($1) as value',[uid(5)]),true);
  });
  await check('AI trial rules remain intact before and after an administrative gift', async () => {
    assert.equal((await status(6)).credits.weekly_limit,1000);
    const g=await grant(6); assert.equal((await status(6)).credits.weekly_limit,2500);
    await revoke(g.grant_id); assert.equal((await status(6)).credits.weekly_limit,1000);
  });
  await check('until-revoked grants have no expiry and expired grants fail closed automatically', async () => {
    const indefinite=await grant(7,'premium','until-revoke-00000001',null);
    await role('authenticated',7);
    assert.equal((await value('select public.bil_get_my_admin_subscription() as value')).expires_at,null);
    await revoke(indefinite.grant_id);
    await grant(8);
    await role('postgres');
    await db.query("update bil_admin_private.subscription_grants set created_at=now()-interval '2 days', expires_at=now()-interval '1 day' where owner_id=$1",[uid(8)]);
    assert.equal((await status(8)).credits.weekly_limit,0);
    await role('authenticated',8); assert.equal(await value('select public.bil_get_my_admin_subscription() as value'),null);
  });
  await check('admin list includes active/expired/revoked history without store receipts or audit payload', async () => {
    await role('service_role');
    const list = await value('select public.bil_list_admin_subscriptions($1) as value',[uid(1)]);
    assert.equal(list.has_more,false); assert.ok(list.rows.length >= 7);
    assert.ok(list.rows.some(r=>r.status==='expired'));
    assert.ok(list.rows.some(r=>r.status==='revoked'));
    assert.deepEqual(Object.keys(list.rows[0]).sort(),['created_at','email','expires_at','id','plan_id','status']);
  });
  await check('regrant does not replenish spent period quota, and a revoked request cannot resurrect a grant', async () => {
    const again=await grant(2,'premium_ai_coach','fresh-grant-request-000001');
    assert.equal((await status(2)).credits.weekly_remaining,2490);
    await revoke(again.grant_id);
    await grant(2,'premium_ai_coach','fresh-grant-request-000001');
    assert.equal((await status(2)).plan,'free');
  });
  await check('already reserved work can settle after revoke but new zero-balance work is denied', async () => {
    const fresh=await grant(7,'premium_ai_coach','inflight-grant-0000001');
    await role('service_role');
    await value("select public.bil_reserve_ai_usage($1,'inflight-request-0001','text',1) as value",[uid(7)]);
    await revoke(fresh.grant_id);
    await role('service_role');
    await value("select public.bil_settle_ai_usage($1,'inflight-request-0001','text',true,'gemini','test',1,1,1,0.001) as value",[uid(7)]);
    await assert.rejects(value("select public.bil_reserve_ai_usage($1,'after-revoke-request-0001','text',1) as value",[uid(7)]),/ai_usage_exhausted/);
  });
  await check('audit retains only hashes of email/reason; target deletion removes its grant records', async () => {
    await role('postgres');
    const audit=(await db.query('select payload from bil_admin_private.subscription_commands')).rows;
    assert.ok(audit.every(r=>!JSON.stringify(r).includes('@example.test')));
    await db.query('delete from auth.users where id=$1',[uid(8)]);
    assert.equal(await value('select count(*)::int as value from bil_admin_private.subscription_grants where owner_id=$1',[uid(8)]),0);
  });
  await check('inactive administrators lose grant and list authority immediately', async () => {
    await role('postgres'); await db.exec('update private.bil_ai_coach_admins set active=false');
    await assert.rejects(grant(7),/administrator_required/);
    await role('service_role'); await assert.rejects(value('select public.bil_list_admin_subscriptions($1) as value',[uid(1)]),/administrator_required/);
  });
  console.log(`All ${checks} PostgreSQL checks passed. No remote writes.`);
} finally { await db.close(); }
