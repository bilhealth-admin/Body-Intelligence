begin;
-- Closed-test access is a server-issued entitlement. The mobile client cannot
-- mint it, and no shared access code is embedded in the application.
alter table public.bil_ai_coach_subscriptions
  drop constraint if exists bil_ai_coach_subscriptions_provider_check;
alter table public.bil_ai_coach_subscriptions
  add constraint bil_ai_coach_subscriptions_provider_check
  check (provider in ('google', 'apple', 'closed_test'));
create table if not exists public.bil_ai_closed_test_grants (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  cohort text not null check (cohort ~ '^[a-z0-9][a-z0-9._:-]{2,63}$'),
  active boolean not null default true,
  expires_at timestamptz not null,
  reason text not null check (length(reason) between 8 and 200),
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > granted_at)
);
alter table public.bil_ai_closed_test_grants enable row level security;
revoke all on public.bil_ai_closed_test_grants from public, anon, authenticated;
grant select on public.bil_ai_closed_test_grants to authenticated;
drop policy if exists bil_ai_closed_test_grants_read_own
  on public.bil_ai_closed_test_grants;
create policy bil_ai_closed_test_grants_read_own
  on public.bil_ai_closed_test_grants for select to authenticated
  using (owner_id = auth.uid());
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
    p_owner_id, trim(p_cohort), coalesce(p_active, false), p_expires_at,
    trim(p_reason)
  )
  on conflict (owner_id) do update set
    cohort = excluded.cohort,
    active = excluded.active,
    expires_at = excluded.expires_at,
    reason = excluded.reason,
    updated_at = now();

  v_transaction_id := 'closed-test:' || p_owner_id::text;
  if p_active then
    insert into public.bil_ai_coach_subscriptions(
      owner_id, provider, product_id, lifecycle, original_transaction_id,
      latest_transaction_id, expires_at, verified_at
    ) values (
      p_owner_id, 'closed_test', 'bil_closed_test', 'active',
      v_transaction_id, v_transaction_id, p_expires_at, now()
    )
    on conflict (owner_id) do update set
      provider = 'closed_test',
      product_id = 'bil_closed_test',
      lifecycle = 'active',
      original_transaction_id = v_transaction_id,
      latest_transaction_id = v_transaction_id,
      expires_at = excluded.expires_at,
      verified_at = now()
    where public.bil_ai_coach_subscriptions.provider = 'closed_test'
       or public.bil_ai_coach_subscriptions.lifecycle not in (
         'trial', 'active', 'grace_period'
       )
       or public.bil_ai_coach_subscriptions.expires_at <= now();
  else
    delete from public.bil_ai_coach_subscriptions
    where owner_id = p_owner_id and provider = 'closed_test';
  end if;

  return jsonb_build_object(
    'owner_id', p_owner_id,
    'cohort', trim(p_cohort),
    'active', p_active,
    'expires_at', p_expires_at
  );
end;
$$;
revoke all on function public.bil_set_ai_closed_test_access(
  uuid, text, boolean, timestamptz, text
) from public, anon, authenticated;
grant execute on function public.bil_set_ai_closed_test_access(
  uuid, text, boolean, timestamptz, text
) to service_role;
-- Product feedback is deliberately content-free. It records whether a reply
-- helped and a bounded reason, never the health question or model answer.
create table if not exists public.bil_ai_coach_feedback (
  feedback_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  response_id text not null check (length(response_id) between 8 and 128),
  helpful boolean not null,
  reason text check (reason is null or reason in (
    'incorrect', 'not_personal', 'unclear', 'unsafe', 'other'
  )),
  locale text not null check (length(locale) between 2 and 16),
  runtime text not null check (runtime in (
    'cloud_personalized', 'on_device', 'local_fallback'
  )),
  created_at timestamptz not null default now(),
  unique(owner_id, response_id)
);
alter table public.bil_ai_coach_feedback enable row level security;
revoke all on public.bil_ai_coach_feedback from public, anon, authenticated;
grant select on public.bil_ai_coach_feedback to authenticated;
drop policy if exists bil_ai_coach_feedback_read_own
  on public.bil_ai_coach_feedback;
create policy bil_ai_coach_feedback_read_own
  on public.bil_ai_coach_feedback for select to authenticated
  using (owner_id = auth.uid());
create or replace function public.bil_record_ai_coach_feedback(
  p_response_id text,
  p_helpful boolean,
  p_reason text,
  p_locale text,
  p_runtime text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_id uuid;
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  if length(trim(p_response_id)) not between 8 and 128
     or length(trim(p_locale)) not between 2 and 16
     or p_runtime not in ('cloud_personalized', 'on_device', 'local_fallback')
     or (p_reason is not null and p_reason not in (
       'incorrect', 'not_personal', 'unclear', 'unsafe', 'other'
     )) then
    raise exception 'invalid_ai_coach_feedback';
  end if;
  if p_runtime = 'cloud_personalized' and not exists (
    select 1
    from public.bil_ai_usage_events e
    where e.owner_id = v_owner
      and e.request_id = trim(p_response_id)
      and e.capability = 'text'
      and e.state = 'succeeded'
  ) then
    raise exception 'unknown_ai_coach_response';
  end if;

  insert into public.bil_ai_coach_feedback(
    owner_id, response_id, helpful, reason, locale, runtime
  ) values (
    v_owner, trim(p_response_id), p_helpful, p_reason,
    lower(trim(p_locale)), p_runtime
  )
  on conflict (owner_id, response_id) do update set
    helpful = excluded.helpful,
    reason = excluded.reason,
    locale = excluded.locale,
    runtime = excluded.runtime,
    created_at = now()
  returning feedback_id into v_id;
  return v_id;
end;
$$;
revoke all on function public.bil_record_ai_coach_feedback(
  text, boolean, text, text, text
) from public, anon;
grant execute on function public.bil_record_ai_coach_feedback(
  text, boolean, text, text, text
) to authenticated;
-- One bounded status endpoint keeps the UI and Edge Function aligned on the
-- latest explicit remote-AI choice without exposing all consent history.
create or replace function public.bil_get_remote_ai_consent()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'granted', coalesce((
      select r.granted
      from public.bil_consent_receipts r
      where r.user_id = auth.uid() and r.purpose = 'remote_ai'
      order by r.recorded_at desc
      limit 1
    ), false),
    'policy_version', coalesce((
      select r.policy_version
      from public.bil_consent_receipts r
      where r.user_id = auth.uid() and r.purpose = 'remote_ai'
      order by r.recorded_at desc
      limit 1
    ), '1')
  )
$$;
revoke all on function public.bil_get_remote_ai_consent() from public, anon;
grant execute on function public.bil_get_remote_ai_consent() to authenticated;
create or replace function public.bil_has_remote_ai_consent(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((
    select r.granted
    from public.bil_consent_receipts r
    where r.user_id = p_owner_id and r.purpose = 'remote_ai'
    order by r.recorded_at desc
    limit 1
  ), false)
$$;
revoke all on function public.bil_has_remote_ai_consent(uuid)
  from public, anon, authenticated;
grant execute on function public.bil_has_remote_ai_consent(uuid)
  to service_role;
commit;
