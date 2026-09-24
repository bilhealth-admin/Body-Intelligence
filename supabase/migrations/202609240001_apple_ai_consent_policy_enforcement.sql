begin;

-- A prior grant is not consent to the materially expanded Apple disclosure.
-- Keep the established RPC signature while requiring the current policy.
create or replace function public.bil_has_remote_ai_consent(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((
    select r.granted and r.policy_version = '3'
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
