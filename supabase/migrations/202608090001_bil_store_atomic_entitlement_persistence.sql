begin;

-- Store product identifiers are scoped by provider. Apple and Google may use
-- the same immutable product ID without referring to the same store record.
alter table public.bil_subscriptions
drop constraint if exists bil_subscriptions_product_id_fkey;

alter table public.bil_store_product_registry
drop constraint if exists bil_store_product_registry_pkey;

alter table public.bil_store_product_registry
add primary key (provider, product_id);

alter table public.bil_subscriptions
add constraint bil_subscriptions_provider_product_fkey
foreign key (provider, product_id)
references public.bil_store_product_registry(provider, product_id);

create or replace function public.bil_persist_verified_store_purchase(
  p_owner_id uuid,
  p_provider text,
  p_product_id text,
  p_package_or_bundle_id text,
  p_lifecycle text,
  p_original_transaction_id text,
  p_latest_transaction_id text,
  p_environment text,
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
  v_active boolean;
  v_access_boundary timestamptz;
begin
  select plan_id
  into v_plan_id
  from public.bil_store_product_registry
  where provider = p_provider
    and product_id = p_product_id
    and package_or_bundle_id = p_package_or_bundle_id
    and enabled = true;

  if v_plan_id is null then
    raise exception using errcode = 'P0001', message = 'product_not_enabled';
  end if;

  v_access_boundary := case
    when p_lifecycle = 'grace_period' then p_grace_period_ends_at
    else p_expires_at
  end;
  v_active := p_lifecycle in ('trial', 'active', 'grace_period', 'cancelled')
    and v_access_boundary is not null
    and v_access_boundary >= now();

  insert into public.bil_subscriptions(
    owner_id,
    provider,
    product_id,
    plan_id,
    lifecycle,
    original_transaction_id,
    latest_transaction_id,
    environment,
    started_at,
    expires_at,
    grace_period_ends_at,
    auto_renews,
    verified_at
  ) values (
    p_owner_id,
    p_provider,
    p_product_id,
    v_plan_id,
    p_lifecycle,
    p_original_transaction_id,
    p_latest_transaction_id,
    p_environment,
    p_started_at,
    p_expires_at,
    p_grace_period_ends_at,
    p_auto_renews,
    p_verified_at
  )
  on conflict (owner_id) do update set
    provider = excluded.provider,
    product_id = excluded.product_id,
    plan_id = excluded.plan_id,
    lifecycle = excluded.lifecycle,
    original_transaction_id = excluded.original_transaction_id,
    latest_transaction_id = excluded.latest_transaction_id,
    environment = excluded.environment,
    started_at = excluded.started_at,
    expires_at = excluded.expires_at,
    grace_period_ends_at = excluded.grace_period_ends_at,
    auto_renews = excluded.auto_renews,
    verified_at = excluded.verified_at,
    revision = public.bil_subscriptions.revision + 1;

  insert into public.bil_entitlements(
    owner_id,
    entitlement_id,
    product_id,
    provider,
    active,
    starts_at,
    expires_at,
    source_transaction_id,
    server_updated_at
  ) values (
    p_owner_id,
    'plan:' || v_plan_id,
    p_product_id,
    p_provider,
    v_active,
    coalesce(p_started_at, p_verified_at),
    p_expires_at,
    p_latest_transaction_id,
    p_verified_at
  )
  on conflict (owner_id, entitlement_id) do update set
    product_id = excluded.product_id,
    provider = excluded.provider,
    active = excluded.active,
    starts_at = excluded.starts_at,
    expires_at = excluded.expires_at,
    source_transaction_id = excluded.source_transaction_id,
    server_updated_at = excluded.server_updated_at;

  insert into public.bil_store_entitlement_audit(
    owner_id,
    provider,
    product_id,
    lifecycle,
    reason,
    transaction_fingerprint
  ) values (
    p_owner_id,
    p_provider,
    p_product_id,
    p_lifecycle,
    'store_verification',
    p_transaction_fingerprint
  );

  return v_active;
end;
$$;

revoke all on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,
  boolean,timestamptz,text
) from public, anon, authenticated;

grant execute on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,
  boolean,timestamptz,text
) to service_role;

commit;
