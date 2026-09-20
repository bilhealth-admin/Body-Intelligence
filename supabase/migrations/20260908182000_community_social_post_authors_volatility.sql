begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_social_post_authors_v2(uuid[])'
     ) is null then
    raise exception 'bil_social_post_authors_v2_missing';
  end if;
end;
$preflight$;

-- bil_can_use_community() is deliberately VOLATILE because it evaluates the
-- caller's current suspension and policy-acceptance state. Match that contract
-- so PostgreSQL never treats an authorization decision as statement-stable.
alter function public.bil_social_post_authors_v2(uuid[]) volatile;

do $postconditions$
declare
  v_signature regprocedure :=
    'public.bil_social_post_authors_v2(uuid[])'::regprocedure;
begin
  if not exists (
    select 1
    from pg_catalog.pg_proc as procedure
    where procedure.oid = v_signature::oid
      and procedure.provolatile = 'v'
      and procedure.prosecdef
  ) then
    raise exception 'bil_social_post_authors_v2_volatility_invalid';
  end if;

  if not pg_catalog.has_function_privilege(
       'authenticated', v_signature, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege('anon', v_signature, 'EXECUTE')
     or pg_catalog.has_function_privilege(
       'service_role', v_signature, 'EXECUTE'
     ) then
    raise exception 'bil_social_post_authors_v2_acl_changed';
  end if;
end;
$postconditions$;

commit;
