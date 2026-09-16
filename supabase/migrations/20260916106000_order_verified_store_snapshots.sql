begin;

create schema if not exists private;
alter table public.bil_subscriptions add column if not exists store_signed_at timestamptz
  check(store_signed_at is null or (isfinite(store_signed_at) and store_signed_at>timestamptz '1970-01-01 UTC'));

-- Preserve the established, already-hardened atomic mutation body verbatim in
-- a non-API helper. Both public signatures must pass the ordering fence first.
do $migration$
declare
  v_oid oid := to_regprocedure('public.bil_persist_verified_store_purchase(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)');
  v_helper oid := to_regprocedure('private.bil_persist_verified_store_purchase_unordered(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text)');
  v_definition text;
begin
  if v_oid is null then raise exception 'required_store_persistence_missing'; end if;
  v_definition := pg_get_functiondef(v_oid);
  if v_helper is null then
    if position('v_terminal_existing' in v_definition)=0 or position('v_access_boundary > now()' in v_definition)=0 then
      raise exception 'store_persistence_hardening_required';
    end if;
    execute replace(v_definition,'FUNCTION public.bil_persist_verified_store_purchase(',
      'FUNCTION private.bil_persist_verified_store_purchase_unordered(');
  elsif position('v_terminal_existing' in pg_get_functiondef(v_helper))=0 then
    raise exception 'unexpected_ordered_store_helper';
  end if;
end
$migration$;
revoke all on function private.bil_persist_verified_store_purchase_unordered(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text
) from public,anon,authenticated,service_role;

create or replace function public.bil_persist_verified_store_purchase(
  p_owner_id uuid,p_provider text,p_product_id text,p_package_or_bundle_id text,
  p_lifecycle text,p_original_transaction_id text,p_latest_transaction_id text,
  p_environment text,p_store_country_code text,p_started_at timestamptz,
  p_expires_at timestamptz,p_grace_period_ends_at timestamptz,p_auto_renews boolean,
  p_verified_at timestamptz,p_transaction_fingerprint text,p_store_signed_at timestamptz
) returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $$
declare
  v_existing public.bil_subscriptions%rowtype;
  v_stale boolean := false;
  v_active boolean;
  v_boundary timestamptz;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'service_role_required'; end if;
  if p_owner_id is null then raise exception 'owner_required'; end if;
  if p_verified_at is null or not isfinite(p_verified_at) or p_verified_at>now()+interval '5 minutes' then
    raise exception 'invalid_verified_at';
  end if;
  if p_store_signed_at is not null and (p_provider<>'apple' or not isfinite(p_store_signed_at)
     or p_store_signed_at<=timestamptz '1970-01-01 UTC' or p_store_signed_at>now()+interval '5 minutes') then
    raise exception 'invalid_store_signed_at';
  end if;
  -- Serializes both first insertion and updates for this owner. A row lock
  -- alone would not fence the initially absent canonical subscription.
  perform pg_advisory_xact_lock(hashtextextended('bil-store-owner:'||p_owner_id::text,0));
  select * into v_existing from public.bil_subscriptions where owner_id=p_owner_id for update;
  if found and v_existing.provider='apple' and p_provider='apple'
     and v_existing.store_signed_at is not null then
    -- Once authoritative ordering is established, a legacy timestamp-less
    -- request remains callable but cannot replace the signed snapshot.
    v_stale := p_store_signed_at is null or p_store_signed_at<v_existing.store_signed_at
      or (p_store_signed_at=v_existing.store_signed_at
        and v_existing.lifecycle in ('expired','refunded','revoked')
        and p_lifecycle not in ('expired','refunded','revoked'));
  end if;
  if v_stale then
    v_boundary := case when v_existing.lifecycle='grace_period'
      then v_existing.grace_period_ends_at else v_existing.expires_at end;
    v_active := v_existing.lifecycle in ('trial','active','grace_period','cancelled')
      and v_boundary is not null and v_boundary>now();
    -- Do not substitute the older request's lifecycle/product/owner/expiry.
    -- Only refresh the receipt-settlement watermark used by existing clients.
    update public.bil_subscriptions set verified_at=greatest(verified_at,p_verified_at),revision=revision+1
      where owner_id=p_owner_id returning * into v_existing;
    update public.bil_entitlements set server_updated_at=greatest(server_updated_at,p_verified_at)
      where owner_id=p_owner_id and entitlement_id='plan:'||v_existing.plan_id;
    return jsonb_build_object('active',v_active,'lifecycle',v_existing.lifecycle,'verified_at',v_existing.verified_at);
  end if;
  v_active := private.bil_persist_verified_store_purchase_unordered(
    p_owner_id,p_provider,p_product_id,p_package_or_bundle_id,p_lifecycle,
    p_original_transaction_id,p_latest_transaction_id,p_environment,p_store_country_code,
    p_started_at,p_expires_at,p_grace_period_ends_at,p_auto_renews,p_verified_at,p_transaction_fingerprint
  );
  update public.bil_subscriptions set store_signed_at=p_store_signed_at where owner_id=p_owner_id returning * into v_existing;
  return jsonb_build_object('active',v_active,'lifecycle',v_existing.lifecycle,'verified_at',v_existing.verified_at);
end
$$;

-- No default on the new overload: PostgREST resolves the two named-argument
-- contracts unambiguously. Existing callers retain their fifteen arguments.
create or replace function public.bil_persist_verified_store_purchase(
  p_owner_id uuid,p_provider text,p_product_id text,p_package_or_bundle_id text,
  p_lifecycle text,p_original_transaction_id text,p_latest_transaction_id text,
  p_environment text,p_store_country_code text,p_started_at timestamptz,
  p_expires_at timestamptz,p_grace_period_ends_at timestamptz,p_auto_renews boolean,
  p_verified_at timestamptz,p_transaction_fingerprint text
) returns boolean language sql security definer set search_path=public,pg_temp
as $$
  select (public.bil_persist_verified_store_purchase(
    p_owner_id,p_provider,p_product_id,p_package_or_bundle_id,p_lifecycle,
    p_original_transaction_id,p_latest_transaction_id,p_environment,p_store_country_code,
    p_started_at,p_expires_at,p_grace_period_ends_at,p_auto_renews,p_verified_at,p_transaction_fingerprint,null
  )->>'active')::boolean
$$;
revoke all on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text),
  public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text),
  public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text,timestamptz)
  to service_role;

commit;
