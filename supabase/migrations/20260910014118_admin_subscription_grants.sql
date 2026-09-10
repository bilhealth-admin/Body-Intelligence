begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Administrative gifts are NOT receipts, store subscriptions, or Boost.
-- Keep privileged code and the audit trail outside the exposed API schema.
create schema bil_admin_private;
revoke all on schema bil_admin_private from public, anon;
grant usage on schema bil_admin_private to authenticated, service_role;

create table bil_admin_private.subscription_grants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  plan_id text not null check (plan_id in ('premium', 'premium_ai_coach')),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  granted_by uuid references auth.users(id) on delete set null,
  reason text not null default '' check (char_length(reason) <= 160),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  check (expires_at is null or expires_at > created_at)
);
create unique index subscription_grants_one_current_owner
  on bil_admin_private.subscription_grants(owner_id) where revoked_at is null;
create index subscription_grants_owner_history
  on bil_admin_private.subscription_grants(owner_id, created_at desc);
create index subscription_grants_created
  on bil_admin_private.subscription_grants(created_at desc, id desc);
create index subscription_grants_granted_by
  on bil_admin_private.subscription_grants(granted_by);
create index subscription_grants_revoked_by
  on bil_admin_private.subscription_grants(revoked_by);

create table bil_admin_private.subscription_commands (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  idempotency_key text not null check (idempotency_key ~ '^[A-Za-z0-9:_-]{16,128}$'),
  payload jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  unique (actor_id, idempotency_key)
);
alter table bil_admin_private.subscription_grants enable row level security;
alter table bil_admin_private.subscription_commands enable row level security;
revoke all on all tables in schema bil_admin_private from public, anon, authenticated, service_role;

