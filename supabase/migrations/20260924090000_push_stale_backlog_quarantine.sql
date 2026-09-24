-- Source-only activation safety. This migration is intentionally not deployed
-- by the build-28/24 preparation task.
create or replace function public.bil_quarantine_stale_push_outbox(
  p_before timestamptz,
  p_reason text default 'stale_before_push_activation'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if p_before is null or p_before > pg_catalog.clock_timestamp() then
    raise exception 'invalid_stale_push_cutoff';
  end if;
  if p_reason not in (
    'stale_before_push_activation',
    'stale_delivery_window_expired'
  ) then
    raise exception 'invalid_stale_push_reason';
  end if;

  update public.bil_push_outbox
     set dispatched_at = pg_catalog.clock_timestamp(),
         failure_code = p_reason
   where dispatched_at is null
     and created_at < p_before;
  get diagnostics v_count = row_count;
  return v_count;
end
$$;

comment on function public.bil_quarantine_stale_push_outbox(timestamptz, text)
is 'Finalizes expired push events without delivery or content deletion; failure_code preserves an auditable non-delivery reason.';

revoke all on function public.bil_quarantine_stale_push_outbox(timestamptz, text)
  from public, anon, authenticated, service_role;
grant execute on function public.bil_quarantine_stale_push_outbox(timestamptz, text)
  to service_role;
