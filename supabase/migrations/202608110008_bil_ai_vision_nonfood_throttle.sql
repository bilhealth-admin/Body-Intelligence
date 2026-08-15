begin;

create or replace function public.bil_check_vision_nonfood_throttle(p_owner_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_count integer; v_last timestamptz; v_cooldown interval; v_retry integer;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  select count(*),max(created_at) into v_count,v_last
    from public.bil_ai_usage_events
    where owner_id=p_owner_id and capability='vision'
      and result_kind='unknown_nonfood' and created_at>=now()-interval '1 hour';
  v_cooldown:=case when v_count>=10 then interval '30 minutes'
    when v_count>=6 then interval '5 minutes'
    when v_count>=3 then interval '1 minute' else interval '0 seconds' end;
  v_retry:=case when v_last is null then 0 else
    greatest(ceil(extract(epoch from ((v_last+v_cooldown)-now())))::integer,0) end;
  return jsonb_build_object('allowed',v_retry=0,'retry_after_seconds',v_retry,
    'unknown_nonfood_1h',v_count);
end $$;

revoke all on function public.bil_check_vision_nonfood_throttle(uuid)
  from public,anon,authenticated;
grant execute on function public.bil_check_vision_nonfood_throttle(uuid)
  to service_role;

commit;
