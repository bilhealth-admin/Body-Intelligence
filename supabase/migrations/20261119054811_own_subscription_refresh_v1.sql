-- EXTERNAL REVIEW ONLY. Generate the eventual migration name with the installed
-- Supabase CLI (`migration new`) after reviewing its --help. Not deployed.
begin;

create table private.bil_own_subscription_refresh (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  period_key text not null,
  period_attempts integer not null default 0,
  hour_bucket bigint not null,
  hour_attempts integer not null default 0,
  last_attempt_at timestamptz,
  lease_id uuid,
  lease_expires_at timestamptz,
  check (period_attempts between 0 and 6),
  check (hour_attempts between 0 and 30)
);
alter table private.bil_own_subscription_refresh enable row level security;
revoke all on private.bil_own_subscription_refresh from public,anon,authenticated,service_role;

create function public.bil_claim_own_subscription_refresh(p_owner_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_snapshot public.bil_store_subscription_snapshots%rowtype;
  v_limit private.bil_own_subscription_refresh%rowtype;
  v_now timestamptz:=clock_timestamp();
  v_hour bigint:=floor(extract(epoch from v_now)/3600)::bigint;
  v_period text;
  v_end timestamptz;
  v_lease uuid;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_owner_id is null then raise exception 'owner_required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bil-store-refresh:'||p_owner_id::text,0));
  -- Choose only the chain that currently backs this owner's canonical row.
  -- The caller cannot choose a provider, environment or transaction identity.
  select s.* into v_snapshot
  from public.bil_subscriptions c
  join public.bil_store_subscription_snapshots s
    on s.owner_id=c.owner_id and s.provider=c.provider
    and s.original_transaction_id=c.original_transaction_id
  where c.owner_id=p_owner_id;
  if not found or v_snapshot.auto_renews is distinct from true
     or v_snapshot.lifecycle not in ('active','trial','grace_period','billing_retry','expired')
     or v_snapshot.expires_at is null then
    return jsonb_build_object('status','not_required');
  end if;
  v_end:=greatest(v_snapshot.expires_at,
    coalesce(v_snapshot.grace_period_ends_at,v_snapshot.expires_at));
  if v_end>v_now+interval '2 seconds' then
    return jsonb_build_object('status','not_required');
  end if;
  v_period:=encode(sha256(convert_to(v_snapshot.provider||'|'||
    v_snapshot.original_transaction_id||'|'||extract(epoch from v_end)::text,'UTF8')),'hex');
  insert into private.bil_own_subscription_refresh(owner_id,period_key,hour_bucket)
    values(p_owner_id,v_period,v_hour) on conflict(owner_id) do nothing;
  select * into strict v_limit from private.bil_own_subscription_refresh
    where owner_id=p_owner_id for update;
  if v_limit.lease_expires_at>v_now then
    return jsonb_build_object('status','busy','retry_after_seconds',10);
  end if;
  if v_limit.hour_bucket<>v_hour then
    v_limit.hour_bucket:=v_hour;
    v_limit.hour_attempts:=0;
    v_limit.period_attempts:=0;
  end if;
  if v_limit.period_key<>v_period then
    v_limit.period_key:=v_period;
    v_limit.period_attempts:=0;
  end if;
  if v_limit.hour_attempts>=30 or v_limit.period_attempts>=6 then
    return jsonb_build_object('status','rate_limited','retry_after_seconds',
      greatest(1,ceil((v_hour+1)*3600-extract(epoch from v_now))::integer));
  end if;
  if v_limit.last_attempt_at>v_now-interval '8 seconds' then
    return jsonb_build_object('status','rate_limited','retry_after_seconds',
      greatest(1,ceil(extract(epoch from v_limit.last_attempt_at+interval '8 seconds'-v_now))::integer));
  end if;
  v_lease:=gen_random_uuid();
  update private.bil_own_subscription_refresh set
    period_key=v_period,period_attempts=v_limit.period_attempts+1,
    hour_bucket=v_hour,hour_attempts=v_limit.hour_attempts+1,
    last_attempt_at=v_now,lease_id=v_lease,
    lease_expires_at=v_now+interval '40 seconds'
  where owner_id=p_owner_id;
  return jsonb_build_object('status','claimed','lease_id',v_lease,
    'snapshot',jsonb_build_object(
      'owner_id',v_snapshot.owner_id,'provider',v_snapshot.provider,
      'original_transaction_id',v_snapshot.original_transaction_id,
      'latest_transaction_id',v_snapshot.latest_transaction_id,
      'environment',v_snapshot.environment,'revision',v_snapshot.revision,
      'package_or_bundle_id',v_snapshot.package_or_bundle_id));
