begin;

alter table public.bil_ai_usage_events
  add column if not exists reserved_seconds integer,
  add column if not exists actual_seconds integer;

alter table public.bil_ai_usage_events
  drop constraint if exists bil_ai_usage_voice_seconds_check;
alter table public.bil_ai_usage_events
  add constraint bil_ai_usage_voice_seconds_check check (
    (reserved_seconds is null or reserved_seconds between 1 and 900)
    and (actual_seconds is null or actual_seconds between 0 and 900)
  );

create or replace function public.bil_reserve_ai_voice(
  p_owner_id uuid,p_request_id text,p_estimated_seconds integer
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_result jsonb;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if p_estimated_seconds not between 1 and 900 then
    raise exception 'invalid_voice_reservation_seconds';
  end if;
  v_result:=public.bil_reserve_ai_usage(
    p_owner_id,p_request_id,'voice',p_estimated_seconds::numeric/60
  );
  if coalesce((v_result->>'duplicate')::boolean,false)=false then
    update public.bil_ai_usage_events set reserved_seconds=p_estimated_seconds
      where owner_id=p_owner_id and request_id=trim(p_request_id)
        and capability='voice';
  end if;
  return v_result||jsonb_build_object('reserved_seconds',p_estimated_seconds);
end $$;

create or replace function public.bil_settle_ai_voice(
  p_owner_id uuid,p_request_id text,p_succeeded boolean,p_actual_seconds integer,
  p_provider text default null,p_model text default null,
  p_input_tokens integer default null,p_output_tokens integer default null,
  p_latency_ms integer default null,p_cost_usd numeric default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_event public.bil_ai_usage_events%rowtype;
  v_actual_units numeric(12,6);
  v_week_actual numeric(12,6);
  v_paid_actual numeric(12,6);
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required'; end if;
  if p_actual_seconds not between 0 and 900 then raise exception 'invalid_voice_actual_seconds'; end if;
  if p_input_tokens<0 or p_output_tokens<0 or p_latency_ms<0 or p_cost_usd<0 then
    raise exception 'invalid_ai_usage_telemetry';
  end if;
  select * into v_event from public.bil_ai_usage_events
    where owner_id=p_owner_id and request_id=trim(p_request_id)
      and capability='voice' for update;
  if not found then raise exception 'unknown_ai_usage_reservation'; end if;
  if v_event.state<>'reserved' then
    return jsonb_build_object('duplicate',true,'state',v_event.state,
      'actual_seconds',v_event.actual_seconds);
  end if;
  if p_actual_seconds>coalesce(v_event.reserved_seconds,0) then
    raise exception 'voice_actual_exceeds_reservation';
  end if;
  if v_event.reservation_expires_at<=now() then
    p_succeeded:=false;
  end if;
  v_actual_units:=case when p_succeeded then p_actual_seconds::numeric/60 else 0 end;
  -- Preserve weekly-first source ordering from the original reservation.
  v_week_actual:=least(v_actual_units,v_event.weekly_debit);
  v_paid_actual:=v_actual_units-v_week_actual;
  if v_paid_actual>v_event.paid_debit then raise exception 'voice_source_settlement_mismatch'; end if;
  update public.bil_ai_weekly_usage set
    reserved=greatest(reserved-v_event.weekly_debit,0),used=used+v_week_actual,updated_at=now()
    where owner_id=p_owner_id and week_start=v_event.week_start and capability='voice';
  update public.bil_ai_paid_balances set
    reserved=greatest(reserved-v_event.paid_debit,0),used=used+v_paid_actual,updated_at=now()
    where owner_id=p_owner_id and capability='voice';
  update public.bil_ai_usage_events set
    state=case when p_succeeded then 'succeeded' else 'refunded' end,
    weekly_debit=v_week_actual,paid_debit=v_paid_actual,actual_seconds=p_actual_seconds,
    provider=nullif(trim(p_provider),''),model=nullif(trim(p_model),''),
    input_tokens=p_input_tokens,output_tokens=p_output_tokens,
    latency_ms=p_latency_ms,cost_usd=p_cost_usd,completed_at=now()
    where owner_id=p_owner_id and request_id=trim(p_request_id) and capability='voice';
  return jsonb_build_object('duplicate',false,
    'state',case when p_succeeded then 'succeeded' else 'refunded' end,
    'actual_seconds',p_actual_seconds,'weekly_debit_minutes',v_week_actual,
    'paid_debit_minutes',v_paid_actual);
end $$;

revoke all on function public.bil_reserve_ai_voice(uuid,text,integer),
  public.bil_settle_ai_voice(uuid,text,boolean,integer,text,text,integer,integer,integer,numeric)
  from public,anon,authenticated;
grant execute on function public.bil_reserve_ai_voice(uuid,text,integer),
  public.bil_settle_ai_voice(uuid,text,boolean,integer,text,text,integer,integer,integer,numeric)
  to service_role;

commit;
