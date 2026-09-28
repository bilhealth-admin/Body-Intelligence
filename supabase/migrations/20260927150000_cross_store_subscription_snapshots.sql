begin;

-- Keep one authoritative row per store subscription chain. The legacy
-- bil_subscriptions row remains the single derived entitlement projection read
-- by existing clients; it is no longer the only source of store truth.
create table if not exists public.bil_store_subscription_snapshots (
  owner_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('apple','google')),
  original_transaction_id text not null,
  product_id text not null,
  package_or_bundle_id text not null,
  plan_id text not null,
  lifecycle text not null,
  latest_transaction_id text not null,
  environment text not null check (environment in ('sandbox','production')),
  store_country_code text,
  started_at timestamptz,
  expires_at timestamptz,
  grace_period_ends_at timestamptz,
  auto_renews boolean,
  verified_at timestamptz not null,
  transaction_fingerprint text,
  store_signed_at timestamptz,
  revision bigint not null default 1 check (revision > 0),
  primary key (owner_id,provider,original_transaction_id),
  unique (provider,original_transaction_id)
);
alter table public.bil_store_subscription_snapshots enable row level security;
revoke all on public.bil_store_subscription_snapshots
  from public,anon,authenticated;

insert into public.bil_store_subscription_snapshots(
  owner_id,provider,original_transaction_id,product_id,
  package_or_bundle_id,plan_id,lifecycle,latest_transaction_id,environment,
  store_country_code,started_at,expires_at,grace_period_ends_at,auto_renews,
  verified_at,store_signed_at,revision
)
select s.owner_id,s.provider,s.original_transaction_id,s.product_id,
  r.package_or_bundle_id,s.plan_id,s.lifecycle,s.latest_transaction_id,
  s.environment,s.store_country_code,s.started_at,s.expires_at,
  s.grace_period_ends_at,s.auto_renews,s.verified_at,s.store_signed_at,
  greatest(s.revision,1)
from public.bil_subscriptions s
join public.bil_store_product_registry r
  on r.provider=s.provider and r.product_id=s.product_id
where s.provider in ('apple','google')
on conflict (owner_id,provider,original_transaction_id) do nothing;

-- Preserve the fully validated, ordered single-snapshot projector. The new
-- public function records the verified chain and then derives the winner from
-- every current Apple/Google snapshot for this member.
do $migration$
declare
  v_public oid := to_regprocedure('public.bil_persist_verified_store_purchase(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text,timestamptz)');
  v_private oid := to_regprocedure('private.bil_persist_verified_store_purchase_single_snapshot(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text,timestamptz)');
  v_definition text;
begin
  if v_public is null then raise exception 'required_store_persistence_missing'; end if;
  if v_private is null then
    v_definition := pg_get_functiondef(v_public);
    if position('bil_persist_verified_store_purchase_unordered' in v_definition)=0
       or position('v_stale' in v_definition)=0 then
      raise exception 'unexpected_store_persistence_definition';
    end if;
    execute replace(v_definition,
      'FUNCTION public.bil_persist_verified_store_purchase(',
      'FUNCTION private.bil_persist_verified_store_purchase_single_snapshot(');
  end if;
