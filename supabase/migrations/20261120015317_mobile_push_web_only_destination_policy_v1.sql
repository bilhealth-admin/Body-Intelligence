-- Mobile administration was removed; retain review receipts/web audit while
-- explicitly closing only their phone-delivery rows. Ordinary social pushes
-- and owner roles are outside this policy. Deploy before the dispatcher.
begin;

create function public.bil_suppress_web_only_mobile_push_v1(p_outbox_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_outbox public.bil_push_outbox%rowtype;
begin
  if p_outbox_id is null then
    raise exception 'push_outbox_id_required' using errcode = '22023';
  end if;

  select * into v_outbox from public.bil_push_outbox
  where id = p_outbox_id for update;
  if not found then return false; end if;

  -- Source keys are produced by the protected review emitter. The destination
  -- alternative covers older admin notices without that source key. Match a
  -- complete route segment; never suppress community, messages or gifts just
  -- because their category/copy contains the word "admin".
  if not (
    pg_catalog.starts_with(coalesce(v_outbox.source_key, ''), 'post-event:review_requested:')
    or pg_catalog.lower(coalesce(v_outbox.deep_link, ''))
      ~ '^bil:/+(admin(/|[?#]|$)|community/(moderation|food-review)(/|[?#]|$))'
  ) then
    return false;
  end if;

  -- Keep the outbox and all receipt/attempt history. An already accepted or
  -- finalized notification is historical evidence, not a retractable push.
  if v_outbox.dispatched_at is null then
    update public.bil_push_outbox
    set dispatched_at = pg_catalog.clock_timestamp(),
        failure_code = 'web_only_destination'
    where id = p_outbox_id;
  end if;
  return true;
end;
$$;

revoke all on function public.bil_suppress_web_only_mobile_push_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.bil_suppress_web_only_mobile_push_v1(uuid)
  to service_role;

comment on function public.bil_suppress_web_only_mobile_push_v1(uuid) is
  'Internal mobile dispatcher policy: preserve web-only review/admin receipts and close only their phone outbox rows without claiming or disabling devices.';

commit;
