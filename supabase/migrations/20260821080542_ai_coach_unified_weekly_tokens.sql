begin;

-- One BIL AI Token represents $0.0001 of recorded provider cost. Text,
-- Vision, and cloud voice all draw from this same weekly balance.
create table if not exists public.bil_ai_credit_config (
  plan_id text primary key,
  weekly_limit bigint not null check (weekly_limit >= 0),
  updated_at timestamptz not null default now()
);

insert into public.bil_ai_credit_config(plan_id, weekly_limit) values
  ('free', 0),
  ('ai_coach', 5000)
on conflict (plan_id) do update set
  weekly_limit = excluded.weekly_limit,
  updated_at = now();

create table if not exists public.bil_ai_credit_weekly_usage (
  owner_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  used bigint not null default 0 check (used >= 0),
  reserved bigint not null default 0 check (reserved >= 0),
  updated_at timestamptz not null default now(),
  primary key(owner_id, week_start)
);

create table if not exists public.bil_ai_credit_balances (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  granted bigint not null default 0 check (granted >= 0),
  used bigint not null default 0 check (used >= 0),
  reserved bigint not null default 0 check (reserved >= 0),
  updated_at timestamptz not null default now(),
  constraint bil_ai_credit_balance_not_overdrawn
    check (used + reserved <= granted)
);

alter table public.bil_ai_credit_config enable row level security;
alter table public.bil_ai_credit_weekly_usage enable row level security;
alter table public.bil_ai_credit_balances enable row level security;

revoke all on public.bil_ai_credit_config,
  public.bil_ai_credit_weekly_usage,
  public.bil_ai_credit_balances
  from public, anon, authenticated;
grant select on public.bil_ai_credit_weekly_usage,
  public.bil_ai_credit_balances to authenticated;

drop policy if exists bil_ai_credit_weekly_usage_read_own
  on public.bil_ai_credit_weekly_usage;
create policy bil_ai_credit_weekly_usage_read_own
  on public.bil_ai_credit_weekly_usage for select to authenticated
  using (owner_id = (select auth.uid()));

drop policy if exists bil_ai_credit_balances_read_own
  on public.bil_ai_credit_balances;
create policy bil_ai_credit_balances_read_own
  on public.bil_ai_credit_balances for select to authenticated
  using (owner_id = (select auth.uid()));

alter table public.bil_ai_usage_events
  add column if not exists credit_reserved bigint,
  add column if not exists credit_weekly_debit bigint,
  add column if not exists credit_paid_debit bigint,
  add column if not exists credit_actual bigint,
  add column if not exists credit_rate_version text;

alter table public.bil_ai_usage_events
  drop constraint if exists bil_ai_usage_credit_values_check;
alter table public.bil_ai_usage_events
  add constraint bil_ai_usage_credit_values_check check (
    (credit_reserved is null or credit_reserved >= 0)
    and (credit_weekly_debit is null or credit_weekly_debit >= 0)
    and (credit_paid_debit is null or credit_paid_debit >= 0)
    and (credit_actual is null or credit_actual >= 0)
    and (credit_rate_version is null or credit_rate_version = 'usd-1e-4-v1')
  );

-- Convert the old non-expiring balances without removing any purchased value.
-- The conversion uses the observed production averages established in the
-- cost audit: text 60, Vision 20, and voice-minute 400 BIL AI Tokens.
insert into public.bil_ai_credit_balances(owner_id, granted, used, reserved)
select
  owner_id,
  greatest(
    ceil(sum(granted * case capability
      when 'text' then 60 when 'vision' then 20 else 400 end))::bigint,
    ceil(sum(used * case capability
      when 'text' then 60 when 'vision' then 20 else 400 end))::bigint
      + ceil(sum(reserved * case capability
        when 'text' then 60 when 'vision' then 20 else 400 end))::bigint
  ),
  ceil(sum(used * case capability
    when 'text' then 60 when 'vision' then 20 else 400 end))::bigint,
  ceil(sum(reserved * case capability
    when 'text' then 60 when 'vision' then 20 else 400 end))::bigint
