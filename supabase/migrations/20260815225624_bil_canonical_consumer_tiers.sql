begin;

-- Canonical consumer tiers are Free, Premium, and Premium AI Coach. Historical
-- Plus purchases remain readable but must never inherit AI Coach access.
alter table public.bil_store_product_registry
  drop constraint if exists bil_store_product_registry_plan_id_check;
alter table public.bil_subscriptions
  drop constraint if exists bil_subscriptions_plan_id_check;
alter table public.bil_store_product_registry
  drop constraint if exists bil_store_registry_only_pro_can_be_enabled;

update public.bil_store_product_registry
set plan_id = case plan_id
  when 'pro' then 'premium'
  when 'plus' then 'legacy_plus'
  else plan_id
end,
updated_at = now()
where plan_id in ('pro', 'plus');

update public.bil_subscriptions
set plan_id = case plan_id
  when 'pro' then 'premium'
  when 'plus' then 'legacy_plus'
  else plan_id
end
where plan_id in ('pro', 'plus');

-- Copy historical entitlement rows to their canonical identifiers before
-- removing the old identifiers. The target row wins only when it is newer.
insert into public.bil_entitlements(
  owner_id, entitlement_id, product_id, provider, active, starts_at, expires_at,
  source_transaction_id, server_updated_at
)
select
  owner_id,
  case entitlement_id
    when 'plan:pro' then 'plan:premium'
    when 'plan:plus' then 'plan:legacy_plus'
  end,
  product_id, provider, active, starts_at, expires_at, source_transaction_id,
  server_updated_at
from public.bil_entitlements
where entitlement_id in ('plan:pro', 'plan:plus')
on conflict (owner_id, entitlement_id) do update set
  product_id = case
    when excluded.server_updated_at >= public.bil_entitlements.server_updated_at
      then excluded.product_id else public.bil_entitlements.product_id end,
  provider = case
    when excluded.server_updated_at >= public.bil_entitlements.server_updated_at
      then excluded.provider else public.bil_entitlements.provider end,
  active = case
    when excluded.server_updated_at >= public.bil_entitlements.server_updated_at
      then excluded.active else public.bil_entitlements.active end,
  starts_at = case
    when excluded.server_updated_at >= public.bil_entitlements.server_updated_at
      then excluded.starts_at else public.bil_entitlements.starts_at end,
  expires_at = case
    when excluded.server_updated_at >= public.bil_entitlements.server_updated_at
      then excluded.expires_at else public.bil_entitlements.expires_at end,
  source_transaction_id = case
    when excluded.server_updated_at >= public.bil_entitlements.server_updated_at
      then excluded.source_transaction_id
      else public.bil_entitlements.source_transaction_id end,
  server_updated_at = greatest(
    excluded.server_updated_at,
    public.bil_entitlements.server_updated_at
  );

delete from public.bil_entitlements
where entitlement_id in ('plan:pro', 'plan:plus');

alter table public.bil_store_product_registry
  add constraint bil_store_product_registry_plan_id_check
  check (plan_id in ('premium', 'premium_ai_coach', 'legacy_plus'));
alter table public.bil_subscriptions
  add constraint bil_subscriptions_plan_id_check
  check (plan_id in ('premium', 'premium_ai_coach', 'legacy_plus'));
alter table public.bil_store_product_registry
  add constraint bil_store_registry_only_canonical_tiers_can_be_enabled
  check (not enabled or plan_id in ('premium', 'premium_ai_coach'));

