-- Preserve the exact document identity that each Community acceptance names.
-- Treat every inserted row as an append-only ledger entry. A published version
-- may only transition from active to inactive. It cannot be edited, deleted,
-- or reactivated; a material policy change must be a new version row.
begin;

do $community_policy_version_integrity_preflight$
begin
  if pg_catalog.to_regclass('public.bil_content_policies') is null
     or pg_catalog.to_regclass(
       'public.bil_content_policy_acceptances'
     ) is null then
    raise exception 'community_policy_version_integrity_precondition_failed'
      using errcode = '55000',
            detail = 'Required Community policy tables are missing.';
  end if;

  if not exists (
    select 1
    from public.bil_content_policies policy
    where policy.version = 'community-policy-v1'
      and policy.active
      and policy.document_url =
        'https://www.bilhealth.com/community-guidelines'
  ) then
    raise exception 'community_policy_version_integrity_precondition_failed'
      using errcode = '55000',
            detail = 'The reviewed canonical Community policy is not active.';
  end if;
end
$community_policy_version_integrity_preflight$;

create or replace function private.bil_guard_community_policy_version_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '55000',
      message = 'community_policy_history_immutable';
  end if;

  if new.version is distinct from old.version
     or new.locale_code is distinct from old.locale_code
     or new.document_url is distinct from old.document_url
     or new.effective_at is distinct from old.effective_at then
    raise exception using
      errcode = '55000',
      message = 'community_policy_version_immutable';
  end if;

  if not old.active and new.active then
    raise exception using
      errcode = '55000',
      message = 'community_policy_reactivation_forbidden';
  end if;

  return new;
end;
$$;

revoke all on function private.bil_guard_community_policy_version_integrity()
from public, anon, authenticated, service_role;

drop trigger if exists bil_00_content_policy_version_integrity
on public.bil_content_policies;
create trigger bil_00_content_policy_version_integrity
before update or delete
on public.bil_content_policies
for each row
execute function private.bil_guard_community_policy_version_integrity();

do $community_policy_version_integrity_postconditions$
declare
  v_security_definer boolean;
  v_configuration text[];
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger trigger
    where trigger.tgrelid = 'public.bil_content_policies'::pg_catalog.regclass
      and trigger.tgname = 'bil_00_content_policy_version_integrity'
      and not trigger.tgisinternal
      and trigger.tgenabled = 'O'
  ) then
    raise exception 'community_policy_version_integrity_postcondition_failed'
      using errcode = '55000',
            detail = 'The Community policy integrity trigger is unavailable.';
  end if;

  select procedure.prosecdef, procedure.proconfig
  into v_security_definer, v_configuration
  from pg_catalog.pg_proc procedure
  where procedure.oid =
    'private.bil_guard_community_policy_version_integrity()'::pg_catalog.regprocedure;

  if v_security_definer is not true
     or not exists (
       select 1
       from pg_catalog.unnest(
         case when v_configuration is null then '{}'::text[]
              else v_configuration end
       ) configuration(setting)
       where configuration.setting in ('search_path=', 'search_path=""')
     )
     or pg_catalog.has_function_privilege(
       'anon',
       'private.bil_guard_community_policy_version_integrity()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated',
       'private.bil_guard_community_policy_version_integrity()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role',
       'private.bil_guard_community_policy_version_integrity()',
       'EXECUTE'
     ) then
    raise exception 'community_policy_version_integrity_postcondition_failed'
      using errcode = '55000',
            detail = 'The policy integrity trigger function boundary has drifted.';
  end if;
end
$community_policy_version_integrity_postconditions$;

commit;
