-- Transactional ACL proof for migration 20260908182200. The test performs no
-- successful settlement and changes no application data.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_vision_settlement_acl_shape$
declare
  v_v1 regprocedure :=
    'public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)'::regprocedure;
  v_v2 regprocedure :=
    'public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)'::regprocedure;
  v_function regprocedure;
begin
  foreach v_function in array array[v_v1, v_v2]
  loop
    if not pg_catalog.has_function_privilege(
         'service_role', v_function, 'EXECUTE'
       )
       or pg_catalog.has_function_privilege(
         'authenticated', v_function, 'EXECUTE'
       )
       or pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE')
       or exists (
         select 1
         from pg_catalog.pg_proc procedure
         cross join lateral pg_catalog.aclexplode(
           coalesce(
             procedure.proacl,
             pg_catalog.acldefault('f', procedure.proowner)
           )
         ) privilege
         where procedure.oid = v_function
           and privilege.grantee = 0
           and privilege.privilege_type = 'EXECUTE'
       ) then
      raise exception 'test_vision_settlement_acl_shape'
        using detail = format('Unexpected ACL for %s.', v_function);
    end if;
  end loop;
end
$test_vision_settlement_acl_shape$;

rollback;
