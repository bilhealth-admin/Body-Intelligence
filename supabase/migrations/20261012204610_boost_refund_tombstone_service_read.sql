begin;

-- The versioned verifier reads back the actual refund state after applying the
-- existing idempotent ledger RPC. Explicit access avoids reliance on historical
-- default privileges. No client role, RLS policy or financial mutation changes.
do $migration$
begin
  if not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'bil_ai_boost_store_state'
      and c.relkind = 'r' and c.relrowsecurity) then
    raise exception 'required_boost_refund_rls_table_missing';
  end if;
  if has_table_privilege('anon', 'public.bil_ai_boost_store_state', 'SELECT')
    or has_table_privilege('authenticated', 'public.bil_ai_boost_store_state', 'SELECT') then
    raise exception 'unexpected_client_boost_refund_access';
  end if;
end
$migration$;

grant select on table public.bil_ai_boost_store_state to service_role;

commit;
