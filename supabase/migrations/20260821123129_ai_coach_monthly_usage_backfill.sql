
insert into public.bil_ai_credit_monthly_usage(
  owner_id, month_start, used, reserved, updated_at
)
select
  owner_id,
  date_trunc('month', now() at time zone 'utc')::date,
  sum(used)::bigint,
  sum(reserved)::bigint,
  now()
from public.bil_ai_credit_weekly_usage
where week_start >= (
    date_trunc('month', now() at time zone 'utc')::date - 6
  )
  and week_start < (
    date_trunc('month', now() at time zone 'utc')::date +
    interval '1 month'
  )
group by owner_id
on conflict (owner_id, month_start) do update set
  used = excluded.used,
  reserved = excluded.reserved,
  updated_at = excluded.updated_at;
;
