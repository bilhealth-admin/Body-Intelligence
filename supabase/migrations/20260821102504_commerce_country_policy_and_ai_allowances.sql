begin;
-- Owner-approved commercial floor: any storefront intentionally priced below
-- either threshold is token-first. High-income storefronts start above both
-- floors; every other valid storefront fails safe to Premium + AI Boost.
create table if not exists public.bil_commerce_country_policy (
  country_code text primary key
    check (country_code ~ '^[A-Z]{2}$'),
  market_class text not null
    check (market_class in ('profitable', 'token_only')),
  target_plan text not null
    check (target_plan in ('premium', 'premium_ai_coach')),
  monthly_floor_usd numeric(8,2) not null default 6.00,
  annual_floor_usd numeric(8,2) not null default 35.00,
  classification_reason text not null,
  policy_version text not null default '2026-08-21-v1',
  updated_at timestamptz not null default now(),
  check (
    (market_class = 'profitable' and target_plan = 'premium_ai_coach')
    or (market_class = 'token_only' and target_plan = 'premium')
  )
);
alter table public.bil_commerce_country_policy enable row level security;
revoke all on table public.bil_commerce_country_policy from anon, authenticated;
grant select on table public.bil_commerce_country_policy to anon, authenticated;
drop policy if exists bil_commerce_country_policy_public_read
  on public.bil_commerce_country_policy;
create policy bil_commerce_country_policy_public_read
  on public.bil_commerce_country_policy for select to anon, authenticated
  using (true);
-- Profitable storefronts: the annual price must remain >= USD 35 and monthly
-- price >= USD 6 in the store console. Dropping below either floor requires a
-- policy update to token_only before the lower store price is published.
insert into public.bil_commerce_country_policy(
  country_code, market_class, target_plan, classification_reason
)
select code, 'profitable', 'premium_ai_coach',
  'annual>=35_usd_and_monthly>=6_usd'
from unnest(array[
  'AD','AE','AG','AS','AT','AU','AW','AX','BB','BE','BG','BH','BM','BN','BS',
  'CA','CH','CL','CR','CW','CY','CZ','DE','DK','EE','ES','FI','FO','FR','GB',
  'GG','GI','GL','GR','GU','GY','HK','HR','HU','IE','IL','IM','IS','IT','JE',
  'JP','KN','KR','KW','KY','LI','LT','LU','LV','MC','MF','MO','MP','MT','NC',
  'NL','NO','NR','NZ','OM','PA','PF','PL','PR','PT','PW','QA','RO','RU','SA',
  'SC','SE','SG','SI','SK','SM','SX','TC','TT','US','UY','VA','VG','VI'
]::text[]) code
on conflict (country_code) do update set
  market_class = excluded.market_class,
  target_plan = excluded.target_plan,
  monthly_floor_usd = excluded.monthly_floor_usd,
  annual_floor_usd = excluded.annual_floor_usd,
  classification_reason = excluded.classification_reason,
  policy_version = excluded.policy_version,
  updated_at = now();
-- Localized/token-first storefronts. This includes upper-middle, lower-middle,
-- and low-income markets in the current global launch policy.
insert into public.bil_commerce_country_policy(
  country_code, market_class, target_plan, classification_reason
)
select code, 'token_only', 'premium',
  'localized_price_below_35_annual_or_6_monthly'
from unnest(array[
  'AF','AL','AM','AO','AR','AZ','BA','BD','BF','BI','BJ','BO','BR','BT','BW',
  'BY','BZ','CD','CF','CG','CI','CM','CN','CO','CU','CV','DJ','DM','DO','DZ',
  'EC','EG','ER','ET','FJ','FM','GA','GD','GE','GM','GN','GQ','GT','GW','HN',
  'HT','ID','IN','IQ','IR','JM','JO','KE','KG','KH','KI','KM','KP','KZ','LA',
  'LB','LC','LK','LR','LS','LY','MA','MD','ME','MG','MH','MK','ML','MM','MN',
  'MR','MU','MV','MW','MX','MY','MZ','NA','NE','NG','NI','NP','PE','PG','PH',
  'PK','PS','PY','RS','RW','SB','SD','SL','SN','SO','SR','SS','ST','SV','SY',
  'SZ','TD','TG','TH','TJ','TL','TM','TN','TO','TR','TV','TZ','UA','UG','UZ',
  'VC','VE','VN','VU','WS','XK','YE','ZA','ZM','ZW'
]::text[]) code
on conflict (country_code) do update set
  market_class = excluded.market_class,
  target_plan = excluded.target_plan,
  monthly_floor_usd = excluded.monthly_floor_usd,
  annual_floor_usd = excluded.annual_floor_usd,
  classification_reason = excluded.classification_reason,
  policy_version = excluded.policy_version,
  updated_at = now();
