-- UNPUBLISHED SOURCE MIGRATION: per-device push delivery ledger and leases.
--
-- This migration is intentionally additive. It prevents a partial multi-device
-- failure (or concurrent dispatcher invocation) from re-sending notifications
-- that another device already received. Deploy this migration before deploying
-- the matching community-push-dispatch Edge Function.
begin;

-- Database-owner managed retry policy. Keeping it in one protected row makes
-- the operational ceiling and backoff parameters inspectable without allowing
-- an Edge Function or client to silently weaken them.
create table if not exists public.bil_push_delivery_policy (
  singleton boolean primary key default true check (singleton),
  max_attempts integer not null default 5 check (max_attempts between 1 and 20),
  base_backoff_seconds integer not null default 30
    check (base_backoff_seconds between 15 and 3600),
  max_backoff_seconds integer not null default 3600
    check (max_backoff_seconds between base_backoff_seconds and 86400),
  updated_at timestamptz not null default now()
);

insert into public.bil_push_delivery_policy(singleton)
values (true)
on conflict (singleton) do nothing;

create table if not exists public.bil_push_delivery_attempts (
  outbox_id uuid not null
    references public.bil_push_outbox(id) on delete cascade,
  device_token_id uuid not null
    references public.bil_push_device_tokens(id) on delete cascade,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  leased_until timestamptz,
  last_attempt_at timestamptz,
  next_attempt_at timestamptz not null default now(),
  delivered_at timestamptz,
  terminal_at timestamptz,
  permanent_token_failure boolean not null default false,
  failure_code text check (
    failure_code is null or char_length(failure_code) between 1 and 120
  ),
  created_at timestamptz not null default now(),
  primary key (outbox_id, device_token_id),
  check (delivered_at is null or terminal_at is null),
  check (not permanent_token_failure or terminal_at is not null)
);

create index if not exists bil_push_delivery_attempts_retry_idx
  on public.bil_push_delivery_attempts(
    outbox_id,
    next_attempt_at,
    leased_until
  )
  where delivered_at is null and terminal_at is null;

alter table public.bil_push_delivery_policy enable row level security;
alter table public.bil_push_delivery_attempts enable row level security;
revoke all on public.bil_push_delivery_policy
  from public, anon, authenticated, service_role;
revoke all on public.bil_push_delivery_attempts
  from public, anon, authenticated, service_role;
revoke all on public.bil_push_device_tokens
  from public, anon, authenticated, service_role;

comment on column public.bil_push_device_tokens.token_ciphertext is
  'Raw APNs/FCM provider token retained for delivery; despite the legacy column name it is not application-layer ciphertext. Exposure is contained by RLS, revoked table privileges, and service-role-only SECURITY DEFINER RPCs until an external KMS/envelope-encryption design is available.';