create function bil_admin_private.require_administrator(p_actor_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role'
     or p_actor_id is null or not exists (
       select 1 from private.bil_ai_coach_admins a
       where a.user_id = p_actor_id and a.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
end $$;

create function bil_admin_private.active_plan(p_owner_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select g.plan_id from bil_admin_private.subscription_grants g
  where g.owner_id = p_owner_id and g.revoked_at is null
    and g.created_at <= now() and (g.expires_at is null or g.expires_at > now())
  limit 1
$$;

create function bil_admin_private.my_subscription()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_owner uuid := auth.uid(); v_result jsonb;
begin
  if v_owner is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  select jsonb_build_object(
    'id', g.id, 'owner_id', g.owner_id, 'plan_id', g.plan_id,
    'created_at', g.created_at, 'expires_at', g.expires_at,
    -- Revocable access is a short server lease, never a fabricated store period.
    'access_until', least(coalesce(g.expires_at, now() + interval '5 minutes'), now() + interval '5 minutes')
  ) into v_result from bil_admin_private.subscription_grants g
  where g.owner_id = v_owner and g.revoked_at is null
    and g.created_at <= now() and (g.expires_at is null or g.expires_at > now());
  return v_result;
end $$;

create function bil_admin_private.manage_subscription(
  p_actor_id uuid, p_operation text, p_idempotency_key text,
  p_email text default null, p_plan_id text default null,
  p_duration_days integer default null, p_reason text default '', p_grant_id uuid default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_email text := lower(btrim(p_email));
  v_reason text := btrim(coalesce(p_reason, ''));
  v_owner uuid; v_matches integer; v_payload jsonb; v_result jsonb;
  v_prior bil_admin_private.subscription_commands%rowtype;
  v_grant bil_admin_private.subscription_grants%rowtype;
begin
  perform bil_admin_private.require_administrator(p_actor_id);
  if p_idempotency_key is null or p_idempotency_key !~ '^[A-Za-z0-9:_-]{16,128}$'
     or p_operation is null or p_operation not in ('grant', 'revoke')
     or char_length(v_reason) > 160 or v_reason ~ '[[:cntrl:]]' then
    raise exception 'invalid_subscription_request' using errcode = '22023';
  end if;
  if p_operation = 'grant' and (
    v_email is null or char_length(v_email) > 254 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    or p_plan_id is null or p_plan_id not in ('premium', 'premium_ai_coach')
    or (p_duration_days is not null and p_duration_days not in (30, 90, 365))
  ) then raise exception 'invalid_subscription_request' using errcode = '22023'; end if;
  if p_operation = 'revoke' and p_grant_id is null then
    raise exception 'invalid_subscription_request' using errcode = '22023';
  end if;
  v_payload := case when p_operation = 'grant' then jsonb_build_object(
    'operation', p_operation, 'email_hash', encode(sha256(convert_to(v_email, 'UTF8')), 'hex'), 'plan', p_plan_id,
    'duration_days', p_duration_days, 'reason_hash', encode(sha256(convert_to(v_reason, 'UTF8')), 'hex')
  ) else jsonb_build_object('operation', p_operation, 'grant_id', p_grant_id) end;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_actor_id::text || ':' || p_idempotency_key, 710));
  select * into v_prior from bil_admin_private.subscription_commands
    where actor_id = p_actor_id and idempotency_key = p_idempotency_key;
  if found then
    if v_prior.payload <> v_payload then raise exception 'idempotency_conflict' using errcode = '22023'; end if;
    return v_prior.result;
  end if;
  if p_operation = 'grant' then
    select count(*), (array_agg(id))[1] into v_matches, v_owner
      from auth.users where lower(email) = v_email and deleted_at is null;
    if v_matches <> 1 then
      v_result := jsonb_build_object('matched', false, 'changed', false, 'grant_id', null);
    else
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::text, 711));
      select * into v_grant from bil_admin_private.subscription_grants
        where owner_id = v_owner and revoked_at is null for update;
      if found and (v_grant.expires_at is null or v_grant.expires_at > now()) then
        -- No silent downgrade/upgrade, period extension, or usage reset on repeated grants.
        if v_grant.plan_id <> p_plan_id then
          raise exception 'existing_admin_subscription' using errcode = '22023';
        end if;
        v_result := jsonb_build_object('matched', true, 'changed', false, 'grant_id', v_grant.id);
      else
        update bil_admin_private.subscription_grants set revoked_at = now(), revoked_by = p_actor_id
          where owner_id = v_owner and revoked_at is null;
        insert into bil_admin_private.subscription_grants(owner_id, plan_id, expires_at, granted_by, reason)
          values(v_owner, p_plan_id, case when p_duration_days is null then null
            else now() + pg_catalog.make_interval(days => p_duration_days) end, p_actor_id, v_reason)
          returning * into v_grant;
        v_result := jsonb_build_object('matched', true, 'changed', true, 'grant_id', v_grant.id);
      end if;
    end if;
  else
    select owner_id into v_owner from bil_admin_private.subscription_grants where id = p_grant_id;
    if v_owner is null then
      v_result := jsonb_build_object('matched', false, 'changed', false, 'grant_id', null);
    else
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_owner::text, 711));
      update bil_admin_private.subscription_grants set revoked_at = now(), revoked_by = p_actor_id
        where id = p_grant_id and revoked_at is null;
      v_result := jsonb_build_object('matched', true, 'changed', found, 'grant_id', p_grant_id);
    end if;
  end if;
  insert into bil_admin_private.subscription_commands(actor_id, idempotency_key, payload, result)
    values(p_actor_id, p_idempotency_key, v_payload, v_result);
  return v_result;
end $$;

