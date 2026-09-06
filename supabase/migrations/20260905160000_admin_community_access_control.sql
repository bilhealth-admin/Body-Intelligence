-- Server-authoritative Community access control for the single protected
-- owner/administrator account already provisioned by the human-moderation
-- migration. Member suspension is intentionally distinct from a member's
-- private block list.
begin;

create table if not exists private.bil_community_member_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  suspended boolean not null default true,
  reason text not null
    check (
      pg_catalog.char_length(reason) between 2 and 160
      and reason !~ '[[:cntrl:]]'
    ),
  suspended_by uuid references auth.users(id) on delete set null,
  suspended_at timestamptz not null default pg_catalog.clock_timestamp(),
  reinstated_by uuid references auth.users(id) on delete set null,
  reinstated_at timestamptz,
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  check (
    (suspended and reinstated_at is null and reinstated_by is null)
    or
    (not suspended and reinstated_at is not null)
  )
);

create table if not exists private.bil_community_member_access_audit (
  id bigint generated always as identity primary key,
  idempotency_key text not null unique
    check (pg_catalog.char_length(idempotency_key) between 16 and 128),
  actor_id uuid references auth.users(id) on delete set null,
  target_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('suspend', 'reinstate')),
  request_digest text not null check (request_digest ~ '^[0-9a-f]{64}$'),
  result jsonb not null,
  occurred_at timestamptz not null default pg_catalog.clock_timestamp()
);

alter table private.bil_community_member_access enable row level security;
alter table private.bil_community_member_access_audit enable row level security;
revoke all on table private.bil_community_member_access,
  private.bil_community_member_access_audit
from public, anon, authenticated, service_role;

-- The product has exactly one owner/administrator. Reconcile any stale
-- server-side grants before adding the uniqueness boundary, while preserving
-- inactive rows for auditability. Store-review accounts and Community
-- moderators therefore cannot accidentally inherit administration rights.
do $single_owner_administrator$
declare
  v_owner_id uuid;
  v_matching_accounts integer;
begin
  select pg_catalog.count(*)::integer
    into v_matching_accounts
  from auth.users account
  where pg_catalog.lower(account.email) =
    pg_catalog.lower('kademcom@yahoo.com');

  if v_matching_accounts <> 1 then
    raise exception 'single_owner_administrator_preflight_failed'
      using detail =
        'The designated owner account must exist exactly once.';
  end if;

  select account.id
    into v_owner_id
  from auth.users account
  where pg_catalog.lower(account.email) =
    pg_catalog.lower('kademcom@yahoo.com')
  limit 1;

  update private.bil_ai_coach_admins administrator
  set active = false
  where administrator.active
    and administrator.user_id <> v_owner_id;

  insert into private.bil_ai_coach_admins(
    user_id, active, granted_by, reason
  ) values (
    v_owner_id, true, v_owner_id, 'designated_operational_owner'
  )
  on conflict (user_id) do update set
    active = true,
    granted_by = excluded.granted_by,
    reason = excluded.reason;

  -- This should be unreachable through the RPCs below, but normalizing a
  -- stale manually-created row prevents the protected owner from being locked
  -- out of the moderation queue when this boundary is installed. Do this
  -- before the roster upsert so rerunning the migration also remains safe
  -- after the moderator-eligibility trigger already exists.
  update private.bil_community_member_access access_row
  set suspended = false,
      reinstated_by = v_owner_id,
      reinstated_at = pg_catalog.clock_timestamp(),
      updated_at = pg_catalog.clock_timestamp()
  where access_row.user_id = v_owner_id
    and access_row.suspended;

  insert into public.bil_community_moderators(user_id)
  values (v_owner_id)
  on conflict (user_id) do nothing;

  if (select pg_catalog.count(*)
      from private.bil_ai_coach_admins administrator
      where administrator.active) <> 1 then
    raise exception 'single_owner_administrator_preflight_failed';
  end if;
end
$single_owner_administrator$;

create unique index if not exists bil_ai_coach_single_active_admin_uidx
on private.bil_ai_coach_admins ((active))
where active;

