-- Prepared locally only. This does not authorize Production execution.
-- Keep the 32/35 RPC identities, signatures, return fields, financial policy,
-- idempotency ledgers, triggers, comments and ACL. Lock the existing active
-- administrator row before any audit, counter, credit or outbox mutation.
-- Withdrawal committed first denies admission; a previously admitted RPC
-- commits or rolls back before withdrawal can complete.
begin;

do $migration$
declare
  v_signature text;
  v_oid regprocedure;
  v_definition text;
  v_predicate constant text := 'where a.user_id = p_actor_id and a.active';
  v_locked constant text := 'where a.user_id = p_actor_id and a.active for share';
begin
  foreach v_signature in array array[
    'public.bil_enqueue_admin_notification(uuid,text,text,uuid,text,text)',
    'public.bil_enqueue_admin_notification_with_message(uuid,text,text,uuid,text,text)',
    'public.bil_global_reset_ai_coach(uuid,text)',
    'public.bil_individual_reset_ai_coach(uuid,uuid,text,text)'
  ] loop
    v_oid := pg_catalog.to_regprocedure(v_signature);
    if v_oid is null then
      raise exception 'admin_credit_authority_rpc_missing: %', v_signature;
    end if;
    v_definition := pg_catalog.pg_get_functiondef(v_oid);
    -- Never silently rewrite a newer/unexpected RPC. Reapplication of this
    -- exact lock is harmless; no duplicate function or new grant is created.
    if pg_catalog.strpos(v_definition, v_locked) > 0 then
      continue;
    end if;
    if (pg_catalog.length(v_definition) - pg_catalog.length(
          pg_catalog.replace(v_definition, v_predicate, '')))
          <> pg_catalog.length(v_predicate) then
      raise exception 'admin_credit_authority_definition_changed: %', v_signature;
    end if;
    execute pg_catalog.replace(v_definition, v_predicate, v_locked);
  end loop;
end;
$migration$;

-- The existing three/five-argument message wrappers call these base reset
-- RPCs in the same transaction. No extra public endpoint or actor claim is
-- introduced. FOR SHARE matches require_administrator's lock ordering.
commit;
