-- BIL: Read-only, owner-scoped review metadata, no broad table grants.
-- Does not update rows, policy, balances, purchases, or entitlements.
BEGIN;

CREATE OR REPLACE FUNCTION public.bil_admin_web_review_context_v1(
  p_actor_id uuid,
  p_post_id uuid
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_post public.bil_community_posts%ROWTYPE;
  v_media jsonb;
  v_hashtags jsonb;
  v_topics jsonb;
  v_circles jsonb;
  v_poll jsonb;
  v_location text;
  v_author_name text;
BEGIN
  IF coalesce((SELECT auth.jwt()->>'role'), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING errcode='42501';
  END IF;
  IF p_actor_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM private.bil_ai_coach_admins a
    WHERE a.user_id=p_actor_id AND a.active
  ) THEN
    RAISE EXCEPTION 'administrator_required' USING errcode='42501';
  END IF;
  IF p_post_id IS NULL THEN
    RAISE EXCEPTION 'invalid_post_id' USING errcode='22023';
  END IF;

  SELECT p.* INTO v_post
  FROM public.bil_community_posts p
  WHERE p.id=p_post_id
    AND p.deleted_at IS NULL
    AND p.moderation_status IN ('pending','approved')
    AND p.author_id<>p_actor_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'post_id', m.post_id,
    'position', m.position,
    'object_path', m.object_path,
    'mime_type', m.mime_type,
    'bytes', m.bytes,
    'width', m.width,
    'height', m.height
  ) ORDER BY m.position), '[]'::jsonb)
  INTO v_media
  FROM public.bil_community_post_media_v1 m
  WHERE m.post_id=p_post_id;

  SELECT coalesce(jsonb_agg(h.hashtag ORDER BY h.hashtag),'[]'::jsonb)
  INTO v_hashtags
  FROM public.bil_community_post_hashtags_v1 h
  WHERE h.post_id=p_post_id;

  SELECT coalesce(jsonb_agg(t.slug ORDER BY t.slug),'[]'::jsonb)
  INTO v_topics
  FROM public.bil_community_post_topics pt
  JOIN public.bil_community_topics t ON t.id=pt.topic_id
  WHERE pt.post_id=p_post_id;

  SELECT coalesce(jsonb_agg(c.slug ORDER BY c.slug),'[]'::jsonb)
  INTO v_circles
  FROM public.bil_community_post_circles pc
  JOIN public.bil_community_circles c ON c.id=pc.circle_id
  WHERE pc.post_id=p_post_id;

  SELECT jsonb_build_object(
    'question', p.question,
    'allow_multiple', p.allow_multiple,
    'closes_at', p.closes_at,
    'options', coalesce((
      SELECT jsonb_agg(o.option_text ORDER BY o.position)
      FROM public.bil_community_poll_options o
      WHERE o.post_id=p.post_id
    ), '[]'::jsonb)
  ) INTO v_poll
  FROM public.bil_community_polls p
  WHERE p.post_id=p_post_id;

  SELECT coalesce(v_post.location_label,(
    SELECT l.label FROM public.bil_community_post_locations_v1 l
    WHERE l.post_id=p_post_id LIMIT 1
  )) INTO v_location;
  SELECT pr.display_name INTO v_author_name
  FROM public.bil_public_profiles pr
  WHERE pr.user_id=v_post.author_id;

  RETURN jsonb_build_object(
    'post_id',v_post.id,
    'author_id',v_post.author_id,
    'author_name',v_author_name,
    'title',v_post.title,
    'location',v_location,
    'hashtags',v_hashtags,
    'topics',v_topics,
    'circles',v_circles,
    'poll',v_poll,
    'media',v_media,
    'media_count',jsonb_array_length(v_media)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.bil_admin_web_review_reward_policy_v1(
  p_actor_id uuid
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_tokens integer;
  v_cap integer;
  v_updated timestamptz;
BEGIN
  IF coalesce((SELECT auth.jwt()->>'role'), '') <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING errcode='42501';
  END IF;
  IF p_actor_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM private.bil_ai_coach_admins a
    WHERE a.user_id=p_actor_id AND a.active
  ) THEN
    RAISE EXCEPTION 'administrator_required' USING errcode='42501';
  END IF;
  SELECT p.tokens_per_approval,p.max_rewarded_posts_per_owner_per_utc_day,p.updated_at
  INTO v_tokens,v_cap,v_updated
  FROM public.bil_community_post_reward_policy p
  WHERE p.singleton;
  IF NOT FOUND OR v_tokens IS NULL OR v_tokens<0 OR v_cap IS NULL OR v_cap<0 THEN
    RAISE EXCEPTION 'reward_policy_unavailable' USING errcode='22023';
  END IF;
  RETURN jsonb_build_object(
    'tokens_per_approval',v_tokens,
    'max_rewarded_posts_per_owner_per_utc_day',v_cap,
    'max_daily_tokens',v_tokens*v_cap,
    'updated_at',v_updated
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.bil_admin_web_review_context_v1(uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_review_context_v1(uuid,uuid) TO service_role;
REVOKE ALL ON FUNCTION public.bil_admin_web_review_reward_policy_v1(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bil_admin_web_review_reward_policy_v1(uuid) TO service_role;

COMMENT ON FUNCTION public.bil_admin_web_review_context_v1(uuid,uuid) IS
  'Owner-authorized service-role review metadata read only. No direct browser grants to private media tables.';
COMMENT ON FUNCTION public.bil_admin_web_review_reward_policy_v1(uuid) IS
  'Owner-authorized service-role immutable reward policy read; cannot award or mutate any tokens.';
COMMIT;