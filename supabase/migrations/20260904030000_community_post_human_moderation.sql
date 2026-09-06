-- Human review boundary for Community posts.
-- Existing posts stay published; every post created after this migration starts
-- pending and is visible only to its author until a moderator approves it.
begin;

-- Fail the whole transaction before pending-by-default moderation is enabled
-- unless the designated operational administrator is an existing, unique auth
-- account. The UUID is resolved at deploy time and is never hard-coded.
do $moderator_preflight$
declare
  v_admin_id uuid;
  v_matching_accounts integer;
begin
  select pg_catalog.count(*)::integer
    into v_matching_accounts
  from auth.users account
  where pg_catalog.lower(account.email) =
    pg_catalog.lower('kademcom@yahoo.com');

  if v_matching_accounts <> 1 then
    raise exception 'community_moderation_preflight_failed'
      using detail =
        'The designated administrator account must exist exactly once before pending moderation is enabled.';
  end if;

  select account.id
    into v_admin_id
  from auth.users account
  where pg_catalog.lower(account.email) =
    pg_catalog.lower('kademcom@yahoo.com')
  limit 1;

  insert into public.bil_community_moderators(user_id)
  values (v_admin_id)
  on conflict (user_id) do nothing;

  -- The operational owner is resolved from auth.users at deploy time. This
  -- is an administrative capability grant, not a fabricated store purchase.
  insert into private.bil_ai_coach_admins(
    user_id, active, granted_by, reason
  ) values (
    v_admin_id, true, v_admin_id, 'designated_operational_owner'
  )
  on conflict (user_id) do update set
    active = true,
    granted_by = excluded.granted_by,
    reason = excluded.reason;

  -- Full product access is a separate, time-bounded closed-test entitlement;
  -- being an administrator never implies a purchase or bypasses AI metering.
  insert into public.bil_ai_closed_test_grants(
    owner_id, cohort, active, expires_at, reason
  ) values (
    v_admin_id,
    'operational-admin',
    true,
    pg_catalog.now() + interval '18 months',
    'Time-bounded operational administrator access.'
  )
  on conflict (owner_id) do update set
    cohort = excluded.cohort,
    active = true,
    expires_at = greatest(
      public.bil_ai_closed_test_grants.expires_at,
      excluded.expires_at
    ),
    reason = excluded.reason,
    updated_at = pg_catalog.now();

  if not exists (
    select 1
    from public.bil_community_moderators moderator
    where moderator.user_id = v_admin_id
  ) then
    raise exception 'community_moderation_preflight_failed'
      using detail = 'The designated administrator could not be enrolled as a moderator.';
  end if;

  if not exists (
    select 1
    from private.bil_ai_coach_admins administrator
    where administrator.user_id = v_admin_id
      and administrator.active
  ) then
    raise exception 'community_moderation_preflight_failed'
      using detail = 'The designated administrator could not be enrolled as an active administrator.';
  end if;

  if not exists (
    select 1
    from public.bil_ai_closed_test_grants grant_row
    where grant_row.owner_id = v_admin_id
      and grant_row.active
      and grant_row.expires_at > pg_catalog.now()
  ) then
    raise exception 'community_moderation_preflight_failed'
      using detail = 'The designated administrator did not receive a separate active closed-test entitlement.';
  end if;
end
$moderator_preflight$;

do $moderator_population_preflight$
begin
  if not exists (select 1 from public.bil_community_moderators) then
    raise exception 'community_moderation_preflight_failed'
      using detail = 'At least one human moderator is required.';
  end if;
end
$moderator_population_preflight$;

-- Membership changes must pass through the administrator RPCs below. Even
-- the service role receives no direct table mutation grant.
revoke all on table public.bil_community_moderators
from public, anon, authenticated, service_role;

alter table public.bil_community_posts
  add column if not exists moderation_status text,
  add column if not exists reviewed_at timestamptz;

-- Preserve the visibility of content that was already published before the
-- review workflow existed. The default is changed only after this backfill.
update public.bil_community_posts
set moderation_status = 'approved'
where moderation_status is null;

alter table public.bil_community_posts
  alter column moderation_status set default 'pending',
  alter column moderation_status set not null;