-- Keep the AI quota authority synchronized exclusively from a verified store
-- subscription. Moving away from Premium AI Coach removes the quota grant.
create or replace function public.bil_sync_ai_coach_store_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.bil_ai_coach_subscriptions
    where owner_id = old.owner_id;

    update public.bil_entitlements
    set active = false,
        server_updated_at = greatest(server_updated_at, now())
    where owner_id = old.owner_id
      and entitlement_id like 'plan:%'
      and active = true;

    return old;
  end if;

  update public.bil_entitlements
  set active = false,
      server_updated_at = greatest(server_updated_at, new.verified_at)
  where owner_id = new.owner_id
    and entitlement_id like 'plan:%'
    and entitlement_id <> 'plan:' || new.plan_id
    and active = true;

  if new.plan_id = 'premium_ai_coach' then
    insert into public.bil_ai_coach_subscriptions(
      owner_id, provider, product_id, lifecycle, original_transaction_id,
      latest_transaction_id, expires_at, verified_at
    ) values (
      new.owner_id, new.provider, new.product_id, new.lifecycle,
      new.original_transaction_id, new.latest_transaction_id,
      case
        when new.lifecycle = 'grace_period' then new.grace_period_ends_at
        else new.expires_at
      end,
      new.verified_at
    )
    on conflict (owner_id) do update set
      provider = excluded.provider,
      product_id = excluded.product_id,
      lifecycle = excluded.lifecycle,
      original_transaction_id = excluded.original_transaction_id,
      latest_transaction_id = excluded.latest_transaction_id,
      expires_at = excluded.expires_at,
      verified_at = excluded.verified_at;
  else
    delete from public.bil_ai_coach_subscriptions
    where owner_id = new.owner_id;
  end if;

  return new;
end;
$$;

revoke all on function public.bil_sync_ai_coach_store_subscription()
  from public, anon, authenticated;

drop trigger if exists bil_sync_ai_coach_store_subscription_trigger
  on public.bil_subscriptions;
create trigger bil_sync_ai_coach_store_subscription_trigger
after insert or update or delete on public.bil_subscriptions
for each row execute function public.bil_sync_ai_coach_store_subscription();

-- Backfill the mirror for already verified canonical subscriptions.
insert into public.bil_ai_coach_subscriptions(
  owner_id, provider, product_id, lifecycle, original_transaction_id,
  latest_transaction_id, expires_at, verified_at
)
select
  owner_id, provider, product_id, lifecycle, original_transaction_id,
  latest_transaction_id,
  case when lifecycle = 'grace_period' then grace_period_ends_at else expires_at end,
  verified_at
from public.bil_subscriptions
where plan_id = 'premium_ai_coach'
on conflict (owner_id) do update set
  provider = excluded.provider,
  product_id = excluded.product_id,
  lifecycle = excluded.lifecycle,
  original_transaction_id = excluded.original_transaction_id,
  latest_transaction_id = excluded.latest_transaction_id,
  expires_at = excluded.expires_at,
  verified_at = excluded.verified_at;

delete from public.bil_ai_coach_subscriptions a
where not exists (
  select 1 from public.bil_subscriptions s
  where s.owner_id = a.owner_id and s.plan_id = 'premium_ai_coach'
);

-- Align the existing monthly Meal Vision quota with the canonical tiers.
alter table public.bil_vision_quota_config
  drop constraint if exists bil_vision_quota_config_plan_id_check;
update public.bil_vision_quota_config
set plan_id = case plan_id
  when 'pro' then 'premium'
  when 'plus' then 'legacy_plus'
  else plan_id
end,
updated_at = now()
where plan_id in ('pro', 'plus');
insert into public.bil_vision_quota_config(plan_id, monthly_limit)
select 'premium_ai_coach', monthly_limit
from public.bil_vision_quota_config
where plan_id = 'premium'
on conflict (plan_id) do update set
  monthly_limit = excluded.monthly_limit,
  updated_at = now();
