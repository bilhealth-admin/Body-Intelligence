begin;

-- Closed-test reviewers need the same server-authoritative feature surface as
-- Premium AI Coach without fabricating an Apple or Google transaction. Keep
-- the provider explicit so store notifications can never be confused with an
-- administrative test grant.
alter table public.bil_store_product_registry
  drop constraint if exists bil_store_product_registry_provider_check;
alter table public.bil_store_product_registry
  add constraint bil_store_product_registry_provider_check
  check (provider in ('google', 'apple', 'closed_test'));

alter table public.bil_subscriptions
  drop constraint if exists bil_subscriptions_provider_check;
alter table public.bil_subscriptions
  add constraint bil_subscriptions_provider_check
  check (provider in ('google', 'apple', 'closed_test'));

alter table public.bil_entitlements
  drop constraint if exists bil_entitlements_provider_check;
alter table public.bil_entitlements
  add constraint bil_entitlements_provider_check
  check (provider in ('google', 'apple', 'closed_test'));

alter table public.bil_store_entitlement_audit
  drop constraint if exists bil_store_entitlement_audit_provider_check;
alter table public.bil_store_entitlement_audit
  add constraint bil_store_entitlement_audit_provider_check
  check (provider in ('google', 'apple', 'closed_test'));

insert into public.bil_store_product_registry(
  provider, product_id, package_or_bundle_id, plan_id, billing_term, enabled
) values (
  'closed_test', 'bil_closed_test', 'com.bilhealth.bodyintelligencelog',
  'premium_ai_coach', 'annual', false
)
on conflict (provider, product_id) do update set
  package_or_bundle_id = excluded.package_or_bundle_id,
  plan_id = excluded.plan_id,
  billing_term = excluded.billing_term,
  enabled = false,
  updated_at = now();

create or replace function public.bil_set_ai_closed_test_access(
  p_owner_id uuid,
  p_cohort text,
  p_active boolean,
  p_expires_at timestamptz,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_transaction_id text;
  v_full_grant_applied boolean := false;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_owner_id is null
     or p_active is null
     or not exists (select 1 from auth.users where id = p_owner_id)
     or p_cohort !~ '^[a-z0-9][a-z0-9._:-]{2,63}$'
     or p_expires_at <= now()
     or p_expires_at > now() + interval '18 months'
     or length(trim(p_reason)) not between 8 and 200 then
    raise exception 'invalid_closed_test_grant';
  end if;

  insert into public.bil_ai_closed_test_grants(
    owner_id, cohort, active, expires_at, reason
  ) values (
    p_owner_id, trim(p_cohort), p_active, p_expires_at, trim(p_reason)
  )
  on conflict (owner_id) do update set
    cohort = excluded.cohort,
    active = excluded.active,
    expires_at = excluded.expires_at,
    reason = excluded.reason,
    updated_at = now();

  v_transaction_id := 'closed-test:' || p_owner_id::text;
  if p_active then
    insert into public.bil_subscriptions(
      owner_id, provider, product_id, plan_id, lifecycle,
      original_transaction_id, latest_transaction_id, environment,
      store_country_code, started_at, expires_at, grace_period_ends_at,
      auto_renews, verified_at
    ) values (
      p_owner_id, 'closed_test', 'bil_closed_test', 'premium_ai_coach',
      'active', v_transaction_id, v_transaction_id, 'sandbox', null,
      now(), p_expires_at, null, false, now()
    )
    on conflict (owner_id) do update set
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
      revision = public.bil_subscriptions.revision + 1
    where public.bil_subscriptions.provider = 'closed_test'
       or public.bil_subscriptions.lifecycle not in (
         'trial', 'active', 'grace_period'
       )
       or coalesce(
         public.bil_subscriptions.grace_period_ends_at,
         public.bil_subscriptions.expires_at
       ) <= now();

    select exists (
      select 1 from public.bil_subscriptions
      where owner_id = p_owner_id
        and provider = 'closed_test'
        and plan_id = 'premium_ai_coach'
        and lifecycle = 'active'
        and expires_at > now()
    ) into v_full_grant_applied;

    if v_full_grant_applied then
      update public.bil_entitlements
      set active = false, server_updated_at = now()
      where owner_id = p_owner_id
        and entitlement_id like 'plan:%'
        and entitlement_id <> 'plan:premium_ai_coach'
        and active = true;

      insert into public.bil_entitlements(
        owner_id, entitlement_id, product_id, provider, active, starts_at,
        expires_at, source_transaction_id, server_updated_at
      ) values (
        p_owner_id, 'plan:premium_ai_coach', 'bil_closed_test',
        'closed_test', true, now(), p_expires_at, v_transaction_id, now()
      )
      on conflict (owner_id, entitlement_id) do update set
        product_id = excluded.product_id,
        provider = excluded.provider,
        active = excluded.active,
        starts_at = excluded.starts_at,
        expires_at = excluded.expires_at,
        source_transaction_id = excluded.source_transaction_id,
        server_updated_at = excluded.server_updated_at;
    end if;
  else
    delete from public.bil_subscriptions
    where owner_id = p_owner_id and provider = 'closed_test';

    update public.bil_entitlements
    set active = false, server_updated_at = now()
    where owner_id = p_owner_id
      and provider = 'closed_test'
      and source_transaction_id = v_transaction_id;
  end if;

  insert into public.bil_store_entitlement_audit(
    owner_id, provider, product_id, lifecycle, reason,
    transaction_fingerprint
  ) values (
    p_owner_id, 'closed_test', 'bil_closed_test',
    case when p_active and v_full_grant_applied then 'active' else 'revoked' end,
    case when p_active and v_full_grant_applied
      then 'closed_test_full_access_granted'
      when p_active then 'closed_test_preserved_real_subscription'
      else 'closed_test_access_revoked'
    end,
    encode(extensions.digest(v_transaction_id, 'sha256'), 'hex')
  );

  return jsonb_build_object(
    'owner_id', p_owner_id,
    'cohort', trim(p_cohort),
    'active', p_active,
    'expires_at', p_expires_at,
    'full_premium_ai_coach', v_full_grant_applied
  );
end;
$$;

revoke all on function public.bil_set_ai_closed_test_access(
  uuid, text, boolean, timestamptz, text
) from public, anon, authenticated;
grant execute on function public.bil_set_ai_closed_test_access(
  uuid, text, boolean, timestamptz, text
) to service_role;

commit;

;
