begin;

create table if not exists public.bil_ai_usage_config (
  plan_id text not null,
  capability text not null check (capability in ('vision','text','voice')),
  weekly_limit numeric(12,3) not null check (weekly_limit >= 0),
  unit text not null check (unit in ('requests','minutes')),
  updated_at timestamptz not null default now(),
  primary key(plan_id, capability)
);
insert into public.bil_ai_usage_config(plan_id,capability,weekly_limit,unit) values
  ('free','vision',0,'requests'),('free','text',0,'requests'),('free','voice',0,'minutes'),
  ('ai_coach','vision',25,'requests'),('ai_coach','text',125,'requests'),('ai_coach','voice',15,'minutes')
on conflict (plan_id,capability) do update set weekly_limit=excluded.weekly_limit,
  unit=excluded.unit,updated_at=now();

-- AI Coach is a standalone entitlement, deliberately independent from Pro.
-- No product is inserted until its price and store identifiers are approved.
create table if not exists public.bil_ai_coach_subscriptions (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  provider text not null check (provider in ('google','apple')),
  product_id text not null,
  lifecycle text not null check (lifecycle in (
    'pending','trial','active','grace_period','billing_retry','account_hold',
    'paused','suspended','deferred','cancelled','expired','refunded','revoked'
  )),
  original_transaction_id text not null,
  latest_transaction_id text not null,
  expires_at timestamptz,
  verified_at timestamptz not null,
  unique(provider,original_transaction_id)
);

create table if not exists public.bil_ai_weekly_usage (
  owner_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  capability text not null check (capability in ('vision','text','voice')),
  used numeric(12,3) not null default 0 check (used >= 0),
  reserved numeric(12,3) not null default 0 check (reserved >= 0),
  updated_at timestamptz not null default now(),
  primary key(owner_id,week_start,capability)
);

create table if not exists public.bil_ai_paid_balances (
  owner_id uuid not null references auth.users(id) on delete cascade,
  capability text not null check (capability in ('vision','text','voice')),
  granted numeric(12,3) not null default 0 check (granted >= 0),
  reserved numeric(12,3) not null default 0 check (reserved >= 0),
  used numeric(12,3) not null default 0 check (used >= 0),
  updated_at timestamptz not null default now(),
  primary key(owner_id,capability)
);
alter table public.bil_ai_paid_balances
  add constraint bil_ai_paid_balance_not_overdrawn
  check (used + reserved <= granted);

create table if not exists public.bil_ai_boost_purchases (
  store text not null check (store in ('google_play','app_store')),
  transaction_id text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null check (product_id='bil_ai_boost'),
  verified_at timestamptz not null,
  credited_at timestamptz not null default now(),
  raw_receipt_hash text not null check (raw_receipt_hash ~ '^[0-9a-f]{64}$'),
  primary key(store,transaction_id)
);

create table if not exists public.bil_ai_usage_events (
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id text not null,
  capability text not null check (capability in ('vision','text','voice')),
  state text not null check (state in ('reserved','succeeded','refunded')),
  weekly_debit numeric(12,3) not null default 0 check (weekly_debit >= 0),
  paid_debit numeric(12,3) not null default 0 check (paid_debit >= 0),
  week_start date not null,
  reservation_expires_at timestamptz not null,
  provider text, model text, input_tokens integer, output_tokens integer,
  latency_ms integer, cost_usd numeric(14,8), completed_at timestamptz,
  created_at timestamptz not null default now(),
  primary key(owner_id,request_id,capability)
);

alter table public.bil_ai_usage_config enable row level security;
alter table public.bil_ai_coach_subscriptions enable row level security;
alter table public.bil_ai_weekly_usage enable row level security;
alter table public.bil_ai_paid_balances enable row level security;
alter table public.bil_ai_boost_purchases enable row level security;
alter table public.bil_ai_usage_events enable row level security;
revoke all on public.bil_ai_usage_config,public.bil_ai_coach_subscriptions,public.bil_ai_weekly_usage,
  public.bil_ai_paid_balances,public.bil_ai_boost_purchases,public.bil_ai_usage_events
  from public,anon,authenticated;
