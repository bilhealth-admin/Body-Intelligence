-- Backend-only Community repairs for the already-submitted Android 22 / iOS 27 clients.
-- Existing RPC names, parameters, return types, owners, and grants are preserved.

create or replace function public.bil_request_friendship(p_addressee_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_addressee_id is null or p_addressee_id = v_actor then
    raise exception 'cannot request self';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'relationship unavailable' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.bil_public_profiles profile
    where profile.user_id = v_actor
      and nullif(pg_catalog.btrim(profile.display_name), '') is not null
  ) then
    raise exception 'community_profile_required' using errcode = '42501';
  end if;

  perform public.bil_consume_rate_limit('friend_request', 20, 3600);

  if exists (
    select 1 from public.bil_blocks block_row
    where (block_row.blocker_id = v_actor and block_row.blocked_id = p_addressee_id)
       or (block_row.blocker_id = p_addressee_id and block_row.blocked_id = v_actor)
  ) then
    raise exception 'relationship unavailable';
  end if;
  if not coalesce((
    select profile.allow_friend_requests
    from public.bil_public_profiles profile
    where profile.user_id = p_addressee_id
  ), false) then
    raise exception 'friend requests disabled';
  end if;

  insert into public.bil_friendships(requester_id, addressee_id)
  values (v_actor, p_addressee_id);
end
$function$;

create or replace function public.bil_list_pending_community_posts(
  p_limit integer default 100
)
returns table(
  id uuid,
  author_id uuid,
  body text,
  visibility text,
  created_at timestamptz,
  media_object_path text,
  media_mime_type text,
  media_bytes integer,
  media_width integer,
  media_height integer,
  moderation_status text,
  reviewed_at timestamptz,
  author_name text,
  author_avatar_url text
)
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.bil_community_moderators moderator
    where moderator.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
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

create or replace function public.bil_list_open_community_reports()
returns setof public.bil_community_reports
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.bil_community_moderators moderator
    where moderator.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
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