end
$$;

create function public.bil_release_own_subscription_refresh(p_owner_id uuid,p_lease_id uuid)
returns void language plpgsql security definer set search_path=''
as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  update private.bil_own_subscription_refresh set lease_expires_at=null
    where owner_id=p_owner_id and lease_id=p_lease_id;
end
$$;

-- A lease is checked in the SAME transaction as the established revision/
-- lineage CAS and signed-store persistence, rather than a racy client check.
create function public.bil_persist_refreshed_store_purchase(
  p_owner_id uuid,p_provider text,p_product_id text,p_package_or_bundle_id text,
  p_lifecycle text,p_original_transaction_id text,p_latest_transaction_id text,
  p_environment text,p_store_country_code text,p_started_at timestamptz,
  p_expires_at timestamptz,p_grace_period_ends_at timestamptz,p_auto_renews boolean,
  p_verified_at timestamptz,p_transaction_fingerprint text,p_store_signed_at timestamptz,
  p_expected_provider text,p_expected_original_transaction_id text,
  p_expected_latest_transaction_id text,p_expected_environment text,
  p_expected_revision bigint,p_refresh_lease uuid
) returns jsonb language plpgsql security definer set search_path=''
as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'service_role_required';
  end if;
  -- Acquire the same lock as ordinary Store persistence before validating the
  -- lease. Waiting behind a notification must not consume its remaining time
  -- after we have already checked the deadline. The nested CAS is reentrant.
  perform pg_advisory_xact_lock(
    hashtextextended('bil-store-owner:'||p_owner_id::text,0)
  );
  perform 1 from private.bil_own_subscription_refresh
    where owner_id=p_owner_id and lease_id=p_refresh_lease
      and lease_expires_at>clock_timestamp() for update;
  if not found then return jsonb_build_object('superseded',true); end if;
  return public.bil_persist_reconciled_store_purchase(
    p_owner_id,p_provider,p_product_id,p_package_or_bundle_id,p_lifecycle,
    p_original_transaction_id,p_latest_transaction_id,p_environment,
    p_store_country_code,p_started_at,p_expires_at,p_grace_period_ends_at,
    p_auto_renews,p_verified_at,p_transaction_fingerprint,p_store_signed_at,
    p_expected_provider,p_expected_original_transaction_id,
    p_expected_latest_transaction_id,p_expected_environment,p_expected_revision);
end
$$;

revoke all on function public.bil_claim_own_subscription_refresh(uuid)
  from public,anon,authenticated;
revoke all on function public.bil_release_own_subscription_refresh(uuid,uuid)
  from public,anon,authenticated;
revoke all on function public.bil_persist_refreshed_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,
  boolean,timestamptz,text,timestamptz,text,text,text,text,bigint,uuid)
  from public,anon,authenticated;
grant execute on function public.bil_claim_own_subscription_refresh(uuid) to service_role;
grant execute on function public.bil_release_own_subscription_refresh(uuid,uuid) to service_role;
grant execute on function public.bil_persist_refreshed_store_purchase(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,
  boolean,timestamptz,text,timestamptz,text,text,text,text,bigint,uuid) to service_role;
commit;
