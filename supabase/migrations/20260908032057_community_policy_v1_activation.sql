-- Activate the first canonical BIL Community policy without fabricating any
-- user acceptance. Existing Social v2 objects, RLS policies, and grants remain
-- untouched; this migration adds only policy integrity and write guards.
begin;

do $community_policy_v1_preflight$
begin
  if pg_catalog.to_regclass('public.bil_content_policies') is null
     or pg_catalog.to_regclass('public.bil_content_policy_acceptances') is null
     or pg_catalog.to_regclass('public.bil_social_comments_v2') is null then
    raise exception 'community_policy_v1_schema_precondition_failed'
      using errcode = '55000',
            detail = 'Required policy or Social v2 tables are missing.';
  end if;

  if exists (
    select 1
    from public.bil_content_policies policy
    where policy.active
  ) then
    raise exception 'community_policy_v1_activation_precondition_failed'
      using errcode = '55000',
            detail = 'Expected no active policy before first activation.';
  end if;

  if exists (
    select 1
    from public.bil_content_policies policy
    where policy.version = 'community-policy-v1'
  ) then
    raise exception 'community_policy_v1_activation_precondition_failed'
      using errcode = '55000',
            detail = 'The canonical version already exists and will not be overwritten.';
  end if;
end
$community_policy_v1_preflight$;

-- A boolean expression partial index is intentionally used as a singleton
-- boundary: inactive historical versions remain available for receipt FKs,
-- while no transaction can commit more than one active version.
create unique index if not exists bil_content_policies_single_active_uidx
on public.bil_content_policies ((active))
where active;

create or replace function private.bil_assert_current_community_policy()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_policy_count bigint;
  v_policy_version text;
  v_policy_effective_at timestamptz;
begin
  if v_actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  select
    pg_catalog.count(*),
    pg_catalog.min(policy.version),
    pg_catalog.min(policy.effective_at)
  into v_policy_count, v_policy_version, v_policy_effective_at
  from public.bil_content_policies policy
  where policy.active
    and policy.effective_at <= pg_catalog.statement_timestamp();

  if v_policy_count <> 1 then
    raise exception using
      errcode = '55000',
      message = 'community_policy_unavailable';
  end if;

  if not exists (
    select 1
    from public.bil_content_policy_acceptances acceptance
    where acceptance.user_id = v_actor_id
      and acceptance.policy_version = v_policy_version
      and acceptance.accepted_at >= v_policy_effective_at
  ) then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  return v_policy_version;
end;
$$;

revoke all on function private.bil_assert_current_community_policy()
from public, anon, authenticated, service_role;

-- Prevent guessed inactive versions from being pre-accepted. A real signed-in
-- user may insert/upsert only the currently active, already-effective version;
-- the server, never the client, records the acceptance time. A service-role
-- write without that user's JWT context therefore fails rather than accepting
-- on the user's behalf.
create or replace function private.bil_validate_community_policy_acceptance()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_policy_count bigint;
  v_policy_version text;
begin
  if v_actor_id is null or new.user_id <> v_actor_id then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  select pg_catalog.count(*), pg_catalog.min(policy.version)
  into v_policy_count, v_policy_version
  from public.bil_content_policies policy
  where policy.active
    and policy.effective_at <= pg_catalog.statement_timestamp();

  if v_policy_count <> 1 then
    raise exception using
      errcode = '55000',
      message = 'community_policy_unavailable';
  end if;

  if new.policy_version <> v_policy_version then
    raise exception using
      errcode = '42501',
      message = 'community_policy_acceptance_required';
  end if;

  new.accepted_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

revoke all on function private.bil_validate_community_policy_acceptance()
from public, anon, authenticated, service_role;

drop trigger if exists bil_00_content_policy_acceptance_guard
on public.bil_content_policy_acceptances;
create trigger bil_00_content_policy_acceptance_guard
before insert or update
on public.bil_content_policy_acceptances
for each row execute function private.bil_validate_community_policy_acceptance();

-- Preserve the existing post/message rate limits, but make the policy check
-- fail closed when no effective policy exists and bind it to the exact current
-- version and its post-effective acceptance receipt.
create or replace function public.bil_require_community_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.bil_assert_current_community_policy();
  perform public.bil_consume_rate_limit(
    case when tg_table_name = 'bil_messages' then 'message' else 'post' end,
    case when tg_table_name = 'bil_messages' then 60 else 12 end,
    3600
  );
  return new;
end;
$$;

-- Social v2 already owns comment authorization, suspension, block, and abuse
-- controls. This separate trigger adds only the policy receipt check so it does
-- not double-charge an existing Social v2 rate-limit bucket.
create or replace function private.bil_guard_social_comment_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.bil_assert_current_community_policy();
  return new;
end;
$$;

revoke all on function private.bil_guard_social_comment_policy()
from public, anon, authenticated, service_role;

drop trigger if exists bil_01_social_comments_policy_guard
on public.bil_social_comments_v2;
create trigger bil_01_social_comments_policy_guard
before insert
on public.bil_social_comments_v2
for each row execute function private.bil_guard_social_comment_policy();

insert into public.bil_content_policies(
  version,
  locale_code,
  document_url,
  effective_at,
  active
) values (
  'community-policy-v1',
  'en',
  'https://www.bilhealth.com/community-guidelines',
  '2026-09-08T00:00:00Z'::timestamptz,
  true
);

do $community_policy_v1_postconditions$
declare
  v_active_count bigint;
begin
  select pg_catalog.count(*)
  into v_active_count
  from public.bil_content_policies policy
  where policy.active;

  if v_active_count <> 1 then
    raise exception 'community_policy_v1_postcondition_failed'
      using errcode = '55000',
            detail = 'Exactly one active policy is required.';
  end if;

  if not exists (
    select 1
    from public.bil_content_policies policy
    where policy.version = 'community-policy-v1'
      and policy.locale_code = 'en'
      and policy.document_url =
        'https://www.bilhealth.com/community-guidelines'
      and policy.effective_at = '2026-09-08T00:00:00Z'::timestamptz
      and policy.active
  ) then
    raise exception 'community_policy_v1_postcondition_failed'
      using errcode = '55000',
            detail = 'The active canonical row does not match the approved values.';
  end if;

  if pg_catalog.has_function_privilege(
       'anon', 'private.bil_assert_current_community_policy()', 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated',
       'private.bil_assert_current_community_policy()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role',
       'private.bil_assert_current_community_policy()',
       'EXECUTE'
     ) then
    raise exception 'community_policy_v1_postcondition_failed'
      using errcode = '55000',
            detail = 'The internal policy helper is directly executable.';
  end if;
end
$community_policy_v1_postconditions$;

commit;