grant select on public.bil_ai_weekly_usage,public.bil_ai_paid_balances,
  public.bil_ai_boost_purchases,public.bil_ai_usage_events,
  public.bil_ai_coach_subscriptions to authenticated;
create policy bil_ai_coach_subscriptions_read_own on public.bil_ai_coach_subscriptions
  for select to authenticated using(owner_id=auth.uid());
create policy bil_ai_weekly_usage_read_own on public.bil_ai_weekly_usage for select
  to authenticated using(owner_id=auth.uid());
create policy bil_ai_paid_balances_read_own on public.bil_ai_paid_balances for select
  to authenticated using(owner_id=auth.uid());
create policy bil_ai_boost_purchases_read_own on public.bil_ai_boost_purchases for select
  to authenticated using(owner_id=auth.uid());
create policy bil_ai_usage_events_read_own on public.bil_ai_usage_events for select
  to authenticated using(owner_id=auth.uid());

create or replace function public.bil_credit_ai_boost_verified(
  p_owner_id uuid,p_store text,p_transaction_id text,p_product_id text,
  p_verified_at timestamptz,p_raw_receipt_hash text
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_inserted integer; v_existing_owner uuid;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if p_product_id<>'bil_ai_boost' or p_store not in ('google_play','app_store')
     or length(trim(p_transaction_id))<8
     or p_verified_at is null or p_verified_at>now()+interval '5 minutes'
     or p_raw_receipt_hash !~ '^[0-9a-f]{64}$' then raise exception 'invalid_verified_boost'; end if;
  insert into public.bil_ai_boost_purchases(store,transaction_id,owner_id,product_id,verified_at,raw_receipt_hash)
  values(p_store,trim(p_transaction_id),p_owner_id,p_product_id,p_verified_at,p_raw_receipt_hash)
  on conflict do nothing;
  get diagnostics v_inserted=row_count;
  if v_inserted=0 then
    select owner_id into v_existing_owner from public.bil_ai_boost_purchases
      where store=p_store and transaction_id=trim(p_transaction_id);
    if v_existing_owner is distinct from p_owner_id then
      raise exception 'purchase_owned_by_another_account';
    end if;
  end if;
  if v_inserted=1 then
    insert into public.bil_ai_paid_balances(owner_id,capability,granted) values
      (p_owner_id,'vision',25),(p_owner_id,'text',125),(p_owner_id,'voice',15)
    on conflict(owner_id,capability) do update set
      granted=public.bil_ai_paid_balances.granted+excluded.granted,updated_at=now();
  end if;
  return jsonb_build_object('credited',v_inserted=1,'product_id',p_product_id);
end $$;

revoke all on function public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text)
  from public,anon,authenticated;
grant execute on function public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text)
  to service_role;

