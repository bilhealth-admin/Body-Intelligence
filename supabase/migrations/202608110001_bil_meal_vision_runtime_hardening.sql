begin;

-- Additive hardening for installations that already applied 202608100003.
alter table public.bil_vision_request_receipts
  add column if not exists provider_attempts integer not null default 0
    check (provider_attempts between 0 and 2),
  add column if not exists cost_source text
    check (cost_source is null or cost_source in ('provider','pricing_table','billing_reconciliation','unavailable'));

create table if not exists public.bil_vision_runtime_config (
  singleton boolean primary key default true check (singleton),
  reservation_ttl_seconds integer not null check (reservation_ttl_seconds between 60 and 3600),
  max_provider_attempts integer not null check (max_provider_attempts between 1 and 2),
  updated_at timestamptz not null default now()
);
insert into public.bil_vision_runtime_config(singleton,reservation_ttl_seconds,max_provider_attempts)
values (true,900,2)
on conflict (singleton) do nothing;

create table if not exists public.bil_vision_model_pricing (
  provider text not null,
  model text not null,
  policy_version text not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  input_usd_per_million_tokens numeric(14,8) not null check (input_usd_per_million_tokens >= 0),
  output_usd_per_million_tokens numeric(14,8) not null check (output_usd_per_million_tokens >= 0),
  source_reference text not null,
  created_at timestamptz not null default now(),
  primary key(provider,model,policy_version),
  check (effective_to is null or effective_to > effective_from)
);

-- Versioned paid-tier rates from the official Gemini Developer API pricing
-- page. Keep historical rows when rates change; insert a new policy version.
insert into public.bil_vision_model_pricing(
  provider, model, policy_version, effective_from,
  input_usd_per_million_tokens, output_usd_per_million_tokens,
  source_reference
) values (
  'gemini', 'gemini-2.5-flash', 'google-ai-pricing-2026-08-11',
  '2026-08-11T00:00:00Z', 0.30, 2.50,
  'https://ai.google.dev/gemini-api/docs/pricing'
) on conflict (provider, model, policy_version) do update set
  input_usd_per_million_tokens = excluded.input_usd_per_million_tokens,
  output_usd_per_million_tokens = excluded.output_usd_per_million_tokens,
  source_reference = excluded.source_reference;

alter table public.bil_vision_runtime_config enable row level security;
alter table public.bil_vision_model_pricing enable row level security;
revoke all on public.bil_vision_runtime_config, public.bil_vision_model_pricing
  from public, anon, authenticated;

create or replace function public.bil_reclaim_stale_vision_reservations()
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_ttl integer;
  v_count integer := 0;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  select reservation_ttl_seconds into v_ttl
    from public.bil_vision_runtime_config where singleton=true;
  if v_ttl is null then raise exception 'vision_runtime_not_configured'; end if;

  with stale as (
    update public.bil_vision_request_receipts
       set state='refunded', completed_at=now(), cost_source='unavailable'
     where owner_id=v_owner and state='reserved'
       and created_at < now() - make_interval(secs => v_ttl)
     returning period_start
  ), counts as (
    select period_start,count(*)::integer as reclaimed
      from stale group by period_start
  ), corrected as (
    update public.bil_vision_monthly_usage u
       set reserved=greatest(u.reserved-c.reclaimed,0), updated_at=now()
      from counts c
     where u.owner_id=v_owner and u.period_start=c.period_start
    returning c.reclaimed
  )
  select coalesce(sum(reclaimed),0)::integer into v_count from corrected;
  return v_count;
end $$;

create or replace function public.bil_estimate_vision_cost(
  p_provider text, p_model text, p_input_tokens integer, p_output_tokens integer
) returns numeric language plpgsql security definer set search_path = public as $$
declare
  v_input numeric;
  v_output numeric;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if coalesce(p_input_tokens,-1) < 0 or coalesce(p_output_tokens,-1) < 0 then
    return null;
  end if;
  select input_usd_per_million_tokens,output_usd_per_million_tokens
    into v_input,v_output
    from public.bil_vision_model_pricing
   where provider=trim(lower(p_provider)) and model=trim(p_model)
     and effective_from<=now() and (effective_to is null or effective_to>now())
   order by effective_from desc limit 1;
  if not found then return null; end if;
  return round((p_input_tokens*v_input+p_output_tokens*v_output)/1000000,8);
end $$;