create or replace function public.bil_moderate_community_report(
  p_report_id uuid,
  p_resolution text,
  p_action text default 'none'::text
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
  v_report public.bil_community_reports%rowtype;
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.bil_community_moderators moderator
    where moderator.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
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

create or replace function public.bil_list_reviewable_products()
returns setof public.bil_community_food_submissions
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.bil_community_moderators moderator
    where moderator.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
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

create or replace function public.bil_finalize_food_submission(
  submission_id uuid,
  decision text
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
  v_submission public.bil_community_food_submissions%rowtype;
  v_decision text := lower(pg_catalog.btrim(coalesce(decision, '')));
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.bil_community_moderators moderator
    where moderator.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
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

create or replace function private.bil_require_food_community_policy()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  perform private.bil_assert_current_community_policy();
  return new;
end
$function$;

revoke all on function private.bil_require_food_community_policy() from public, anon, authenticated;

drop trigger if exists bil_00_food_submissions_policy_guard
on public.bil_community_food_submissions;
create trigger bil_00_food_submissions_policy_guard
before insert on public.bil_community_food_submissions
for each row execute function private.bil_require_food_community_policy();

create or replace function public.bil_upsert_community_food_contribution(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_submission_id uuid;
  v_client_food_id text := nullif(pg_catalog.btrim(p_payload->>'client_food_id'), '');
  v_name text := nullif(pg_catalog.btrim(p_payload->>'canonical_name'), '');
  v_serving_amount numeric := nullif(p_payload->>'serving_amount', '')::numeric;
  v_serving_unit text := lower(coalesce(nullif(pg_catalog.btrim(p_payload->>'serving_unit'), ''), 'g'));
  v_mask integer := coalesce(nullif(p_payload->>'nutrient_evidence_mask', '')::integer, 0);
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;
  perform private.bil_assert_current_community_policy();
  if not public.bil_can_use_community() then
    raise exception 'community_access_suspended' using errcode = '42501';
  end if;
  if v_client_food_id is null or v_client_food_id !~
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    raise exception 'invalid_client_food_id';
  end if;
  if v_name is null or pg_catalog.char_length(v_name) not between 2 and 180 then
    raise exception 'invalid_food_name';
  end if;
  if v_serving_amount is null or v_serving_amount <= 0 then
    raise exception 'invalid_serving_amount';
  end if;

  insert into public.bil_community_food_submissions (
    contributor_id, client_food_id, canonical_name, localized_names, aliases,
    barcode, serving_grams, serving_amount, serving_unit,
    calories_kcal, protein_g, carbohydrate_g, fat_g, fiber_g, sugar_g,
    sodium_mg, potassium_mg, calcium_mg, magnesium_mg, phosphorus_mg,
    iron_mg, vitamin_c_mg, nutrient_evidence_mask, product_kind,
    submission_source, submission_confidence, status, updated_at, withdrawn_at
  ) values (
    v_user_id,
    v_client_food_id,
    v_name,
    coalesce(p_payload->'localized_names', '{}'::jsonb),
    coalesce(p_payload->'aliases', '[]'::jsonb),
    nullif(pg_catalog.regexp_replace(coalesce(p_payload->>'barcode', ''), '[^0-9]', '', 'g'), ''),
    case when v_serving_unit = 'g' then v_serving_amount else null end,
    v_serving_amount,
    v_serving_unit,
    nullif(p_payload->>'calories_kcal', '')::numeric,
    nullif(p_payload->>'protein_g', '')::numeric,
    nullif(p_payload->>'carbohydrate_g', '')::numeric,
    nullif(p_payload->>'fat_g', '')::numeric,
    nullif(p_payload->>'fiber_g', '')::numeric,
    nullif(p_payload->>'sugar_g', '')::numeric,
    nullif(p_payload->>'sodium_mg', '')::numeric,
    nullif(p_payload->>'potassium_mg', '')::numeric,
    nullif(p_payload->>'calcium_mg', '')::numeric,
    nullif(p_payload->>'magnesium_mg', '')::numeric,
    nullif(p_payload->>'phosphorus_mg', '')::numeric,
    nullif(p_payload->>'iron_mg', '')::numeric,
    nullif(p_payload->>'vitamin_c_mg', '')::numeric,
    v_mask,
    'food', 'user_created_food', 'low', 'pending', pg_catalog.now(), null
  )
  on conflict (contributor_id, client_food_id) where client_food_id is not null
  do update set
    canonical_name = excluded.canonical_name,
    localized_names = excluded.localized_names,
    aliases = excluded.aliases,
    barcode = excluded.barcode,
    serving_grams = excluded.serving_grams,
    serving_amount = excluded.serving_amount,
    serving_unit = excluded.serving_unit,
    calories_kcal = excluded.calories_kcal,
    protein_g = excluded.protein_g,
    carbohydrate_g = excluded.carbohydrate_g,
    fat_g = excluded.fat_g,
    fiber_g = excluded.fiber_g,
    sugar_g = excluded.sugar_g,
    sodium_mg = excluded.sodium_mg,
    potassium_mg = excluded.potassium_mg,
    calcium_mg = excluded.calcium_mg,
    magnesium_mg = excluded.magnesium_mg,
    phosphorus_mg = excluded.phosphorus_mg,
    iron_mg = excluded.iron_mg,
    vitamin_c_mg = excluded.vitamin_c_mg,
    nutrient_evidence_mask = excluded.nutrient_evidence_mask,
    submission_source = excluded.submission_source,
    submission_confidence = 'low',
    status = 'pending',
    reviewed_at = null,
    review_note = null,
    updated_at = pg_catalog.now(),
    withdrawn_at = null
  returning id into v_submission_id;

  return v_submission_id;
end
$function$;

create or replace function public.bil_follow_member(p_followed_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_followed_id is null or p_followed_id = v_actor then
    raise exception 'cannot_follow_self';
  end if;
  if exists (
    select 1 from public.bil_blocks block_row
    where (block_row.blocker_id = v_actor and block_row.blocked_id = p_followed_id)
       or (block_row.blocker_id = p_followed_id and block_row.blocked_id = v_actor)
  ) then
    raise exception 'relationship unavailable' using errcode = '42501';
  end if;

  perform public.bil_consume_rate_limit('follow', 40, 3600);

  if not coalesce((
    select profile.allow_follows from public.bil_public_profiles profile
    where profile.user_id = p_followed_id
  ), false) then
    raise exception 'follows disabled';
  end if;

  insert into public.bil_follows(follower_id, followed_id)
  values (v_actor, p_followed_id)
  on conflict do nothing;
end
$function$;

create or replace function public.bil_block_community_member(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required';
  end if;
  if p_blocked_id is null or p_blocked_id = v_actor then
    raise exception 'cannot_block_self';
  end if;

  insert into public.bil_blocks(blocker_id, blocked_id)
  values (v_actor, p_blocked_id)
  on conflict (blocker_id, blocked_id) do nothing;

  delete from public.bil_friendships friendship
  where (friendship.requester_id = v_actor and friendship.addressee_id = p_blocked_id)
     or (friendship.requester_id = p_blocked_id and friendship.addressee_id = v_actor);

  delete from public.bil_follows follow_row
  where (follow_row.follower_id = v_actor and follow_row.followed_id = p_blocked_id)
     or (follow_row.follower_id = p_blocked_id and follow_row.followed_id = v_actor);
end
$function$;

;
