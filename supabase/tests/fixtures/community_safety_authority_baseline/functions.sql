-- Eight exact pg_get_functiondef captures; metadata in catalog.json. No user rows.

CREATE OR REPLACE FUNCTION public.bil_add_community_moderator_by_email(p_actor_id uuid, p_email text, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_email text := pg_catalog.lower(pg_catalog.btrim(p_email));
  v_target_id uuid;
  v_matches integer;
  v_inserted integer := 0;
  v_digest text;
  v_existing_action text;
  v_existing_digest text;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
     or p_actor_id is null
     or not exists (
       select 1
       from private.bil_ai_coach_admins administrator
       where administrator.user_id = p_actor_id
         and administrator.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  if p_idempotency_key is null
     or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
       not between 16 and 128
     or pg_catalog.btrim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;
  if v_email is null or v_email = '' or pg_catalog.char_length(v_email) > 254
     or v_email ~ '[[:cntrl:][:space:]]'
     or v_email !~ '^[^@]+@[^@]+[.][^@]+$' then
    raise exception 'invalid_email';
  end if;

  v_digest := pg_catalog.encode(
    extensions.digest(v_email, 'sha256'),
    'hex'
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_moderator_request:' || pg_catalog.btrim(p_idempotency_key),
      0
    )
  );
  select audit.action, audit.request_digest, audit.result
    into v_existing_action, v_existing_digest, v_existing_result
  from private.bil_community_moderator_admin_audit audit
  where audit.idempotency_key = pg_catalog.btrim(p_idempotency_key);
  if found then
    if v_existing_action <> 'add' or v_existing_digest <> v_digest then
      raise exception 'idempotency_key_request_mismatch';
    end if;
    return v_existing_result;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('community_moderator_roster', 0)
  );

  select pg_catalog.count(*)::integer
    into v_matches
  from auth.users account
  where pg_catalog.lower(account.email) = v_email;

  if v_matches <> 1 then
    v_result := pg_catalog.jsonb_build_object(
      'matched', false,
      'added', false
    );
    insert into private.bil_community_moderator_admin_audit(
      idempotency_key, actor_id, action, request_digest, result
    ) values (
      pg_catalog.btrim(p_idempotency_key), p_actor_id, 'add', v_digest,
      v_result
    );
    return v_result;
  end if;

  select account.id
    into v_target_id
  from auth.users account
  where pg_catalog.lower(account.email) = v_email
  limit 1;

  insert into public.bil_community_moderators(user_id)
  values (v_target_id)
  on conflict (user_id) do nothing;
  get diagnostics v_inserted = row_count;

  v_result := pg_catalog.jsonb_build_object(
    'matched', true,
    'added', v_inserted = 1
  );
  insert into private.bil_community_moderator_admin_audit(
    idempotency_key, actor_id, target_id, action, request_digest, result
  ) values (
    pg_catalog.btrim(p_idempotency_key), p_actor_id, v_target_id, 'add',
    v_digest, v_result
  );
  return v_result;
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