end
$migration$;
revoke all on function private.bil_persist_verified_store_purchase_single_snapshot(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz
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
  v_previous public.bil_store_subscription_snapshots%rowtype;
  v_winner public.bil_store_subscription_snapshots%rowtype;
  v_projected public.bil_subscriptions%rowtype;
  v_stale boolean := false;
  v_active boolean;
  v_input_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_owner_id is null or p_provider not in ('apple','google')
     or nullif(trim(p_original_transaction_id),'') is null then
    raise exception 'invalid_store_snapshot_identity';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended('bil-store-owner:'||p_owner_id::text,0)
  );
  select * into v_previous
  from public.bil_store_subscription_snapshots
  where owner_id=p_owner_id and provider=p_provider
    and original_transaction_id=p_original_transaction_id
  for update;

  if found and p_provider='apple' and v_previous.store_signed_at is not null then
    v_stale := p_store_signed_at is null
      or p_store_signed_at<v_previous.store_signed_at
      or (p_store_signed_at=v_previous.store_signed_at
        and v_previous.lifecycle in ('expired','refunded','revoked')
        and p_lifecycle not in ('expired','refunded','revoked'));
  end if;

  if not v_stale then
    -- This call retains all product, market, lifecycle, timestamp, ownership,
    -- entitlement, and audit validation from the established implementation.
    v_input_result:=private.bil_persist_verified_store_purchase_single_snapshot(
      p_owner_id,p_provider,p_product_id,p_package_or_bundle_id,p_lifecycle,
      p_original_transaction_id,p_latest_transaction_id,p_environment,
      p_store_country_code,p_started_at,p_expires_at,p_grace_period_ends_at,
      p_auto_renews,p_verified_at,p_transaction_fingerprint,p_store_signed_at
    );
    select * into strict v_projected from public.bil_subscriptions
      where owner_id=p_owner_id;
    insert into public.bil_store_subscription_snapshots(
      owner_id,provider,original_transaction_id,product_id,
      package_or_bundle_id,plan_id,lifecycle,latest_transaction_id,environment,
      store_country_code,started_at,expires_at,grace_period_ends_at,auto_renews,
      verified_at,transaction_fingerprint,store_signed_at,revision
    ) values (
      p_owner_id,p_provider,p_original_transaction_id,p_product_id,
      p_package_or_bundle_id,v_projected.plan_id,p_lifecycle,
      p_latest_transaction_id,p_environment,v_projected.store_country_code,
      p_started_at,p_expires_at,p_grace_period_ends_at,p_auto_renews,
      p_verified_at,p_transaction_fingerprint,p_store_signed_at,1
    ) on conflict (owner_id,provider,original_transaction_id) do update set
      product_id=excluded.product_id,
      package_or_bundle_id=excluded.package_or_bundle_id,
      plan_id=excluded.plan_id,lifecycle=excluded.lifecycle,
      latest_transaction_id=excluded.latest_transaction_id,
      environment=excluded.environment,
      store_country_code=excluded.store_country_code,
      started_at=excluded.started_at,expires_at=excluded.expires_at,
      grace_period_ends_at=excluded.grace_period_ends_at,
      auto_renews=excluded.auto_renews,verified_at=excluded.verified_at,
      transaction_fingerprint=excluded.transaction_fingerprint,
      store_signed_at=excluded.store_signed_at,
      revision=public.bil_store_subscription_snapshots.revision+1;
  else
    update public.bil_store_subscription_snapshots
    set verified_at=greatest(verified_at,p_verified_at),revision=revision+1
    where owner_id=p_owner_id and provider=p_provider
      and original_transaction_id=p_original_transaction_id;
  end if;

  select * into strict v_winner
  from public.bil_store_subscription_snapshots s
  where s.owner_id=p_owner_id
  order by
    (s.lifecycle in ('trial','active','grace_period','cancelled') and
      (case when s.lifecycle='grace_period' then s.grace_period_ends_at
        else s.expires_at end)>now()) desc,
    (case s.plan_id when 'premium_ai_coach' then 2 when 'pro' then 2
      when 'premium' then 1 when 'plus' then 1 else 0 end) desc,
    (case when s.lifecycle='grace_period' then s.grace_period_ends_at
      else s.expires_at end) desc nulls last,
    s.verified_at desc,s.provider asc,s.original_transaction_id asc
  limit 1;

  if not v_stale and v_winner.provider=p_provider
     and v_winner.original_transaction_id=p_original_transaction_id then
    return v_input_result;
  end if;

  -- Project only the derived winner. A terminal event from one provider can
  -- update its snapshot without revoking a still-valid entitlement from the
  -- other provider.
  v_active := private.bil_persist_verified_store_purchase_unordered(
    v_winner.owner_id,v_winner.provider,v_winner.product_id,
    v_winner.package_or_bundle_id,v_winner.lifecycle,
    v_winner.original_transaction_id,v_winner.latest_transaction_id,
    v_winner.environment,v_winner.store_country_code,v_winner.started_at,
    v_winner.expires_at,v_winner.grace_period_ends_at,v_winner.auto_renews,
    v_winner.verified_at,v_winner.transaction_fingerprint
  );
  update public.bil_subscriptions set store_signed_at=v_winner.store_signed_at
    where owner_id=p_owner_id returning * into strict v_projected;
  return jsonb_build_object('active',v_active,'lifecycle',v_projected.lifecycle,
    'verified_at',v_projected.verified_at);
