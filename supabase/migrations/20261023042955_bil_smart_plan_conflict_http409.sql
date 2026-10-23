-- A stale application revision is a terminal business conflict, not a database
-- serialization retry. PostgREST 14 retries custom 40001 indefinitely:
-- https://supabase.com/kb/troubleshooting/high-cpu-and-infinite-transaction-retries-when-using-custom-error-codes-in-rpc-functions
-- Preserve all ownership, consent, premium, CAS, advisory lock and ACL checks.
begin;
do $migration$
declare definition text; before_body text; after_body text;
begin
  select pg_get_functiondef(p.oid), replace(p.prosrc,E'\r\n',E'\n')
    into definition,before_body
  from pg_proc p where p.oid='public.bil_smart_plan_cas_v1(bigint,jsonb)'::regprocedure
    and p.prosecdef and p.provolatile='v' and p.proconfig=array['search_path=""'];
  if definition is null or md5(before_body)<>'2ab15681ac3d406a4245ea012bbf4da1'
    or (length(before_body)-length(replace(before_body,'40001','')))/5<>2 then
    raise exception 'smart_plan_cas_definition_drift';
  end if;
  execute replace(definition,'''40001''','''PT409''');
  select replace(prosrc,E'\r\n',E'\n') into after_body
    from pg_proc where oid='public.bil_smart_plan_cas_v1(bigint,jsonb)'::regprocedure;
  if replace(after_body,'''PT409''','''40001''') is distinct from before_body
    or position('40001' in after_body)>0 then
    raise exception 'smart_plan_cas_conflict_patch_mismatch';
  end if;
end $migration$;
commit;
