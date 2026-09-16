// Executes the actual NEW migrations and their PostgreSQL functions/triggers.
// PGlite is local/in-memory: no Apple/Supabase call or customer data. Queued
// duplicate requests are covered, NOT independent production-session races.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const sql = (name) => readFileSync(new URL(`../migrations/${name}`, import.meta.url), 'utf8');
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const digest = 'a'.repeat(64);
const scalar = async (query, args = []) => (await db.query(query, args)).rows[0].value;
let checks = 0;
let eventNumber = 0;
let eventBase;
const check = async (name, run) => { await run(); console.log(`PASS ${++checks}: ${name}`); };
function tableDefinition(name, migration) {
  const match = sql(migration).match(new RegExp(`create table if not exists public\\.${name} \\([\\s\\S]*?\\n\\);`, 'i'));
  assert.ok(match, `actual ${name} table definition`);
  return match[0];
}
function functionDefinition(name, migration) {
  const pattern = new RegExp(`create or replace function public\\.${name}\\([\\s\\S]*?\\bas\\s+(\\$[a-zA-Z0-9_]*\\$)[\\s\\S]*?\\1\\s*;`, 'i');
  const match = sql(migration).match(pattern);
  assert.ok(match, `actual ${name} function definition`);
  return match[0];
}
const claim = (id, token, hash = digest, environment = 'sandbox') => scalar(
  'select public.bil_claim_store_notification($1,$2,$3,$4,$5::uuid) as value',
  ['apple', id, hash, environment, uid(token)],
);
const finish = (id, token, status) => scalar(
  'select public.bil_finish_store_notification($1,$2,$3::uuid,$4) as value',
  ['apple', id, uid(token), status],
);
const credit = (owner, transaction, environment = 'sandbox') => scalar(
  'select public.bil_credit_ai_boost_verified($1::uuid,$2,$3,$4,now(),$5,$6) as value',
  [uid(owner), 'app_store', transaction, 'bil_ai_boost', digest, environment],
);
async function event(transaction, type, options = {}) {
  const sequence = ++eventNumber;
  return scalar('select public.bil_apply_ai_boost_store_event($1,$2,$3,$4,$5,$6,$7::timestamptz,$8) as value',
    ['app_store', transaction, 'bil_ai_boost', options.environment ?? 'sandbox', options.id ?? `event-${sequence}`,
      type, options.at ?? new Date(eventBase + sequence * 1000).toISOString(), digest]);
}
async function balance(owner) {
  return (await db.query('select granted,used,reserved,refund_debt,granted-used-reserved as available from public.bil_ai_credit_balances where owner_id=$1', [uid(owner)])).rows[0];
}
async function persist(owner, overrides = {}) {
  const row = {
    product: 'bil_premium_ai_coach', lifecycle: 'trial', chain: `chain-${owner}`, transaction: `transaction-${owner}`,
    environment: 'production', country: 'US', started: new Date(eventBase).toISOString(),
    expires: new Date(eventBase + 7 * 86400000).toISOString(), grace: null, ...overrides,
  };
  const ordered = Object.hasOwn(overrides,'signedAt');
  const args = [uid(owner),row.product,row.lifecycle,row.chain,row.transaction,row.environment,row.country,row.started,row.expires,row.grace,digest];
  if (ordered) args.push(overrides.signedAt);
  return scalar(`select public.bil_persist_verified_store_purchase($1::uuid,'apple',$2,'app.bil.health',$3,$4,$5,$6,$7,
    $8::timestamptz,$9::timestamptz,$10::timestamptz,false,now(),$11${ordered ? ',$12::timestamptz' : ''}) as value`,args);
}

