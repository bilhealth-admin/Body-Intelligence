begin;

create table if not exists private.bil_admin_ai_boost_grants (
  notification_id uuid not null
    references private.bil_admin_notification_audit(notification_id)
    on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  tokens bigint not null check (tokens = 2500),
  created_at timestamptz not null default now(),
  primary key (notification_id, owner_id)
);

alter table private.bil_admin_ai_boost_grants enable row level security;
revoke all on table private.bil_admin_ai_boost_grants
  from public, anon, authenticated;

create table if not exists private.bil_admin_notification_message_overrides (
  idempotency_key text primary key,
  notification_kind text not null
    check (notification_kind in ('compensation', 'gift')),
  created_at timestamptz not null default now()
);

alter table private.bil_admin_notification_message_overrides
  enable row level security;
revoke all on table private.bil_admin_notification_message_overrides
  from public, anon, authenticated;

create or replace function private.bil_grant_admin_notice_ai_boost()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.notification_kind not in ('compensation', 'gift') then
    return new;
  end if;

  insert into private.bil_admin_ai_boost_grants(
    notification_id, owner_id, tokens
  ) values (
    new.notification_id, new.owner_id, 2500
  ) on conflict do nothing;

  if found then
    insert into public.bil_ai_credit_balances(owner_id, granted)
    values(new.owner_id, 2500)
    on conflict(owner_id) do update set
      granted = public.bil_ai_credit_balances.granted + excluded.granted,
      updated_at = now();
  end if;

  return new;
end
$$;

revoke all on function private.bil_grant_admin_notice_ai_boost()
  from public, anon, authenticated;

drop trigger if exists bil_admin_notice_ai_boost_grant
  on public.bil_admin_notices;
create trigger bil_admin_notice_ai_boost_grant
after insert or update of notification_kind
on public.bil_admin_notices
for each row execute function private.bil_grant_admin_notice_ai_boost();

create or replace function public.bil_enqueue_admin_notification_with_message(
  p_actor_id uuid,
  p_notification_kind text,
  p_audience text,
  p_target_id uuid,
  p_message text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text := lower(trim(coalesce(p_notification_kind, '')));
  v_message text := trim(coalesce(p_message, ''));
  v_inserted integer;
  v_existing_kind text;
  v_result jsonb;
  v_notification_id uuid;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if not exists (
    select 1 from private.bil_ai_coach_admins a
    where a.user_id = p_actor_id
  ) then
    raise exception 'ai_coach_admin_required';
  end if;
  if v_kind not in ('compensation', 'gift') then
    raise exception 'invalid_notification_kind';
  end if;
  if char_length(v_message) not between 1 and 180
     or v_message ~ '[[:cntrl:]]' then
    raise exception 'invalid_notification_message';
  end if;

  insert into private.bil_admin_notification_message_overrides(
    idempotency_key, notification_kind
  ) values (
    trim(p_idempotency_key), v_kind
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select notification_kind into v_existing_kind
    from private.bil_admin_notification_message_overrides
    where idempotency_key = trim(p_idempotency_key);
    if v_existing_kind is distinct from v_kind then
      raise exception 'idempotency_key_request_mismatch';
    end if;
  end if;

  v_result := public.bil_enqueue_admin_notification(
    p_actor_id,
    'custom',
    p_audience,
    p_target_id,
    v_message,
    p_idempotency_key
  );

  select a.notification_id into v_notification_id
  from private.bil_admin_notification_audit a
  where a.idempotency_key = trim(p_idempotency_key);

  if v_notification_id is null then
    raise exception 'notification_audit_missing';
  end if;

  update public.bil_admin_notices n
  set notification_kind = v_kind
  where n.notification_id = v_notification_id
    and n.notification_kind = 'custom';

  return v_result || jsonb_build_object(
    'boost_tokens_per_recipient', 2500
  );
end
$$;

revoke all on function public.bil_enqueue_admin_notification_with_message(
  uuid, text, text, uuid, text, text
) from public, anon, authenticated;
grant execute on function public.bil_enqueue_admin_notification_with_message(
  uuid, text, text, uuid, text, text
) to service_role;

commit;