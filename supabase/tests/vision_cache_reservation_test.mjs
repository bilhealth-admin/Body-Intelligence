// Executes the actual migration and current shared-meter wrapper in local Postgres.
// Refund stub isolates the cache ordering; live E2E verifies real settlement.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {PGlite} from '@electric-sql/pglite';
const db = new PGlite();
const owner = '48000000-0000-4000-8000-000000000001';
const digest = 'a'.repeat(64);
const read = p => readFileSync(p, 'utf8');
try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    create function auth.jwt() returns jsonb language sql stable as $$
      select jsonb_build_object('role',coalesce(current_setting('test.role',true),'service_role')) $$;
    create table public.bil_ai_usage_events(owner_id uuid,request_id text,capability text,state text,
      payload_digest text,response_body jsonb,result_kind text,completed_at timestamptz,
      week_start date,reservation_expires_at timestamptz,weekly_debit numeric,paid_debit numeric,
      credit_reserved bigint,credit_weekly_debit bigint,credit_paid_debit bigint,
      credit_rate_version text,credit_actual bigint,primary key(owner_id,request_id,capability));
    create unique index bil_ai_one_live_vision_per_payload on public.bil_ai_usage_events(owner_id,capability,payload_digest)
      where capability='vision' and payload_digest is not null and state in ('reserved','succeeded');
    create table public.bil_ai_credit_balances(owner_id uuid primary key,granted bigint default 0,used bigint default 0,reserved bigint default 0,updated_at timestamptz);
    create table public.bil_ai_credit_weekly_usage(owner_id uuid,week_start date,reserved bigint,updated_at timestamptz);
    create table public.bil_ai_weekly_usage(owner_id uuid,week_start date,capability text,reserved numeric,updated_at timestamptz);
    create table public.bil_ai_paid_balances(owner_id uuid,capability text,reserved numeric,updated_at timestamptz);
    create function public.bil_reserve_ai_usage(uuid,text,text,numeric) returns jsonb language plpgsql as $$
    begin
      if (select granted-used-reserved from public.bil_ai_credit_balances where owner_id=$1) < 100 then raise exception 'ai_usage_exhausted'; end if;
      update public.bil_ai_credit_balances set reserved=reserved+100 where owner_id=$1;
      insert into public.bil_ai_usage_events(owner_id,request_id,capability,state,credit_reserved,credit_paid_debit) values($1,$2,$3,'reserved',100,100);
      return jsonb_build_object('duplicate',false,'state','reserved','paid_tokens_reserved',100);
    end $$;
    create function public.bil_settle_ai_usage(uuid,text,text,boolean) returns jsonb language plpgsql as $$
    begin
      if $4 then raise exception 'fixture is refund-only'; end if;
      update public.bil_ai_credit_balances set reserved=reserved-100 where owner_id=$1;
      update public.bil_ai_usage_events set state='refunded',credit_actual=0 where owner_id=$1 and request_id=$2 and capability=$3;
      return jsonb_build_object('state','refunded');
    end $$;
  `);
  await db.exec(read('supabase/migrations/20260918120000_meal_vision_uses_shared_ai_coach_tokens.sql'));
  await db.exec(read('supabase/migrations/20261018143000_vision_cache_replay_before_digest_reservation.sql'));
  await db.query('insert into bil_ai_credit_balances(owner_id,granted,used) values($1,1000,47)',[owner]);
  await db.query(`insert into bil_ai_usage_events(owner_id,request_id,capability,state,payload_digest,result_kind,response_body,completed_at)
    values($1,'original-food-0001','vision','succeeded',$2,'food','{"candidates":[{"name":"food"}]}',now())`,[owner,digest]);
  const reserve = async (id, hash=digest) => (await db.query('select bil_reserve_ai_vision($1,$2,$3) as value',[owner,id,hash])).rows[0].value;
  const cached = await reserve('cached-request-0001');
  assert.equal(cached.cache_hit,true);
  assert.equal(cached.state,'succeeded');
  assert.deepEqual(await reserve('cached-request-0001'),cached);
  const balance = (await db.query('select used,reserved from bil_ai_credit_balances where owner_id=$1',[owner])).rows[0];
  assert.deepEqual(balance,{used:47,reserved:0});
  const event = (await db.query("select state,credit_actual,payload_digest from bil_ai_usage_events where request_id='cached-request-0001'")).rows[0];
  assert.equal(event.state,'refunded'); assert.equal(event.credit_actual,0); assert.equal(event.payload_digest,digest);
  await assert.rejects(reserve('cached-request-0001','b'.repeat(64)),/idempotency_payload_mismatch/);
  await db.query('update bil_ai_credit_balances set granted=47 where owner_id=$1',[owner]);
  await assert.rejects(reserve('unfunded-cache-0001'),/ai_usage_exhausted/);
  await db.query('update bil_ai_credit_balances set granted=1000 where owner_id=$1',[owner]);
  assert.equal((await reserve('first-provider-0001','c'.repeat(64))).duplicate,false);
  await assert.rejects(reserve('duplicate-live-0001','c'.repeat(64)),/duplicate_image/);
  await db.exec("select set_config('test.role','authenticated',false)");
  await assert.rejects(reserve('unauthorized-0001'),/service_role_required/);
  await db.exec("select set_config('test.role','service_role',false)");
  await assert.rejects(reserve('invalid-digest-0001',null),/invalid_image_digest/);
  const acl = (await db.query("select has_function_privilege('authenticated','public.bil_reserve_ai_vision(uuid,text,text)','EXECUTE') as authenticated,has_function_privilege('anon','public.bil_reserve_ai_vision(uuid,text,text)','EXECUTE') as anon,has_function_privilege('service_role','public.bil_reserve_ai_vision(uuid,text,text)','EXECUTE') as service")).rows[0];
  assert.deepEqual(acl,{authenticated:false,anon:false,service:true});
  console.log('PASS: real unique constraint, cache and repeated cache key, shared-meter admission, digest binding, pending duplicate, role ACL, null digest; no live network');
} finally {
  await db.close();
}
