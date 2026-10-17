-- ISOLATED POSTGRES 17 TEST COPY. NOT DEPLOYED TO PRODUCTION.
CREATE TABLE bil_admin_private.web_financial_step_up_receipts(
  actor_id uuid NOT NULL,
  totp_verified_at_epoch bigint NOT NULL,
  operation text NOT NULL CHECK (operation IN ('grant','revoke')),
  idempotency_key text NOT NULL CHECK(idempotency_key~'^[A-Za-z0-9:_-]{16,128}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(actor_id,totp_verified_at_epoch)
);
ALTER TABLE bil_admin_private.web_financial_step_up_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON bil_admin_private.web_financial_step_up_receipts FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.bil_admin_web_execute_financial_command(
  p_actor_id uuid,p_step_up_epoch bigint,p_idempotency_key text,p_operation text,
  p_email text DEFAULT NULL,p_plan_id text DEFAULT NULL,p_duration_days integer DEFAULT NULL,
  p_reason text DEFAULT '',p_grant_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fn$
DECLARE
  v_existing bil_admin_private.web_financial_step_up_receipts%rowtype;
  v_now bigint;
BEGIN
  PERFORM bil_admin_private.require_administrator(p_actor_id);
  v_now:=pg_catalog.floor(extract(epoch FROM pg_catalog.statement_timestamp()))::bigint;
  IF p_step_up_epoch IS NULL OR p_step_up_epoch > v_now+30 OR p_step_up_epoch < v_now-90
    THEN RAISE EXCEPTION 'fresh_step_up_required' USING errcode='42501'; END IF;
  IF p_operation NOT IN ('grant','revoke') OR p_idempotency_key IS NULL
    OR p_idempotency_key !~ '^[A-Za-z0-9:_-]{16,128}$' THEN
    RAISE EXCEPTION 'invalid_subscription_request' USING errcode='22023';
  END IF;
  IF p_operation='grant' AND
     (p_duration_days IS NULL OR p_duration_days NOT IN (30,90,365)
      OR p_plan_id NOT IN ('premium','premium_ai_coach')
      OR p_email IS NULL OR char_length(btrim(p_email)) > 254
      OR char_length(btrim(coalesce(p_reason,''))) NOT BETWEEN 10 AND 160)
    THEN RAISE EXCEPTION 'invalid_subscription_request' USING errcode='22023'; END IF;
  IF p_operation='revoke' AND p_grant_id IS NULL
    THEN RAISE EXCEPTION 'invalid_subscription_request' USING errcode='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('bil_web_finance_cooldown:'||p_actor_id::text,74017));
  IF EXISTS(SELECT 1 FROM bil_admin_private.web_financial_step_up_receipts r
     WHERE r.actor_id=p_actor_id
       AND r.created_at > pg_catalog.statement_timestamp()-interval '120 seconds'
       AND (r.operation IS DISTINCT FROM p_operation
            OR r.idempotency_key IS DISTINCT FROM p_idempotency_key)) THEN
    RAISE EXCEPTION 'financial_cooldown_active' USING errcode='P0001';
  END IF;
  INSERT INTO bil_admin_private.web_financial_step_up_receipts
    (actor_id,totp_verified_at_epoch,operation,idempotency_key)
    VALUES(p_actor_id,p_step_up_epoch,p_operation,p_idempotency_key)
    ON CONFLICT(actor_id,totp_verified_at_epoch) DO NOTHING;
  IF NOT FOUND THEN
    SELECT * INTO v_existing FROM bil_admin_private.web_financial_step_up_receipts
    WHERE actor_id=p_actor_id AND totp_verified_at_epoch=p_step_up_epoch FOR UPDATE;
    IF NOT FOUND OR v_existing.operation IS DISTINCT FROM p_operation
       OR v_existing.idempotency_key IS DISTINCT FROM p_idempotency_key THEN
       RAISE EXCEPTION 'fresh_step_up_already_used' USING errcode='23505';
    END IF;
  END IF;
  RETURN bil_admin_private.manage_subscription(
    p_actor_id,p_operation,p_idempotency_key,p_email,p_plan_id,p_duration_days,p_reason,p_grant_id);
END;
$fn$;
REVOKE ALL ON FUNCTION public.bil_admin_web_execute_financial_command(uuid,bigint,text,text,text,text,integer,text,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_execute_financial_command(uuid,bigint,text,text,text,text,integer,text,uuid)
 TO service_role;