create or replace function public.bil_reserve_ai_usage(
  p_owner_id uuid,p_request_id text,p_capability text,p_units numeric default 1
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_owner uuid:=p_owner_id; v_week date:=date_trunc('week',now() at time zone 'utc')::date;
  v_plan text; v_limit numeric; v_week_used numeric; v_week_reserved numeric;
  v_paid_granted numeric; v_paid_used numeric; v_paid_reserved numeric;
  v_week_debit numeric; v_paid_debit numeric; v_existing public.bil_ai_usage_events%rowtype;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_capability not in ('vision','text','voice') or p_units<=0 or p_units>1000
     or length(trim(p_request_id)) not between 16 and 128 then raise exception 'invalid_ai_usage_request'; end if;
  -- Reclaim only this user's expired reservations. Row locks serialize this
  -- with settlement, so a late response can never consume a refunded grant.
  for v_existing in select * from public.bil_ai_usage_events
    where owner_id=v_owner and state='reserved' and reservation_expires_at<=now()
    for update
  loop
    update public.bil_ai_weekly_usage set
      reserved=greatest(reserved-v_existing.weekly_debit,0),updated_at=now()
      where owner_id=v_owner and week_start=v_existing.week_start
        and capability=v_existing.capability;
    update public.bil_ai_paid_balances set
      reserved=greatest(reserved-v_existing.paid_debit,0),updated_at=now()
      where owner_id=v_owner and capability=v_existing.capability;
    update public.bil_ai_usage_events set state='refunded',completed_at=now()
      where owner_id=v_owner and request_id=v_existing.request_id
        and capability=v_existing.capability;
  end loop;
  select * into v_existing from public.bil_ai_usage_events where owner_id=v_owner
    and request_id=trim(p_request_id) and capability=p_capability;
  if found then return jsonb_build_object('duplicate',true,'state',v_existing.state); end if;
  select case when exists(select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id=v_owner and s.lifecycle in ('trial','active','grace_period')
    and (s.expires_at is null or s.expires_at>now())) then 'ai_coach' else 'free' end into v_plan;
  select weekly_limit into v_limit from public.bil_ai_usage_config
    where plan_id=v_plan and capability=p_capability;
  if v_limit is null then raise exception 'ai_usage_not_configured'; end if;
  insert into public.bil_ai_weekly_usage(owner_id,week_start,capability)
    values(v_owner,v_week,p_capability) on conflict do nothing;
  select used,reserved into v_week_used,v_week_reserved from public.bil_ai_weekly_usage
    where owner_id=v_owner and week_start=v_week and capability=p_capability for update;
  insert into public.bil_ai_paid_balances(owner_id,capability) values(v_owner,p_capability)
    on conflict do nothing;
  select granted,used,reserved into v_paid_granted,v_paid_used,v_paid_reserved
    from public.bil_ai_paid_balances where owner_id=v_owner and capability=p_capability for update;
  v_week_debit:=least(p_units,greatest(v_limit-v_week_used-v_week_reserved,0));
  v_paid_debit:=p_units-v_week_debit;
  if v_paid_debit>greatest(v_paid_granted-v_paid_used-v_paid_reserved,0) then
    raise exception 'ai_usage_exhausted'; end if;
  update public.bil_ai_weekly_usage set reserved=reserved+v_week_debit,updated_at=now()
    where owner_id=v_owner and week_start=v_week and capability=p_capability;
  update public.bil_ai_paid_balances set reserved=reserved+v_paid_debit,updated_at=now()
    where owner_id=v_owner and capability=p_capability;
  insert into public.bil_ai_usage_events(owner_id,request_id,capability,state,
    weekly_debit,paid_debit,week_start,reservation_expires_at)
    values(v_owner,trim(p_request_id),p_capability,'reserved',v_week_debit,
      v_paid_debit,v_week,now()+interval '15 minutes');
  return jsonb_build_object('duplicate',false,'state','reserved','weekly_debit',v_week_debit,
    'paid_debit',v_paid_debit,'week_start',v_week,'reset_at',(v_week+7)::date);
end $$;

create or replace function public.bil_settle_ai_usage(
  p_owner_id uuid,p_request_id text,p_capability text,p_succeeded boolean,p_provider text default null,
  p_model text default null,p_input_tokens integer default null,p_output_tokens integer default null,
  p_latency_ms integer default null,p_cost_usd numeric default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_owner uuid:=p_owner_id; v_event public.bil_ai_usage_events%rowtype;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_input_tokens<0 or p_output_tokens<0 or p_latency_ms<0 or p_cost_usd<0 then
    raise exception 'invalid_ai_usage_telemetry'; end if;
  select * into v_event from public.bil_ai_usage_events where owner_id=v_owner
    and request_id=trim(p_request_id) and capability=p_capability for update;
  if not found then raise exception 'unknown_ai_usage_reservation'; end if;
  if v_event.state<>'reserved' then return jsonb_build_object('duplicate',true,'state',v_event.state); end if;
  if v_event.reservation_expires_at<=now() then
    update public.bil_ai_weekly_usage set reserved=greatest(reserved-v_event.weekly_debit,0),
      updated_at=now() where owner_id=v_owner and week_start=v_event.week_start
      and capability=p_capability;
    update public.bil_ai_paid_balances set reserved=greatest(reserved-v_event.paid_debit,0),
      updated_at=now() where owner_id=v_owner and capability=p_capability;
    update public.bil_ai_usage_events set state='refunded',completed_at=now()
      where owner_id=v_owner and request_id=trim(p_request_id) and capability=p_capability;
    return jsonb_build_object('duplicate',false,'state','refunded','reason','reservation_expired');
  end if;
  update public.bil_ai_weekly_usage set reserved=greatest(reserved-v_event.weekly_debit,0),
    used=used+case when p_succeeded then v_event.weekly_debit else 0 end,updated_at=now()
    where owner_id=v_owner and week_start=v_event.week_start
      and capability=p_capability;
  update public.bil_ai_paid_balances set reserved=greatest(reserved-v_event.paid_debit,0),
    used=used+case when p_succeeded then v_event.paid_debit else 0 end,updated_at=now()
    where owner_id=v_owner and capability=p_capability;
  update public.bil_ai_usage_events set state=case when p_succeeded then 'succeeded' else 'refunded' end,
    provider=nullif(trim(p_provider),''),model=nullif(trim(p_model),''),input_tokens=p_input_tokens,
    output_tokens=p_output_tokens,latency_ms=p_latency_ms,cost_usd=p_cost_usd,completed_at=now()
    where owner_id=v_owner and request_id=trim(p_request_id) and capability=p_capability;
  return jsonb_build_object('duplicate',false,'state',case when p_succeeded then 'succeeded' else 'refunded' end);
end $$;

revoke all on function public.bil_reserve_ai_usage(uuid,text,text,numeric),
  public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)
  from public,anon,authenticated;
grant execute on function public.bil_reserve_ai_usage(uuid,text,text,numeric),
  public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)
  to service_role;

