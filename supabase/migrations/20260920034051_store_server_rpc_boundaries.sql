begin;

-- Keep store-verification functions on narrow server-only database contracts.
-- service_role is intentionally denied direct access to the sensitive tables;
-- these RPCs expose only the fields and operations required by the Edge
-- Function and reject every client role before touching the tables.

create or replace function public.bil_lookup_store_subscription_owner(
  p_provider text,
  p_original_transaction_id text
) returns table(owner_id uuid, environment text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_provider not in ('apple', 'google')
     or p_original_transaction_id is null
     or length(trim(p_original_transaction_id)) not between 1 and 256 then
    raise exception 'invalid_store_owner_lookup';
  end if;
  return query
    select s.owner_id, s.environment
    from public.bil_subscriptions s
    where s.provider = p_provider
      and s.original_transaction_id = trim(p_original_transaction_id)
    limit 1;
end;
$$;

create or replace function public.bil_list_store_subscriptions_page(
  p_after_owner_id uuid,
  p_limit integer
) returns table(
  owner_id uuid,
  provider text,
  original_transaction_id text,
  latest_transaction_id text,
  environment text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 101 then
    raise exception 'invalid_reconciliation_limit';
  end if;
  return query
    select s.owner_id, s.provider, s.original_transaction_id,
      s.latest_transaction_id, s.environment
    from public.bil_subscriptions s
    where s.provider in ('apple', 'google')
      and (p_after_owner_id is null or s.owner_id > p_after_owner_id)
    order by s.owner_id asc
    limit p_limit;
end;
$$;

create or replace function public.bil_record_store_entitlement_audit(
  p_owner_id uuid,
  p_provider text,
  p_product_id text,
  p_lifecycle text,
  p_reason text,
  p_transaction_fingerprint text
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_provider not in ('apple', 'google', 'closed_test')
     or p_lifecycle is null or length(trim(p_lifecycle)) not between 1 and 64
     or p_reason is null or length(trim(p_reason)) not between 1 and 160
     or (p_transaction_fingerprint is not null
       and p_transaction_fingerprint !~ '^[0-9a-f]{24,64}$') then
    raise exception 'invalid_store_audit';
  end if;
  insert into public.bil_store_entitlement_audit(
    owner_id, provider, product_id, lifecycle, reason,
    transaction_fingerprint
  ) values (
    p_owner_id, p_provider, p_product_id, p_lifecycle, trim(p_reason),
    p_transaction_fingerprint
  );
  return true;
end;
$$;

create or replace function public.bil_lookup_ai_boost_purchase(
  p_store text,
  p_transaction_id text
) returns table(product_id text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_store not in ('app_store', 'google_play')
     or p_transaction_id is null
     or length(trim(p_transaction_id)) not between 8 and 256 then
    raise exception 'invalid_boost_lookup';
  end if;
  return query
    select p.product_id
    from public.bil_ai_boost_purchases p
    where p.store = p_store
      and p.transaction_id = trim(p_transaction_id)
    limit 1;
end;
$$;

revoke all on function public.bil_lookup_store_subscription_owner(text, text)
  from public, anon, authenticated;
revoke all on function public.bil_list_store_subscriptions_page(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.bil_record_store_entitlement_audit(
  uuid, text, text, text, text, text
) from public, anon, authenticated;
revoke all on function public.bil_lookup_ai_boost_purchase(text, text)
  from public, anon, authenticated;

grant execute on function public.bil_lookup_store_subscription_owner(text, text)
  to service_role;
grant execute on function public.bil_list_store_subscriptions_page(uuid, integer)
  to service_role;
grant execute on function public.bil_record_store_entitlement_audit(
  uuid, text, text, text, text, text
) to service_role;
grant execute on function public.bil_lookup_ai_boost_purchase(text, text)
  to service_role;

commit;