alter table public.bil_vision_quota_config
  add constraint bil_vision_quota_config_plan_id_check
  check (plan_id in ('free', 'premium', 'premium_ai_coach', 'legacy_plus'));

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

  select coalesce((
    select case s.plan_id
      when 'premium_ai_coach' then 'premium_ai_coach'
      when 'premium' then 'premium'
      when 'legacy_plus' then 'legacy_plus'
      else null
    end
    from public.bil_subscriptions s
    where s.owner_id = v_owner
      and s.plan_id in ('premium', 'premium_ai_coach', 'legacy_plus')
      and s.lifecycle in ('trial', 'active', 'grace_period')
      and (case when s.lifecycle = 'grace_period'
        then s.grace_period_ends_at else s.expires_at end) >= now()
  ), 'free') into v_plan;
  select monthly_limit into v_limit
  from public.bil_vision_quota_config where plan_id = v_plan;
  if v_limit is null then raise exception 'vision_quota_not_configured'; end if;

  select * into v_receipt from public.bil_vision_request_receipts
   where owner_id = v_owner and request_id = trim(p_request_id);
  if found then
    if v_receipt.image_digest <> p_image_digest then
      raise exception 'idempotency_payload_mismatch';
    end if;
    if v_receipt.state <> 'refunded' then
      return jsonb_build_object('duplicate', true, 'state', v_receipt.state,
        'response_body', v_receipt.response_body);
    end if;
    v_reusing_refund := true;
  end if;
  if exists (
    select 1 from public.bil_vision_request_receipts
    where owner_id = v_owner and image_digest = p_image_digest
      and period_start = v_period and request_id <> trim(p_request_id)
  ) then
    raise exception 'duplicate_image';
  end if;

  insert into public.bil_vision_monthly_usage(owner_id, period_start)
  values(v_owner, v_period) on conflict do nothing;
  select * into v_usage from public.bil_vision_monthly_usage
   where owner_id = v_owner and period_start = v_period for update;
  if v_usage.used + v_usage.reserved >= v_limit then
    raise exception 'vision_quota_exhausted';
  end if;
  update public.bil_vision_monthly_usage
  set reserved = reserved + 1, updated_at = now()
  where owner_id = v_owner and period_start = v_period;
  if v_reusing_refund then
    update public.bil_vision_request_receipts
    set state = 'reserved', period_start = v_period, provider = null,
      model = null, latency_ms = null, input_tokens = null,
      output_tokens = null, cost_usd = null, response_body = null,
      completed_at = null, provider_attempts = 0, cost_source = null,
      created_at = now()
    where owner_id = v_owner and request_id = trim(p_request_id);
  else
    insert into public.bil_vision_request_receipts(
      owner_id, request_id, image_digest, period_start, state
    ) values (v_owner, trim(p_request_id), p_image_digest, v_period, 'reserved');
  end if;
  return jsonb_build_object(
    'duplicate', false, 'state', 'reserved', 'plan', v_plan,
    'limit', v_limit, 'used', v_usage.used,
    'reserved', v_usage.reserved + 1,
    'remaining', greatest(v_limit - v_usage.used - v_usage.reserved - 1, 0),
    'reclaimed_stale', v_reclaimed
  );
end $$;

create or replace function public.bil_get_vision_usage()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := auth.uid();
  v_period date := date_trunc('month', now() at time zone 'utc')::date;
  v_plan text;
  v_limit integer;
  v_used integer := 0;
  v_reserved integer := 0;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  select coalesce((
    select case s.plan_id
      when 'premium_ai_coach' then 'premium_ai_coach'
      when 'premium' then 'premium'
      when 'legacy_plus' then 'legacy_plus'
      else null
    end
    from public.bil_subscriptions s
    where s.owner_id = v_owner
      and s.plan_id in ('premium', 'premium_ai_coach', 'legacy_plus')
      and s.lifecycle in ('trial', 'active', 'grace_period')
      and (case when s.lifecycle = 'grace_period'
        then s.grace_period_ends_at else s.expires_at end) >= now()
  ), 'free') into v_plan;
  select monthly_limit into v_limit
  from public.bil_vision_quota_config where plan_id = v_plan;
  if v_limit is null then raise exception 'vision_quota_not_configured'; end if;
  select coalesce(u.used, 0), coalesce(u.reserved, 0)
  into v_used, v_reserved
  from public.bil_vision_monthly_usage u
  where u.owner_id = v_owner and u.period_start = v_period;
  if not found then v_used := 0; v_reserved := 0; end if;
  return jsonb_build_object(
    'period_start', v_period, 'plan', v_plan, 'limit', v_limit,
    'used', v_used, 'reserved', v_reserved,
    'remaining', greatest(v_limit - v_used - v_reserved, 0)
  );
end $$;

commit;

;