from public.bil_ai_paid_balances
group by owner_id
on conflict (owner_id) do update set
  granted = excluded.granted,
  used = excluded.used,
  reserved = excluded.reserved,
  updated_at = now();

insert into public.bil_ai_credit_weekly_usage(owner_id, week_start, used, reserved)
select
  owner_id,
  week_start,
  ceil(sum(used * case capability
    when 'text' then 60 when 'vision' then 20 else 400 end))::bigint,
  ceil(sum(reserved * case capability
    when 'text' then 60 when 'vision' then 20 else 400 end))::bigint
from public.bil_ai_weekly_usage
group by owner_id, week_start
on conflict (owner_id, week_start) do update set
  used = excluded.used,
  reserved = excluded.reserved,
  updated_at = now();

update public.bil_ai_usage_events set
  credit_reserved = case when state = 'reserved' then
    ceil((weekly_debit + paid_debit) * case capability
      when 'text' then 60 when 'vision' then 20 else 400 end)::bigint
    else 0 end,
  credit_weekly_debit = case when state = 'reserved' then
    ceil(weekly_debit * case capability
      when 'text' then 60 when 'vision' then 20 else 400 end)::bigint
    else 0 end,
  credit_paid_debit = case when state = 'reserved' then
    ceil(paid_debit * case capability
      when 'text' then 60 when 'vision' then 20 else 400 end)::bigint
    else 0 end,
  credit_actual = case
    when state = 'succeeded' and cost_usd is not null
      then ceil(cost_usd * 10000)::bigint
    when state = 'succeeded'
      then ceil((weekly_debit + paid_debit) * case capability
        when 'text' then 60 when 'vision' then 20 else 400 end)::bigint
    when state = 'refunded' then 0
    else null end,
  credit_rate_version = 'usd-1e-4-v1'
where credit_rate_version is null;

