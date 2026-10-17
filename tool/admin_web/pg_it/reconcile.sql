-- Ephemeral PostgreSQL 17 ONLY; matches deployed read-only reconciliation semantics.
CREATE FUNCTION public.bil_admin_web_reconcile_subscription_command(
  p_actor_id uuid,p_idempotency_key text
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_payload jsonb;v_result jsonb;
BEGIN
  PERFORM bil_admin_private.require_administrator(p_actor_id);
  IF p_idempotency_key IS NULL
     OR pg_catalog.char_length(p_idempotency_key) NOT BETWEEN 16 AND 128
     OR p_idempotency_key !~ '^[A-Za-z0-9:_-]+$' THEN
    RAISE EXCEPTION 'invalid_subscription_request' USING errcode='22023';
  END IF;
  SELECT c.payload,c.result INTO v_payload,v_result
    FROM bil_admin_private.subscription_commands c
    WHERE c.actor_id=p_actor_id AND c.idempotency_key=p_idempotency_key;
  IF NOT FOUND THEN RETURN pg_catalog.jsonb_build_object('found',false); END IF;
  IF coalesce(v_payload->>'operation','') NOT IN ('grant','revoke')
      OR pg_catalog.jsonb_typeof(v_result->'matched') <> 'boolean'
      OR pg_catalog.jsonb_typeof(v_result->'changed') <> 'boolean'
      OR ((v_result->>'matched')::boolean AND
          pg_catalog.jsonb_typeof(v_result->'grant_id') <> 'string') THEN
    RAISE EXCEPTION 'invalid_subscription_command' USING errcode='22023';
  END IF;
  RETURN pg_catalog.jsonb_build_object(
    'found',true,'operation',v_payload->>'operation',
    'receipt',pg_catalog.jsonb_build_object(
      'matched',v_result->'matched','changed',v_result->'changed',
      'grant_id',v_result->'grant_id'));
END;
$fn$;
REVOKE ALL ON FUNCTION public.bil_admin_web_reconcile_subscription_command(uuid,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_reconcile_subscription_command(uuid,text)
  TO service_role;
