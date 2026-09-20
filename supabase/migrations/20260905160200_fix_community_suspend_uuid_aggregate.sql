-- Repair the Community suspend RPC installed by 20260905160000.
-- PostgreSQL does not provide min(uuid). The email uniqueness check still
-- needs a deterministic target, so aggregate the textual UUID and cast the
-- single result back to uuid.
begin;

do $repair_community_suspend_uuid_aggregate$
declare
  v_signature constant regprocedure :=
    'public.bil_suspend_community_member_by_email(uuid,text,text,text)'::regprocedure;
  v_definition text;
begin
  select pg_catalog.pg_get_functiondef(v_signature)
    into v_definition;

  if v_definition is null then
    raise exception 'community_suspend_function_missing: %', v_signature;
  end if;

  v_definition := pg_catalog.replace(
    v_definition,
    'pg_catalog.min(account.id)',
    'pg_catalog.min(account.id::text)::uuid'
  );

  execute v_definition;

  v_definition := pg_catalog.pg_get_functiondef(v_signature);
  if pg_catalog.strpos(v_definition, 'pg_catalog.min(account.id)') > 0
     or pg_catalog.strpos(v_definition, 'min(account.id)') > 0 then
    raise exception 'community_suspend_uuid_aggregate_repair_failed: %',
      v_signature;
  end if;
end
$repair_community_suspend_uuid_aggregate$;

commit;
