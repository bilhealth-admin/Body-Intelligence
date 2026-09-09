-- Give the signed-in client one server-authoritative snapshot of the current
-- Community policy and that caller's receipt, plus a narrow self-only
-- publish-readiness assertion. This avoids deciding whether a policy is
-- effective from an iOS/Android device clock or trusting a client-side gate.
--
-- The function is deliberately SECURITY INVOKER: the existing grants and RLS
-- continue to limit the caller to the active policy and their own acceptance.
-- It performs no writes and does not change table policies or privileges.
begin;

do $community_policy_status_preflight$
begin
  if pg_catalog.to_regclass('public.bil_content_policies') is null
     or pg_catalog.to_regclass('public.bil_content_policy_acceptances') is null then
    raise exception 'community_policy_status_schema_precondition_failed'
      using errcode = '55000',
            detail = 'Required Community policy tables are missing.';
  end if;

  if pg_catalog.to_regclass(
       'public.bil_content_policies_single_active_uidx'
     ) is null then
    raise exception 'community_policy_status_schema_precondition_failed'
      using errcode = '55000',
            detail = 'The single-active Community policy invariant is missing.';
  end if;

  if pg_catalog.to_regprocedure(
       'public.bil_current_community_policy_status()'
     ) is not null then
    raise exception 'community_policy_status_drift_detected'
      using errcode = '55000',
            detail = 'The status RPC already exists and will not be overwritten.';
  end if;

  if pg_catalog.to_regprocedure(
       'public.bil_can_use_community()'
     ) is null
     or pg_catalog.to_regprocedure(
       'private.bil_assert_current_community_policy()'
     ) is null then
    raise exception 'community_policy_status_schema_precondition_failed'
      using errcode = '55000',
            detail = 'Required Community access guards are missing.';
  end if;

  if pg_catalog.to_regprocedure(
       'public.bil_assert_community_publish_ready()'
     ) is not null then
    raise exception 'community_policy_status_drift_detected'
      using errcode = '55000',
            detail = 'The publish-readiness RPC already exists and will not be overwritten.';
  end if;
end
$community_policy_status_preflight$;

create function public.bil_current_community_policy_status()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with server_clock as (
    select
      pg_catalog.statement_timestamp() as server_now,
      (select auth.uid()) as actor_id
  ),
  effective_policies as (
    select
      policy.version,
      policy.locale_code,
      policy.document_url,
      policy.effective_at
    from public.bil_content_policies policy
    cross join server_clock clock
    where policy.active
      and policy.effective_at <= clock.server_now
  ),
  current_policy as (
    select
      policy.version,
      policy.locale_code,
      policy.document_url,
      policy.effective_at,
      pg_catalog.count(*) over () as effective_policy_count
    from effective_policies policy
    order by policy.effective_at desc, policy.version
    limit 1
  )
  select pg_catalog.jsonb_build_object(
    'server_now', clock.server_now,
    'status', case
      when clock.actor_id is null then 'unauthenticated'
      -- Match the write guards: an unexpected cardinality must fail closed,
      -- never silently select one policy by sort order.
      when coalesce(policy.effective_policy_count, 0) <> 1 then 'unavailable'
      when acceptance.accepted_at is not null
       and acceptance.accepted_at >= policy.effective_at then 'accepted'
      else 'acceptance_required'
    end,
    'version', case when policy.effective_policy_count = 1 then policy.version end,
    'locale_code', case when policy.effective_policy_count = 1 then policy.locale_code end,
    'document_url', case when policy.effective_policy_count = 1 then policy.document_url end,
    'effective_at', case when policy.effective_policy_count = 1 then policy.effective_at end,
    'accepted_at', case
      when policy.effective_policy_count = 1 then acceptance.accepted_at
    end,
    'accepted', coalesce(
      policy.effective_policy_count = 1
      and acceptance.accepted_at is not null
      and acceptance.accepted_at >= policy.effective_at,
      false
    )
  )
  from server_clock clock
  left join current_policy policy on true
  left join public.bil_content_policy_acceptances acceptance
    on acceptance.user_id = clock.actor_id
   and acceptance.policy_version = policy.version;
