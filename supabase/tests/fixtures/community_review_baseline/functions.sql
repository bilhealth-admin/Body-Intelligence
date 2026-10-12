-- Actual deployed definitions, read-only catalog capture 2026-10-11.
CREATE OR REPLACE FUNCTION private.bil_resolve_community_moderation_authority(p_actor uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when p_actor is null then null
    when exists (
      select 1 from private.bil_ai_coach_admins administrator
      where administrator.user_id = p_actor and administrator.active
    ) then 'admin'
    when exists (
      select 1 from public.bil_community_moderators moderator
      where moderator.user_id = p_actor
    ) then 'moderator'
    else null
  end
$function$
;
CREATE OR REPLACE FUNCTION private.bil_activity_pair_allowed_v1(p_recipient uuid, p_actor uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    p_recipient is not null
    and p_actor is not null
    and p_recipient<>p_actor
    and not exists(
      select 1
      from private.bil_community_member_access a
      where a.user_id in(p_recipient,p_actor)
        and a.suspended
    )
    and not exists(
      select 1
      from public.bil_blocks b
      where (b.blocker_id=p_recipient and b.blocked_id=p_actor)
         or (b.blocker_id=p_actor and b.blocked_id=p_recipient)
    );
$function$
;
CREATE OR REPLACE FUNCTION private.bil_emit_community_activity_v2(p_recipient uuid, p_actor uuid, p_kind text, p_source_key text, p_entity_kind text, p_entity_id text, p_copy_key text, p_deep_link_path text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_existing public.bil_community_notifications%rowtype;
  v_id uuid;
begin
  if p_recipient is null or not exists(
    select 1 from auth.users u where u.id=p_recipient
  ) then
    raise exception 'activity_recipient_invalid' using errcode='22023';
  end if;
  if p_actor is not null and not exists(
    select 1 from auth.users u where u.id=p_actor
  ) then
    raise exception 'activity_actor_invalid' using errcode='22023';
  end if;
  if p_source_key is null
     or char_length(p_source_key) not between 16 and 128 then
    raise exception 'activity_source_key_invalid' using errcode='22023';
  end if;
  if p_metadata is null
     or pg_catalog.jsonb_typeof(p_metadata)<>'object'
     or pg_catalog.octet_length(p_metadata::text)>4096 then
    raise exception 'activity_metadata_invalid' using errcode='22023';
  end if;

  select * into v_existing
  from public.bil_community_notifications n
  where n.source_key=p_source_key;

  if found then
    if v_existing.recipient_id is distinct from p_recipient
       or v_existing.actor_id is distinct from p_actor
       or v_existing.kind is distinct from p_kind
       or v_existing.entity_kind is distinct from p_entity_kind
       or v_existing.entity_id is distinct from p_entity_id
       or v_existing.copy_key is distinct from p_copy_key
       or v_existing.deep_link_path is distinct from p_deep_link_path
       or v_existing.metadata is distinct from p_metadata then
      raise exception 'activity_source_payload_mismatch'
        using errcode='22023';
    end if;
    return v_existing.id;
  end if;

  insert into public.bil_community_notifications(
    recipient_id,
    actor_id,
    kind,
    friendship_id,
    source_key,
    entity_kind,
    entity_id,
    copy_key,
    deep_link_path,
    metadata
  ) values(
    p_recipient,
    p_actor,
    p_kind,
    null,
    p_source_key,
    p_entity_kind,
    p_entity_id,
    p_copy_key,
    p_deep_link_path,
    p_metadata
  )
  returning id into v_id;

  return v_id;
end
$function$
;
CREATE OR REPLACE FUNCTION private.bil_post_approval_receipt_trigger_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform private.bil_emit_post_receipt_v1(new.owner_id,'post_approved','post',new.post_id,new.tokens,new.reward_reason);
  return new;
end
$function$
;
CREATE OR REPLACE FUNCTION private.bil_post_rejection_receipt_trigger_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if old.moderation_status='pending' and new.moderation_status='rejected' then perform private.bil_emit_post_receipt_v1(new.author_id,'post_rejected','post',new.id); end if;
  return new;
end
$function$
;
CREATE OR REPLACE FUNCTION public.bil_guard_community_post_moderation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if tg_op = 'INSERT' then
    if not public.bil_has_community_moderators(new.author_id) then
      raise exception 'community_moderation_unavailable'
        using errcode = '55000',
              detail = 'No eligible human moderator is currently enrolled.';
    end if;
    new.moderation_status := 'pending';
    new.moderation_visibility := 'visible';
    new.reviewed_at := null;
    return new;
  end if;

  if current_user in ('anon', 'authenticated') then
    if new.moderation_status is distinct from old.moderation_status
       or new.moderation_visibility is distinct from old.moderation_visibility
       or new.reviewed_at is distinct from old.reviewed_at then
      raise exception 'moderation_fields_are_server_managed'
        using errcode = '42501';
    end if;

    if new.author_id = (select auth.uid())
       and new.deleted_at is not null
       and new.media_url is null
       and new.media_object_path is null
       and new.media_mime_type is null
       and new.media_bytes is null
       and new.media_width is null
       and new.media_height is null
       and (
         pg_catalog.to_jsonb(new) - array[
           'deleted_at', 'media_url', 'media_object_path', 'media_mime_type',
           'media_bytes', 'media_width', 'media_height'
         ]::text[]
       ) = (
         pg_catalog.to_jsonb(old) - array[
           'deleted_at', 'media_url', 'media_object_path', 'media_mime_type',
           'media_bytes', 'media_width', 'media_height'
         ]::text[]
       ) then
      return new;
    end if;

    raise exception 'community_post_update_requires_human_review'
      using errcode = '42501';
  end if;

  return new;
end
$function$
;
CREATE OR REPLACE FUNCTION public.bil_guard_suspended_author_post_approval()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.moderation_status = 'approved'
     and new.moderation_status is distinct from old.moderation_status then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'community_member_state:' || new.author_id::text, 0
      )
    );

    if exists (
       select 1
       from private.bil_community_member_access access_row
       where access_row.user_id = new.author_id
         and access_row.suspended
    ) then
      raise exception 'suspended_author_post_approval_forbidden'
        using errcode = '42501';
    end if;
  end if;
  return new;
end
$function$
;
CREATE OR REPLACE FUNCTION private.bil_emit_post_receipt_v1(p_owner uuid, p_kind text, p_entity_kind text, p_entity_id uuid, p_tokens integer DEFAULT 0, p_reason text DEFAULT 'not_applicable'::text, p_push boolean DEFAULT true)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_key text := 'post-event:'||p_kind||':'||p_entity_id::text||':'||p_owner::text;
  v_id uuid;
  v_existing private.bil_community_post_events_v1%rowtype;
  v_body text;
  v_link text;
begin
  if p_owner is null or p_entity_id is null or p_push is null then raise exception 'post_receipt_invalid' using errcode='22023'; end if;
  insert into private.bil_community_post_events_v1(owner_id,event_kind,entity_kind,entity_id,event_key,ai_tokens,reward_reason)
  values(p_owner,p_kind,p_entity_kind,p_entity_id,v_key,p_tokens,p_reason)
  on conflict(event_key) do nothing returning id into v_id;
  if v_id is null then
    select * into strict v_existing from private.bil_community_post_events_v1 where event_key=v_key;
    if v_existing.entity_kind is distinct from p_entity_kind or v_existing.ai_tokens is distinct from p_tokens or v_existing.reward_reason is distinct from p_reason then raise exception 'post_receipt_idempotency_mismatch' using errcode='22023'; end if;
    return v_existing.id;
  end if;
  if p_kind='post_approved' and p_tokens>0 then
    perform private.bil_emit_community_activity_v2(p_owner,null,'reward_earned','post-ai-reward:'||p_entity_id::text,'post',p_entity_id::text,'community_post_ai_reward_v1','/community',pg_catalog.jsonb_build_object('currency','ai_tokens','tokens',p_tokens,'decision','approved','receipt_id',v_id));
  end if;
  if p_push then
    v_body := case p_kind
      when 'review_requested' then case p_entity_kind when 'report' then 'بلاغ جديد ينتظر المراجعة. A report is awaiting review.' else 'منشور جديد ينتظر المراجعة. A post is awaiting review.' end
      when 'post_submitted' then 'منشورك قيد المراجعة. Your post is awaiting review.'
      when 'post_approved' then case when p_tokens>0 then 'تم اعتماد منشورك وإضافة '||p_tokens::text||' توكن AI. Post approved: +'||p_tokens::text||' AI tokens.' else 'تم اعتماد منشورك. بلغت حد المكافآت اليوم. Post approved; daily reward limit reached.' end
      when 'post_rejected' then 'تمت مراجعة منشورك ولم يُنشر. Your post was reviewed and was not published.' end;
    v_link := case when p_kind='review_requested' then 'bil://community/moderation' else 'bil://community' end;
    insert into public.bil_push_outbox(recipient_id,category,body,deep_link,source_key) values(p_owner,'community',v_body,v_link,v_key) on conflict do nothing;
  end if;
  return v_id;
end
$function$
;
CREATE OR REPLACE FUNCTION public.bil_moderate_community_post(p_post_id uuid, p_decision text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
  v_post public.bil_community_posts%rowtype;
  v_decision text := lower(trim(coalesce(p_decision, '')));
  v_reward_day date :=
    (pg_catalog.timezone('UTC', pg_catalog.clock_timestamp())::date);
  v_reward_tokens integer := 0;
  v_reward_reason text := 'not_applicable';
  v_daily_cap integer;
  v_rewarded_posts integer;
  v_grant_inserted integer := 0;
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if v_decision not in ('approved', 'rejected') then
    raise exception 'invalid_post_moderation_decision';
  end if;

  select p.* into v_post
  from public.bil_community_posts p
  where p.id = p_post_id
  for update;

  if not found or v_post.deleted_at is not null then
    raise exception 'post_not_found';
  end if;
  if v_post.author_id = v_actor then
    raise exception 'moderator_cannot_review_own_post'
      using errcode = '42501';
  end if;

  -- A retry of the same completed request is a read-only success. A different
  -- second decision is rejected instead of silently rewriting human history.
  if v_post.moderation_status = v_decision then
    return jsonb_build_object(
      'post_id', v_post.id,
      'decision', v_decision,
      'duplicate', true,
      'tokens_granted', 0,
      'reward_reason', 'duplicate_decision'
    );
  end if;
  if v_post.moderation_status <> 'pending' then
    raise exception 'post_already_moderated';
  end if;

  update public.bil_community_posts p
  set moderation_status = v_decision,
      reviewed_at = now()
  where p.id = v_post.id;

  if v_decision = 'approved' then
    select
      policy.tokens_per_approval,
      policy.max_rewarded_posts_per_owner_per_utc_day
      into v_reward_tokens, v_daily_cap
    from public.bil_community_post_reward_policy policy
    where policy.singleton
    for share;

    if not found then
      raise exception 'community_reward_policy_unavailable';
    end if;

    insert into public.bil_community_post_reward_usage(
      owner_id,
      reward_day
    ) values (
      v_post.author_id,
      v_reward_day
    )
    on conflict (owner_id, reward_day) do nothing;

    select usage.rewarded_posts
      into v_rewarded_posts
    from public.bil_community_post_reward_usage usage
    where usage.owner_id = v_post.author_id
      and usage.reward_day = v_reward_day
    for update;

    if v_rewarded_posts >= v_daily_cap then
      v_reward_tokens := 0;
      v_reward_reason := 'daily_cap_reached';
    else
      v_reward_reason := 'granted';
    end if;

    insert into public.bil_community_post_approval_grants(
      post_id,
      owner_id,
      approved_by,
      reward_day,
      tokens,
      reward_reason
    ) values (
      v_post.id,
      v_post.author_id,
      v_actor,
      v_reward_day,
      v_reward_tokens,
      v_reward_reason
    )
    on conflict (post_id) do nothing;
    get diagnostics v_grant_inserted = row_count;

    if v_grant_inserted = 1 and v_reward_tokens > 0 then
      update public.bil_community_post_reward_usage usage
      set rewarded_posts = usage.rewarded_posts + 1,
          granted_tokens = usage.granted_tokens + v_reward_tokens,
          updated_at = pg_catalog.clock_timestamp()
      where usage.owner_id = v_post.author_id
        and usage.reward_day = v_reward_day;

      insert into public.bil_ai_credit_balances(owner_id, granted)
      values (v_post.author_id, v_reward_tokens)
      on conflict (owner_id) do update set
        granted = public.bil_ai_credit_balances.granted + excluded.granted,
        updated_at = pg_catalog.clock_timestamp();
    elsif v_grant_inserted = 0 then
      -- A pre-existing immutable receipt wins over a malformed replay. No
      -- second balance mutation is ever attempted.
      v_reward_tokens := 0;
      v_reward_reason := 'duplicate_receipt';
    end if;
  end if;

  insert into public.bil_community_audit_events(
    actor_id,
    event_kind,
    target_kind,
    target_id,
    metadata
  ) values (
    v_actor,
    'POST_REVIEW',
    'community_post',
    v_post.id::text,
    jsonb_build_object(
      'decision', v_decision,
      'tokens_granted', case
        when v_grant_inserted = 1 then v_reward_tokens
        else 0
      end,
      'reward_reason', v_reward_reason,
      'reward_day', case
        when v_decision = 'approved' then v_reward_day::text
        else null
      end,
      'daily_reward_cap', case
        when v_decision = 'approved' then v_daily_cap
        else null
      end
    )
  );

  return jsonb_build_object(
    'post_id', v_post.id,
    'decision', v_decision,
    'duplicate', false,
    'tokens_granted', case
      when v_grant_inserted = 1 then v_reward_tokens
      else 0
    end,
    'reward_reason', v_reward_reason
  );
end
$function$
;