create or replace function public.bil_market_plan_for_store_country(
  p_store_country_code text
) returns text
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_code text := upper(trim(coalesce(p_store_country_code, '')));
  v_plan text;
begin
  if v_code ~ '^[A-Z]{2}$' then
    select target_plan into v_plan
    from public.bil_commerce_country_policy
    where country_code = v_code;
    return coalesce(v_plan, 'premium');
  end if;

  -- Apple signed transactions expose a three-letter storefront. Only the
  -- profitable allow-list is needed: every other/unknown code is token-first.
  if v_code = any(array[
    'AND','ARE','ATG','ASM','AUT','AUS','ABW','ALA','BRB','BEL','BGR','BHR',
    'BMU','BRN','BHS','CAN','CHE','CHL','CRI','CUW','CYP','CZE','DEU','DNK',
    'EST','ESP','FIN','FRO','FRA','GBR','GGY','GIB','GRL','GRC','GUM','GUY',
    'HKG','HRV','HUN','IRL','ISR','IMN','ISL','ITA','JEY','JPN','KNA','KOR',
    'KWT','CYM','LIE','LTU','LUX','LVA','MCO','MAF','MAC','MNP','MLT','NCL',
    'NLD','NOR','NRU','NZL','OMN','PAN','PYF','POL','PRI','PRT','PLW','QAT',
    'ROU','RUS','SAU','SYC','SWE','SGP','SVN','SVK','SMR','SXM','TCA','TTO',
    'USA','URY','VAT','VGB','VIR'
  ]::text[]) then
    return 'premium_ai_coach';
  end if;
  return 'premium';
end
$$;
revoke all on function public.bil_market_plan_for_store_country(text)
  from public;
grant execute on function public.bil_market_plan_for_store_country(text)
  to anon, authenticated, service_role;
alter table public.bil_subscriptions
  add column if not exists store_country_code text
    check (store_country_code is null or store_country_code ~ '^[A-Z]{2,3}$');
drop function if exists public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,
  boolean,timestamptz,text
);
create or replace function public.bil_persist_verified_store_purchase(
  p_owner_id uuid,
  p_provider text,
  p_product_id text,
  p_package_or_bundle_id text,
  p_lifecycle text,
  p_original_transaction_id text,
  p_latest_transaction_id text,
  p_environment text,
  p_store_country_code text,
  p_started_at timestamptz,
  p_expires_at timestamptz,
  p_grace_period_ends_at timestamptz,
  p_auto_renews boolean,
  p_verified_at timestamptz,
  p_transaction_fingerprint text
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan_id text;
  v_expected_plan text;
  v_country text := upper(trim(coalesce(p_store_country_code, '')));
  v_active boolean;
  v_access_boundary timestamptz;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_environment = 'production' and v_country !~ '^[A-Z]{2,3}$' then
    raise exception 'store_country_required';
  end if;

  select plan_id into v_plan_id
  from public.bil_store_product_registry
  where provider = p_provider
    and product_id = p_product_id
    and package_or_bundle_id = p_package_or_bundle_id
    and enabled = true;
  if v_plan_id is null then raise exception 'product_not_enabled'; end if;

  if v_country ~ '^[A-Z]{2,3}$'
     and v_plan_id in ('premium', 'premium_ai_coach') then
    v_expected_plan := public.bil_market_plan_for_store_country(v_country);
    if v_plan_id <> v_expected_plan then
      raise exception 'market_plan_mismatch';
    end if;
  end if;

  v_access_boundary := case
    when p_lifecycle = 'grace_period' then p_grace_period_ends_at
    else p_expires_at
  end;
  v_active := p_lifecycle in ('trial','active','grace_period','cancelled')
    and v_access_boundary is not null and v_access_boundary >= now();

  insert into public.bil_subscriptions(
    owner_id, provider, product_id, plan_id, lifecycle,
    original_transaction_id, latest_transaction_id, environment,
    store_country_code, started_at, expires_at, grace_period_ends_at,
    auto_renews, verified_at
  ) values (
    p_owner_id, p_provider, p_product_id, v_plan_id, p_lifecycle,
    p_original_transaction_id, p_latest_transaction_id, p_environment,
    nullif(v_country, ''), p_started_at, p_expires_at,
    p_grace_period_ends_at, p_auto_renews, p_verified_at
  ) on conflict (owner_id) do update set
    provider = excluded.provider,
    product_id = excluded.product_id,
    plan_id = excluded.plan_id,
    lifecycle = excluded.lifecycle,
    original_transaction_id = excluded.original_transaction_id,
    latest_transaction_id = excluded.latest_transaction_id,
    environment = excluded.environment,
    store_country_code = excluded.store_country_code,
    started_at = excluded.started_at,
    expires_at = excluded.expires_at,
    grace_period_ends_at = excluded.grace_period_ends_at,
    auto_renews = excluded.auto_renews,
    verified_at = excluded.verified_at,
    revision = public.bil_subscriptions.revision + 1;

  update public.bil_entitlements set active = false, server_updated_at = p_verified_at
  where owner_id = p_owner_id and entitlement_id like 'plan:%'
    and entitlement_id <> 'plan:' || v_plan_id;

  insert into public.bil_entitlements(
    owner_id, entitlement_id, product_id, provider, active, starts_at,
    expires_at, source_transaction_id, server_updated_at
  ) values (
    p_owner_id, 'plan:' || v_plan_id, p_product_id, p_provider, v_active,
    coalesce(p_started_at, p_verified_at), p_expires_at,
    p_latest_transaction_id, p_verified_at
  ) on conflict (owner_id, entitlement_id) do update set
    product_id = excluded.product_id,
    provider = excluded.provider,
    active = excluded.active,
    starts_at = excluded.starts_at,
    expires_at = excluded.expires_at,
    source_transaction_id = excluded.source_transaction_id,
    server_updated_at = excluded.server_updated_at;

  insert into public.bil_store_entitlement_audit(
    owner_id, provider, product_id, lifecycle, reason,
    transaction_fingerprint
  ) values (
    p_owner_id, p_provider, p_product_id, p_lifecycle,
    'store_verification:' || coalesce(nullif(v_country, ''), 'sandbox'),
    p_transaction_fingerprint
  );
  return v_active;
end
$$;
revoke all on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text
) from public, anon, authenticated;
grant execute on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text
) to service_role;
-- Apply the approved included allowance and repeatable Boost size.
alter table public.bil_ai_credit_config
  add column if not exists monthly_limit bigint not null default 10000
    check (monthly_limit >= 0);
