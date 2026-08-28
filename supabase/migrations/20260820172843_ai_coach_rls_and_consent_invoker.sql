begin;
drop policy if exists bil_ai_closed_test_grants_read_own
  on public.bil_ai_closed_test_grants;
create policy bil_ai_closed_test_grants_read_own
  on public.bil_ai_closed_test_grants for select to authenticated
  using (owner_id = (select auth.uid()));
drop policy if exists bil_ai_coach_feedback_read_own
  on public.bil_ai_coach_feedback;
create policy bil_ai_coach_feedback_read_own
  on public.bil_ai_coach_feedback for select to authenticated
  using (owner_id = (select auth.uid()));
-- EXECUTE is restricted to service_role below, so deprecated role
-- introspection in the body is redundant. Keep validation intact.
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
-- This status reader needs no RLS bypass: authenticated users already have
-- SELECT on their own consent rows and the table policy enforces ownership.
alter function public.bil_get_remote_ai_consent() security invoker;
commit;