end
$$;

-- Ownership checks must see non-canonical chains too.
create or replace function public.bil_lookup_store_subscription_owner(
  p_provider text,p_original_transaction_id text
) returns table(owner_id uuid,environment text)
language plpgsql security definer set search_path=public,pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  return query select s.owner_id,s.environment
  from public.bil_store_subscription_snapshots s
  where s.provider=p_provider
    and s.original_transaction_id=p_original_transaction_id
  limit 1;
end
$$;

create or replace function public.bil_list_store_subscription_snapshots_page(
  p_after_cursor text,p_limit integer
) returns table(
  snapshot_cursor text,owner_id uuid,provider text,
  original_transaction_id text,latest_transaction_id text,environment text,
  revision bigint
)
language plpgsql security definer set search_path=public,pg_temp
as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_limit is null or p_limit<1 or p_limit>101 then
    raise exception 'invalid_reconciliation_limit';
  end if;
  return query
    select s.owner_id::text||'|'||s.provider||'|'||s.original_transaction_id,
      s.owner_id,s.provider,s.original_transaction_id,s.latest_transaction_id,
      s.environment,s.revision
    from public.bil_store_subscription_snapshots s
    where p_after_cursor is null or
      s.owner_id::text||'|'||s.provider||'|'||s.original_transaction_id>
        p_after_cursor
    order by s.owner_id::text||'|'||s.provider||'|'||s.original_transaction_id
    limit p_limit;
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
) returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $$
declare
  v_current public.bil_store_subscription_snapshots%rowtype;
  v_result jsonb;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended('bil-store-owner:'||p_owner_id::text,0)
  );
  select * into v_current from public.bil_store_subscription_snapshots
  where owner_id=p_owner_id and provider=p_expected_provider
    and original_transaction_id=p_expected_original_transaction_id
  for update;
  if not found or v_current.revision is distinct from p_expected_revision
     or v_current.latest_transaction_id is distinct from
       p_expected_latest_transaction_id
     or v_current.environment is distinct from p_expected_environment then
    return jsonb_build_object('superseded',true);
  end if;
  v_result:=public.bil_persist_verified_store_purchase(
    p_owner_id,p_provider,p_product_id,p_package_or_bundle_id,p_lifecycle,
    p_original_transaction_id,p_latest_transaction_id,p_environment,
    p_store_country_code,p_started_at,p_expires_at,p_grace_period_ends_at,
    p_auto_renews,p_verified_at,p_transaction_fingerprint,p_store_signed_at
  );
  return v_result||jsonb_build_object('superseded',false);
end
$$;

revoke all on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz)
  from public,anon,authenticated;
revoke all on function public.bil_lookup_store_subscription_owner(text,text)
  from public,anon,authenticated;
revoke all on function public.bil_list_store_subscription_snapshots_page(text,integer)
  from public,anon,authenticated;
revoke all on function public.bil_persist_reconciled_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz,text,text,text,text,bigint)
  from public,anon,authenticated;
grant execute on function public.bil_persist_verified_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz)
  to service_role;
grant execute on function public.bil_lookup_store_subscription_owner(text,text)
  to service_role;
grant execute on function public.bil_list_store_subscription_snapshots_page(text,integer)
  to service_role;
grant execute on function public.bil_persist_reconciled_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz,text,text,text,text,bigint)
  to service_role;

commit;