alter table public.bil_community_posts
  drop constraint if exists bil_community_posts_moderation_status_check,
  drop constraint if exists bil_community_posts_review_pair_check,
  drop constraint if exists bil_community_posts_review_state_check;
alter table public.bil_community_posts
  add constraint bil_community_posts_moderation_status_check
    check (moderation_status in ('pending', 'approved', 'rejected')),
  add constraint bil_community_posts_review_state_check check (
    (moderation_status = 'pending'
      and reviewed_at is null)
    or
    (moderation_status = 'rejected'
      and reviewed_at is not null)
    or
    moderation_status = 'approved'
  );

create index if not exists bil_community_posts_pending_review_idx
on public.bil_community_posts (created_at asc)
where moderation_status = 'pending' and deleted_at is null;

create index if not exists bil_community_posts_media_path_idx
on public.bil_community_posts (media_object_path)
where media_object_path is not null;

-- This durable receipt is the idempotency boundary for the five-token reward.
-- It deliberately survives a post hard-delete while the account exists, so a
-- client cannot delete and recreate the same UUID to claim the reward again.
create table if not exists public.bil_community_post_approval_grants (
  post_id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  approved_by uuid references auth.users(id) on delete set null,
  reward_day date not null default
    (pg_catalog.timezone('UTC', pg_catalog.now())::date),
  tokens integer not null default 5 check (tokens in (0, 5)),
  reward_reason text not null default 'granted'
    check (reward_reason in ('granted', 'daily_cap_reached')),
  granted_at timestamptz not null default now()
);

create index if not exists bil_community_post_approval_grants_owner_day_idx
  on public.bil_community_post_approval_grants(owner_id, reward_day);

-- One auditable policy row controls both the award and its abuse ceiling. The
-- policy is database-owner managed; clients and moderators cannot alter it.
create table if not exists public.bil_community_post_reward_policy (
  singleton boolean primary key default true check (singleton),
  tokens_per_approval integer not null default 5
    check (tokens_per_approval = 5),
  max_rewarded_posts_per_owner_per_utc_day integer not null default 5
    check (max_rewarded_posts_per_owner_per_utc_day between 1 and 100),
  updated_at timestamptz not null default now()
);

insert into public.bil_community_post_reward_policy(singleton)
values (true)
on conflict (singleton) do nothing;

-- This row is locked before each reward decision, serializing concurrent
-- approvals for the same author and UTC day so the cap cannot be raced.
create table if not exists public.bil_community_post_reward_usage (
  owner_id uuid not null references auth.users(id) on delete cascade,
  reward_day date not null,
  rewarded_posts integer not null default 0 check (rewarded_posts >= 0),
  granted_tokens integer not null default 0 check (granted_tokens >= 0),
  updated_at timestamptz not null default now(),
  primary key (owner_id, reward_day),
  check (granted_tokens = rewarded_posts * 5)
);

alter table public.bil_community_post_approval_grants enable row level security;
alter table public.bil_community_post_reward_policy enable row level security;
alter table public.bil_community_post_reward_usage enable row level security;
revoke all on public.bil_community_post_approval_grants
from public, anon, authenticated, service_role;
revoke all on public.bil_community_post_reward_policy
from public, anon, authenticated, service_role;
revoke all on public.bil_community_post_reward_usage
from public, anon, authenticated, service_role;

create or replace function public.bil_has_community_moderators(
  p_excluded_user_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.bil_community_moderators moderator
    where p_excluded_user_id is null
      or moderator.user_id <> p_excluded_user_id
  )
$$;

