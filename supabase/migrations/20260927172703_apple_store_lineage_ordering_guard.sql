begin;

-- Apple signed dates order events only within one store subscription lineage.
-- The canonical bil_subscriptions row may currently project a different Apple
-- original_transaction_id, so comparing against that row without the lineage
-- keys can reject a valid snapshot before cross-chain reconciliation runs.
do $migration$
declare
  v_oid oid := to_regprocedure(
    'private.bil_persist_verified_store_purchase_single_snapshot(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,timestamptz,boolean,timestamptz,text,timestamptz)'
  );
  v_definition text;
  v_old text := $old$  if found and v_existing.provider='apple' and p_provider='apple'
     and v_existing.store_signed_at is not null then$old$;
  v_new text := $new$  if found and v_existing.provider='apple' and p_provider='apple'
     and v_existing.original_transaction_id=p_original_transaction_id
     and v_existing.environment=p_environment
     and v_existing.store_signed_at is not null then$new$;
begin
  if v_oid is null then
    raise exception 'required_single_snapshot_persistence_missing';
  end if;
  v_definition := pg_get_functiondef(v_oid);
  if position(
    'v_existing.original_transaction_id=p_original_transaction_id'
    in v_definition
  ) > 0 and position(
    'v_existing.environment=p_environment'
    in v_definition
  ) > 0 then
    return;
  end if;
  if position(v_old in v_definition)=0 then
    raise exception 'unexpected_single_snapshot_persistence_definition';
  end if;
  execute replace(v_definition,v_old,v_new);
end
$migration$;

revoke all on function private.bil_persist_verified_store_purchase_single_snapshot(
  uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,
  timestamptz,boolean,timestamptz,text,timestamptz
) from public,anon,authenticated,service_role;

commit;
