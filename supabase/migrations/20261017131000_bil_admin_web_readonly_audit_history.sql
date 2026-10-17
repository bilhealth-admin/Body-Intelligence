-- BIL Secure Admin read-only audit history migration, deployed 2026-10-17.
-- Does not change subscription grants, purchases, balances, or app permission rosters.
DO $guard$
BEGIN
  IF to_regprocedure('bil_admin_private.require_administrator(uuid)') IS NULL
     OR to_regclass('bil_admin_private.subscription_commands') IS NULL THEN
    RAISE EXCEPTION 'Admin audit dependencies missing';
  END IF;
END $guard$;
-- On fresh environments this CREATE is intended; on existing Production,
-- compare catalog & original deployed hash before any replay.
CREATE OR REPLACE FUNCTION public.bil_admin_web_list_subscription_commands(
  p_actor_id uuid, p_offset integer DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE v_total bigint; v_rows jsonb;
BEGIN
  PERFORM bil_admin_private.require_administrator(p_actor_id);
  IF p_offset IS NULL OR p_offset < 0 OR p_offset > 10000 THEN
    RAISE EXCEPTION 'invalid_audit_offset' USING errcode='22023';
  END IF;
  SELECT count(*) INTO v_total FROM bil_admin_private.subscription_commands c
  WHERE c.payload->>'operation' IN ('grant','revoke');
  SELECT coalesce(jsonb_agg(a.record ORDER BY a.created_at DESC,a.id DESC), '[]'::jsonb)
  INTO v_rows FROM (
    SELECT c.created_at,c.id,jsonb_build_object(
      'id',c.id,'actor_id',c.actor_id,'operation',c.payload->>'operation',
      'created_at',c.created_at,'matched',c.result->'matched',
      'changed',c.result->'changed','grant_id',c.result->'grant_id'
    ) AS record FROM bil_admin_private.subscription_commands c
    WHERE c.payload->>'operation' IN ('grant','revoke')
    ORDER BY c.created_at DESC,c.id DESC LIMIT 50 OFFSET p_offset
  ) a;
  RETURN jsonb_build_object('rows',v_rows,'has_more',p_offset+50<v_total);
END;
$fn$;
REVOKE ALL ON FUNCTION public.bil_admin_web_list_subscription_commands(uuid,integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_list_subscription_commands(uuid,integer) TO service_role;
NOTIFY pgrst, 'reload schema';