alter table private.bil_ai_coach_admins enable row level security;
revoke all on table private.bil_ai_coach_admins from service_role;

create or replace function public.bil_can_use_community()
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null then
    return false;
  end if;

  -- Serialize every Community mutation (including the Storage insert policy)
  -- against suspension/reinstatement for this member. This prevents an action
  -- that checked the old state from committing after a suspension commits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_state:' || v_actor_id::text, 0
    )
  );

  return not exists (
    select 1
    from private.bil_community_member_access access_row
    where access_row.user_id = v_actor_id
      and access_row.suspended
  );
end
$$;

revoke all on function public.bil_can_use_community()
from public, anon, authenticated, service_role;
grant execute on function public.bil_can_use_community()
to authenticated;

create or replace function public.bil_guard_community_member_access()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.bil_can_use_community() then
    return new;
  end if;

  -- The mobile delete flow is an owner-scoped soft delete followed by media
  -- reference cleanup. Preserve that privacy action for a suspended member,
  -- but compare every other row field so this exception cannot edit or
  -- republish content.
  if tg_op = 'UPDATE'
     and tg_table_schema = 'public'
     and tg_table_name = 'bil_community_posts' then
    -- Keep OLD/NEW post-field access inside this table-specific branch. The
    -- same function is also attached to tables with different row shapes.
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
  end if;

  raise exception 'community_access_suspended' using errcode = '42501';
end
$$;

revoke all on function public.bil_guard_community_member_access()
from public, anon, authenticated, service_role;

-- An approved post must not be rewritten by its author after human review.
-- The current client exposes deletion, not post editing, so direct client
-- updates are restricted to the exact privacy-preserving soft-delete shape.
-- Trusted moderation RPCs execute under their SECURITY DEFINER owner and keep
-- the existing approved/rejected workflow.
create or replace function public.bil_guard_community_post_moderation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if not public.bil_has_community_moderators(new.author_id) then
      raise exception 'community_moderation_unavailable'
        using errcode = '55000',
              detail = 'No eligible human moderator is currently enrolled.';
    end if;
    new.moderation_status := 'pending';
    new.reviewed_at := null;
    return new;
  end if;

  if current_user in ('anon', 'authenticated') then
    if new.moderation_status is distinct from old.moderation_status
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
$$;

revoke all on function public.bil_guard_community_post_moderation()
from public, anon, authenticated, service_role;

-- A suspended account must never regain review powers through a concurrent
-- or later moderator-roster change. This table trigger protects every trusted
-- writer, including future maintenance RPCs, rather than relying on one Edge
-- handler to remember the check.
create or replace function public.bil_guard_community_moderator_eligibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_member_state:' || new.user_id::text, 0
    )
  );

  if exists (
    select 1
    from private.bil_community_member_access access_row
    where access_row.user_id = new.user_id
      and access_row.suspended
  ) then
    raise exception 'suspended_member_cannot_be_moderator'
      using errcode = '42501';
  end if;
  return new;
end
$$;

revoke all on function public.bil_guard_community_moderator_eligibility()
from public, anon, authenticated, service_role;

drop trigger if exists bil_00_moderator_member_access
  on public.bil_community_moderators;
create trigger bil_00_moderator_member_access
before insert or update of user_id on public.bil_community_moderators
for each row execute function public.bil_guard_community_moderator_eligibility();

-- A suspended account can still sign in, review its data, delete its own
-- content, and manage safety/privacy. It cannot create or alter Community
-- content or relationships until an administrator reinstates it.
drop trigger if exists bil_00_posts_member_access
  on public.bil_community_posts;
create trigger bil_00_posts_member_access
before insert or update on public.bil_community_posts
for each row execute function public.bil_guard_community_member_access();

drop trigger if exists bil_00_messages_member_access
  on public.bil_messages;
create trigger bil_00_messages_member_access
before insert on public.bil_messages
for each row execute function public.bil_guard_community_member_access();

drop trigger if exists bil_00_friendships_member_access
  on public.bil_friendships;
