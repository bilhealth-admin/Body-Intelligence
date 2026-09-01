begin;

-- Forward-only replacement for the lifecycle mirror originally introduced by
-- 20260815225624. Applied migration files remain immutable.
--
-- The AI subscription table is an access mirror, not a second lifecycle
-- authority. Normalize it from the canonical store entitlement so cancelled
-- subscriptions keep access only through their paid boundary and missing or
-- expired boundaries always fail closed.
create or replace function public.bil_sync_ai_coach_store_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_boundary timestamptz;
  v_access_lifecycle text;
begin
  if tg_op = 'DELETE' then
    delete from public.bil_ai_coach_subscriptions
    where owner_id = old.owner_id
      and provider = old.provider
      and provider in ('google', 'apple');
    update public.bil_entitlements
    set active = false, server_updated_at = greatest(server_updated_at, now())
    where owner_id = old.owner_id and entitlement_id like 'plan:%' and active;
    return old;
  end if;

  update public.bil_entitlements
  set active = false, server_updated_at = greatest(server_updated_at, new.verified_at)
  where owner_id = new.owner_id
    and entitlement_id like 'plan:%'
    and entitlement_id <> 'plan:' || new.plan_id
    and active;

  v_boundary := case when new.lifecycle = 'grace_period'
    then new.grace_period_ends_at else new.expires_at end;
  v_access_lifecycle := case
    when new.lifecycle not in ('trial', 'active', 'grace_period', 'cancelled')
      then 'expired'
    when v_boundary is null then 'expired'
    when v_boundary <= now() then 'expired'
    when new.lifecycle = 'cancelled' then 'active'
    else new.lifecycle
  end;

  if new.plan_id = 'premium_ai_coach'
     and new.product_id in (
       'bil_premium_ai_coach',
       'bil_premium_ai_coach_annual'
     )
     and v_access_lifecycle <> 'expired' then
    insert into public.bil_ai_coach_subscriptions(
      owner_id, provider, product_id, lifecycle, original_transaction_id,
      latest_transaction_id, expires_at, verified_at
    ) values (
      new.owner_id, new.provider, new.product_id, v_access_lifecycle,
      new.original_transaction_id, new.latest_transaction_id,
      v_boundary, new.verified_at
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
    -- Closed-test grants are a separate, time-bounded review authority. A
    -- Premium-only store row must never erase that independent QA overlay.
    delete from public.bil_ai_coach_subscriptions
    where owner_id = new.owner_id
      and provider = new.provider
      and provider in ('google', 'apple');
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

-- Re-run the existing trigger for every current AI row and every owner that
-- already has an AI mirror. The second condition is important: it deletes a
-- stale mirror after an owner moved to ordinary Premium instead of leaving the
-- old AI row untouched. This does not infer or grant an entitlement: every
-- value is derived from the one canonical bil_subscriptions row and the
-- function fails closed for aliases, missing boundaries, and expired rows.
update public.bil_subscriptions
set verified_at = verified_at
where plan_id = 'premium_ai_coach'
   or exists (
     select 1
     from public.bil_ai_coach_subscriptions a
     where a.owner_id = bil_subscriptions.owner_id
   );

-- A mirror can outlive its canonical subscription if the canonical row was
-- removed while an older trigger/version was installed. Remove those orphaned
-- or malformed rows explicitly; aliases and null/ended boundaries fail closed.
delete from public.bil_ai_coach_subscriptions a
where a.provider in ('google', 'apple')
  and not exists (
  select 1
  from public.bil_subscriptions s
  where s.owner_id = a.owner_id
    and s.plan_id = 'premium_ai_coach'
    and s.product_id in (
      'bil_premium_ai_coach',
      'bil_premium_ai_coach_annual'
    )
    and s.lifecycle in ('trial', 'active', 'grace_period', 'cancelled')
    and (case when s.lifecycle = 'grace_period'
      then s.grace_period_ends_at else s.expires_at end) is not null
    and (case when s.lifecycle = 'grace_period'
      then s.grace_period_ends_at else s.expires_at end) > now()
);

commit;