revoke all on function public.bil_has_community_moderators(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.bil_has_community_moderators(uuid)
to authenticated, service_role;

-- Direct client inserts are always pending. Direct client updates cannot forge
-- moderator-owned fields; the SECURITY DEFINER decision RPC runs as its owner.
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
  elsif current_user in ('anon', 'authenticated') and (
    new.moderation_status is distinct from old.moderation_status
    or new.reviewed_at is distinct from old.reviewed_at
  ) then
    raise exception 'moderation_fields_are_server_managed'
      using errcode = '42501';
  end if;
  return new;
end
$$;

revoke all on function public.bil_guard_community_post_moderation()
from public, anon, authenticated, service_role;

drop trigger if exists bil_01_posts_moderation_guard
  on public.bil_community_posts;
create trigger bil_01_posts_moderation_guard
before insert or update of moderation_status, reviewed_at
on public.bil_community_posts
for each row execute function public.bil_guard_community_post_moderation();

-- The author can always see their own non-deleted post and its review status.
-- Everyone else inherits the existing block/friend/visibility rules, but only
-- after an explicit human approval.
drop policy if exists bil_posts_read on public.bil_community_posts;
create policy bil_posts_read
on public.bil_community_posts
for select
to authenticated
using (
  deleted_at is null
  and (
    author_id = (select auth.uid())
    or (
      moderation_status = 'approved'
      and not exists (
        select 1
        from public.bil_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = author_id)
           or (b.blocker_id = author_id and b.blocked_id = (select auth.uid()))
      )
      and (
        visibility = 'community'
        or exists (
          select 1
          from public.bil_friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = author_id
                and f.addressee_id = (select auth.uid()))
              or
              (f.addressee_id = author_id
                and f.requester_id = (select auth.uid()))
            )
        )
      )
    )
  )
);

drop policy if exists bil_posts_insert_own on public.bil_community_posts;
create policy bil_posts_insert_own
on public.bil_community_posts
for insert
to authenticated
with check (
  author_id = (select auth.uid())
  and moderation_status = 'pending'
  and reviewed_at is null
);

create or replace function public.bil_is_community_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1
    from public.bil_community_moderators m
    where m.user_id = (select auth.uid())
  )
$$;

-- Administration of the human-review roster is an explicit, integrity-gated
-- Edge workflow. Clients cannot call these service-only RPCs or mutate the
-- underlying table directly.
create table if not exists private.bil_community_moderator_admin_audit (
  id bigint generated always as identity primary key,
  idempotency_key text not null unique
    check (pg_catalog.char_length(idempotency_key) between 16 and 128),
  actor_id uuid references auth.users(id) on delete set null,
  target_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('add', 'remove')),
  request_digest text not null check (request_digest ~ '^[0-9a-f]{64}$'),
  result jsonb not null,
  occurred_at timestamptz not null default pg_catalog.now()
);

alter table private.bil_community_moderator_admin_audit
  enable row level security;
revoke all on table private.bil_community_moderator_admin_audit
from public, anon, authenticated, service_role;