create or replace function public.bil_reserve_ai_usage(
  p_owner_id uuid,
  p_request_id text,
  p_capability text,
  p_units numeric default 1
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := p_owner_id;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_plan text;
  v_limit bigint;
  v_week_used bigint;
  v_week_reserved bigint;
  v_paid_granted bigint;
  v_paid_used bigint;
  v_paid_reserved bigint;
  v_credit_reserve bigint;
  v_week_debit bigint;
  v_paid_debit bigint;
  v_existing public.bil_ai_usage_events%rowtype;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_capability not in ('vision','text','voice')
     or p_units <= 0 or p_units > 1000
     or length(trim(p_request_id)) not between 16 and 128 then
    raise exception 'invalid_ai_usage_request';
  end if;

  v_credit_reserve := case p_capability
    when 'text' then 100
    when 'vision' then 100
    else ceil(p_units * 500)::bigint + 50
  end;

  for v_existing in
    select * from public.bil_ai_usage_events
    where owner_id = v_owner and state = 'reserved'
      and reservation_expires_at <= now()
    for update
  loop
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(reserved - coalesce(v_existing.credit_weekly_debit,0),0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_existing.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(reserved - coalesce(v_existing.credit_paid_debit,0),0),
      updated_at = now()
      where owner_id = v_owner;
    update public.bil_ai_weekly_usage set
      reserved = greatest(reserved - v_existing.weekly_debit,0), updated_at = now()
      where owner_id = v_owner and week_start = v_existing.week_start
        and capability = v_existing.capability;
    update public.bil_ai_paid_balances set
      reserved = greatest(reserved - v_existing.paid_debit,0), updated_at = now()
      where owner_id = v_owner and capability = v_existing.capability;
    update public.bil_ai_usage_events set state = 'refunded',
      credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = v_existing.request_id
        and capability = v_existing.capability;
  end loop;

  select * into v_existing from public.bil_ai_usage_events
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability;
  if found then
    return jsonb_build_object('duplicate',true,'state',v_existing.state,
      'bil_ai_tokens_reserved',coalesce(v_existing.credit_reserved,0));
  end if;

  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at > now())
  ) then 'ai_coach' else 'free' end into v_plan;

  select weekly_limit into v_limit from public.bil_ai_credit_config
    where plan_id = v_plan;
  if v_limit is null then raise exception 'ai_usage_not_configured'; end if;

  insert into public.bil_ai_credit_weekly_usage(owner_id, week_start)
    values(v_owner, v_week) on conflict do nothing;
  select used, reserved into v_week_used, v_week_reserved
    from public.bil_ai_credit_weekly_usage
    where owner_id = v_owner and week_start = v_week for update;

  insert into public.bil_ai_credit_balances(owner_id)
    values(v_owner) on conflict do nothing;
  select granted, used, reserved
    into v_paid_granted, v_paid_used, v_paid_reserved
    from public.bil_ai_credit_balances where owner_id = v_owner for update;

  v_week_debit := least(
    v_credit_reserve,
    greatest(v_limit - v_week_used - v_week_reserved,0)
  );
  v_paid_debit := v_credit_reserve - v_week_debit;
  if v_paid_debit > greatest(v_paid_granted - v_paid_used - v_paid_reserved,0)
  then raise exception 'ai_usage_exhausted'; end if;

  update public.bil_ai_credit_weekly_usage set
    reserved = reserved + v_week_debit, updated_at = now()
    where owner_id = v_owner and week_start = v_week;
  update public.bil_ai_credit_balances set
    reserved = reserved + v_paid_debit, updated_at = now()
    where owner_id = v_owner;

  insert into public.bil_ai_usage_events(
    owner_id, request_id, capability, state, weekly_debit, paid_debit,
    week_start, reservation_expires_at, credit_reserved,
    credit_weekly_debit, credit_paid_debit, credit_rate_version
  ) values (
    v_owner, trim(p_request_id), p_capability, 'reserved', 0, 0,
    v_week, now() + interval '15 minutes', v_credit_reserve,
    v_week_debit, v_paid_debit, 'usd-1e-4-v1'
  );

  return jsonb_build_object(
    'duplicate',false,'state','reserved','unit','BIL AI Token',
    'bil_ai_tokens_reserved',v_credit_reserve,
    'weekly_tokens_reserved',v_week_debit,
    'paid_tokens_reserved',v_paid_debit,
    'week_start',v_week,'reset_at',(v_week + 7)::date
  );
end
$$;