create or replace function public.bil_get_ai_usage_status()
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_owner uuid:=auth.uid();
  v_week date:=date_trunc('week',now() at time zone 'utc')::date;
  v_plan text;
  v_capability text;
  v_limit numeric;
  v_used numeric;
  v_reserved numeric;
  v_granted numeric;
  v_paid_used numeric;
  v_paid_reserved numeric;
  v_event public.bil_ai_usage_events%rowtype;
  v_rows jsonb:='{}'::jsonb;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  for v_event in select * from public.bil_ai_usage_events
    where owner_id=v_owner and state='reserved' and reservation_expires_at<=now()
    for update
  loop
    update public.bil_ai_weekly_usage set
      reserved=greatest(reserved-v_event.weekly_debit,0),updated_at=now()
      where owner_id=v_owner and week_start=v_event.week_start
        and capability=v_event.capability;
    update public.bil_ai_paid_balances set
      reserved=greatest(reserved-v_event.paid_debit,0),updated_at=now()
      where owner_id=v_owner and capability=v_event.capability;
    update public.bil_ai_usage_events set state='refunded',completed_at=now()
      where owner_id=v_owner and request_id=v_event.request_id
        and capability=v_event.capability;
  end loop;
  select case when exists(select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id=v_owner and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at>now())) then 'ai_coach' else 'free' end
    into v_plan;
  foreach v_capability in array array['vision','text','voice'] loop
    select weekly_limit into v_limit from public.bil_ai_usage_config
      where plan_id=v_plan and capability=v_capability;
    select coalesce(used,0),coalesce(reserved,0) into v_used,v_reserved
      from public.bil_ai_weekly_usage where owner_id=v_owner
      and week_start=v_week and capability=v_capability;
    if not found then v_used:=0; v_reserved:=0; end if;
    select coalesce(granted,0),coalesce(used,0),coalesce(reserved,0)
      into v_granted,v_paid_used,v_paid_reserved
      from public.bil_ai_paid_balances where owner_id=v_owner
      and capability=v_capability;
    if not found then v_granted:=0; v_paid_used:=0; v_paid_reserved:=0; end if;
    v_rows:=v_rows||jsonb_build_object(v_capability,jsonb_build_object(
      'unit',case when v_capability='voice' then 'minutes' else 'requests' end,
      'weekly_limit',v_limit,'weekly_used',v_used,'weekly_reserved',v_reserved,
      'weekly_remaining',greatest(v_limit-v_used-v_reserved,0),
      'paid_granted',v_granted,'paid_used',v_paid_used,'paid_reserved',v_paid_reserved,
      'paid_remaining',greatest(v_granted-v_paid_used-v_paid_reserved,0)));
  end loop;
  return jsonb_build_object('plan',v_plan,'week_start',v_week,
    'reset_at',(v_week+7)::date,'capabilities',v_rows);
end $$;

revoke all on function public.bil_get_ai_usage_status() from public,anon;
grant execute on function public.bil_get_ai_usage_status() to authenticated;

commit;
