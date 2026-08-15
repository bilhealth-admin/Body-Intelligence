begin;

create table if not exists public.bil_vision_quota_config (
  plan_id text primary key check (plan_id in ('free','pro','plus')),
  monthly_limit integer not null check (monthly_limit between 0 and 100000),
  updated_at timestamptz not null default now()
);

insert into public.bil_vision_quota_config(plan_id, monthly_limit)
values ('free', 0), ('pro', 100), ('plus', 100)
on conflict (plan_id) do nothing;

create table if not exists public.bil_vision_monthly_usage (
  owner_id uuid not null references auth.users(id) on delete cascade,
  period_start date not null,
  used integer not null default 0 check (used >= 0),
  reserved integer not null default 0 check (reserved >= 0),
  updated_at timestamptz not null default now(),
  primary key (owner_id, period_start)
);

create table if not exists public.bil_vision_request_receipts (
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id text not null,
  image_digest text not null check (image_digest ~ '^[0-9a-f]{64}$'),
  period_start date not null,
  state text not null check (state in ('reserved','succeeded','refunded')),
  provider text,
  model text,
  latency_ms integer check (latency_ms is null or latency_ms >= 0),
  input_tokens integer check (input_tokens is null or input_tokens >= 0),
  output_tokens integer check (output_tokens is null or output_tokens >= 0),
  cost_usd numeric(14,8) check (cost_usd is null or cost_usd >= 0),
  response_body jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (owner_id, request_id),
  unique (owner_id, image_digest, period_start),
  check (length(request_id) between 16 and 128)
);

alter table public.bil_vision_quota_config enable row level security;
alter table public.bil_vision_monthly_usage enable row level security;
alter table public.bil_vision_request_receipts enable row level security;

-- These policies may already exist when the Vision quota contract was
-- provisioned manually before the migration ledger was adopted. Replacing
-- them makes this migration safe to reconcile without touching table data.
drop policy if exists bil_vision_usage_read_own on public.bil_vision_monthly_usage;
drop policy if exists bil_vision_receipts_read_own on public.bil_vision_request_receipts;

create policy bil_vision_usage_read_own on public.bil_vision_monthly_usage
for select to authenticated using (owner_id = (select auth.uid()));
create policy bil_vision_receipts_read_own on public.bil_vision_request_receipts
for select to authenticated using (owner_id = (select auth.uid()));

revoke all on public.bil_vision_quota_config, public.bil_vision_monthly_usage,
  public.bil_vision_request_receipts from public, anon, authenticated;
grant select on public.bil_vision_monthly_usage,
  public.bil_vision_request_receipts to authenticated;

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
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  if length(trim(p_request_id)) not between 16 and 128
     or p_image_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_vision_request';
  end if;

  select case when exists (
    select 1 from public.bil_subscriptions s
    where s.owner_id = v_owner and s.plan_id in ('pro','plus')
      and s.lifecycle in ('trial','active','grace_period')
      and (s.expires_at is null or s.expires_at > now())
  ) then 'pro' else 'free' end into v_plan;
  select monthly_limit into v_limit from public.bil_vision_quota_config where plan_id = v_plan;
  if v_limit is null then raise exception 'vision_quota_not_configured'; end if;

  select * into v_receipt from public.bil_vision_request_receipts
   where owner_id = v_owner and request_id = trim(p_request_id);
  if found then
    if v_receipt.image_digest <> p_image_digest then raise exception 'idempotency_payload_mismatch'; end if;
    if v_receipt.state <> 'refunded' then
      return jsonb_build_object('duplicate', true, 'state', v_receipt.state,
        'response_body', v_receipt.response_body);
    end if;
    v_reusing_refund := true;
  end if;
  if exists (select 1 from public.bil_vision_request_receipts where owner_id=v_owner
      and image_digest=p_image_digest and period_start=v_period
      and request_id<>trim(p_request_id)) then
    raise exception 'duplicate_image';
  end if;

  insert into public.bil_vision_monthly_usage(owner_id, period_start)
  values(v_owner, v_period) on conflict do nothing;
  select * into v_usage from public.bil_vision_monthly_usage
   where owner_id=v_owner and period_start=v_period for update;
  if v_usage.used + v_usage.reserved >= v_limit then raise exception 'vision_quota_exhausted'; end if;
  update public.bil_vision_monthly_usage set reserved=reserved+1, updated_at=now()
   where owner_id=v_owner and period_start=v_period;
  if v_reusing_refund then
    update public.bil_vision_request_receipts set state='reserved',period_start=v_period,provider=null,model=null,
      latency_ms=null,input_tokens=null,output_tokens=null,cost_usd=null,response_body=null,
      completed_at=null where owner_id=v_owner and request_id=trim(p_request_id);
  else
    insert into public.bil_vision_request_receipts(owner_id,request_id,image_digest,period_start,state)
    values(v_owner,trim(p_request_id),p_image_digest,v_period,'reserved');
  end if;
  return jsonb_build_object('duplicate',false,'state','reserved','limit',v_limit,
    'used',v_usage.used+1,'reserved',v_usage.reserved,
    'remaining',greatest(v_limit-v_usage.used-v_usage.reserved-1,0));
