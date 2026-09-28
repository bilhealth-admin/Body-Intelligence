begin;
-- Scheduled verification is optimistic: the store call happens outside the
-- database transaction, so persist only if the owner snapshot is unchanged.
drop function if exists public.bil_list_store_subscriptions_page(uuid, integer);
create function public.bil_list_store_subscriptions_page(
  p_after_owner_id uuid,
  p_limit integer
) returns table(
  owner_id uuid,
  provider text,
  original_transaction_id text,
  latest_transaction_id text,
  environment text,
  revision bigint
)
language plpgsql security definer set search_path=public,pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 101 then
    raise exception 'invalid_reconciliation_limit';
  end if;
  return query
    select s.owner_id,s.provider,s.original_transaction_id,
      s.latest_transaction_id,s.environment,s.revision
    from public.bil_subscriptions s
    where s.provider in ('apple','google')
      and (p_after_owner_id is null or s.owner_id > p_after_owner_id)
    order by s.owner_id asc limit p_limit;
end
$$;
create or replace function public.bil_persist_reconciled_store_purchase(
  p_owner_id uuid,p_provider text,p_product_id text,p_package_or_bundle_id text,
  p_lifecycle text,p_original_transaction_id text,p_latest_transaction_id text,
  p_environment text,p_store_country_code text,p_started_at timestamptz,
  p_expires_at timestamptz,p_grace_period_ends_at timestamptz,p_auto_renews boolean,
  p_verified_at timestamptz,p_transaction_fingerprint text,p_store_signed_at timestamptz,
  p_expected_provider text,p_expected_original_transaction_id text,
  p_expected_latest_transaction_id text,p_expected_environment text,
  p_expected_revision bigint
) returns jsonb
language plpgsql security definer set search_path=public,pg_temp
as $$
declare
  v_current public.bil_subscriptions%rowtype;
  v_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_expected_revision is null or p_expected_revision < 1 then
    raise exception 'invalid_expected_subscription_revision';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended('bil-store-owner:'||p_owner_id::text,0)
  );
  select * into v_current from public.bil_subscriptions
    where owner_id=p_owner_id for update;
  if not found
     or v_current.revision is distinct from p_expected_revision
     or v_current.provider is distinct from p_expected_provider
     or v_current.original_transaction_id is distinct from
       p_expected_original_transaction_id
     or v_current.latest_transaction_id is distinct from
       p_expected_latest_transaction_id
     or v_current.environment is distinct from p_expected_environment then
    return jsonb_build_object('superseded',true);
  end if;
  v_result := public.bil_persist_verified_store_purchase(
    p_owner_id,p_provider,p_product_id,p_package_or_bundle_id,p_lifecycle,
    p_original_transaction_id,p_latest_transaction_id,p_environment,
    p_store_country_code,p_started_at,p_expires_at,p_grace_period_ends_at,
    p_auto_renews,p_verified_at,p_transaction_fingerprint,p_store_signed_at
  );
  return v_result || jsonb_build_object('superseded',false);
end
$$;
revoke all on function public.bil_list_store_subscriptions_page(uuid,integer)
  from public,anon,authenticated;
revoke all on function public.bil_persist_reconciled_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz,text,text,text,text,bigint
) from public,anon,authenticated;
grant execute on function public.bil_list_store_subscriptions_page(uuid,integer)
  to service_role;
grant execute on function public.bil_persist_reconciled_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz,text,text,text,text,bigint
) to service_role;
commit;
