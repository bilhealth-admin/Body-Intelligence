-- BIL Admin Web: minimal report contact lookup; NEVER grant this to browser clients.
-- A verified web owner requests these only after reading an authorized report queue.
CREATE OR REPLACE FUNCTION public.bil_admin_web_reporter_contacts_v1(
  p_actor_id uuid, p_report_kind text, p_report_ids uuid[]
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $body$
DECLARE
  v_result jsonb;
BEGIN
  IF coalesce((SELECT auth.jwt()->>'role'),'') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING errcode='42501';
  END IF;
  IF p_actor_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM private.bil_ai_coach_admins a
     WHERE a.user_id=p_actor_id AND a.active
  ) THEN
    RAISE EXCEPTION 'administrator_required' USING errcode='42501';
  END IF;
  IF p_report_kind IS NULL OR p_report_kind NOT IN ('safety','community','posts')
      OR p_report_ids IS NULL OR cardinality(p_report_ids)>50
      OR array_position(p_report_ids,NULL::uuid) IS NOT NULL THEN
    RAISE EXCEPTION 'invalid_report_lookup' USING errcode='22023';
  END IF;
  IF cardinality(p_report_ids)=0 THEN RETURN '[]'::jsonb; END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'record_id', scoped.record_id,
      'reporter_user_id', scoped.owner_id,
      'reporter_email', lower(u.email)
    ) ORDER BY scoped.record_id), '[]'::jsonb)
    INTO v_result
  FROM (
    SELECT s.report_id AS record_id, s.owner_id
    FROM private.bil_ai_coach_safety_reports_v1 s
    WHERE p_report_kind='safety' AND s.report_id=ANY(p_report_ids)
      AND s.owner_id IS DISTINCT FROM p_actor_id
      AND (s.status='open' OR s.reviewed_at>=now()-interval '30 days')
    UNION ALL
    SELECT c.id AS record_id, c.reporter_id AS owner_id
    FROM public.bil_community_reports c
    WHERE p_report_kind='community' AND c.id=ANY(p_report_ids)
      AND c.reporter_id IS DISTINCT FROM p_actor_id
      AND c.status IN ('open','reviewing')
    UNION ALL
    SELECT p.id AS record_id, p.author_id AS owner_id
    FROM public.bil_community_posts p
    WHERE p_report_kind='posts' AND p.id=ANY(p_report_ids)
      AND p.author_id IS DISTINCT FROM p_actor_id
      AND p.moderation_status='pending' AND p.deleted_at IS NULL
  ) scoped
  JOIN auth.users u ON u.id=scoped.owner_id
  WHERE u.deleted_at IS NULL AND nullif(trim(u.email),'') IS NOT NULL;
  RETURN v_result;
END
$body$;

REVOKE ALL ON FUNCTION public.bil_admin_web_reporter_contacts_v1(uuid,text,uuid[])
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_reporter_contacts_v1(uuid,text,uuid[])
  TO service_role;
COMMENT ON FUNCTION public.bil_admin_web_reporter_contacts_v1(uuid,text,uuid[]) IS
 'Service-role only: a report ID already visible to the owner yields the reporter email and ID. No anonymous/authenticated directory lookup.';

