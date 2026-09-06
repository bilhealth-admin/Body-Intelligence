begin;

-- A reset notice grants one fixed AI Boost credit exactly once for the
-- reset/user pair. reset_id intentionally has no standalone foreign key: the
-- durable notice authority is keyed by (owner_id, reset_id), while this
-- idempotency ledger is keyed in the requested reset-first order.
create table if not exists private.bil_ai_coach_reset_token_grants (
  reset_id uuid not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  tokens bigint not null default 2500 check (tokens = 2500),
  granted_at timestamptz not null default now(),
  primary key (reset_id, owner_id)
);

alter table private.bil_ai_coach_reset_token_grants enable row level security;
revoke all on table private.bil_ai_coach_reset_token_grants
  from public, anon, authenticated;

create or replace function private.bil_grant_ai_coach_reset_tokens()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted integer := 0;
begin
  insert into private.bil_ai_coach_reset_token_grants(
    reset_id, owner_id, tokens
  ) values (
    new.reset_id, new.owner_id, 2500
  )
  on conflict (reset_id, owner_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 1 then
    insert into public.bil_ai_credit_balances(owner_id, granted)
    values (new.owner_id, 2500)
    on conflict (owner_id) do update set
      granted = public.bil_ai_credit_balances.granted + excluded.granted,
      updated_at = now();
  end if;

  return new;
end
$$;

revoke all on function private.bil_grant_ai_coach_reset_tokens()
  from public, anon, authenticated;

drop trigger if exists bil_ai_coach_reset_token_grant
  on public.bil_ai_coach_reset_notices;
create trigger bil_ai_coach_reset_token_grant
after insert on public.bil_ai_coach_reset_notices
for each row execute function private.bil_grant_ai_coach_reset_tokens();

-- Existing installs receive at most one repair grant per owner: only the
-- newest still-unread reset notice from the last 14 days is eligible.
with ranked_unread as (
  select
    n.owner_id,
    n.reset_id,
    row_number() over (
      partition by n.owner_id
      order by n.created_at desc, n.reset_id desc
    ) as owner_rank
  from public.bil_ai_coach_reset_notices n
  where n.seen_at is null
    and n.created_at >= now() - interval '14 days'
), inserted_grants as (
  insert into private.bil_ai_coach_reset_token_grants(
    reset_id, owner_id, tokens
  )
  select r.reset_id, r.owner_id, 2500
  from ranked_unread r
  where r.owner_rank = 1
  on conflict (reset_id, owner_id) do nothing
  returning owner_id, tokens
)
insert into public.bil_ai_credit_balances(owner_id, granted)
select g.owner_id, sum(g.tokens)::bigint
from inserted_grants g
group by g.owner_id
on conflict (owner_id) do update set
  granted = public.bil_ai_credit_balances.granted + excluded.granted,
  updated_at = now();

-- Preserve owner-authored gift/compensation copy by creating the underlying
-- notice as custom text, then changing only its semantic kind. The base RPC's
-- message digest continues to reject reuse of an idempotency key with
-- different text.
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
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_actor_id is null or not exists (
    select 1
    from private.bil_ai_coach_admins a
    where a.user_id = p_actor_id and a.active
  ) then
    raise exception 'ai_coach_admin_required' using errcode = '42501';
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

comment on function public.bil_enqueue_admin_notification_with_message(
  uuid, text, text, uuid, text, text
) is
  'Service-only active-admin notification fan-out preserving exact owner-authored gift or compensation text.';

-- Reset gifts are deliberately 2,500 non-expiring paid tokens, so a reset
-- opens AI Coach even for an account without an included allowance. Keep the
-- administrator-authored message on the same atomic reset transaction and on
-- the durable in-app notice; the push outbox cannot observe it before commit.
alter table public.bil_ai_coach_reset_notices
  add column if not exists message text;
alter table public.bil_ai_coach_reset_notices
  drop constraint if exists bil_ai_coach_reset_notices_message_check;
alter table public.bil_ai_coach_reset_notices
  add constraint bil_ai_coach_reset_notices_message_check
  check (
    message is null or (
      char_length(message) between 1 and 180
      and message !~ '[[:cntrl:]]'
    )
  );

alter table private.bil_ai_coach_global_reset_audit
  add column if not exists custom_message text;
alter table private.bil_ai_coach_individual_reset_audit
  add column if not exists custom_message text;

alter table private.bil_ai_coach_global_reset_audit
  drop constraint if exists bil_ai_coach_global_reset_message_check;
alter table private.bil_ai_coach_global_reset_audit
  add constraint bil_ai_coach_global_reset_message_check
  check (
    custom_message is null or (
      char_length(custom_message) between 1 and 180
      and custom_message !~ '[[:cntrl:]]'
    )
  );
alter table private.bil_ai_coach_individual_reset_audit
  drop constraint if exists bil_ai_coach_individual_reset_message_check;
alter table private.bil_ai_coach_individual_reset_audit
  add constraint bil_ai_coach_individual_reset_message_check
  check (
    custom_message is null or (
      char_length(custom_message) between 1 and 180
      and custom_message !~ '[[:cntrl:]]'
    )
  );

create or replace function public.bil_global_reset_ai_coach(
  p_actor_id uuid,
  p_idempotency_key text,
  p_message text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message text := trim(coalesce(p_message, ''));
  v_result jsonb;
  v_reset_id uuid;
  v_existing_message text;
begin
  if char_length(v_message) not between 1 and 180
     or v_message ~ '[[:cntrl:]]' then
    raise exception 'invalid_reset_message';
  end if;

  -- The established two-argument function owns authorization, locking,
  -- counter reset, audit creation, notice fan-out, and idempotency.
  v_result := public.bil_global_reset_ai_coach(
    p_actor_id,
    p_idempotency_key
  );
  v_reset_id := nullif(v_result->>'reset_id', '')::uuid;
  if v_reset_id is null then
    raise exception 'reset_audit_missing';
  end if;

  select a.custom_message into v_existing_message
  from private.bil_ai_coach_global_reset_audit a
  where a.reset_id = v_reset_id;
  if v_existing_message is not null
     and v_existing_message is distinct from v_message then
    raise exception 'idempotency_key_request_mismatch';
  end if;

  update private.bil_ai_coach_global_reset_audit a
  set custom_message = v_message
  where a.reset_id = v_reset_id
    and a.custom_message is null;

  update public.bil_ai_coach_reset_notices n
  set message = v_message
  where n.reset_id = v_reset_id
    and (n.message is null or n.message = v_message);

  update public.bil_push_outbox o
  set body = v_message
  where o.source_key = 'ai-coach-global-reset:' || v_reset_id::text;

  return v_result || jsonb_build_object(
    'boost_tokens_per_recipient', 2500,
    'custom_message_applied', true
  );
end
$$;

create or replace function public.bil_individual_reset_ai_coach(
  p_actor_id uuid,
  p_target_id uuid,
  p_reason text,
  p_idempotency_key text,
  p_message text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message text := trim(coalesce(p_message, ''));
  v_result jsonb;
  v_reset_id uuid;
  v_existing_message text;
begin
  if char_length(v_message) not between 1 and 180
     or v_message ~ '[[:cntrl:]]' then
    raise exception 'invalid_reset_message';
  end if;

  v_result := public.bil_individual_reset_ai_coach(
    p_actor_id,
    p_target_id,
    p_reason,
    p_idempotency_key
  );
  v_reset_id := nullif(v_result->>'reset_id', '')::uuid;
  if v_reset_id is null then
    raise exception 'reset_audit_missing';
  end if;

  select a.custom_message into v_existing_message
  from private.bil_ai_coach_individual_reset_audit a
  where a.reset_id = v_reset_id;
  if v_existing_message is not null
     and v_existing_message is distinct from v_message then
    raise exception 'idempotency_key_request_mismatch';
  end if;

  update private.bil_ai_coach_individual_reset_audit a
  set custom_message = v_message
  where a.reset_id = v_reset_id
    and a.custom_message is null;

  update public.bil_ai_coach_reset_notices n
  set message = v_message
  where n.owner_id = p_target_id
    and n.reset_id = v_reset_id
    and (n.message is null or n.message = v_message);

  update public.bil_push_outbox o
  set body = v_message
  where o.recipient_id = p_target_id
    and o.source_key = 'ai-coach-individual-reset:' || v_reset_id::text;

  return v_result || jsonb_build_object(
    'boost_tokens_per_recipient', 2500,
    'custom_message_applied', true
  );
end
$$;

revoke all on function public.bil_global_reset_ai_coach(uuid, text, text),
  public.bil_individual_reset_ai_coach(uuid, uuid, text, text, text)
  from public, anon, authenticated;

-- Service callers must supply the administrator-authored message through the
-- overloads below. The wrappers can still invoke the established base
-- functions atomically as their owning role.
revoke execute on function public.bil_global_reset_ai_coach(uuid, text),
  public.bil_individual_reset_ai_coach(uuid, uuid, text, text)
  from service_role;

grant execute on function public.bil_global_reset_ai_coach(uuid, text, text),
  public.bil_individual_reset_ai_coach(uuid, uuid, text, text, text)
  to service_role;

comment on function public.bil_global_reset_ai_coach(uuid, text, text) is
  'Atomic global current-period usage reset plus pair-idempotent 2,500-token gift and administrator-authored notice.';
comment on function public.bil_individual_reset_ai_coach(uuid, uuid, text, text, text) is
  'Atomic individual current-period usage reset plus pair-idempotent 2,500-token gift and administrator-authored notice.';

commit;
