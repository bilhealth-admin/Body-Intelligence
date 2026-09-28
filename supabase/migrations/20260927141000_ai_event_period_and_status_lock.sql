begin;
alter table public.bil_ai_usage_events
  add column if not exists credit_plan_id text,
  add column if not exists credit_period_start date;
create or replace function public.bil_stamp_ai_usage_event_period()
returns trigger language plpgsql security invoker set search_path=public
as $$
begin
  if tg_op='UPDATE' then
    if old.created_at is distinct from new.created_at
       or old.credit_plan_id is distinct from new.credit_plan_id
       or old.credit_period_start is distinct from new.credit_period_start then
      raise exception 'ai_usage_event_period_immutable';
    end if;
    return new;
  end if;
  if new.credit_weekly_debit is not null then
    new.credit_plan_id := public.bil_resolve_ai_allowance_plan(new.owner_id);
    new.credit_period_start := private.bil_current_ai_month_start(
      new.owner_id,new.created_at
    );
  end if;
  return new;
end
$$;
drop trigger if exists bil_ai_usage_event_period_stamp
  on public.bil_ai_usage_events;
create trigger bil_ai_usage_event_period_stamp
before insert or update of created_at,credit_plan_id,credit_period_start
on public.bil_ai_usage_events
for each row execute function public.bil_stamp_ai_usage_event_period();
-- Only live reservations can still settle under a later plan. Historical rows
-- remain untouched because reconstructing a past plan would be speculative.
update public.bil_ai_usage_events event set
  credit_plan_id=public.bil_resolve_ai_allowance_plan(event.owner_id),
  credit_period_start=private.bil_current_ai_month_start(
    event.owner_id,event.created_at
  )
where event.state='reserved'
  and event.credit_weekly_debit is not null
  and (event.credit_plan_id is null or event.credit_period_start is null);
create or replace function public.bil_sync_ai_monthly_usage_from_event()
returns trigger language plpgsql security invoker set search_path=public
as $$
declare
  v_month date := coalesce(
    new.credit_period_start,
    private.bil_current_ai_month_start(new.owner_id,new.created_at)
  );
  v_plan text := coalesce(
    new.credit_plan_id,
    public.bil_resolve_ai_allowance_plan(new.owner_id)
  );
  v_old_used bigint := 0; v_old_reserved bigint := 0;
  v_new_used bigint := 0; v_new_reserved bigint := 0;
  v_used_delta bigint; v_reserved_delta bigint;
  v_limit bigint; v_total bigint;
begin
  if tg_op='UPDATE' and (
    old.created_at is distinct from new.created_at
    or old.credit_plan_id is distinct from new.credit_plan_id
    or old.credit_period_start is distinct from new.credit_period_start
  ) then raise exception 'ai_usage_event_period_immutable'; end if;
  if tg_op='UPDATE' then
    v_old_reserved := case when old.state='reserved'
      then coalesce(old.credit_weekly_debit,0) else 0 end;
    v_old_used := case when old.state='succeeded' then greatest(
      coalesce(old.credit_actual,0)-least(greatest(
        coalesce(old.credit_actual,0)-coalesce(old.credit_weekly_debit,0),0
      ),coalesce(old.credit_paid_debit,0)),0
    ) else 0 end;
  end if;
  v_new_reserved := case when new.state='reserved'
    then coalesce(new.credit_weekly_debit,0) else 0 end;
  v_new_used := case when new.state='succeeded' then greatest(
    coalesce(new.credit_actual,0)-least(greatest(
      coalesce(new.credit_actual,0)-coalesce(new.credit_weekly_debit,0),0
    ),coalesce(new.credit_paid_debit,0)),0
  ) else 0 end;
  v_used_delta:=v_new_used-v_old_used;
  v_reserved_delta:=v_new_reserved-v_old_reserved;
  insert into public.bil_ai_credit_monthly_usage(owner_id,month_start)
    values(new.owner_id,v_month) on conflict do nothing;
  select monthly_limit into v_limit from public.bil_ai_credit_config
    where plan_id=v_plan;
  update public.bil_ai_credit_monthly_usage set
    used=greatest(used+v_used_delta,0),
    reserved=greatest(reserved+v_reserved_delta,0),updated_at=now()
    where owner_id=new.owner_id and month_start=v_month
    returning used+reserved into v_total;
  if v_used_delta+v_reserved_delta>0 and v_limit is not null
     and v_total>v_limit then raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$$;
-- Status cleanup mutates the same ledgers as reserve/settle. Serialize it with
-- their established per-owner lock to remove reverse lock-order deadlocks.
alter function public.bil_get_ai_usage_status()
  rename to bil_get_ai_usage_status_unserialized;
revoke all on function public.bil_get_ai_usage_status_unserialized()
  from public,anon,authenticated;
create function public.bil_get_ai_usage_status()
returns jsonb language plpgsql security definer set search_path=public,pg_temp
as $$
declare v_owner uuid:=auth.uid();
begin
  if v_owner is null then raise exception 'authentication_required'; end if;
  perform pg_advisory_xact_lock(
    hashtextextended('bil.ai.'||v_owner::text,0)
  );
  return public.bil_get_ai_usage_status_unserialized();
end
$$;
revoke all on function public.bil_stamp_ai_usage_event_period()
  from public,anon,authenticated;
revoke all on function public.bil_sync_ai_monthly_usage_from_event()
  from public,anon,authenticated;
revoke all on function public.bil_get_ai_usage_status()
  from public,anon;
grant execute on function public.bil_get_ai_usage_status()
  to authenticated;
commit;
