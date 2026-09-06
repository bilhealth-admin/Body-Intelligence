-- Repair the three Community administrator RPCs installed by 20260905160000.
-- COALESCE is SQL syntax and cannot be schema-qualified as pg_catalog.coalesce.
-- Recreate the live definitions from PostgreSQL's canonical source after
-- removing only that invalid qualifier, then fail the migration if any
-- affected definition still contains it.
begin;

do $repair_community_admin_coalesce$
declare
  v_signature regprocedure;
  v_definition text;
begin
  foreach v_signature in array array[
    'public.bil_list_suspended_community_members_for_admin(uuid)'::regprocedure,
    'public.bil_suspend_community_member_by_email(uuid,text,text,text)'::regprocedure,
    'public.bil_reinstate_community_member(uuid,uuid,text)'::regprocedure
  ]
  loop
    select pg_catalog.pg_get_functiondef(v_signature)
      into v_definition;
    if v_definition is null then
      raise exception 'community_admin_function_missing: %', v_signature;
    end if;
    execute pg_catalog.replace(
      v_definition,
      'pg_catalog.coalesce',
      'coalesce'
    );
  end loop;

  foreach v_signature in array array[
    'public.bil_list_suspended_community_members_for_admin(uuid)'::regprocedure,
    'public.bil_suspend_community_member_by_email(uuid,text,text,text)'::regprocedure,
    'public.bil_reinstate_community_member(uuid,uuid,text)'::regprocedure
  ]
  loop
    if pg_catalog.strpos(
      pg_catalog.pg_get_functiondef(v_signature),
      'pg_catalog.coalesce'
    ) > 0 then
      raise exception 'community_admin_coalesce_repair_failed: %', v_signature;
    end if;
  end loop;
end
$repair_community_admin_coalesce$;

commit;