CREATE OR REPLACE FUNCTION public.bil_moderate_community_report(p_report_id uuid, p_resolution text, p_action text DEFAULT 'none'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
  v_report public.bil_community_reports%rowtype;
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if p_resolution not in ('reviewing', 'closed')
     or p_action not in ('none', 'remove_content') then
    raise exception 'invalid_moderation_action';
  end if;

  select report_row.* into v_report
  from public.bil_community_reports report_row
  where report_row.id = p_report_id
  for update;
  if not found then
    raise exception 'report_not_found';
  end if;

  if (v_report.target_kind = 'post' and exists (
        select 1 from public.bil_community_posts post_row
        where post_row.id = v_report.target_id and post_row.author_id = v_actor
      ))
     or (v_report.target_kind = 'message' and exists (
        select 1 from public.bil_messages message_row
        where message_row.id = v_report.target_id and message_row.sender_id = v_actor
      ))
     or (v_report.target_kind = 'food' and exists (
        select 1 from public.bil_community_food_submissions food_row
        where food_row.id = v_report.target_id and food_row.contributor_id = v_actor
      ))
     or (v_report.target_kind = 'profile' and v_report.target_id = v_actor) then
    raise exception 'moderator_cannot_review_own_content' using errcode = '42501';
  end if;

  if p_action = 'remove_content' and v_report.target_kind = 'post' then
    update public.bil_community_posts
    set deleted_at = pg_catalog.now()
    where id = v_report.target_id;
  elsif p_action = 'remove_content' and v_report.target_kind = 'message' then
    update public.bil_messages
    set deleted_by_sender_at = pg_catalog.now(),
        deleted_by_recipient_at = pg_catalog.now()
    where id = v_report.target_id;
  end if;

  update public.bil_community_reports
  set status = p_resolution
  where id = p_report_id;

  insert into public.bil_community_audit_events(
    actor_id, event_kind, target_kind, target_id, metadata
  ) values (
    v_actor,
    'MODERATE',
    v_report.target_kind,
    v_report.target_id::text,
    pg_catalog.jsonb_build_object(
      'report_id', p_report_id,
      'resolution', p_resolution,
      'action', p_action
    )
  );
end
$function$
;

CREATE OR REPLACE FUNCTION public.bil_moderate_published_community_post(p_post_id uuid, p_action text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
  v_role text;
  v_action text := pg_catalog.lower(pg_catalog.btrim(p_action));
  v_reason text := pg_catalog.lower(pg_catalog.btrim(p_reason));
  v_post public.bil_community_posts%rowtype;
  v_previous text;
  v_next text;
begin
  v_role := private.bil_resolve_community_moderation_authority(v_actor);
  if v_role is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if v_action not in ('hide', 'restore', 'remove') then
    raise exception 'invalid_moderation_action' using errcode = '22023';
  end if;
  if v_action in ('hide', 'remove') and v_reason not in (
    'spam', 'abuse', 'misleading', 'privacy',
    'unsafe_or_inappropriate', 'other'
  ) then
    raise exception 'invalid_moderation_reason' using errcode = '22023';
  end if;
  if v_action = 'restore' then
    v_reason := 'restored';
  end if;

  select * into v_post
  from public.bil_community_posts
  where id = p_post_id
  for update;
  if not found or v_post.moderation_status <> 'approved' then
    raise exception 'published_post_not_found' using errcode = 'P0002';
  end if;
  v_previous := v_post.moderation_visibility;

  if v_action = 'hide' then
    if v_post.deleted_at is not null or v_previous = 'removed_by_moderator' then
      raise exception 'removed_post_cannot_be_hidden' using errcode = '22023';
    end if;
    v_next := 'hidden_by_moderator';
  elsif v_action = 'restore' then
    if v_post.deleted_at is not null or v_previous <> 'hidden_by_moderator' then
      raise exception 'only_hidden_post_can_be_restored' using errcode = '22023';
    end if;
    v_next := 'visible';
  else
    v_next := 'removed_by_moderator';
  end if;

  if v_previous = v_next then
    return pg_catalog.jsonb_build_object(
      'post_id', p_post_id, 'action', v_action, 'duplicate', true,
      'previous_visibility', v_previous, 'new_visibility', v_next
    );
  end if;

  update public.bil_community_posts
  set moderation_visibility = v_next,
      deleted_at = case
        when v_action = 'remove' then pg_catalog.clock_timestamp()
        else deleted_at
      end
  where id = p_post_id;

  insert into public.bil_community_audit_events(
    actor_id, event_kind, target_kind, target_id, metadata
  ) values (
    v_actor,
    case v_action
      when 'hide' then 'moderator_hide'
      when 'restore' then 'moderator_restore'
      else 'moderator_remove'
    end,
    'post', p_post_id,
    pg_catalog.jsonb_build_object(
      'actor_role', v_role,
      'post_author_id', v_post.author_id,
      'reason', v_reason,
      'previous_moderation_status', v_post.moderation_status,
      'new_moderation_status', v_post.moderation_status,
      'previous_visibility', v_previous,
      'new_visibility', v_next
    )
  );

  return pg_catalog.jsonb_build_object(
    'post_id', p_post_id, 'action', v_action, 'duplicate', false,
    'previous_visibility', v_previous, 'new_visibility', v_next
  );
end
$function$
;

CREATE OR REPLACE FUNCTION public.bil_reinstate_community_member(p_actor_id uuid, p_user_id uuid, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_changed boolean := false;
  v_digest text;
  v_existing_actor uuid;
  v_existing_action text;
  v_existing_digest text;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
     or p_actor_id is null
     or not exists (
       select 1
       from private.bil_ai_coach_admins administrator
       where administrator.user_id = p_actor_id
         and administrator.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'invalid_member';
  end if;
  if p_idempotency_key is null
     or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
       not between 16 and 128
     or pg_catalog.btrim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;

  v_digest := pg_catalog.encode(
    extensions.digest(p_user_id::text, 'sha256'), 'hex'
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_access:' || pg_catalog.btrim(p_idempotency_key), 0
    )
  );
  select audit.actor_id, audit.action, audit.request_digest, audit.result
    into v_existing_actor, v_existing_action, v_existing_digest,
      v_existing_result
  from private.bil_community_member_access_audit audit
  where audit.idempotency_key = pg_catalog.btrim(p_idempotency_key);
  if found then
    if v_existing_actor is distinct from p_actor_id then
      raise exception 'idempotency_key_owned_by_another_admin'
        using errcode = '42501';
    end if;
    if v_existing_action <> 'reinstate' or v_existing_digest <> v_digest then
      raise exception 'idempotency_key_request_mismatch';
    end if;
    return v_existing_result;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_state:' || p_user_id::text, 0
    )
  );

  update private.bil_community_member_access access_row
  set suspended = false,
      reinstated_by = p_actor_id,
      reinstated_at = pg_catalog.clock_timestamp(),
      updated_at = pg_catalog.clock_timestamp()
  where access_row.user_id = p_user_id
    and access_row.suspended;
  v_changed := found;

  v_result := pg_catalog.jsonb_build_object('reinstated', v_changed);
  insert into private.bil_community_member_access_audit(
    idempotency_key, actor_id, target_id, action, request_digest, result
  ) values (
    pg_catalog.btrim(p_idempotency_key), p_actor_id, p_user_id, 'reinstate',
    v_digest, v_result
  );
  return v_result;
end
$function$
;

CREATE OR REPLACE FUNCTION public.bil_remove_community_moderator(p_actor_id uuid, p_user_id uuid, p_idempotency_key text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_removed integer := 0;
  v_digest text;
  v_existing_action text;
  v_existing_digest text;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
     or p_actor_id is null
     or not exists (
       select 1
       from private.bil_ai_coach_admins administrator
       where administrator.user_id = p_actor_id
         and administrator.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'invalid_moderator';
  end if;
  if p_idempotency_key is null
     or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
       not between 16 and 128
     or pg_catalog.btrim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;

  v_digest := pg_catalog.encode(
    extensions.digest(p_user_id::text, 'sha256'),
    'hex'
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_moderator_request:' || pg_catalog.btrim(p_idempotency_key),
      0
    )
  );
  select audit.action, audit.request_digest, audit.result
    into v_existing_action, v_existing_digest, v_existing_result
  from private.bil_community_moderator_admin_audit audit
  where audit.idempotency_key = pg_catalog.btrim(p_idempotency_key);
  if found then
    if v_existing_action <> 'remove' or v_existing_digest <> v_digest then
      raise exception 'idempotency_key_request_mismatch';
    end if;
    return coalesce((v_existing_result->>'removed')::boolean, false);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('community_moderator_roster', 0)
  );
  if exists (
    select 1
    from private.bil_ai_coach_admins administrator
    where administrator.user_id = p_user_id
      and administrator.active
  ) then
    raise exception 'protected_administrator_moderator';
  end if;

  delete from public.bil_community_moderators moderator
  where moderator.user_id = p_user_id;
  get diagnostics v_removed = row_count;

  if not public.bil_has_community_moderators(null) then
    raise exception 'community_moderation_preflight_failed';
  end if;
  v_result := pg_catalog.jsonb_build_object('removed', v_removed = 1);
  insert into private.bil_community_moderator_admin_audit(
    idempotency_key, actor_id, target_id, action, request_digest, result
  ) values (
    pg_catalog.btrim(p_idempotency_key), p_actor_id, p_user_id, 'remove',
    v_digest, v_result
  );
  return v_removed = 1;
end
$function$
;

CREATE OR REPLACE FUNCTION public.bil_social_resolve_comment_report_v2(p_report_id uuid, p_remove boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_comment uuid; v_author uuid;
begin
 if not public.bil_can_use_community() or not public.bil_is_community_moderator() then raise exception 'moderator_required' using errcode='42501'; end if;
 if p_remove is null then raise exception 'invalid_decision' using errcode='22023'; end if;
 select r.comment_id,c.author_id into v_comment,v_author from public.bil_social_comment_reports_v2 r join public.bil_social_comments_v2 c on c.id=r.comment_id where r.id=p_report_id and r.reviewed_at is null for update of r;
 if not found then raise exception 'report_unavailable' using errcode='42501'; end if;
 if v_author=auth.uid() then raise exception 'moderator_cannot_review_own_comment' using errcode='42501'; end if;
 if p_remove then update public.bil_social_comments_v2 set removed_at=now(),removed_by=auth.uid() where id=v_comment; end if;
 update public.bil_social_comment_reports_v2 set reviewed_at=now(),reviewed_by=auth.uid() where id=p_report_id;
end; $function$
;

CREATE OR REPLACE FUNCTION public.bil_suspend_community_member_by_email(p_actor_id uuid, p_email text, p_reason text, p_idempotency_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_email text := pg_catalog.lower(pg_catalog.btrim(p_email));
  v_reason text := pg_catalog.btrim(p_reason);
  v_target_id uuid;
  v_matches integer;
  v_changed boolean := false;
  v_moderator_removed boolean := false;
  v_digest text;
  v_existing_actor uuid;
  v_existing_action text;
  v_existing_digest text;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
     or p_actor_id is null
     or not exists (
       select 1
       from private.bil_ai_coach_admins administrator
       where administrator.user_id = p_actor_id
         and administrator.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  if p_idempotency_key is null
     or pg_catalog.char_length(pg_catalog.btrim(p_idempotency_key))
       not between 16 and 128
     or pg_catalog.btrim(p_idempotency_key) !~ '^[A-Za-z0-9:_-]+$' then
    raise exception 'invalid_idempotency_key';
  end if;
  if v_email is null or v_email = '' or pg_catalog.char_length(v_email) > 254
     or v_email ~ '[[:cntrl:][:space:]]'
     or v_email !~ '^[^@]+@[^@]+[.][^@]+$' then
    raise exception 'invalid_email';
  end if;
  if v_reason is null or pg_catalog.char_length(v_reason) not between 2 and 160
     or v_reason ~ '[[:cntrl:]]' then
    raise exception 'invalid_suspension_reason';
  end if;

  v_digest := pg_catalog.encode(
    extensions.digest(v_email || E'\n' || v_reason, 'sha256'),
    'hex'
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_access:' || pg_catalog.btrim(p_idempotency_key), 0
    )
  );
  select audit.actor_id, audit.action, audit.request_digest, audit.result
    into v_existing_actor, v_existing_action, v_existing_digest,
      v_existing_result
  from private.bil_community_member_access_audit audit
  where audit.idempotency_key = pg_catalog.btrim(p_idempotency_key);
  if found then
    if v_existing_actor is distinct from p_actor_id then
      raise exception 'idempotency_key_owned_by_another_admin'
        using errcode = '42501';
    end if;
    if v_existing_action <> 'suspend' or v_existing_digest <> v_digest then
      raise exception 'idempotency_key_request_mismatch';
    end if;
    return v_existing_result;
  end if;

  select pg_catalog.count(*)::integer, pg_catalog.min(account.id::text)::uuid
    into v_matches, v_target_id
  from auth.users account
  where pg_catalog.lower(account.email) = v_email;

  if v_matches <> 1 then
    v_result := pg_catalog.jsonb_build_object(
      'matched', false, 'active', false, 'changed', false,
      'moderator_removed', false
    );
    insert into private.bil_community_member_access_audit(
      idempotency_key, actor_id, action, request_digest, result
    ) values (
      pg_catalog.btrim(p_idempotency_key), p_actor_id, 'suspend', v_digest,
      v_result
    );
    return v_result;
  end if;

  if exists (
    select 1
    from private.bil_ai_coach_admins administrator
    where administrator.user_id = v_target_id
      and administrator.active
  ) then
    raise exception 'protected_administrator_member' using errcode = '42501';
  end if;

  -- Serialize with moderator add/remove. Without the shared roster lock, an
  -- add waiting on this transaction's moderator-row delete could run its
  -- eligibility trigger against the pre-suspension snapshot and recreate the
  -- moderator immediately after the delete commits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('community_moderator_roster', 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_state:' || v_target_id::text, 0
    )
  );

  insert into private.bil_community_member_access(
    user_id, suspended, reason, suspended_by, suspended_at,
    reinstated_by, reinstated_at, updated_at
  ) values (
    v_target_id, true, v_reason, p_actor_id, pg_catalog.clock_timestamp(),
    null, null, pg_catalog.clock_timestamp()
  )
  on conflict (user_id) do update set
    suspended = true,
    reason = excluded.reason,
    suspended_by = excluded.suspended_by,
    suspended_at = case
      when private.bil_community_member_access.suspended
        then private.bil_community_member_access.suspended_at
      else excluded.suspended_at
    end,
    reinstated_by = null,
    reinstated_at = null,
    updated_at = pg_catalog.clock_timestamp()
  where not private.bil_community_member_access.suspended
     or private.bil_community_member_access.reason is distinct from excluded.reason;
  v_changed := found;

  delete from public.bil_community_moderators moderator
  where moderator.user_id = v_target_id;
  v_moderator_removed := found;

  v_result := pg_catalog.jsonb_build_object(
    'matched', true,
    'active', true,
    'changed', v_changed,
    'moderator_removed', v_moderator_removed
  );
  insert into private.bil_community_member_access_audit(
    idempotency_key, actor_id, target_id, action, request_digest, result
  ) values (
    pg_catalog.btrim(p_idempotency_key), p_actor_id, v_target_id, 'suspend',
    v_digest, v_result
  );
  return v_result;
end
$function$
;