-- Preserve the public signature while fixing immediate reservation telemetry.
create or replace function public.bil_reserve_vision_request(
  p_request_id text, p_image_digest text
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_period date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_limit integer;
  v_usage public.bil_vision_monthly_usage%rowtype;
  v_receipt public.bil_vision_request_receipts%rowtype;
  v_reusing_refund boolean := false;
  v_reclaimed integer;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  v_reclaimed := public.bil_reclaim_stale_vision_reservations();
  if length(trim(p_request_id)) not between 16 and 128
     or p_image_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_vision_request';
  end if;

  select case when exists (
    select 1 from public.bil_subscriptions s
    where s.owner_id=v_owner and s.plan_id in ('pro','plus')
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at>now())
  ) then 'pro' else 'free' end into v_plan;
  select monthly_limit into v_limit from public.bil_vision_quota_config where plan_id=v_plan;
  if v_limit is null then raise exception 'vision_quota_not_configured'; end if;

  select * into v_receipt from public.bil_vision_request_receipts
   where owner_id=v_owner and request_id=trim(p_request_id);
  if found then
    if v_receipt.image_digest<>p_image_digest then raise exception 'idempotency_payload_mismatch'; end if;
    if v_receipt.state<>'refunded' then
      return jsonb_build_object('duplicate',true,'state',v_receipt.state,
        'response_body',v_receipt.response_body);
    end if;
    v_reusing_refund:=true;
  end if;
  if exists (select 1 from public.bil_vision_request_receipts where owner_id=v_owner
      and image_digest=p_image_digest and period_start=v_period
      and request_id<>trim(p_request_id)) then
    raise exception 'duplicate_image';
  end if;

  insert into public.bil_vision_monthly_usage(owner_id,period_start)
  values(v_owner,v_period) on conflict do nothing;
  select * into v_usage from public.bil_vision_monthly_usage
   where owner_id=v_owner and period_start=v_period for update;
  if v_usage.used+v_usage.reserved>=v_limit then raise exception 'vision_quota_exhausted'; end if;
  update public.bil_vision_monthly_usage set reserved=reserved+1,updated_at=now()
   where owner_id=v_owner and period_start=v_period;
  if v_reusing_refund then
    update public.bil_vision_request_receipts set state='reserved',period_start=v_period,
      provider=null,model=null,latency_ms=null,input_tokens=null,output_tokens=null,
      cost_usd=null,response_body=null,completed_at=null,provider_attempts=0,cost_source=null,
      created_at=now() where owner_id=v_owner and request_id=trim(p_request_id);
  else
    insert into public.bil_vision_request_receipts(owner_id,request_id,image_digest,period_start,state)
    values(v_owner,trim(p_request_id),p_image_digest,v_period,'reserved');
  end if;
  return jsonb_build_object('duplicate',false,'state','reserved','limit',v_limit,
    'used',v_usage.used,'reserved',v_usage.reserved+1,
    'remaining',greatest(v_limit-v_usage.used-v_usage.reserved-1,0),
    'reclaimed_stale',v_reclaimed);
end $$;

create or replace function public.bil_settle_vision_request_v2(
  p_request_id text, p_succeeded boolean, p_provider text default null,
  p_model text default null, p_latency_ms integer default null,
  p_input_tokens integer default null, p_output_tokens integer default null,
  p_cost_usd numeric default null, p_response_body jsonb default null,
  p_provider_attempts integer default 1, p_cost_source text default 'unavailable'
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_receipt public.bil_vision_request_receipts%rowtype;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  if p_provider_attempts not between 0 and 2 or
     p_cost_source not in ('provider','pricing_table','billing_reconciliation','unavailable') then
    raise exception 'invalid_vision_metrics';
  end if;
  select * into v_receipt from public.bil_vision_request_receipts
   where owner_id=v_owner and request_id=trim(p_request_id) for update;
  if not found then raise exception 'unknown_vision_reservation'; end if;
  if v_receipt.state<>'reserved' then
    return jsonb_build_object('state',v_receipt.state,'duplicate',true,
      'response_body',v_receipt.response_body);
  end if;
  if coalesce(p_latency_ms,-1)<-1 or coalesce(p_input_tokens,-1)<-1
     or coalesce(p_output_tokens,-1)<-1 or coalesce(p_cost_usd,-1)<-1 then
    raise exception 'invalid_vision_metrics';
  end if;
  update public.bil_vision_monthly_usage set
    reserved=greatest(reserved-1,0),used=used+case when p_succeeded then 1 else 0 end,
    updated_at=now() where owner_id=v_owner and period_start=v_receipt.period_start;
  update public.bil_vision_request_receipts set
    state=case when p_succeeded then 'succeeded' else 'refunded' end,
    provider=nullif(trim(p_provider),''),model=nullif(trim(p_model),''),
    latency_ms=p_latency_ms,input_tokens=p_input_tokens,output_tokens=p_output_tokens,
    cost_usd=p_cost_usd,response_body=case when p_succeeded then p_response_body else null end,
    provider_attempts=p_provider_attempts,cost_source=p_cost_source,completed_at=now()
   where owner_id=v_owner and request_id=trim(p_request_id);
  return jsonb_build_object('state',case when p_succeeded then 'succeeded' else 'refunded' end,
    'duplicate',false);
end $$;

revoke all on function public.bil_reclaim_stale_vision_reservations(),
  public.bil_estimate_vision_cost(text,text,integer,integer),
  public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)
  from public,anon;
grant execute on function public.bil_reclaim_stale_vision_reservations(),
  public.bil_estimate_vision_cost(text,text,integer,integer),
  public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)
  to authenticated;

commit;