end $$;

create or replace function public.bil_get_vision_usage()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid(); v_period date := date_trunc('month',now() at time zone 'utc')::date;
  v_plan text; v_limit integer; v_used integer := 0; v_reserved integer := 0;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  select case when exists (select 1 from public.bil_subscriptions s where s.owner_id=v_owner
    and s.plan_id in ('pro','plus') and s.lifecycle in ('trial','active','grace_period')
    and (s.expires_at is null or s.expires_at>now())) then 'pro' else 'free' end into v_plan;
  select monthly_limit into v_limit from public.bil_vision_quota_config where plan_id=v_plan;
  if v_limit is null then raise exception 'vision_quota_not_configured'; end if;
  select coalesce(u.used,0),coalesce(u.reserved,0) into v_used,v_reserved
    from public.bil_vision_monthly_usage u where u.owner_id=v_owner and u.period_start=v_period;
  if not found then v_used:=0; v_reserved:=0; end if;
  return jsonb_build_object('period_start',v_period,'plan',v_plan,'limit',v_limit,
    'used',v_used,'reserved',v_reserved,'remaining',greatest(v_limit-v_used-v_reserved,0));
end $$;

create or replace function public.bil_settle_vision_request(
  p_request_id text, p_succeeded boolean, p_provider text default null,
  p_model text default null, p_latency_ms integer default null,
  p_input_tokens integer default null, p_output_tokens integer default null,
  p_cost_usd numeric default null, p_response_body jsonb default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_receipt public.bil_vision_request_receipts%rowtype;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  select * into v_receipt from public.bil_vision_request_receipts
   where owner_id=v_owner and request_id=trim(p_request_id) for update;
  if not found then raise exception 'unknown_vision_reservation'; end if;
  if v_receipt.state <> 'reserved' then
    return jsonb_build_object('state',v_receipt.state,'duplicate',true,'response_body',v_receipt.response_body);
  end if;
  if coalesce(p_latency_ms,-1) < -1 or coalesce(p_input_tokens,-1) < -1
     or coalesce(p_output_tokens,-1) < -1 or coalesce(p_cost_usd,-1) < -1 then
    raise exception 'invalid_vision_metrics';
  end if;
  update public.bil_vision_monthly_usage set
    reserved=greatest(reserved-1,0), used=used+case when p_succeeded then 1 else 0 end,
    updated_at=now() where owner_id=v_owner and period_start=v_receipt.period_start;
  update public.bil_vision_request_receipts set
    state=case when p_succeeded then 'succeeded' else 'refunded' end,
    provider=nullif(trim(p_provider),''), model=nullif(trim(p_model),''),
    latency_ms=p_latency_ms,input_tokens=p_input_tokens,output_tokens=p_output_tokens,
    cost_usd=p_cost_usd,response_body=case when p_succeeded then p_response_body else null end,
    completed_at=now() where owner_id=v_owner and request_id=trim(p_request_id);
  return jsonb_build_object('state',case when p_succeeded then 'succeeded' else 'refunded' end,'duplicate',false);
end $$;

revoke all on function public.bil_reserve_vision_request(text,text),
  public.bil_get_vision_usage(),
  public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)
  from public, anon;
grant execute on function public.bil_reserve_vision_request(text,text),
  public.bil_get_vision_usage(),
  public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)
  to authenticated;

commit;
