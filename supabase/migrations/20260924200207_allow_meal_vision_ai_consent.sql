begin;

-- Meal-photo analysis has a disclosure that is materially separate from the
-- AI Coach text-context disclosure. Permit the dedicated versioned purpose
-- without broadening client access to any consent row owned by another user.
alter table public.bil_consent_receipts
  drop constraint if exists bil_consent_receipts_purpose_check;

alter table public.bil_consent_receipts
  add constraint bil_consent_receipts_purpose_check
  check (purpose in (
    'health','camera','microphone','photos','notifications','devices',
    'remote_ai','cloud_sync','meal_vision_ai'
  ));

create or replace function public.bil_record_consent(
  p_purpose text, p_policy_version text, p_granted boolean
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_purpose not in (
      'health','camera','microphone','photos','notifications','devices',
      'remote_ai','cloud_sync','meal_vision_ai'
    )
    or length(trim(p_policy_version)) not between 1 and 64 then
    raise exception 'invalid_consent';
  end if;
  insert into public.bil_consent_receipts(
    user_id, purpose, policy_version, granted
  ) values (
    auth.uid(), p_purpose, trim(p_policy_version), coalesce(p_granted, false)
  )
  on conflict(user_id, purpose, policy_version) do update
    set granted = excluded.granted, recorded_at = now();
end;
$$;

revoke all on function public.bil_record_consent(text, text, boolean)
  from public, anon;
grant execute on function public.bil_record_consent(text, text, boolean)
  to authenticated;

commit;
