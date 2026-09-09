-- Re-assert the complete canonical identity after installing the append-only
-- row guard, and protect the policy ledger from privileged accidental
-- TRUNCATE. This migration changes no policy or acceptance rows.
begin;

do $community_policy_ledger_preflight$
declare
  v_active_count bigint;
begin
  if pg_catalog.to_regclass('public.bil_content_policies') is null
     or pg_catalog.to_regclass(
       'public.bil_content_policy_acceptances'
     ) is null
     or pg_catalog.to_regclass(
       'public.bil_content_policies_single_active_uidx'
     ) is null
     or pg_catalog.to_regprocedure(
       'private.bil_guard_community_policy_version_integrity()'
     ) is null then
    raise exception 'community_policy_ledger_precondition_failed'
      using errcode = '55000',
            detail = 'The reviewed policy ledger invariants are incomplete.';
  end if;

  select pg_catalog.count(*)
  into v_active_count
  from public.bil_content_policies policy
  where policy.active;

  if v_active_count <> 1
     or not exists (
       select 1
       from public.bil_content_policies policy
       where policy.version = 'community-policy-v1'
         and policy.locale_code = 'en'
         and policy.document_url =
           'https://www.bilhealth.com/community-guidelines'
         and policy.effective_at = '2026-09-08T00:00:00Z'::timestamptz
         and policy.active
     ) then
    raise exception 'community_policy_ledger_precondition_failed'
      using errcode = '55000',
            detail = 'The canonical active policy identity has drifted.';
  end if;
end
$community_policy_ledger_preflight$;

create or replace function private.bil_guard_community_policy_history_truncate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'community_policy_history_immutable';
  return null;
end;
$$;

revoke all on function private.bil_guard_community_policy_history_truncate()
from public, anon, authenticated, service_role;

drop trigger if exists bil_00_content_policy_history_truncate
on public.bil_content_policies;
create trigger bil_00_content_policy_history_truncate
before truncate
on public.bil_content_policies
for each statement
execute function private.bil_guard_community_policy_history_truncate();

do $community_policy_ledger_postconditions$
declare
  v_trigger_definition text;
begin
  select pg_catalog.pg_get_triggerdef(trigger.oid)
  into v_trigger_definition
  from pg_catalog.pg_trigger trigger
  where trigger.tgrelid = 'public.bil_content_policies'::pg_catalog.regclass
    and trigger.tgname = 'bil_00_content_policy_history_truncate'
    and not trigger.tgisinternal
    and trigger.tgenabled = 'O';

  if v_trigger_definition is null
     or pg_catalog.strpos(v_trigger_definition, 'BEFORE TRUNCATE') = 0
     or pg_catalog.has_function_privilege(
       'anon',
       'private.bil_guard_community_policy_history_truncate()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated',
       'private.bil_guard_community_policy_history_truncate()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role',
       'private.bil_guard_community_policy_history_truncate()',
       'EXECUTE'
     ) then
    raise exception 'community_policy_ledger_postcondition_failed'
      using errcode = '55000',
            detail = 'The policy ledger TRUNCATE boundary has drifted.';
  end if;
end
$community_policy_ledger_postconditions$;

commit;
