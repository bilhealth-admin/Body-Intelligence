-- The legacy vision settlement RPCs mutate server-owned usage and receipt
-- state from caller-supplied provider metadata and response bodies. No local
-- Flutter or Edge Function caller uses either RPC. Keep the bodies and all
-- production data intact, but close the direct Data API surface so only the
-- trusted service role can execute them.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $vision_settlement_acl_preflight$
declare
  v_v1 regprocedure :=
    'public.bil_settle_vision_request(text,boolean,text,text,integer,integer,integer,numeric,jsonb)'::regprocedure;
  v_v2 regprocedure :=
    'public.bil_settle_vision_request_v2(text,boolean,text,text,integer,integer,integer,numeric,jsonb,integer,text)'::regprocedure;
  v_function regprocedure;
begin
  foreach v_function in array array[v_v1, v_v2]
  loop
    if not (
         select procedure.prosecdef
         from pg_catalog.pg_proc procedure
         where procedure.oid = v_function
       )
       or (
         select pg_catalog.pg_get_userbyid(procedure.proowner) <> 'postgres'
         from pg_catalog.pg_proc procedure
         where procedure.oid = v_function
       )
       or not pg_catalog.has_function_privilege(
         'authenticated', v_function, 'EXECUTE'
       )
       or not pg_catalog.has_function_privilege(
         'service_role', v_function, 'EXECUTE'
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
      raise exception 'vision_settlement_acl_precondition_failed'
        using errcode = '55000',
              detail = format(
                'Function %s no longer matches the reviewed owner/security/ACL boundary.',
                v_function
              );
    end if;
  end loop;
end
$vision_settlement_acl_preflight$;

revoke all on function
  public.bil_settle_vision_request(
    text, boolean, text, text, integer, integer, integer, numeric, jsonb
  )
from public, anon, authenticated, service_role;

revoke all on function
  public.bil_settle_vision_request_v2(
    text, boolean, text, text, integer, integer, integer, numeric, jsonb,
    integer, text
  )
from public, anon, authenticated, service_role;

grant execute on function
  public.bil_settle_vision_request(
    text, boolean, text, text, integer, integer, integer, numeric, jsonb
  )
to service_role;

grant execute on function
  public.bil_settle_vision_request_v2(
    text, boolean, text, text, integer, integer, integer, numeric, jsonb,
    integer, text
  )
to service_role;

do $vision_settlement_acl_postconditions$
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
      raise exception 'vision_settlement_acl_postcondition_failed'
        using errcode = '55000',
              detail = format(
                'Function %s is not service-role-only.',
                v_function
              );
    end if;
  end loop;
end
$vision_settlement_acl_postconditions$;

notify pgrst, 'reload schema';

commit;