create or replace function public.bil_claim_push_deliveries(
  p_outbox_id uuid,
  p_lease_seconds integer default 60
)
returns table (
  device_token_id uuid,
  provider_token text,
  platform text,
  sensitive_preview_allowed boolean,
  delivery_key text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient_id uuid;
  v_max_attempts integer;
  v_lease_seconds integer := least(
    greatest(coalesce(p_lease_seconds, 60), 15),
    300
  );
begin
  select policy.max_attempts
    into v_max_attempts
  from public.bil_push_delivery_policy policy
  where policy.singleton;

  if v_max_attempts is null then
    raise exception 'push_delivery_policy_unavailable';
  end if;

  select o.recipient_id
    into v_recipient_id
  from public.bil_push_outbox o
  where o.id = p_outbox_id
    and o.dispatched_at is null
  for update;

  if v_recipient_id is null then
    return;
  end if;

  insert into public.bil_push_delivery_attempts(outbox_id, device_token_id)
  select p_outbox_id, token.id
  from public.bil_push_device_tokens token
  where token.user_id = v_recipient_id
    and token.enabled
  on conflict (outbox_id, device_token_id) do nothing;

  return query
  with eligible as (
    select attempt.outbox_id, attempt.device_token_id
    from public.bil_push_delivery_attempts attempt
    join public.bil_push_device_tokens token
      on token.id = attempt.device_token_id
    where attempt.outbox_id = p_outbox_id
      and token.user_id = v_recipient_id
      and token.enabled
      and attempt.delivered_at is null
      and attempt.terminal_at is null
      and attempt.attempt_count < v_max_attempts
      and attempt.next_attempt_at <= pg_catalog.clock_timestamp()
      and (
        attempt.leased_until is null or
        attempt.leased_until <= pg_catalog.clock_timestamp()
      )
    order by attempt.device_token_id
    limit 100
    for update of attempt skip locked
  ), claimed as (
    update public.bil_push_delivery_attempts attempt
       set leased_until = pg_catalog.clock_timestamp() +
             pg_catalog.make_interval(secs => v_lease_seconds),
           last_attempt_at = pg_catalog.clock_timestamp(),
           attempt_count = attempt.attempt_count + 1
      from eligible
     where attempt.outbox_id = eligible.outbox_id
       and attempt.device_token_id = eligible.device_token_id
    returning attempt.device_token_id
  )
  select
    token.id,
    token.token_ciphertext as provider_token,
    token.platform,
    token.sensitive_preview_allowed,
    p_outbox_id::text || ':' || token.id::text
  from claimed
  join public.bil_push_device_tokens token
    on token.id = claimed.device_token_id;
end
$$;

create or replace function public.bil_record_push_delivery_result(
  p_outbox_id uuid,
  p_device_token_id uuid,
  p_delivered boolean,
  p_failure_code text default null,
  p_permanent_token_failure boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt_count integer;
  v_existing_delivered_at timestamptz;
  v_max_attempts integer;
  v_base_backoff_seconds integer;
  v_max_backoff_seconds integer;
  v_backoff_seconds integer;
  v_terminal boolean;
  v_failure_code text;
begin
  select
    policy.max_attempts,
    policy.base_backoff_seconds,
    policy.max_backoff_seconds
    into v_max_attempts, v_base_backoff_seconds, v_max_backoff_seconds
  from public.bil_push_delivery_policy policy
  where policy.singleton;

  if v_max_attempts is null then
    raise exception 'push_delivery_policy_unavailable';
  end if;

  select attempt.attempt_count, attempt.delivered_at
    into v_attempt_count, v_existing_delivered_at
  from public.bil_push_delivery_attempts attempt
  where attempt.outbox_id = p_outbox_id
    and attempt.device_token_id = p_device_token_id
  for update;

  if not found or v_existing_delivered_at is not null then
    return;
  end if;

  if coalesce(p_delivered, false) then
    update public.bil_push_delivery_attempts attempt
       set delivered_at = pg_catalog.clock_timestamp(),
           terminal_at = null,
           permanent_token_failure = false,
           failure_code = null,
           leased_until = null
     where attempt.outbox_id = p_outbox_id
       and attempt.device_token_id = p_device_token_id;
    return;
  end if;

  v_failure_code := pg_catalog.left(
    coalesce(
      nullif(pg_catalog.btrim(p_failure_code), ''),
      'provider_failure'
    ),
    120
  );
  v_terminal := coalesce(p_permanent_token_failure, false)
    or v_attempt_count >= v_max_attempts;
  v_backoff_seconds := least(
    v_max_backoff_seconds,
    (
      v_base_backoff_seconds * pg_catalog.power(
        2::numeric,
        greatest(v_attempt_count - 1, 0)
      )
    )::integer
  );

  update public.bil_push_delivery_attempts attempt
     set terminal_at = case
           when v_terminal then pg_catalog.clock_timestamp()
           else null
         end,
         permanent_token_failure =
           coalesce(p_permanent_token_failure, false),
         failure_code = v_failure_code,
         leased_until = null,
         next_attempt_at = case
           when v_terminal then attempt.next_attempt_at
           else pg_catalog.clock_timestamp() +
             pg_catalog.make_interval(secs => v_backoff_seconds)
         end
   where attempt.outbox_id = p_outbox_id
     and attempt.device_token_id = p_device_token_id;

  -- Only the trusted provider gateway can assert this flag. A plain HTTP
  -- status is deliberately insufficient, preventing a bad gateway URL from
  -- disabling every device token. Exhausting retries terminates this delivery
  -- only and does not disable the token for future outbox rows.
  if coalesce(p_permanent_token_failure, false) then
    update public.bil_push_device_tokens token
       set enabled = false
     where token.id = p_device_token_id
       and exists (
         select 1
         from public.bil_push_outbox outbox
         where outbox.id = p_outbox_id
           and outbox.recipient_id = token.user_id
       );
  end if;
end
$$;

create or replace function public.bil_finalize_push_outbox(p_outbox_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient_id uuid;
  v_enabled_tokens integer := 0;
  v_enabled_without_attempt integer := 0;
  v_unresolved_enabled integer := 0;
  v_attempted_tokens integer := 0;
  v_delivered_tokens integer := 0;
  v_terminal_tokens integer := 0;
  v_failure_code text;
  v_reason text;
begin
  select o.recipient_id
    into v_recipient_id
  from public.bil_push_outbox o
  where o.id = p_outbox_id
    and o.dispatched_at is null
  for update;

  if v_recipient_id is null then
    return pg_catalog.jsonb_build_object(
      'finalized', true,
      'reason', 'already_finalized'
    );
  end if;

  select pg_catalog.count(*)::integer
    into v_enabled_tokens
  from public.bil_push_device_tokens token
  where token.user_id = v_recipient_id
    and token.enabled;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.count(*) filter (
      where attempt.delivered_at is not null
    )::integer,
    pg_catalog.count(*) filter (
      where attempt.delivered_at is null
        and attempt.terminal_at is not null
    )::integer
    into v_attempted_tokens, v_delivered_tokens, v_terminal_tokens
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token
    on token.id = attempt.device_token_id
  where attempt.outbox_id = p_outbox_id
    and token.user_id = v_recipient_id;

  select pg_catalog.count(*)::integer
    into v_enabled_without_attempt
  from public.bil_push_device_tokens token
  where token.user_id = v_recipient_id
    and token.enabled
    and not exists (
      select 1
      from public.bil_push_delivery_attempts attempt
      where attempt.outbox_id = p_outbox_id
        and attempt.device_token_id = token.id
    );

  select pg_catalog.count(*)::integer
    into v_unresolved_enabled
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token
    on token.id = attempt.device_token_id
  where attempt.outbox_id = p_outbox_id
    and token.user_id = v_recipient_id
    and token.enabled
    and attempt.delivered_at is null
    and attempt.terminal_at is null;

  if v_enabled_tokens = 0 and v_attempted_tokens = 0 then
    update public.bil_push_outbox
       set dispatched_at = pg_catalog.clock_timestamp(),
           failure_code = 'no_enabled_tokens'
     where id = p_outbox_id;
    return pg_catalog.jsonb_build_object(
      'finalized', true,
      'reason', 'no_enabled_tokens',
      'delivered', 0,
      'expected', 0
    );
  end if;

  if v_enabled_without_attempt = 0 and v_unresolved_enabled = 0 then
    v_reason := case
      when v_delivered_tokens = v_attempted_tokens then 'delivered'
      when v_delivered_tokens > 0 then 'partial_delivery'
      else 'delivery_failed'
    end;

    update public.bil_push_outbox
       set dispatched_at = pg_catalog.clock_timestamp(),
           failure_code = case
             when v_reason = 'delivered' then null
             else v_reason
           end
     where id = p_outbox_id;
    return pg_catalog.jsonb_build_object(
      'finalized', true,
      'reason', v_reason,
      'delivered', v_delivered_tokens,
      'terminal', v_terminal_tokens,
      'expected', v_attempted_tokens
    );
  end if;

  select attempt.failure_code
    into v_failure_code
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token
    on token.id = attempt.device_token_id
  where attempt.outbox_id = p_outbox_id
    and token.user_id = v_recipient_id
    and token.enabled
    and attempt.delivered_at is null
    and attempt.terminal_at is null
    and attempt.failure_code is not null
  order by attempt.last_attempt_at desc nulls last
  limit 1;

  update public.bil_push_outbox
     set dispatched_at = null,
         failure_code = coalesce(v_failure_code, 'delivery_pending')
   where id = p_outbox_id;

  return pg_catalog.jsonb_build_object(
    'finalized', false,
    'reason', coalesce(v_failure_code, 'delivery_pending'),
    'delivered', v_delivered_tokens,
    'terminal', v_terminal_tokens,
    'expected', v_attempted_tokens + v_enabled_without_attempt
  );
end
$$;

revoke all on function public.bil_claim_push_deliveries(uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.bil_record_push_delivery_result(uuid, uuid, boolean, text, boolean)
  from public, anon, authenticated, service_role;
revoke all on function public.bil_finalize_push_outbox(uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.bil_claim_push_deliveries(uuid, integer)
  to service_role;
grant execute on function public.bil_record_push_delivery_result(uuid, uuid, boolean, text, boolean)
  to service_role;
grant execute on function public.bil_finalize_push_outbox(uuid)
  to service_role;

commit;
