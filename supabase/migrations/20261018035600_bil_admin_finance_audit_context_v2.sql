-- Owner-only financial command audit, full context for BIL Secure Administration.
-- Additive read-only API. No modifications to existing grant ledgers, commands, entitlement checks or store receipts.
CREATE OR REPLACE FUNCTION public.bil_admin_web_list_subscription_commands_v2(
  p_actor_id uuid, p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_total bigint; v_rows jsonb;
BEGIN
  PERFORM bil_admin_private.require_administrator(p_actor_id);
  IF p_offset IS NULL OR p_offset < 0 OR p_offset > 10000 THEN
    RAISE EXCEPTION 'invalid_audit_offset' USING errcode='22023';
  END IF;
  SELECT count(*) INTO v_total FROM bil_admin_private.subscription_commands c
   WHERE c.payload->>'operation' IN ('grant','revoke');
  SELECT coalesce(jsonb_agg(p.record ORDER BY p.created_at DESC,p.id DESC),'[]'::jsonb)
    INTO v_rows FROM (
      SELECT c.id, c.created_at, pg_catalog.jsonb_build_object(
        'id',c.id,'actor_id',c.actor_id,'operation',c.payload->>'operation',
        'created_at',c.created_at,'matched',c.result->'matched',
        'changed',c.result->'changed','grant_id',c.result->'grant_id',
        'recipient_email',pg_catalog.lower(recipient.email),
        'actor_email',pg_catalog.lower(actor.email),
        'plan_id',g.plan_id,'grant_created_at',g.created_at,
        'grant_expires_at',g.expires_at,
        'grant_revoked_at',g.revoked_at,
        'grant_reason',g.reason
      ) AS record
      FROM bil_admin_private.subscription_commands c
      LEFT JOIN bil_admin_private.subscription_grants g ON g.id = (
         CASE WHEN c.result->>'grant_id' ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
            THEN (c.result->>'grant_id')::uuid ELSE NULL END
      )
      LEFT JOIN auth.users recipient ON recipient.id=g.owner_id
      LEFT JOIN auth.users actor ON actor.id=c.actor_id
      WHERE c.payload->>'operation' IN ('grant','revoke')
      ORDER BY c.created_at DESC,c.id DESC LIMIT 50 OFFSET p_offset
    ) p;
  RETURN pg_catalog.jsonb_build_object('rows',v_rows,'has_more',p_offset+50<v_total);
END;
$fn$;
REVOKE ALL ON FUNCTION public.bil_admin_web_list_subscription_commands_v2(uuid,integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_list_subscription_commands_v2(uuid,integer)
  TO service_role;