try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create schema auth; create table auth.users(id uuid primary key);
    create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    create function auth.uid() returns uuid language sql stable as $$select (auth.jwt()->>'sub')::uuid$$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    create schema bil_admin_private;
    create table bil_admin_private.test_admin_plans(owner_id uuid primary key,plan text);
    create function bil_admin_private.active_plan(p_owner uuid) returns text language sql stable as $$select plan from bil_admin_private.test_admin_plans where owner_id=p_owner$$;
  `);
  // Existing table snapshot is baseline only. The new migration SQL, including
  // ACL, check constraints, trigger, debt and function definitions, runs whole.
  await db.exec(readFileSync(new URL('fixtures/admin_subscription_baseline/tables.sql', import.meta.url), 'utf8'));
  await db.exec(tableDefinition('bil_store_notification_inbox','202608040004_bil_store_entitlement_truth.sql'));
  await db.exec(functionDefinition('bil_claim_store_notification','202608040004_bil_store_entitlement_truth.sql'));
  await db.exec(tableDefinition('bil_ai_boost_purchases','202608110004_bil_ai_coach_weekly_usage_and_boost.sql'));
  await db.exec(tableDefinition('bil_store_entitlement_audit','202608040004_bil_store_entitlement_truth.sql'));
  await db.exec(`create table public.bil_store_product_registry(
    provider text,product_id text,package_or_bundle_id text,plan_id text,enabled boolean,
    primary key(provider,product_id));
    create function public.bil_market_plan_for_store_country(p_country text) returns text language sql stable as $$select case when p_country='US' then 'premium_ai_coach' else 'premium' end$$;
    insert into public.bil_store_product_registry values
      ('apple','bil_premium','app.bil.health','premium',true),
      ('apple','bil_premium_annual','app.bil.health','premium',true),
      ('apple','bil_premium_ai_coach','app.bil.health','premium_ai_coach',true),
      ('apple','bil_premium_ai_coach_annual','app.bil.health','premium_ai_coach',true);
    select set_config('request.jwt.claims','{"role":"service_role"}',false);
  `);
  await db.exec(functionDefinition('bil_persist_verified_store_purchase','20260821102504_commerce_country_policy_and_ai_allowances.sql'));
  await db.exec(functionDefinition('bil_credit_ai_boost_verified','20260821102504_commerce_country_policy_and_ai_allowances.sql'));
  await db.exec(sql('20260830120109_canonical_store_lifecycle_mirror_forward_20260830110000.sql'));
  for (let n = 1; n <= 30; n++) await db.query('insert into auth.users values($1)',[uid(n)]);
  await db.query('insert into public.bil_ai_credit_balances(owner_id,granted,used,reserved) values($1,3000,1000,200)',[uid(30)]);
  const migrations = ['20260916103000_retryable_store_notification_leases.sql','20260916104000_verified_boost_refund_ledger.sql','20260916105000_canonical_trial_and_terminal_store_persistence.sql','20260916106000_order_verified_store_snapshots.sql'];
  for (const name of migrations) await db.exec(sql(name));
  eventBase = Date.parse(await scalar("select (now()-interval '1 day')::text as value"));

  await check('migrations leave historical grant/usage/reservation amounts untouched', async () => {
    assert.deepEqual(await balance(30),{granted:3000,used:1000,reserved:200,refund_debt:0,available:1800});
  });

  await check('claim, error, retry and processed duplicate preserve a stable event identity', async () => {
    assert.equal(await claim('lease-error-retry',1),true);
    assert.equal(await finish('lease-error-retry',1,'error'),true);
    assert.equal(await claim('lease-error-retry',2),true);
    assert.equal(await finish('lease-error-retry',1,'processed'),false);
    assert.equal(await finish('lease-error-retry',2,'processed'),true);
    assert.equal(await claim('lease-error-retry',3),false);
    assert.equal(await scalar("select attempt_count as value from public.bil_store_notification_inbox where notification_id='lease-error-retry'"),2);
  });
  await check('concurrent queued claims leave one active worker and signal retry not duplicate', async () => {
    const outcomes = await Promise.allSettled([claim('queued-workers',4),claim('queued-workers',5)]);
    assert.equal(outcomes.filter(r=>r.status==='fulfilled' && r.value===true).length,1);
    assert.equal(outcomes.filter(r=>r.status==='rejected' && /notification_claim_in_progress/.test(r.reason.message)).length,1);
  });
  await check('expired leases are retryable and stale workers cannot complete newer claims', async () => {
    assert.equal(await claim('expired-lease',6),true);
    await db.exec("update public.bil_store_notification_inbox set lease_expires_at=clock_timestamp()-interval '1 second' where notification_id='expired-lease'");
    assert.equal(await finish('expired-lease',6,'processed'),false);
    assert.equal(await claim('expired-lease',7),true);
    assert.equal(await finish('expired-lease',6,'error'),false);
    assert.equal(await finish('expired-lease',7,'processed'),true);
  });
  await check('payload/environment conflicts abort without marking notification processed', async () => {
    assert.equal(await claim('conflicting-claim',8),true);
    await assert.rejects(()=>claim('conflicting-claim',9,'b'.repeat(64)),/notification_payload_conflict/);
    await assert.rejects(()=>claim('conflicting-claim',9,digest,'production'),/notification_payload_conflict/);
    assert.equal(await scalar("select status as value from public.bil_store_notification_inbox where notification_id='conflicting-claim'"),'received');
  });
  await check('legacy four-argument signature remains callable', async () => {
    assert.equal(await scalar('select public.bil_claim_store_notification($1,$2,$3,$4) as value',['apple','legacy-delivery',digest,'sandbox']),true);
    await db.exec("update public.bil_store_notification_inbox set status='error' where notification_id='legacy-delivery'");
    assert.equal(await scalar('select public.bil_claim_store_notification($1,$2,$3,$4) as value',['apple','legacy-delivery',digest,'sandbox']),true);
  });
  await check('rejected delivery is terminal and reused claim tokens cannot reacquire expired work', async () => {
    assert.equal(await claim('rejected-delivery',10),true);
    assert.equal(await finish('rejected-delivery',10,'rejected'),true);
    assert.equal(await claim('rejected-delivery',11),false);
    assert.equal(await claim('reused-token',12),true);
    await db.exec("update public.bil_store_notification_inbox set lease_expires_at=clock_timestamp()-interval '1 second' where notification_id='reused-token'");
    await assert.rejects(()=>claim('reused-token',12),/notification_claim_token_reused/);
    assert.equal(await claim('reused-token',13),true);
  });
  await check('unspent refunded Boost loses exactly 2500 once and cannot be purchased again via receipt replay', async () => {
    await credit(1,'boost-unspent');
    const first = await event('boost-unspent','refunded',{id:'refund-unspent'});
    assert.equal(first.tokens_delta,-2500);
    assert.deepEqual(await balance(1),{granted:0,used:0,reserved:0,refund_debt:0,available:0});
    assert.equal((await event('boost-unspent','refunded',{id:'refund-unspent'})).duplicate,true);
    assert.equal((await event('boost-unspent','refunded')).tokens_delta,0);
    assert.equal((await credit(1,'boost-unspent')).refunded,true);
    assert.equal(await scalar("select count(*)::int as value from public.bil_ai_boost_purchases where transaction_id='boost-unspent'"),1);
    assert.equal(await scalar("select count(*)::int as value from public.bil_ai_boost_store_events where transaction_id='boost-unspent'"),2);
  });
  await check('partially spent refund carries token debt and the next top-up repays it', async () => {
    await credit(2,'boost-partially-spent');
    await db.query('update public.bil_ai_credit_balances set used=1000 where owner_id=$1',[uid(2)]);
    await event('boost-partially-spent','refunded');
    assert.deepEqual(await balance(2),{granted:1000,used:1000,reserved:0,refund_debt:1000,available:0});
    await credit(2,'boost-new-after-refund');
    assert.deepEqual(await balance(2),{granted:2500,used:1000,reserved:0,refund_debt:0,available:1500});
    await event('boost-partially-spent','refund_reversed');
    assert.deepEqual(await balance(2),{granted:5000,used:1000,reserved:0,refund_debt:0,available:4000});
  });
  await check('reserved credit is not broken and a released reservation cannot resurrect refunded tokens', async () => {
    await credit(3,'boost-reserved');
    await db.query('update public.bil_ai_credit_balances set used=600,reserved=400 where owner_id=$1',[uid(3)]);
    await event('boost-reserved','refunded');
    assert.deepEqual(await balance(3),{granted:1000,used:600,reserved:400,refund_debt:1000,available:0});
    await db.query('update public.bil_ai_credit_balances set reserved=0 where owner_id=$1',[uid(3)]);
    assert.deepEqual(await balance(3),{granted:600,used:600,reserved:0,refund_debt:600,available:0});
    await event('boost-reserved','refund_reversed');
    assert.deepEqual(await balance(3),{granted:2500,used:600,reserved:0,refund_debt:0,available:1900});
  });
  await check('fully spent credit preserves consumption and refund reversal cancels debt once', async () => {
    await credit(4,'boost-fully-spent');
    await db.query('update public.bil_ai_credit_balances set used=2500 where owner_id=$1',[uid(4)]);
    await event('boost-fully-spent','refunded');
    assert.deepEqual(await balance(4),{granted:2500,used:2500,reserved:0,refund_debt:2500,available:0});
    await event('boost-fully-spent','refund_reversed',{id:'reverse-spent'});
    await event('boost-fully-spent','refund_reversed',{id:'reverse-spent'});
    assert.deepEqual(await balance(4),{granted:2500,used:2500,reserved:0,refund_debt:0,available:0});
  });
  await check('in-flight reservation may settle after refund without restoring refunded availability', async () => {
    await credit(8,'boost-inflight-settlement');
    await db.query('update public.bil_ai_credit_balances set used=600,reserved=400 where owner_id=$1',[uid(8)]);
    await event('boost-inflight-settlement','refunded');
    // Same balance transition used by successful settlement, exercising the
    // real new trigger and constraints without mocking a calculated balance.
    await db.query('update public.bil_ai_credit_balances set used=used+400,reserved=reserved-400 where owner_id=$1',[uid(8)]);
    assert.deepEqual(await balance(8),{granted:1000,used:1000,reserved:0,refund_debt:1000,available:0});
    await event('boost-inflight-settlement','refund_reversed');
    assert.deepEqual(await balance(8),{granted:2500,used:1000,reserved:0,refund_debt:0,available:1500});
  });
  await check('two refunds and out-of-order reversals preserve pooled credit conservation', async () => {
    await credit(9,'boost-pooled-one');
    await credit(9,'boost-pooled-two');
    await db.query('update public.bil_ai_credit_balances set used=3500,reserved=500 where owner_id=$1',[uid(9)]);
    await event('boost-pooled-one','refunded');
    await event('boost-pooled-two','refunded');
    assert.deepEqual(await balance(9),{granted:4000,used:3500,reserved:500,refund_debt:4000,available:0});
    await event('boost-pooled-one','refund_reversed');
    await db.query('update public.bil_ai_credit_balances set reserved=0 where owner_id=$1',[uid(9)]);
    await credit(9,'boost-pooled-three');
    assert.deepEqual(await balance(9),{granted:5000,used:3500,reserved:0,refund_debt:0,available:1500});
    await event('boost-pooled-two','refund_reversed');
    assert.deepEqual(await balance(9),{granted:7500,used:3500,reserved:0,refund_debt:0,available:4000});
  });
  await check('refund before first credit creates a tombstone; reversal alone never grants tokens', async () => {
    assert.equal((await event('boost-before-credit','refunded')).purchase_found,false);
    assert.equal((await credit(5,'boost-before-credit')).refunded,true);
    assert.equal(await balance(5),undefined);
    assert.equal((await event('boost-before-credit','refund_reversed')).tokens_delta,0);
    assert.equal(await balance(5),undefined);
    assert.equal((await credit(5,'boost-before-credit')).credited,true);
    assert.equal((await credit(5,'boost-before-credit')).credited,false);
    assert.equal((await balance(5)).available,2500);
  });
  await check('stale store event cannot undo a newer reversal; exact-timestamp refund wins safely', async () => {
    await credit(6,'boost-ordered');
    const at = new Date(eventBase+100000).toISOString();
    const later = new Date(eventBase+110000).toISOString();
    await event('boost-ordered','refunded',{at});
    await event('boost-ordered','refund_reversed',{at:later});
    assert.equal((await event('boost-ordered','refunded',{at})).stale,true);
    assert.equal((await balance(6)).available,2500);
    await event('boost-ordered','refunded',{at:later});
    assert.equal((await balance(6)).available,0);
    assert.equal((await event('boost-ordered','refund_reversed',{at:later})).stale,true);
  });
  await check('Boost owner/environment conflicts and conflicting event IDs cannot mutate balances', async () => {
    await credit(7,'boost-identity');
    await assert.rejects(()=>credit(29,'boost-identity'),/purchase_owned_by_another_account/);
    await assert.rejects(()=>event('boost-identity','refunded',{environment:'production'}),/wrong_environment/);
    await event('boost-identity','refunded',{id:'identity-event'});
    await assert.rejects(()=>event('another-transaction','refunded',{id:'identity-event'}),/boost_event_identity_conflict/);
    assert.equal((await balance(7)).available,0);
    assert.equal(await balance(29),undefined);
  });
  await check('all new write RPCs deny ordinary members and grant execution only to service role', async () => {
    for (const signature of [
      'public.bil_claim_store_notification(text,text,text,text,uuid)',
      'public.bil_finish_store_notification(text,text,uuid,text)',
      'public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text,text)',
      'public.bil_apply_ai_boost_store_event(text,text,text,text,text,text,timestamptz,text)',
      'public.bil_persist_verified_store_purchase(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text,timestamptz)',
    ]) {
      assert.equal(await scalar('select has_function_privilege($1,$2,$3) as value',['authenticated',signature,'execute']),false);
      assert.equal(await scalar('select has_function_privilege($1,$2,$3) as value',['anon',signature,'execute']),false);
      assert.equal(await scalar('select has_function_privilege($1,$2,$3) as value',['service_role',signature,'execute']),true);
    }
    assert.equal(await scalar("select bool_and(relrowsecurity) as value from pg_class where relname in ('bil_ai_boost_store_state','bil_ai_boost_store_events')"),true);
    assert.equal(await scalar('select has_function_privilege($1,$2,$3) as value',['service_role',
      'private.bil_persist_verified_store_purchase_unordered(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)','execute']),false);
  });
  await check('canonical trial remains trial when cancelled and sandbox short trial never becomes paid allowance', async () => {
    assert.equal(await persist(10),true);
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(10)]),'trial');
    assert.equal(await persist(10,{lifecycle:'cancelled'}),true);
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(10)]),'trial');
    assert.equal(await scalar('select lifecycle as value from public.bil_ai_coach_subscriptions where owner_id=$1',[uid(10)]),'trial');
    const now = Date.parse(await scalar('select now()::text as value'));
    await persist(11,{environment:'sandbox',started:new Date(now-60000).toISOString(),expires:new Date(now+60000).toISOString()});
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(11)]),'trial');
    assert.ok(await scalar('select public.bil_resolve_ai_trial_anchor($1) as value',[uid(11)]));
    await persist(11,{environment:'sandbox',lifecycle:'cancelled',started:new Date(now-60000).toISOString(),expires:new Date(now+60000).toISOString()});
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(11)]),'trial');
    await persist(16,{environment:'sandbox',lifecycle:'active',started:new Date(now-60000).toISOString(),expires:new Date(now+60000).toISOString()});
    await persist(16,{environment:'sandbox',lifecycle:'cancelled',started:new Date(now-60000).toISOString(),expires:new Date(now+60000).toISOString()});
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(16)]),'ai_coach');
  });
  await check('canonical downgrade denies AI even with a stale paid mirror, preserving private admin overlay', async () => {
    await persist(12,{lifecycle:'active'});
    await persist(12,{product:'bil_premium',country:'EG',lifecycle:'active'});
    await db.query(`insert into public.bil_ai_coach_subscriptions values($1,'apple','bil_premium_ai_coach','active','stale-chain','stale-latest',now()+interval '1 day',now())`,[uid(12)]);
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(12)]),'free');
    await db.query("insert into bil_admin_private.test_admin_plans values($1,'premium_ai_coach')",[uid(12)]);
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(12)]),'ai_coach');
  });
  await check('exact expiry is inactive in real atomic persistence', async () => {
    await db.exec('begin');
    try {
      const boundary = await scalar('select now()::text as value');
      assert.equal(await persist(13,{lifecycle:'active',expires:boundary}),false);
      assert.equal(await scalar('select active as value from public.bil_entitlements where owner_id=$1',[uid(13)]),false);
    } finally { await db.exec('rollback'); }
  });
  await check('terminal exact-subscription updates remove access despite country/product-policy drift', async () => {
    await persist(14,{lifecycle:'active'});
    await db.exec("update public.bil_store_product_registry set enabled=false where product_id='bil_premium_ai_coach'");
    assert.equal(await persist(14,{lifecycle:'revoked',country:null}),false);
    assert.equal(await scalar('select active as value from public.bil_entitlements where owner_id=$1',[uid(14)]),false);
    await assert.rejects(()=>persist(15,{lifecycle:'revoked',country:null}),/store_country_required/);
    await assert.rejects(()=>persist(14,{lifecycle:'active',country:null}),/store_country_required/);
    await assert.rejects(()=>persist(14,{lifecycle:'revoked',chain:'other-chain',country:null}),/store_country_required/);
    await db.exec("update public.bil_store_product_registry set enabled=true where product_id='bil_premium_ai_coach'");
  });
  await check('late older active response cannot overwrite a newer signed refund and returns actual state atomically', async () => {
    const oldSigned = new Date(eventBase+1000).toISOString();
    const newSigned = new Date(eventBase+2000).toISOString();
    assert.equal((await persist(17,{lifecycle:'active',signedAt:oldSigned})).active,true);
    assert.equal((await persist(17,{lifecycle:'revoked',signedAt:newSigned})).active,false);
    const stale = await persist(17,{lifecycle:'active',signedAt:oldSigned});
    assert.equal(stale.active,false);
    assert.equal(stale.lifecycle,'revoked');
    const stored = (await db.query('select lifecycle,verified_at,store_signed_at from public.bil_subscriptions where owner_id=$1',[uid(17)])).rows[0];
    assert.equal(stored.lifecycle,'revoked');
    // PGlite returns timestamptz as Date objects. Date.parse(Date) goes through
    // Date.toString(), which drops milliseconds; getTime() keeps exact precision.
    assert.equal(stored.store_signed_at.getTime(),Date.parse(newSigned));
    assert.equal(stored.verified_at.getTime(),Date.parse(stale.verified_at));
    assert.equal(await scalar('select active as value from public.bil_entitlements where owner_id=$1',[uid(17)]),false);
  });
  await check('equal-time terminal snapshot wins, legacy writes cannot revive it, newer signed renewal can', async () => {
    const signedAt = new Date(eventBase+3000).toISOString();
    await persist(18,{lifecycle:'active',signedAt});
    await persist(18,{lifecycle:'revoked',signedAt});
    assert.equal((await persist(18,{lifecycle:'active',signedAt})).lifecycle,'revoked');
    assert.equal(await persist(18,{lifecycle:'active'}),false);
    const renewal = await persist(18,{lifecycle:'active',signedAt:new Date(eventBase+4000).toISOString(),
      transaction:'transaction-renewal-18',expires:new Date(eventBase+31*86400000).toISOString()});
    assert.equal(renewal.active,true);
    assert.equal(renewal.lifecycle,'active');
    assert.equal(await scalar('select latest_transaction_id as value from public.bil_subscriptions where owner_id=$1',[uid(18)]),'transaction-renewal-18');
  });
  await check('signed-time ordering rejects non-finite or future metadata and serializes queued stale state', async () => {
    for (const signedAt of ['infinity','-infinity','1970-01-01T00:00:00Z',new Date(Date.now()+86400000).toISOString()]) {
      await assert.rejects(()=>persist(19,{lifecycle:'active',signedAt}),/invalid_store_signed_at/);
    }
    const newSigned = new Date(eventBase+6000).toISOString();
    const oldSigned = new Date(eventBase+5000).toISOString();
    const results = await Promise.all([persist(19,{lifecycle:'revoked',signedAt:newSigned}),persist(19,{lifecycle:'active',signedAt:oldSigned})]);
    assert.equal(results[0].active,false);
    assert.equal(results[1].active,false);
    assert.equal(results[1].lifecycle,'revoked');
  });
  await check('subsecond signed timestamps remain exact and a same-second older receipt cannot revive a refund', async () => {
    const second = Math.floor(eventBase / 1000) * 1000 + 10000;
    const oldSigned = new Date(second + 123).toISOString();
    const newSigned = new Date(second + 789).toISOString();
    assert.equal((await persist(20,{lifecycle:'active',signedAt:oldSigned})).active,true);
    assert.equal((await persist(20,{lifecycle:'refunded',signedAt:newSigned})).active,false);
    const stale = await persist(20,{lifecycle:'active',signedAt:oldSigned});
    assert.equal(stale.active,false);
    assert.equal(stale.lifecycle,'refunded');
    const stored = (await db.query('select store_signed_at,verified_at from public.bil_subscriptions where owner_id=$1',[uid(20)])).rows[0];
    assert.equal(stored.store_signed_at.getTime(),second + 789);
    assert.equal(stored.verified_at.getTime(),Date.parse(stale.verified_at));
    assert.equal(await scalar('select active as value from public.bil_entitlements where owner_id=$1',[uid(20)]),false);
  });
  await check('migration reapplication is idempotent and unexpected legacy claim drift aborts', async () => {
    const before = (await db.query('select * from public.bil_ai_credit_balances order by owner_id')).rows;
    for (const name of migrations) await db.exec(sql(name));
    assert.deepEqual((await db.query('select * from public.bil_ai_credit_balances order by owner_id')).rows,before);
    const definition = await scalar("select pg_get_functiondef('public.bil_claim_store_notification(text,text,text,text)'::regprocedure) as value");
    await db.exec("create or replace function public.bil_claim_store_notification(p_provider text,p_notification_id text,p_payload_digest text,p_environment text default null) returns boolean language sql as $$select true$$");
    await assert.rejects(()=>db.exec(sql('20260916103000_retryable_store_notification_leases.sql')),/unexpected_notification_claim_definition/);
    await db.exec('rollback');
    await db.exec(definition);
  });
  console.log(`PASS: ${checks} real PostgreSQL store refund/retry execution checks`);
} finally { await db.close(); }
