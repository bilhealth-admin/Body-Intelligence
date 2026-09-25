-- Final server-side hardening for cloud-key custody and Community authority.

create or replace function public.bil_get_or_create_cloud_key()
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_owner uuid := (select auth.uid());
  v_latest_consent boolean;
  v_secret_id uuid;
  v_secret text;
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  select consent.granted
    into v_latest_consent
    from (
      select receipt.granted
      from public.bil_consent_receipts receipt
      where receipt.user_id = v_owner
        and receipt.purpose = 'cloud_sync'
      order by receipt.recorded_at desc
      limit 1
    ) as consent;

  if v_latest_consent is distinct from true then
    raise exception 'cloud_sync_consent_required' using errcode = '42501';
  end if;

  -- Serialize first-key creation for one owner without blocking other users.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_owner::text, 0)
  );

  select key_ref.vault_secret_id
    into v_secret_id
    from public.bil_cloud_key_refs key_ref
   where key_ref.owner_id = v_owner;

  if v_secret_id is null then
    v_secret := pg_catalog.encode(extensions.gen_random_bytes(32), 'base64');
    v_secret_id := vault.create_secret(
      v_secret,
      'bil_cloud_payload_' || pg_catalog.replace(v_owner::text, '-', ''),
      'BIL account cloud payload key v1',
      null
    );
    insert into public.bil_cloud_key_refs(owner_id, vault_secret_id)
    values (v_owner, v_secret_id);
  end if;

  select secret.decrypted_secret
    into v_secret
    from vault.decrypted_secrets secret
   where secret.id = v_secret_id;

  if v_secret is null or pg_catalog.length(v_secret) < 40 then
    raise exception 'cloud_key_unavailable';
  end if;

  return v_secret;
end;
$function$;

revoke all on function public.bil_get_or_create_cloud_key()
from public, anon;
grant execute on function public.bil_get_or_create_cloud_key()
to authenticated;


-- All privileged Community moderation paths use the same server authority:
-- active AI Coach administrators OR Community moderators.
CREATE OR REPLACE FUNCTION public.bil_can_moderate_community_post_image(p_object_path text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select (select auth.uid()) is not null
    and private.bil_resolve_community_moderation_authority(
      (select auth.uid())
    ) is not null
    and exists (
      select 1
      from public.bil_community_posts p
      where p.media_object_path = p_object_path
        and p.moderation_status = 'pending'
        and p.deleted_at is null
    )
$function$;

CREATE OR REPLACE FUNCTION public.bil_finalize_food_submission(submission_id uuid, decision text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
  v_submission public.bil_community_food_submissions%rowtype;
  v_decision text := lower(pg_catalog.btrim(coalesce(decision, '')));
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if v_decision not in ('approved', 'needs_changes', 'rejected') then
    raise exception 'invalid_decision';
  end if;

  select food_row.* into v_submission
  from public.bil_community_food_submissions food_row
  where food_row.id = submission_id
  for update;
  if not found then
    raise exception 'food_submission_not_found';
  end if;
  if v_submission.contributor_id = v_actor then
    raise exception 'moderator_cannot_review_own_food' using errcode = '42501';
  end if;

  if v_submission.status = v_decision then
    return;
  end if;
  if v_submission.status not in ('pending', 'needs_changes') then
    raise exception 'food_submission_already_finalized';
  end if;

  update public.bil_community_food_submissions food_row
  set status = v_decision,
      reviewed_at = pg_catalog.now(),
      updated_at = pg_catalog.now()
  where food_row.id = v_submission.id;

  insert into public.bil_community_audit_events(
    actor_id, event_kind, target_kind, target_id, metadata
  ) values (
    v_actor,
    'FOOD_REVIEW',
    'community_food_submission',
    v_submission.id::text,
    pg_catalog.jsonb_build_object(
      'decision', v_decision,
      'previous_status', v_submission.status
    )
  );
end
$function$;

CREATE OR REPLACE FUNCTION public.bil_list_open_community_reports()
 RETURNS SETOF bil_community_reports
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;

  return query
  select report_row.*
  from public.bil_community_reports report_row
  where report_row.status in ('open', 'reviewing')
    and not (
      (report_row.target_kind = 'post' and exists (
        select 1 from public.bil_community_posts post_row
        where post_row.id = report_row.target_id and post_row.author_id = v_actor
      ))
      or (report_row.target_kind = 'message' and exists (
        select 1 from public.bil_messages message_row
        where message_row.id = report_row.target_id and message_row.sender_id = v_actor
      ))
      or (report_row.target_kind = 'food' and exists (
        select 1 from public.bil_community_food_submissions food_row
        where food_row.id = report_row.target_id and food_row.contributor_id = v_actor
      ))
      or (report_row.target_kind = 'profile' and report_row.target_id = v_actor)
    )
  order by report_row.created_at asc
  limit 200;
end
$function$;

CREATE OR REPLACE FUNCTION public.bil_list_pending_community_posts(p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, author_id uuid, body text, visibility text, created_at timestamp with time zone, media_object_path text, media_mime_type text, media_bytes integer, media_width integer, media_height integer, moderation_status text, reviewed_at timestamp with time zone, author_name text, author_avatar_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;

  return query
  select
    post_row.id,
    post_row.author_id,
    post_row.body,
    post_row.visibility,
    post_row.created_at,
    post_row.media_object_path,
    post_row.media_mime_type,
    post_row.media_bytes,
    post_row.media_width,
    post_row.media_height,
    post_row.moderation_status,
    post_row.reviewed_at,
    profile.display_name,
    profile.avatar_url
  from public.bil_community_posts post_row
  left join public.bil_public_profiles profile
    on profile.user_id = post_row.author_id
  where post_row.moderation_status = 'pending'
    and post_row.deleted_at is null
    and post_row.author_id <> v_actor
  order by post_row.created_at asc
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
end
$function$;

CREATE OR REPLACE FUNCTION public.bil_list_reviewable_products()
 RETURNS SETOF bil_community_food_submissions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_actor) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;

  return query
  select food_row.*
  from public.bil_community_food_submissions food_row
  where food_row.status in ('pending', 'needs_changes')
    and food_row.contributor_id <> v_actor
  order by food_row.created_at desc
  limit 40;
end
$function$;

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
$function$;

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
$function$;
