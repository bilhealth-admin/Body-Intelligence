// Local real PostgreSQL regression for the checked-in Sandbox receipt recovery.
// Replays repository migrations; no deployed-function injection, live service,
// credentials, filesystem writes, or Apple/JWS verification occurs in this test.
// PGlite is a single backend and does not prove production-session races.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import crypto from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const sql = (name) => readFileSync(new URL(`../migrations/${name}`, import.meta.url), 'utf8');
const hash = (value) => crypto.createHash('sha256').update(value).digest('hex');
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const digest = 'a'.repeat(64);
const scalar = async (query, args = []) => (await db.query(query, args)).rows[0].value;
let checks = 0;
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
  // The baseline's current store table is intentionally maintained as a
  // separate snapshot from the older pre-migration public schema.
  await db.exec(readFileSync(new URL('fixtures/admin_subscription_baseline/store_subscription_table.sql', import.meta.url), 'utf8'));
  await db.exec(tableDefinition('bil_store_notification_inbox','202608040004_bil_store_entitlement_truth.sql'));
  await db.exec(functionDefinition('bil_claim_store_notification','202608040004_bil_store_entitlement_truth.sql'));
  await db.exec(tableDefinition('bil_ai_boost_purchases','202608110004_bil_ai_coach_weekly_usage_and_boost.sql'));
  await db.exec(tableDefinition('bil_store_entitlement_audit','202608040004_bil_store_entitlement_truth.sql'));
  await db.exec(`create table public.bil_store_product_registry(
    provider text,product_id text,package_or_bundle_id text,plan_id text,enabled boolean,
    primary key(provider,product_id));
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
  for (let n = 1; n <= 150; n++) await db.query('insert into auth.users values($1)',[uid(n)]);
  await db.query('insert into public.bil_ai_credit_balances(owner_id,granted,used,reserved) values($1,3000,1000,200)',[uid(30)]);
  const migrations = ['20260916103000_retryable_store_notification_leases.sql','20260916104000_verified_boost_refund_ledger.sql','20260916105000_canonical_trial_and_terminal_store_persistence.sql','20260916106000_order_verified_store_snapshots.sql'];
  for (const name of migrations) await db.exec(sql(name));
  eventBase = Date.parse(await scalar("select (now()-interval '1 day')::text as value"));


  await db.exec(tableDefinition('bil_commerce_country_policy','20260821102504_commerce_country_policy_and_ai_allowances.sql'));
  await db.exec('alter table public.bil_commerce_country_policy add column sale_enabled boolean not null default false');
  await db.exec(sql('20260905170000_owner_store_market_policy_nigeria_alignment.sql'));
  await db.exec(`insert into public.bil_store_product_registry
    select 'google',product_id,package_or_bundle_id,plan_id,enabled
    from public.bil_store_product_registry where provider='apple'`);
  // The actual historical migration chain above must reproduce the exact
  // guarded preimage by itself. Never install a saved/live function fixture.
  const signature = 'private.bil_persist_verified_store_purchase_unordered(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)';
  const definition = () => scalar('select pg_get_functiondef($1::regprocedure) as value', [signature]);
  const preimage = await definition();
  assert.equal(hash(preimage), '4544d66c792a9e5bf94815196ea55357d00eea0cb7aa32d524f49a5211a56710',
    'Checked-in historical migrations must reproduce the exact guarded preimage.');
  const migration = sql('20261117020330_apple_sandbox_base_premium_receipt_recovery.sql');
  assert.equal(hash(migration), '5ec08fdfdeca7c0f3e9b4b952c7f789bd3ea428f8b801b27c4b986945f469a95',
    'Exercise the exact migration bytes applied to the live database.');
  let candidate;
  const now=Date.parse(await scalar('select now()::text as value'));
  let owner=31;
  async function receipt(n,o={}){
    const x={provider:'apple',product:'bil_premium',bundle:'app.bil.health',lifecycle:'active',chain:`receipt-${n}`,transaction:`tx-${n}`,environment:'sandbox',country:'JOR',started:new Date(now-60000).toISOString(),expires:new Date(now+86400000).toISOString(),grace:null,...o};
    return scalar(`select private.bil_persist_verified_store_purchase_unordered(
      $1::uuid,$2,$3,$4,$5,$6,$7,$8,$9,$10::timestamptz,$11::timestamptz,$12::timestamptz,false,now(),$13) as value`,
      [uid(n),x.provider,x.product,x.bundle,x.lifecycle,x.chain,x.transaction,x.environment,x.country,x.started,x.expires,x.grace,digest]);
  }
  async function countRows(table,n,where=''){
    assert(['bil_subscriptions','bil_entitlements','bil_ai_coach_subscriptions','bil_ai_credit_balances','bil_store_entitlement_audit'].includes(table));
    return scalar(`select count(*)::int as value from public.${table} where owner_id=$1 ${where}`,[uid(n)]);
  }
  async function assertNoAI(n){
    assert.equal(await countRows('bil_ai_coach_subscriptions',n),0);
    assert.equal(await countRows('bil_ai_credit_balances',n),0);
    assert.equal(await countRows('bil_entitlements',n,"and entitlement_id='plan:premium_ai_coach' and active"),0);
    assert.equal(await scalar('select public.bil_resolve_ai_allowance_plan($1) as value',[uid(n)]),'free');
    assert.equal(await scalar('select public.bil_resolve_ai_trial_anchor($1) as value',[uid(n)]),null);
  }
  await check('RED control actual old helper rejects Apple Sandbox base Premium in JOR without any partial grant',async()=>{
    await assert.rejects(()=>receipt(owner),/market_plan_mismatch/);
    assert.equal(await countRows('bil_subscriptions',owner),0);
    assert.equal(await countRows('bil_entitlements',owner),0);
    assert.equal(await countRows('bil_store_entitlement_audit',owner),0);
  });
  await check('candidate changes exactly one predicate and the exact guarded migration applies',async()=>{
    await db.exec(migration);
    candidate = await definition();
    assert.equal(hash(candidate), 'c0d6b0cd8bad21aad20000a83389e8e40863b399d33a6a9c68584557bbc111a5');
    assert.equal(candidate.replace(/    if v_plan_id <> v_expected_plan\n       and not coalesce\(\(\n         p_provider = 'apple'\n         and p_environment = 'sandbox'\n         and p_product_id in \('bil_premium', 'bil_premium_annual'\)\n         and v_plan_id = 'premium'\n         and v_expected_plan = 'premium_ai_coach'\n       \), false\) then/, '    if v_plan_id <> v_expected_plan then'),preimage);
  });
  const firstOwner=owner;
  for(const product of ['bil_premium','bil_premium_annual']){
    const n=owner++;
    await check(`GREEN ${product} Sandbox JOR persists only the paid Premium plan and no AI/trial/tokens`,async()=>{
      assert.equal(await receipt(n,{product}),true);
      const row=(await db.query('select provider,product_id,plan_id,environment,store_country_code from public.bil_subscriptions where owner_id=$1',[uid(n)])).rows[0];
      assert.deepEqual(row,{provider:'apple',product_id:product,plan_id:'premium',environment:'sandbox',store_country_code:'JOR'});
      assert.equal(await countRows('bil_entitlements',n,"and entitlement_id='plan:premium' and active"),1);
      await assertNoAI(n);
    });
  }
  for(const country of ['JO','US','USA','JOR','AE','ARE']){
    await check(`known AI market ${country} accepts lower-tier Apple Sandbox monthly receipt`,async()=>{
      const n=owner++;assert.equal(await receipt(n,{country}),true);await assertNoAI(n);
    });
  }
  for(const country of ['EG','NG','PK','TR','EGY','NGA','PAK','TUR']){
    await check(`reverse AI-in-Premium-market remains rejected for ${country}`,async()=>{
      const n=owner++;await assert.rejects(()=>receipt(n,{product:'bil_premium_ai_coach',country}),/market_plan_mismatch/);
      assert.equal(await countRows('bil_subscriptions',n),0);assert.equal(await countRows('bil_entitlements',n),0);
    });
  }
  for(const environment of ['sandbox','production']){
    await check(`normal Premium-in-EGY ${environment} remains valid`,async()=>{const n=owner++;assert.equal(await receipt(n,{environment,country:'EGY'}),true);await assertNoAI(n);});
    await check(`normal AI-in-JOR ${environment} remains valid`,async()=>{const n=owner++;assert.equal(await receipt(n,{environment,product:'bil_premium_ai_coach'}),true);assert.equal(await scalar('select plan_id as value from public.bil_subscriptions where owner_id=$1',[uid(n)]),'premium_ai_coach');});
  }
  for(const provider of ['apple','google']){
    for(const product of ['bil_premium','bil_premium_annual']){
      await check(`${provider} Production lower-tier mismatch remains rejected for ${product}`,async()=>{const n=owner++;await assert.rejects(()=>receipt(n,{provider,product,environment:'production'}),/market_plan_mismatch/);assert.equal(await countRows('bil_subscriptions',n),0);});
    }
  }
  await check('Google Sandbox lower-tier mismatch remains rejected',async()=>{const n=owner++;await assert.rejects(()=>receipt(n,{provider:'google'}),/market_plan_mismatch/);assert.equal(await countRows('bil_subscriptions',n),0);});
  for(const country of ['BY','CN','RU','BLR','CHN','RUS','ZZ','ZZZ']){
    await check(`held or unknown country ${country} is not an exception`,async()=>{const n=owner++;await assert.rejects(()=>receipt(n,{country}),/market_plan_mismatch/);assert.equal(await countRows('bil_subscriptions',n),0);});
  }
  await check('Production missing country still fails before any grant',async()=>{const n=owner++;await assert.rejects(()=>receipt(n,{environment:'production',country:null}),/store_country_required/);assert.equal(await countRows('bil_entitlements',n),0);});
  await check('disabled exact SKU cannot use the recovery exception',async()=>{
    await db.exec("update public.bil_store_product_registry set enabled=false where provider='apple' and product_id='bil_premium'");
    try{const n=owner++;await assert.rejects(()=>receipt(n),/product_not_enabled/);assert.equal(await countRows('bil_subscriptions',n),0);}finally{await db.exec("update public.bil_store_product_registry set enabled=true where provider='apple' and product_id='bil_premium'");}
  });
  await check('wrong bundle and unregistered/alias SKU remain rejected',async()=>{
    for(const o of [{bundle:'foreign.bundle'},{product:'bil_premium_ALIAS'},{product:'BIL_PREMIUM'},{product:' bil_premium'}]){const n=owner++;await assert.rejects(()=>receipt(n,o),/product_not_enabled/);assert.equal(await countRows('bil_entitlements',n),0);}
  });
  await check('another BIL owner cannot take the already persisted exact subscription chain',async()=>{
    const n=owner++;await assert.rejects(()=>receipt(n,{chain:`receipt-${firstOwner}`}),/duplicate key value|unique constraint/);assert.equal(await countRows('bil_subscriptions',n),0);assert.equal(await countRows('bil_entitlements',n),0);assert.equal(await countRows('bil_store_entitlement_audit',n),0);assert.equal(await scalar('select plan_id as value from public.bil_subscriptions where owner_id=$1',[uid(firstOwner)]),'premium');
  });
  for(const lifecycle of ['expired','refunded','revoked','pending','account_hold','suspended']){
    await check(`${lifecycle} lower-tier receipt never grants active access`,async()=>{const n=owner++;assert.equal(await receipt(n,{lifecycle}),false);assert.equal(await countRows('bil_entitlements',n,'and active'),0);await assertNoAI(n);});
  }
  await check('exact expiry remains inactive even with eligible Sandbox recovery',async()=>{
    await db.exec('begin');try{const boundary=await scalar('select now()::text as value'),n=owner++;assert.equal(await receipt(n,{expires:boundary}),false);assert.equal(await countRows('bil_entitlements',n,'and active'),0);}finally{await db.exec('rollback');}
  });
  await check('ordinary JWT roles still fail service-role guard and helper ACLs stay private',async()=>{
    for(const role of ['anon','authenticated']){
      await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role,sub:uid(owner)})]);
      try{await assert.rejects(()=>receipt(owner),/service_role_required/);}finally{await db.exec("select set_config('request.jwt.claims','{\"role\":\"service_role\"}',false)");}
      assert.equal(await scalar('select has_function_privilege($1,$2,$3) as value',[role,signature,'execute']),false);
    }
    assert.equal(await scalar('select has_function_privilege($1,$2,$3) as value',['service_role',signature,'execute']),false);
  });
  await check('terminal exact-owner cleanup still revokes after country and enabled-product policy drift',async()=>{
    await db.exec("update public.bil_store_product_registry set enabled=false where provider='apple' and product_id='bil_premium'");
    try{assert.equal(await receipt(firstOwner,{lifecycle:'revoked',country:null}),false);assert.equal(await countRows('bil_entitlements',firstOwner,'and active'),0);}finally{await db.exec("update public.bil_store_product_registry set enabled=true where provider='apple' and product_id='bil_premium'");}
  });
  await check('a repeated migration stops on changed preimage without silently applying again',async()=>{
    await assert.rejects(()=>db.exec(migration),/unexpected_market_guard_preimage/);await db.exec('rollback');assert.equal(await definition(),candidate);
  });
  assert.equal(checks, 49, 'All original meaningful SQL regression checks must execute.');
  console.log(`PASS: ${checks} real local PostgreSQL receipt-recovery checks`);
} finally {
  await db.close();
}
