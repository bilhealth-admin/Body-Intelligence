-- Keep an account-deletion request idempotent while it is active. Recording
-- the request does not claim that the separately deployed worker completed it.

lock table public.bil_account_deletion_requests in share row exclusive mode;

with ranked as (
  select id,
         row_number() over (
           partition by user_id
           order by
             case status when 'processing' then 0 else 1 end,
             requested_at,
             id
         ) as position
  from public.bil_account_deletion_requests
  where status in ('pending', 'processing')
)
update public.bil_account_deletion_requests as request
set status = 'cancelled'
from ranked
where request.id = ranked.id and ranked.position > 1;

create unique index if not exists bil_account_deletion_one_active_per_user
  on public.bil_account_deletion_requests(user_id)
  where status in ('pending', 'processing');

drop function if exists public.bil_request_account_deletion(text);
create function public.bil_request_account_deletion(p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.bil_account_deletion_requests%rowtype;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select * into v_request
  from public.bil_account_deletion_requests
  where user_id = v_user_id and status in ('pending', 'processing')
  order by requested_at, id
  limit 1;

  if not found then
    perform bil_consume_rate_limit('account_deletion', 3, 86400);
    insert into public.bil_account_deletion_requests(user_id, reason)
    values (v_user_id, left(nullif(trim(p_reason), ''), 500))
    returning * into v_request;
  end if;

  update public.bil_push_device_tokens
  set enabled = false
  where user_id = v_user_id;

  return jsonb_build_object(
    'request_id', v_request.id,
    'status', v_request.status,
    'requested_at', v_request.requested_at
  );
end $$;

revoke all on function public.bil_request_account_deletion(text) from public, anon;
grant execute on function public.bil_request_account_deletion(text) to authenticated;