$$;

revoke all on function public.bil_current_community_policy_status()
from public, anon, authenticated, service_role;
grant execute on function public.bil_current_community_policy_status()
to authenticated;

do $community_policy_status_postconditions$
declare
  v_security_definer boolean;
  v_volatility text;
  v_configuration text[];
begin
  select procedure.prosecdef, procedure.provolatile::text, procedure.proconfig
  into v_security_definer, v_volatility, v_configuration
  from pg_catalog.pg_proc procedure
  where procedure.oid =
    'public.bil_current_community_policy_status()'::pg_catalog.regprocedure;

  if v_security_definer is not false
     or v_volatility <> 's'
     or not exists (
       select 1
       from pg_catalog.unnest(
         coalesce(v_configuration, '{}'::text[])
       ) configuration(setting)
       where configuration.setting in ('search_path=', 'search_path=""')
     ) then
    raise exception 'community_policy_status_postcondition_failed'
      using errcode = '55000',
            detail = 'The status RPC must remain fixed-search-path SECURITY INVOKER.';
  end if;

  if not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_current_community_policy_status()',
       'EXECUTE'
     )
   or pg_catalog.has_function_privilege(
       'anon',
       'public.bil_current_community_policy_status()',
       'EXECUTE'
     )
   or pg_catalog.has_function_privilege(
       'service_role',
       'public.bil_current_community_policy_status()',
       'EXECUTE'
     )
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid =
         'public.bil_current_community_policy_status()'::pg_catalog.regprocedure
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'community_policy_status_postcondition_failed'
      using errcode = '55000',
            detail = 'The status RPC ACL does not match the reviewed client boundary.';
  end if;
end
$community_policy_status_postconditions$;

-- This is intentionally a no-argument, SECURITY DEFINER assertion wrapper.
-- It has no caller-supplied identity, writes nothing, and evaluates only the
-- JWT-bound actor. The existing helpers retain their own membership, locking,
-- effective-policy, and receipt checks.
create function public.bil_assert_community_publish_ready()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_policy_version text;
begin
  if v_actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'community_authentication_required';
  end if;

  if not public.bil_can_use_community() then
    raise exception using
      errcode = '42501',
      message = 'community_access_suspended';
  end if;

  v_policy_version := private.bil_assert_current_community_policy();
  return v_policy_version;
end;
$$;

revoke all on function public.bil_assert_community_publish_ready()
from public, anon, authenticated, service_role;
grant execute on function public.bil_assert_community_publish_ready()
to authenticated;

do $community_publish_ready_postconditions$
declare
  v_security_definer boolean;
  v_volatility text;
  v_configuration text[];
begin
  select procedure.prosecdef, procedure.provolatile::text, procedure.proconfig
  into v_security_definer, v_volatility, v_configuration
  from pg_catalog.pg_proc procedure
  where procedure.oid =
    'public.bil_assert_community_publish_ready()'::pg_catalog.regprocedure;

  if v_security_definer is not true
     or v_volatility <> 'v'
     or not exists (
       select 1
       from pg_catalog.unnest(
         coalesce(v_configuration, '{}'::text[])
       ) configuration(setting)
       where configuration.setting in ('search_path=', 'search_path=""')
     ) then
    raise exception 'community_publish_ready_postcondition_failed'
      using errcode = '55000',
            detail = 'The publish-readiness RPC must remain fixed-search-path SECURITY DEFINER.';
  end if;

  if not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     )
   or pg_catalog.has_function_privilege(
       'anon',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     )
   or pg_catalog.has_function_privilege(
       'service_role',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     )
   or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid =
         'public.bil_assert_community_publish_ready()'::pg_catalog.regprocedure
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'community_publish_ready_postcondition_failed'
      using errcode = '55000',
            detail = 'The publish-readiness RPC ACL does not match the reviewed client boundary.';
  end if;
end
$community_publish_ready_postconditions$;

commit;