update public.bil_ai_credit_config set
  weekly_limit = case when plan_id = 'ai_coach' then 2500 else 0 end,
  monthly_limit = case when plan_id = 'ai_coach' then 10000 else 0 end,
  updated_at = now()
where plan_id in ('free', 'ai_coach');
create table if not exists public.bil_ai_credit_monthly_usage (
  owner_id uuid not null references auth.users(id) on delete cascade,
  month_start date not null,
  used bigint not null default 0 check (used >= 0),
  reserved bigint not null default 0 check (reserved >= 0),
  updated_at timestamptz not null default now(),
  primary key(owner_id, month_start)
);
alter table public.bil_ai_credit_monthly_usage enable row level security;
revoke all on table public.bil_ai_credit_monthly_usage
  from public, anon, authenticated;
grant select on table public.bil_ai_credit_monthly_usage to authenticated;
drop policy if exists bil_ai_credit_monthly_usage_read_own
  on public.bil_ai_credit_monthly_usage;
create policy bil_ai_credit_monthly_usage_read_own
  on public.bil_ai_credit_monthly_usage for select to authenticated
  using (owner_id = (select auth.uid()));
create or replace function public.bil_sync_ai_monthly_usage()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_month date := date_trunc('month', now() at time zone 'utc')::date;
  v_used_delta bigint;
  v_reserved_delta bigint;
  v_limit bigint;
  v_total bigint;
begin
  if tg_op = 'INSERT' then
    v_used_delta := new.used;
    v_reserved_delta := new.reserved;
  else
    v_used_delta := new.used - old.used;
    v_reserved_delta := new.reserved - old.reserved;
  end if;
  insert into public.bil_ai_credit_monthly_usage(owner_id, month_start)
    values(new.owner_id, v_month) on conflict do nothing;
  select monthly_limit into v_limit from public.bil_ai_credit_config
    where plan_id = 'ai_coach';
  update public.bil_ai_credit_monthly_usage set
    used = greatest(used + v_used_delta, 0),
    reserved = greatest(reserved + v_reserved_delta, 0),
    updated_at = now()
  where owner_id = new.owner_id and month_start = v_month
  returning used + reserved into v_total;
  if v_limit is not null and v_total > v_limit then
    raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$$;
drop trigger if exists bil_ai_credit_monthly_usage_sync
  on public.bil_ai_credit_weekly_usage;
create trigger bil_ai_credit_monthly_usage_sync
after insert or update of used, reserved
on public.bil_ai_credit_weekly_usage
for each row execute function public.bil_sync_ai_monthly_usage();
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
  v_boost_tokens constant bigint := 2500;
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
revoke all on function public.bil_credit_ai_boost_verified(
  uuid,text,text,text,timestamptz,text
) from public, anon, authenticated;
grant execute on function public.bil_credit_ai_boost_verified(
  uuid,text,text,text,timestamptz,text
) to service_role;
commit;
