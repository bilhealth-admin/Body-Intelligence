begin;

-- Monthly allowance belongs to the reservation event's period, not to the
-- Monday that names its weekly aggregate row.  A week can cross a calendar
-- month, while the event timestamp remains the stable reservation period for
-- both reservation and later settlement/refund.
create or replace function public.bil_sync_ai_monthly_usage_from_event()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_month date := private.bil_current_ai_month_start(
    new.owner_id,
    new.created_at
  );
  v_plan text := public.bil_resolve_ai_allowance_plan(new.owner_id);
  v_old_used bigint := 0;
  v_old_reserved bigint := 0;
  v_new_used bigint := 0;
  v_new_reserved bigint := 0;
  v_used_delta bigint;
  v_reserved_delta bigint;
  v_limit bigint;
  v_total bigint;
begin
  if tg_op = 'UPDATE' and old.created_at is distinct from new.created_at then
    raise exception 'ai_usage_event_period_immutable';
  end if;

  if tg_op = 'UPDATE' then
    v_old_reserved := case when old.state = 'reserved'
      then coalesce(old.credit_weekly_debit, 0) else 0 end;
    v_old_used := case when old.state = 'succeeded' then
      greatest(
        coalesce(old.credit_actual, 0) - least(
          greatest(
            coalesce(old.credit_actual, 0) -
              coalesce(old.credit_weekly_debit, 0),
            0
          ),
          coalesce(old.credit_paid_debit, 0)
        ),
        0
      )
      else 0 end;
  end if;

  v_new_reserved := case when new.state = 'reserved'
    then coalesce(new.credit_weekly_debit, 0) else 0 end;
  v_new_used := case when new.state = 'succeeded' then
    greatest(
      coalesce(new.credit_actual, 0) - least(
        greatest(
          coalesce(new.credit_actual, 0) -
            coalesce(new.credit_weekly_debit, 0),
          0
        ),
        coalesce(new.credit_paid_debit, 0)
      ),
      0
    )
    else 0 end;

  v_used_delta := v_new_used - v_old_used;
  v_reserved_delta := v_new_reserved - v_old_reserved;

  insert into public.bil_ai_credit_monthly_usage(owner_id, month_start)
    values(new.owner_id, v_month) on conflict do nothing;
  select monthly_limit into v_limit
  from public.bil_ai_credit_config
  where plan_id = v_plan;

  update public.bil_ai_credit_monthly_usage set
    used = greatest(used + v_used_delta, 0),
    reserved = greatest(reserved + v_reserved_delta, 0),
    updated_at = now()
  where owner_id = new.owner_id and month_start = v_month
  returning used + reserved into v_total;

  if v_used_delta + v_reserved_delta > 0
     and v_limit is not null
     and v_total > v_limit then
    raise exception 'ai_monthly_usage_exhausted';
  end if;
  return new;
end
$$;

drop trigger if exists bil_ai_credit_monthly_usage_sync
  on public.bil_ai_credit_weekly_usage;
drop trigger if exists bil_ai_credit_monthly_event_sync
  on public.bil_ai_usage_events;
create trigger bil_ai_credit_monthly_event_sync
after insert or update of state, credit_weekly_debit, credit_paid_debit,
  credit_actual
on public.bil_ai_usage_events
for each row execute function public.bil_sync_ai_monthly_usage_from_event();

-- Reconcile existing rows from the immutable reservation timestamp. This also
-- repairs any cross-month rows attributed previously from week_start.
insert into public.bil_ai_credit_monthly_usage(
  owner_id, month_start, used, reserved, updated_at
)
select
  event.owner_id,
  private.bil_current_ai_month_start(event.owner_id, event.created_at),
  coalesce(sum(
    case when event.state = 'succeeded' then
      greatest(
        coalesce(event.credit_actual, 0) - least(
          greatest(
            coalesce(event.credit_actual, 0) -
              coalesce(event.credit_weekly_debit, 0),
            0
          ),
          coalesce(event.credit_paid_debit, 0)
        ),
        0
      )
      else 0 end
  ), 0)::bigint,
  coalesce(sum(
    case when event.state = 'reserved'
      then coalesce(event.credit_weekly_debit, 0) else 0 end
  ), 0)::bigint,
  now()
from public.bil_ai_usage_events event
where event.credit_weekly_debit is not null
group by
  event.owner_id,
  private.bil_current_ai_month_start(event.owner_id, event.created_at)
on conflict (owner_id, month_start) do update set
  used = excluded.used,
  reserved = excluded.reserved,
  updated_at = excluded.updated_at;

revoke all on function public.bil_sync_ai_monthly_usage_from_event()
  from public, anon, authenticated;

commit;