create or replace function public.bil_list_community_moderators_for_admin(
  p_actor_id uuid
)
returns table (
  user_id uuid,
  email text,
  created_at timestamptz,
  protected_administrator boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
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

  return query
  select
    moderator.user_id,
    pg_catalog.lower(account.email)::text,
    moderator.created_at,
    coalesce(administrator.active, false)
  from public.bil_community_moderators moderator
  join auth.users account on account.id = moderator.user_id
  left join private.bil_ai_coach_admins administrator
    on administrator.user_id = moderator.user_id
  order by pg_catalog.lower(account.email), moderator.user_id;
end
$$;

create or replace function public.bil_add_community_moderator_by_email(
  p_actor_id uuid,
  p_email text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

create or replace function public.bil_remove_community_moderator(
  p_actor_id uuid,
  p_user_id uuid,
  p_idempotency_key text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.bil_list_community_moderators_for_admin(uuid),
  public.bil_add_community_moderator_by_email(uuid, text, text),
  public.bil_remove_community_moderator(uuid, uuid, text)
from public, anon, authenticated, service_role;
grant execute on function public.bil_list_community_moderators_for_admin(uuid),
  public.bil_add_community_moderator_by_email(uuid, text, text),
  public.bil_remove_community_moderator(uuid, uuid, text)
to service_role;

create or replace function public.bil_list_pending_community_posts(
  p_limit integer default 100
)
returns table (
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
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.bil_community_moderators m
    where m.user_id = (select auth.uid())
  ) then
    raise exception 'moderator_required' using errcode = '42501';
  end if;

  return query
  select
    p.id,
    p.author_id,
    p.body,
    p.visibility,
    p.created_at,
    p.media_object_path,
    p.media_mime_type,
    p.media_bytes,
    p.media_width,
    p.media_height,
    p.moderation_status,
    p.reviewed_at,
    profile.display_name,
    profile.avatar_url
  from public.bil_community_posts p
  left join public.bil_public_profiles profile on profile.user_id = p.author_id
  where p.moderation_status = 'pending'
    and p.deleted_at is null
  order by p.created_at asc
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
end
$$;

-- Moderators need temporary read/sign access to an attached image while the
-- post is still hidden from the community. Keep that exception path-scoped to
-- a live pending post rather than opening the whole private bucket.
create or replace function public.bil_can_moderate_community_post_image(
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.bil_community_moderators m
      where m.user_id = (select auth.uid())
    )
    and exists (
      select 1
      from public.bil_community_posts p
      where p.media_object_path = p_object_path
        and p.moderation_status = 'pending'
        and p.deleted_at is null
    )
$$;

create or replace function public.bil_moderate_community_post(
  p_post_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  if not exists (
    select 1
    from public.bil_community_moderators m
    where m.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
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
$$;

revoke all on function public.bil_is_community_moderator(),
  public.bil_list_pending_community_posts(integer),
  public.bil_can_moderate_community_post_image(text),
  public.bil_moderate_community_post(uuid, text)
from public, anon, authenticated;
-- The service role also has no direct moderation decision surface; the
-- authenticated human moderator RPC is the only granted path.
revoke all on function public.bil_is_community_moderator(),
  public.bil_list_pending_community_posts(integer),
  public.bil_can_moderate_community_post_image(text),
  public.bil_moderate_community_post(uuid, text)
from service_role;
grant execute on function public.bil_is_community_moderator(),
  public.bil_list_pending_community_posts(integer),
  public.bil_can_moderate_community_post_image(text),
  public.bil_moderate_community_post(uuid, text)
to authenticated;

drop policy if exists community_post_image_read_visible on storage.objects;
create policy community_post_image_read_visible
on storage.objects
for select
to authenticated
using (
  bucket_id = 'community-post-images'
  and storage.allow_any_operation(array[
    'storage.object.sign',
    'storage.object.sign_many',
    'storage.object.get_authenticated',
    'object.get_authenticated_info',
    'storage.render.image_authenticated'
  ])
  and (
    owner_id = (select auth.uid()::text)
    or public.bil_can_moderate_community_post_image(name)
    or exists (
      select 1
      from public.bil_community_posts post
      where post.media_object_path = storage.objects.name
    )
  )
);

-- Reuse the existing service-only push outbox. No post/report body, reason,
-- profile, or health information is copied into a notification row.
create or replace function public.bil_enqueue_community_moderator_attention()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_body text;
  v_source_key text;
begin
  v_body := case tg_table_name
    when 'bil_community_posts'
      then 'A new community post is waiting for human review.'
    when 'bil_community_reports'
      then 'A new community report is waiting for review.'
    else null
  end;
  v_source_key := case tg_table_name
    when 'bil_community_posts'
      then 'community_post_review:' || new.id::text
    when 'bil_community_reports'
      then 'community_report_review:' || new.id::text
    else null
  end;

  if v_body is null or v_source_key is null then
    return new;
  end if;

  insert into public.bil_push_outbox(
    recipient_id,
    category,
    body,
    deep_link,
    source_key
  )
  select
    moderator.user_id,
    'community',
    v_body,
    'bil://community/moderation',
    v_source_key
  from public.bil_community_moderators moderator
  on conflict do nothing;

  return new;
end
$$;

revoke all on function public.bil_enqueue_community_moderator_attention()
from public, anon, authenticated, service_role;

drop trigger if exists bil_post_moderator_attention
  on public.bil_community_posts;
create trigger bil_post_moderator_attention
after insert on public.bil_community_posts
for each row execute function public.bil_enqueue_community_moderator_attention();

drop trigger if exists bil_report_moderator_attention
  on public.bil_community_reports;
create trigger bil_report_moderator_attention
after insert on public.bil_community_reports
for each row execute function public.bil_enqueue_community_moderator_attention();

commit;
