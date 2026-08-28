begin;
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
      and e.capability in ('text', 'voice')
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
commit;
