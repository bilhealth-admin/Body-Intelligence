-- Run only against the isolated ephemeral PostgreSQL container.
\set ON_ERROR_STOP on
SELECT set_config('request.jwt.claims','{"role":"service_role"}',false);
DO $t$
BEGIN
 IF has_function_privilege('anon','public.bil_admin_web_execute_financial_command(uuid,bigint,text,text,text,text,integer,text,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.bil_admin_web_execute_financial_command(uuid,bigint,text,text,text,text,integer,text,uuid)','EXECUTE')
 OR NOT has_function_privilege('service_role','public.bil_admin_web_execute_financial_command(uuid,bigint,text,text,text,text,integer,text,uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'PUBLIC_EXECUTION_UNSAFE'; END IF;
END $t$;
CREATE TEMP TABLE outcome(step_epoch bigint,grant_id uuid);
DO $t$
DECLARE v_epoch bigint := floor(extract(epoch from statement_timestamp()))::bigint; v jsonb;
BEGIN
  v := public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch,
    'grant-first-test-0001','grant','recipient-testing@example.invalid','premium',30,
    'QA grant for isolated test account',NULL);
  IF v->>'matched'!='true' OR v->>'changed'!='true' OR v->>'grant_id' IS NULL
    THEN RAISE EXCEPTION 'GRANT_FAILED %',v; END IF;
  INSERT INTO outcome VALUES(v_epoch,(v->>'grant_id')::uuid);
END $t$;
DO $t$
DECLARE v_epoch bigint; v jsonb;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 v := public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch,
    'grant-first-test-0001','grant','recipient-testing@example.invalid','premium',30,
    'QA grant for isolated test account',NULL);
 IF v->>'changed'!='true' OR
   (SELECT count(*) FROM bil_admin_private.subscription_grants)!=1 OR
   (SELECT count(*) FROM bil_admin_private.subscription_commands)!=1 OR
   (SELECT count(*) FROM bil_admin_private.web_financial_step_up_receipts)!=1
 THEN RAISE EXCEPTION 'IDEMPOTENCY_FAILED %',v; END IF;
END $t$;
DO $t$
DECLARE v_epoch bigint; caught boolean:=false;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 BEGIN
  PERFORM public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch+1,
    'grant-second-test-0002','grant','recipient-testing@example.invalid','premium',30,
    'QA grant for isolated test account',NULL);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM!='financial_cooldown_active' THEN RAISE; END IF;
  caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'COOLDOWN_FAILED'; END IF;
END $t$;
DO $t$
DECLARE v_epoch bigint; caught boolean:=false;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 BEGIN
  PERFORM public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch,
    'grant-first-test-0001','grant','recipient-testing@example.invalid','premium_ai_coach',30,
    'QA grant for isolated test account',NULL);
 EXCEPTION WHEN SQLSTATE '22023' THEN
  IF SQLERRM!='idempotency_conflict' THEN RAISE; END IF; caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'FINGERPRINT_FAILED'; END IF;
END $t$;
DO $t$
DECLARE v_epoch bigint; caught boolean:=false;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 BEGIN
  PERFORM public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch+2,
    'missing-duration-00001','grant','recipient-testing@example.invalid','premium',NULL,
    'QA grant for isolated test account',NULL);
 EXCEPTION WHEN SQLSTATE '22023' THEN caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'OPEN_ENDED_GRANT_WAS_ALLOWED'; END IF;
END $t$;
DO $t$
DECLARE v_epoch bigint; caught boolean:=false;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 BEGIN
  PERFORM public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch-95,
    'stale-mfa-test-00001','grant','recipient-testing@example.invalid','premium',30,
    'QA grant for isolated test account',NULL);
 EXCEPTION WHEN SQLSTATE '42501' THEN
  IF SQLERRM!='fresh_step_up_required' THEN RAISE; END IF; caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'STALE_MFA_WAS_ALLOWED'; END IF;
END $t$;
DO $t$
DECLARE v_epoch bigint; caught boolean:=false;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 BEGIN
  PERFORM public.bil_admin_web_execute_financial_command(
    '33333333-3333-4333-8333-333333333333',v_epoch,
    'reviewer-test-000001','grant','recipient-testing@example.invalid','premium',30,
    'QA grant for isolated test account',NULL);
 EXCEPTION WHEN SQLSTATE '42501' THEN
  IF SQLERRM!='administrator_required' THEN RAISE; END IF; caught:=true;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'REVIEWER_GRANTED_SUBSCRIPTION'; END IF;
END $t$;
DO $t$
DECLARE v_epoch bigint; caught boolean:=false;
BEGIN
 SELECT step_epoch INTO v_epoch FROM outcome;
 PERFORM set_config('request.jwt.claims','{"role":"authenticated"}',true);
 BEGIN
  PERFORM public.bil_admin_web_execute_financial_command(
    '11111111-1111-4111-8111-111111111111',v_epoch,
    'user-privilege-test-001','grant','recipient-testing@example.invalid','premium',30,
    'QA grant for isolated test account',NULL);
 EXCEPTION WHEN SQLSTATE '42501' THEN
  IF SQLERRM!='administrator_required' THEN RAISE; END IF; caught:=true;
 END;
 PERFORM set_config('request.jwt.claims','{"role":"service_role"}',true);
 IF NOT caught THEN RAISE EXCEPTION 'SERVICE_ROLE_CHECK_BYPASSED'; END IF;
END $t$;
-- Advance the synthetic receipt's created_at; never touch production or real records.
UPDATE bil_admin_private.web_financial_step_up_receipts
  SET created_at = statement_timestamp() - interval '130 seconds';
DO $t$
DECLARE v_epoch bigint;v_id uuid;v jsonb;
BEGIN
 SELECT step_epoch,grant_id INTO v_epoch,v_id FROM outcome;
 v:=public.bil_admin_web_execute_financial_command(
   '11111111-1111-4111-8111-111111111111',v_epoch+3,
   'revoke-first-test-001','revoke',NULL,NULL,NULL,'',v_id);
 IF v->>'matched'!='true' OR v->>'changed'!='true' OR (v->>'grant_id')::uuid != v_id
 THEN RAISE EXCEPTION 'REVOKE_FAILED %',v; END IF;
 IF (SELECT count(*) FROM bil_admin_private.subscription_grants WHERE revoked_at IS NOT NULL)!=1
 THEN RAISE EXCEPTION 'REVOKE_NOT_REFLECTED'; END IF;
END $t$;
DO $t$
BEGIN
 IF (SELECT count(*) FROM bil_admin_private.subscription_commands)!=2
 OR (SELECT count(*) FROM bil_admin_private.web_financial_step_up_receipts)!=2
 THEN RAISE EXCEPTION 'EXTRA_SIDE_EFFECTS'; END IF;
END $t$;
SELECT 'PASS: real PostgreSQL 17 grant + idempotent replay + cooldown + MFA + ACL + revoke' AS integration_result;