create function bil_admin_private.list_subscriptions(p_actor_id uuid, p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_rows jsonb; v_count bigint;
begin
  perform bil_admin_private.require_administrator(p_actor_id);
  if p_offset is null or p_offset < 0 or p_offset > 1000000 then
    raise exception 'invalid_subscription_request' using errcode = '22023';
  end if;
  select count(*) into v_count from bil_admin_private.subscription_grants;
  select coalesce(jsonb_agg(row_data order by created_at desc, id desc), '[]'::jsonb) into v_rows
    from (
      select g.id, g.created_at, jsonb_build_object(
        'id', g.id, 'email', u.email, 'plan_id', g.plan_id,
        'created_at', g.created_at, 'expires_at', g.expires_at,
        'status', case when g.expires_at <= now() and (g.revoked_at is null or g.revoked_at >= g.expires_at)
          then 'expired' when g.revoked_at is not null then 'revoked' else 'active' end
      ) as row_data from bil_admin_private.subscription_grants g
      join auth.users u on u.id = g.owner_id
      order by g.created_at desc, g.id desc limit 50 offset p_offset
    ) page;
  return jsonb_build_object('rows', v_rows, 'has_more', p_offset + 50 < v_count);
end $$;

-- Exposed functions are invokers, with minimum EXECUTE grants. The private
-- implementations re-check the authenticated identity/active administrator.
create function public.bil_get_my_admin_subscription()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select bil_admin_private.my_subscription()
$$;
create function public.bil_manage_admin_subscription(
  p_actor_id uuid, p_operation text, p_idempotency_key text,
  p_email text default null, p_plan_id text default null,
  p_duration_days integer default null, p_reason text default '', p_grant_id uuid default null
) returns jsonb language sql security invoker set search_path = '' as $$
  select bil_admin_private.manage_subscription(p_actor_id, p_operation, p_idempotency_key,
    p_email, p_plan_id, p_duration_days, p_reason, p_grant_id)
$$;
create function public.bil_list_admin_subscriptions(p_actor_id uuid, p_offset integer default 0)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select bil_admin_private.list_subscriptions(p_actor_id, p_offset)
$$;

revoke all on all functions in schema bil_admin_private from public, anon, authenticated, service_role;
revoke all on function public.bil_get_my_admin_subscription() from public, anon, authenticated, service_role;
revoke all on function public.bil_manage_admin_subscription(uuid,text,text,text,text,integer,text,uuid) from public, anon, authenticated, service_role;
revoke all on function public.bil_list_admin_subscriptions(uuid,integer) from public, anon, authenticated, service_role;
grant execute on function bil_admin_private.my_subscription(), public.bil_get_my_admin_subscription() to authenticated;
grant execute on function bil_admin_private.manage_subscription(uuid,text,text,text,text,integer,text,uuid),
  public.bil_manage_admin_subscription(uuid,text,text,text,text,integer,text,uuid),
  bil_admin_private.list_subscriptions(uuid,integer), public.bil_list_admin_subscriptions(uuid,integer) to service_role;

-- Extend the existing authorities, not their paid ledgers. Keep all store,
-- closed-test, trial, expiry, reservation and settlement logic unchanged.
-- A paid subscriber and an admin recipient share the plan's period allowance;
-- grants do not stack, replenish consumed tokens, or modify Boost balances.
do $migration$
declare v_definition text; v_old text; v_new text;
begin
  v_definition := pg_get_functiondef('public.bil_resolve_ai_allowance_plan(uuid)'::regprocedure);
  v_old := E'  select case\n    when exists (';
  v_new := E'  select case\n    when bil_admin_private.active_plan(p_owner) = ''premium_ai_coach'' then ''ai_coach''\n    when exists (';
  if position('bil_admin_private' in v_definition) > 0 or position(v_old in v_definition) = 0 then
    raise exception 'ai_allowance_definition_drift';
  end if;
  execute replace(v_definition, v_old, v_new);
  v_definition := pg_get_functiondef('public.bil_has_active_premium(uuid)'::regprocedure);
  v_old := 'select p_owner_id is not null and (';
  v_new := 'select p_owner_id is not null and (bil_admin_private.active_plan(p_owner_id) is not null or ';
  if position('bil_admin_private' in v_definition) > 0 or position(v_old in v_definition) = 0 then
    raise exception 'premium_definition_drift';
  end if;
  execute replace(v_definition, v_old, v_new);
  -- The rate limiter deliberately rejects unknown action/limit/window tuples.
  -- Add exactly the three new operations without relaxing any existing tuple.
  v_definition := pg_get_functiondef('public.bil_consume_rate_limit(text,integer,integer)'::regprocedure);
  v_old := '(''admin_notification_all'', 10, 3600),';
  v_new := E'(''admin_subscription_list'', 120, 3600),\n           (''admin_subscription_grant'', 60, 3600),\n           (''admin_subscription_revoke'', 60, 3600),\n           (''admin_notification_all'', 10, 3600),';
  if position('admin_subscription_' in v_definition) > 0
     or position('invalid_rate_limit_contract' in v_definition) = 0
     or position(v_old in v_definition) = 0 then
    raise exception 'admin_rate_limit_definition_drift';
  end if;
  execute replace(v_definition, v_old, v_new);
end $migration$;

commit;