create trigger bil_00_friendships_member_access
before insert or update of status on public.bil_friendships
for each row execute function public.bil_guard_community_member_access();

drop trigger if exists bil_00_follows_member_access
  on public.bil_follows;
create trigger bil_00_follows_member_access
before insert on public.bil_follows
for each row execute function public.bil_guard_community_member_access();

drop trigger if exists bil_00_reports_member_access
  on public.bil_community_reports;
-- Reporting and blocking are safety controls, not publishing activity. Keep
-- them available to a suspended account so it can still protect itself and
-- report abuse while every social/content mutation remains disabled.

drop trigger if exists bil_00_food_submissions_member_access
  on public.bil_community_food_submissions;
create trigger bil_00_food_submissions_member_access
before insert or update on public.bil_community_food_submissions
for each row execute function public.bil_guard_community_member_access();

drop trigger if exists bil_00_food_reviews_member_access
  on public.bil_food_peer_reviews;
create trigger bil_00_food_reviews_member_access
before insert or update on public.bil_food_peer_reviews
for each row execute function public.bil_guard_community_member_access();

-- A post that was still pending when its author was suspended must not become
-- newly public or earn an approval reward. Moderators may still reject it.
create or replace function public.bil_guard_suspended_author_post_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.bil_guard_suspended_author_post_approval()
from public, anon, authenticated, service_role;

drop trigger if exists bil_02_posts_suspended_author_approval
  on public.bil_community_posts;
create trigger bil_02_posts_suspended_author_approval
before update of moderation_status on public.bil_community_posts
for each row execute function public.bil_guard_suspended_author_post_approval();

-- Image upload precedes post insertion in the mobile flow. Carry the same
-- server suspension boundary into Storage so a modified client cannot create
-- orphaned Community media while publishing is disabled. Deletion remains
-- available for privacy and cleanup.
drop policy if exists community_post_image_insert_own on storage.objects;
create policy community_post_image_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'community-post-images'
  and public.bil_can_use_community()
  and owner_id = (select auth.uid()::text)
  and (storage.foldername(name))[1] = (select auth.uid()::text)
  and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
  and storage.extension(name) in ('jpg', 'png', 'webp')
);

create or replace function public.bil_list_suspended_community_members_for_admin(
  p_actor_id uuid
)
returns table (
  user_id uuid,
  email text,
  reason text,
  suspended_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if pg_catalog.coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
     or p_actor_id is null
     or not exists (
       select 1
       from private.bil_ai_coach_admins administrator
       where administrator.user_id = p_actor_id
         and administrator.active
     ) then
    raise exception 'administrator_required' using errcode = '42501';
  end if;

  return query
  select
    access_row.user_id,
    pg_catalog.lower(account.email)::text,
    access_row.reason,
    access_row.suspended_at
  from private.bil_community_member_access access_row
  join auth.users account on account.id = access_row.user_id
  where access_row.suspended
  order by access_row.suspended_at desc, access_row.user_id;
end
$$;

create or replace function public.bil_suspend_community_member_by_email(
  p_actor_id uuid,
  p_email text,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  if pg_catalog.coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
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

  select pg_catalog.count(*)::integer,
         pg_catalog.min(account.id::text)::uuid
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
$$;

create or replace function public.bil_reinstate_community_member(
  p_actor_id uuid,
  p_user_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_changed boolean := false;
  v_digest text;
  v_existing_actor uuid;
  v_existing_action text;
  v_existing_digest text;
  v_existing_result jsonb;
  v_result jsonb;
begin
  if pg_catalog.coalesce((select auth.jwt()->>'role'), '') <> 'service_role'
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
$$;

revoke all on function
  public.bil_list_suspended_community_members_for_admin(uuid),
  public.bil_suspend_community_member_by_email(uuid, text, text, text),
  public.bil_reinstate_community_member(uuid, uuid, text)
from public, anon, authenticated, service_role;
grant execute on function
  public.bil_list_suspended_community_members_for_admin(uuid),
  public.bil_suspend_community_member_by_email(uuid, text, text, text),
  public.bil_reinstate_community_member(uuid, uuid, text)
to service_role;

commit;
