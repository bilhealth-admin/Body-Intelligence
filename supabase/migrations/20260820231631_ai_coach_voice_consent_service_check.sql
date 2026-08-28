begin;

-- Edge Functions need to know only whether the latest explicit receipt is a
-- currently granted voice-capable policy. Do not grant service_role direct
-- SELECT access to the consent history table.
create or replace function public.bil_has_remote_ai_voice_consent(
  p_owner_id uuid
) returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((
    select r.granted and r.policy_version = '2'
    from public.bil_consent_receipts r
    where r.user_id = p_owner_id
      and r.purpose = 'remote_ai'
    order by r.recorded_at desc
    limit 1
  ), false)
$$;

revoke all on function public.bil_has_remote_ai_voice_consent(uuid)
  from public, anon, authenticated;
grant execute on function public.bil_has_remote_ai_voice_consent(uuid)
  to service_role;

commit;;
