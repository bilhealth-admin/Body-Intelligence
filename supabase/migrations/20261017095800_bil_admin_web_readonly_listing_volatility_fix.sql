-- BIL 2026-10-17 — fix HTTP 405 for read-only admin grant listing.
-- Production deployed and catalog-verified 2026-10-17 UTC.
-- Root cause: two grant-listing RPCs were marked STABLE, but the existing
-- private.require_administrator() intentionally uses SELECT ... FOR SHARE,
-- which cannot execute inside PostgREST's read-only transaction (SQLSTATE 25006).
-- No grant/revoke, balance, role, business rule or existing function body changes.
-- Safe to replay: the target volatility can already be VOLATILE.
DO $verify$
DECLARE
  v_private oid := to_regprocedure('bil_admin_private.list_subscriptions(uuid,integer)');
  v_public oid := to_regprocedure('public.bil_list_admin_subscriptions(uuid,integer)');
BEGIN
  IF v_private IS NULL OR v_public IS NULL THEN
    RAISE EXCEPTION 'Expected admin listing functions absent';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=v_private AND provolatile IN ('s','v') AND prosecdef)
     OR NOT EXISTS (SELECT 1 FROM pg_proc WHERE oid=v_public AND provolatile IN ('s','v') AND NOT prosecdef)
     OR has_function_privilege('anon',v_public,'EXECUTE')
     OR has_function_privilege('authenticated',v_public,'EXECUTE')
     OR NOT has_function_privilege('service_role',v_public,'EXECUTE') THEN
    RAISE EXCEPTION 'Unexpected admin listing function baseline, abort';
  END IF;
END
$verify$;
ALTER FUNCTION bil_admin_private.list_subscriptions(uuid, integer) VOLATILE;
ALTER FUNCTION public.bil_list_admin_subscriptions(uuid, integer) VOLATILE;
NOTIFY pgrst, 'reload schema';