create or replace function public.bil_settle_ai_usage(
  p_owner_id uuid,
  p_request_id text,
  p_capability text,
  p_succeeded boolean,
  p_provider text default null,
  p_model text default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_latency_ms integer default null,
  p_cost_usd numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := p_owner_id;
  v_event public.bil_ai_usage_events%rowtype;
  v_actual bigint;
  v_week_actual bigint;
  v_paid_actual bigint;
  v_overage bigint;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if v_owner is null then raise exception 'owner_required'; end if;
  if p_capability not in ('vision','text','voice')
     or p_input_tokens < 0 or p_output_tokens < 0
     or p_latency_ms < 0 or p_cost_usd < 0 then
    raise exception 'invalid_ai_usage_telemetry';
  end if;

  select * into v_event from public.bil_ai_usage_events
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability for update;
  if not found then raise exception 'unknown_ai_usage_reservation'; end if;
  if v_event.state <> 'reserved' then
    return jsonb_build_object('duplicate',true,'state',v_event.state,
      'bil_ai_tokens_actual',coalesce(v_event.credit_actual,0));
  end if;

  if v_event.reservation_expires_at <= now() then
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_event.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(reserved - coalesce(v_event.credit_paid_debit,0),0),
      updated_at = now() where owner_id = v_owner;
    update public.bil_ai_usage_events set state = 'refunded',
      credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = trim(p_request_id)
        and capability = p_capability;
    return jsonb_build_object('duplicate',false,'state','refunded',
      'reason','reservation_expired','bil_ai_tokens_actual',0);
  end if;

  v_actual := case
    when not p_succeeded then 0
    when p_cost_usd is null then coalesce(v_event.credit_reserved,0)
    else ceil(p_cost_usd * 10000)::bigint
  end;
  v_week_actual := least(v_actual, coalesce(v_event.credit_weekly_debit,0));
  v_paid_actual := least(
    greatest(v_actual - v_week_actual,0),
    coalesce(v_event.credit_paid_debit,0)
  );
  v_overage := greatest(v_actual - v_week_actual - v_paid_actual,0);

  update public.bil_ai_credit_weekly_usage set
    reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
    used = used + v_week_actual + v_overage,
    updated_at = now()
    where owner_id = v_owner and week_start = v_event.week_start;
  update public.bil_ai_credit_balances set
    reserved = greatest(reserved - coalesce(v_event.credit_paid_debit,0),0),
    used = used + v_paid_actual,
    updated_at = now()
    where owner_id = v_owner;

  update public.bil_ai_usage_events set
    state = case when p_succeeded then 'succeeded' else 'refunded' end,
    provider = nullif(trim(p_provider),''),
    model = nullif(trim(p_model),''),
    input_tokens = p_input_tokens,
    output_tokens = p_output_tokens,
    latency_ms = p_latency_ms,
    cost_usd = p_cost_usd,
    credit_actual = v_actual,
    completed_at = now()
    where owner_id = v_owner and request_id = trim(p_request_id)
      and capability = p_capability;

  return jsonb_build_object(
    'duplicate',false,
    'state',case when p_succeeded then 'succeeded' else 'refunded' end,
    'unit','BIL AI Token','bil_ai_tokens_actual',v_actual,
    'weekly_tokens_debited',v_week_actual + v_overage,
    'paid_tokens_debited',v_paid_actual
  );
end
$$;

create or replace function public.bil_settle_ai_voice(
  p_owner_id uuid,
  p_request_id text,
  p_succeeded boolean,
  p_actual_seconds integer,
  p_provider text default null,
  p_model text default null,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_latency_ms integer default null,
  p_cost_usd numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.bil_ai_usage_events%rowtype;
  v_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_actual_seconds not between 0 and 900 then
    raise exception 'invalid_voice_actual_seconds';
  end if;
  select * into v_event from public.bil_ai_usage_events
    where owner_id = p_owner_id and request_id = trim(p_request_id)
      and capability = 'voice' for update;
  if not found then raise exception 'unknown_ai_usage_reservation'; end if;
  if v_event.state = 'reserved'
     and p_actual_seconds > coalesce(v_event.reserved_seconds,0) then
    raise exception 'voice_actual_exceeds_reservation';
  end if;
  v_result := public.bil_settle_ai_usage(
    p_owner_id,p_request_id,'voice',p_succeeded,p_provider,p_model,
    p_input_tokens,p_output_tokens,p_latency_ms,p_cost_usd
  );
  update public.bil_ai_usage_events set actual_seconds = p_actual_seconds
    where owner_id = p_owner_id and request_id = trim(p_request_id)
      and capability = 'voice' and actual_seconds is null;
  return v_result || jsonb_build_object('actual_seconds',p_actual_seconds);
end
$$;

create or replace function public.bil_get_ai_usage_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_plan text;
  v_limit bigint;
  v_used bigint := 0;
  v_reserved bigint := 0;
  v_granted bigint := 0;
  v_paid_used bigint := 0;
  v_paid_reserved bigint := 0;
  v_week_remaining bigint;
  v_paid_remaining bigint;
  v_shared jsonb;
  v_event public.bil_ai_usage_events%rowtype;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;

  for v_event in
    select * from public.bil_ai_usage_events
    where owner_id = v_owner and state = 'reserved'
      and reservation_expires_at <= now()
    for update
  loop
    update public.bil_ai_credit_weekly_usage set
      reserved = greatest(reserved - coalesce(v_event.credit_weekly_debit,0),0),
      updated_at = now()
      where owner_id = v_owner and week_start = v_event.week_start;
    update public.bil_ai_credit_balances set
      reserved = greatest(reserved - coalesce(v_event.credit_paid_debit,0),0),
      updated_at = now() where owner_id = v_owner;
    update public.bil_ai_weekly_usage set
      reserved = greatest(reserved - v_event.weekly_debit,0), updated_at = now()
      where owner_id = v_owner and week_start = v_event.week_start
        and capability = v_event.capability;
    update public.bil_ai_paid_balances set
      reserved = greatest(reserved - v_event.paid_debit,0), updated_at = now()
      where owner_id = v_owner and capability = v_event.capability;
    update public.bil_ai_usage_events set state = 'refunded',
      credit_actual = 0, completed_at = now()
      where owner_id = v_owner and request_id = v_event.request_id
        and capability = v_event.capability;
  end loop;

  select case when exists(
    select 1 from public.bil_ai_coach_subscriptions s
    where s.owner_id = v_owner
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at > now())
  ) then 'ai_coach' else 'free' end into v_plan;

  select weekly_limit into v_limit from public.bil_ai_credit_config
    where plan_id = v_plan;
  if v_limit is null then raise exception 'ai_usage_not_configured'; end if;

  select used, reserved into v_used, v_reserved
    from public.bil_ai_credit_weekly_usage
    where owner_id = v_owner and week_start = v_week;
  if not found then v_used := 0; v_reserved := 0; end if;
  select granted, used, reserved into v_granted, v_paid_used, v_paid_reserved
    from public.bil_ai_credit_balances where owner_id = v_owner;
  if not found then
    v_granted := 0; v_paid_used := 0; v_paid_reserved := 0;
  end if;

  v_week_remaining := greatest(v_limit - v_used - v_reserved,0);
  v_paid_remaining := greatest(v_granted - v_paid_used - v_paid_reserved,0);
  v_shared := jsonb_build_object(
    'unit','BIL AI Token','billing_scope','shared',
    'weekly_limit',v_limit,'weekly_used',v_used,
    'weekly_reserved',v_reserved,'weekly_remaining',v_week_remaining,
    'paid_granted',v_granted,'paid_used',v_paid_used,
    'paid_reserved',v_paid_reserved,'paid_remaining',v_paid_remaining,
    'total_remaining',v_week_remaining + v_paid_remaining
  );

  return jsonb_build_object(
    'plan',v_plan,'week_start',v_week,'reset_at',(v_week + 7)::date,
    'credits',v_shared,
    'capabilities',jsonb_build_object(
      'text',v_shared,'vision',v_shared,'voice',v_shared
    )
  );
end
$$;

create or replace function public.bil_credit_ai_boost_verified(
  p_owner_id uuid,
  p_store text,
  p_transaction_id text,
  p_product_id text,
  p_verified_at timestamptz,
  p_raw_receipt_hash text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer;
  v_existing_owner uuid;
  v_boost_tokens constant bigint := 5000;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_product_id <> 'bil_ai_boost'
     or p_store not in ('google_play','app_store')
     or length(trim(p_transaction_id)) < 8
     or p_verified_at is null or p_verified_at > now() + interval '5 minutes'
     or p_raw_receipt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_verified_boost';
  end if;
  insert into public.bil_ai_boost_purchases(
    store,transaction_id,owner_id,product_id,verified_at,raw_receipt_hash
  ) values (
    p_store,trim(p_transaction_id),p_owner_id,p_product_id,
    p_verified_at,p_raw_receipt_hash
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select owner_id into v_existing_owner from public.bil_ai_boost_purchases
      where store = p_store and transaction_id = trim(p_transaction_id);
    if v_existing_owner is distinct from p_owner_id then
      raise exception 'purchase_owned_by_another_account';
    end if;
  else
    insert into public.bil_ai_credit_balances(owner_id, granted)
      values(p_owner_id, v_boost_tokens)
    on conflict(owner_id) do update set
      granted = public.bil_ai_credit_balances.granted + excluded.granted,
      updated_at = now();
  end if;
  return jsonb_build_object(
    'credited',v_inserted = 1,'product_id',p_product_id,
    'unit','BIL AI Token','tokens_granted',
    case when v_inserted = 1 then v_boost_tokens else 0 end,
    'tokens_per_boost',v_boost_tokens
  );
end
$$;

create or replace function public.bil_grant_ai_agent_qa_balance(
  p_grant_id text,
  p_owner_id uuid,
  p_text_units numeric,
  p_vision_units numeric,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_inserted integer;
  v_existing public.bil_ai_qa_grants%rowtype;
  v_credit_tokens bigint;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_grant_id !~ '^[a-z0-9][a-z0-9._:-]{7,127}$'
     or p_text_units not between 0 and 250
     or p_vision_units not between 0 and 50
     or p_text_units + p_vision_units <= 0
     or length(trim(p_reason)) not between 8 and 200 then
    raise exception 'invalid_qa_grant';
  end if;
  select lower(email) into v_email from auth.users where id = p_owner_id;
  if v_email is null or v_email !~ '^[^@]+@bilhealth[.]invalid$' then
    raise exception 'qa_agent_account_required';
  end if;
  v_credit_tokens := ceil(p_text_units * 60 + p_vision_units * 20)::bigint;
  insert into public.bil_ai_qa_grants(
    grant_id,owner_id,text_units,vision_units,reason
  ) values (
    trim(p_grant_id),p_owner_id,p_text_units,p_vision_units,trim(p_reason)
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select * into v_existing from public.bil_ai_qa_grants
      where grant_id = trim(p_grant_id);
    if v_existing.owner_id is distinct from p_owner_id
       or v_existing.text_units is distinct from p_text_units
       or v_existing.vision_units is distinct from p_vision_units
       or v_existing.reason is distinct from trim(p_reason) then
      raise exception 'qa_grant_replay_conflict';
    end if;
  else
    insert into public.bil_ai_credit_balances(owner_id, granted)
      values(p_owner_id, v_credit_tokens)
    on conflict(owner_id) do update set
      granted = public.bil_ai_credit_balances.granted + excluded.granted,
      updated_at = now();
  end if;
  return jsonb_build_object(
    'credited',v_inserted = 1,'grant_id',trim(p_grant_id),
    'text_units',p_text_units,'vision_units',p_vision_units,
    'unit','BIL AI Token','tokens_granted',
    case when v_inserted = 1 then v_credit_tokens else 0 end
  );
end
$$;

revoke all on function public.bil_reserve_ai_usage(uuid,text,text,numeric),
  public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric),
  public.bil_settle_ai_voice(uuid,text,boolean,integer,text,text,integer,integer,integer,numeric),
  public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text),
  public.bil_grant_ai_agent_qa_balance(text,uuid,numeric,numeric,text)
  from public, anon, authenticated;
grant execute on function public.bil_reserve_ai_usage(uuid,text,text,numeric),
  public.bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric),
  public.bil_settle_ai_voice(uuid,text,boolean,integer,text,text,integer,integer,integer,numeric),
  public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text),
  public.bil_grant_ai_agent_qa_balance(text,uuid,numeric,numeric,text)
  to service_role;

revoke all on function public.bil_get_ai_usage_status() from public, anon;
grant execute on function public.bil_get_ai_usage_status() to authenticated;

commit;

;
