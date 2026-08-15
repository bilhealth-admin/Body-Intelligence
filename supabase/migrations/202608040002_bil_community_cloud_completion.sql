-- Epic 9: privacy, follows, moderation, deletion and push delivery boundary.
begin;
create extension if not exists pgcrypto;
alter table public.bil_public_profiles
  add column if not exists profile_visibility text not null default 'friends'
    check (profile_visibility in ('public', 'friends', 'private')),
  add column if not exists allow_friend_requests boolean not null default true,
  add column if not exists allow_follows boolean not null default false,
  add column if not exists allow_messages_from text not null default 'friends'
    check (allow_messages_from in ('friends', 'nobody'));

create table if not exists public.bil_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

create table if not exists public.bil_push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_ciphertext text not null,
  token_fingerprint text not null unique,
  platform text not null check (platform in ('fcm', 'apns')),
  timezone text not null default 'UTC',
  enabled boolean not null default true,
  sensitive_preview_allowed boolean not null default false,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.bil_push_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('friend_request', 'message', 'community', 'account')),
  title text not null default 'BIL',
  body text not null default 'You have a new update.',
  deep_link text,
  created_at timestamptz not null default now(),
  dispatched_at timestamptz,
  failure_code text,
  check (length(title) <= 80 and length(body) <= 180),
  check (deep_link is null or deep_link ~ '^bil://(community|settings)(/|$)')
);

create table if not exists public.bil_content_policies (
  version text primary key,
  locale_code text not null default 'en',
  document_url text not null,
  effective_at timestamptz not null,
  active boolean not null default false
);

create table if not exists public.bil_content_policy_acceptances (
  user_id uuid not null references auth.users(id) on delete cascade,
  policy_version text not null references public.bil_content_policies(version),
  accepted_at timestamptz not null default now(),
  primary key (user_id, policy_version)
);

create table if not exists public.bil_account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  status text not null default 'pending' check (status in ('pending', 'processing', 'completed', 'cancelled')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.bil_community_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  event_kind text not null,
  target_kind text,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (not (metadata ?| array['body', 'message', 'health', 'token']))
);

create table if not exists public.bil_rate_limit_buckets (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null,
  hit_count integer not null default 1,
  primary key (user_id, action, window_started_at)
);

alter table public.bil_follows enable row level security;
alter table public.bil_push_device_tokens enable row level security;
alter table public.bil_push_outbox enable row level security;
alter table public.bil_content_policy_acceptances enable row level security;
alter table public.bil_account_deletion_requests enable row level security;
alter table public.bil_community_audit_events enable row level security;
alter table public.bil_rate_limit_buckets enable row level security;
alter table public.bil_content_policies enable row level security;

drop policy if exists bil_content_policies_active_read on public.bil_content_policies;
create policy bil_content_policies_active_read on public.bil_content_policies
for select to authenticated using (active = true);

drop policy if exists bil_follows_read on public.bil_follows;
create policy bil_follows_read on public.bil_follows for select to authenticated
using (follower_id = auth.uid() or followed_id = auth.uid());
drop policy if exists bil_follows_own_write on public.bil_follows;
create policy bil_follows_own_write on public.bil_follows for all to authenticated
using (follower_id = auth.uid()) with check (follower_id = auth.uid());
-- Tokens and delivery queues are service-only. Clients use narrow RPCs which
-- never return a token or notification body.
drop policy if exists bil_policy_acceptance_own on public.bil_content_policy_acceptances;
create policy bil_policy_acceptance_own on public.bil_content_policy_acceptances for all to authenticated
using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists bil_deletion_request_own on public.bil_account_deletion_requests;
create policy bil_deletion_request_own on public.bil_account_deletion_requests for select to authenticated
using (user_id = auth.uid());

create or replace function public.bil_consume_rate_limit(p_action text, p_limit integer, p_window_seconds integer)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid := auth.uid(); v_window timestamptz;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  v_window := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  insert into bil_rate_limit_buckets(user_id, action, window_started_at, hit_count)
  values (v_user, p_action, v_window, 1)
  on conflict (user_id, action, window_started_at)
  do update set hit_count = bil_rate_limit_buckets.hit_count + 1;
  if (select hit_count from bil_rate_limit_buckets where user_id=v_user and action=p_action and window_started_at=v_window) > p_limit then
    raise exception 'rate limit exceeded' using errcode = 'P0001';
  end if;
end $$;

create or replace function public.bil_request_friendship(p_addressee_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform bil_consume_rate_limit('friend_request', 20, 3600);
  if p_addressee_id = auth.uid() then raise exception 'cannot request self'; end if;
  if exists(select 1 from bil_blocks where
    (blocker_id=auth.uid() and blocked_id=p_addressee_id) or
    (blocker_id=p_addressee_id and blocked_id=auth.uid())) then
    raise exception 'relationship unavailable';
  end if;
  if not coalesce((select allow_friend_requests from bil_public_profiles where user_id=p_addressee_id), false) then raise exception 'friend requests disabled'; end if;
  insert into bil_friendships(requester_id, addressee_id) values(auth.uid(), p_addressee_id);
end $$;

create or replace function public.bil_follow_member(p_followed_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform bil_consume_rate_limit('follow', 40, 3600);
  if not coalesce((select allow_follows from bil_public_profiles where user_id=p_followed_id), false) then raise exception 'follows disabled'; end if;
  insert into bil_follows(follower_id, followed_id) values(auth.uid(), p_followed_id) on conflict do nothing;
end $$;

create or replace function public.bil_unfollow_member(p_followed_id uuid)
returns void language sql security definer set search_path = public as $$
  delete from bil_follows where follower_id=auth.uid() and followed_id=p_followed_id
$$;

create or replace function public.bil_delete_message(p_message_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update bil_messages set deleted_by_sender_at=now() where id=p_message_id and sender_id=auth.uid();
  update bil_messages set deleted_by_recipient_at=now() where id=p_message_id and recipient_id=auth.uid();
end $$;

create or replace function public.bil_register_push_token(p_token text, p_platform text, p_timezone text, p_sensitive_preview_allowed boolean default false)
returns void language plpgsql security definer set search_path = public as $$
begin
  if length(p_token) < 20 or p_platform not in ('fcm','apns') then raise exception 'invalid push token'; end if;
  insert into bil_push_device_tokens(user_id, token_ciphertext, token_fingerprint, platform, timezone, sensitive_preview_allowed)
  values(auth.uid(), p_token, encode(digest(p_token, 'sha256'),'hex'), p_platform, p_timezone, false)
  on conflict(token_fingerprint) do update set user_id=auth.uid(), enabled=true, timezone=excluded.timezone, last_seen_at=now(), sensitive_preview_allowed=false;
end $$;

create or replace function public.bil_get_push_preferences()
returns table(enabled boolean, timezone text, sensitive_preview_allowed boolean)
language sql security definer set search_path = public as $$
  select coalesce(bool_or(t.enabled), false), coalesce(max(t.timezone), 'UTC'),
         coalesce(bool_or(t.sensitive_preview_allowed), false)
  from bil_push_device_tokens t where t.user_id=auth.uid()
$$;

create or replace function public.bil_disable_push_tokens()
returns void language sql security definer set search_path = public as $$
  update bil_push_device_tokens set enabled=false where user_id=auth.uid()
$$;

create or replace function public.bil_set_sensitive_push_previews(p_allowed boolean)
returns void language sql security definer set search_path = public as $$
  update bil_push_device_tokens set sensitive_preview_allowed=coalesce(p_allowed,false)
  where user_id=auth.uid()
$$;

create or replace function public.bil_require_community_policy()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists(select 1 from bil_content_policies where active)
     and not exists(
       select 1 from bil_content_policy_acceptances a
       join bil_content_policies p on p.version=a.policy_version and p.active
       where a.user_id=auth.uid()
     ) then raise exception 'content policy acceptance required';
  end if;
  perform bil_consume_rate_limit(
    case when tg_table_name='bil_messages' then 'message' else 'post' end,
    case when tg_table_name='bil_messages' then 60 else 12 end,
    3600
  );
  return new;
end $$;

drop trigger if exists bil_posts_abuse_guard on public.bil_community_posts;
create trigger bil_posts_abuse_guard before insert on public.bil_community_posts
for each row execute function public.bil_require_community_policy();
drop trigger if exists bil_messages_abuse_guard on public.bil_messages;
create trigger bil_messages_abuse_guard before insert on public.bil_messages
for each row execute function public.bil_require_community_policy();

create or replace function public.bil_audit_community_action()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into bil_community_audit_events(actor_id,event_kind,target_kind,target_id)
  values(auth.uid(),tg_op,replace(tg_table_name,'bil_',''),coalesce(new.id::text,old.id::text));
  return coalesce(new,old);
end $$;

drop trigger if exists bil_reports_audit on public.bil_community_reports;
create trigger bil_reports_audit after insert or update on public.bil_community_reports
for each row execute function public.bil_audit_community_action();

create or replace function public.bil_enqueue_private_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'bil_messages' then
    insert into bil_push_outbox(recipient_id, category, body, deep_link)
    values(new.recipient_id, 'message', 'You have a new private message.',
           'bil://community/chat/' || new.sender_id::text);
  elsif tg_table_name = 'bil_friendships' then
    insert into bil_push_outbox(recipient_id, category, body, deep_link)
    values(new.addressee_id, 'friend_request', 'You have a new friend request.',
           'bil://community/connections');
  end if;
  return new;
end $$;

drop trigger if exists bil_message_push_outbox on public.bil_messages;
create trigger bil_message_push_outbox after insert on public.bil_messages
for each row execute function public.bil_enqueue_private_push();
drop trigger if exists bil_friend_request_push_outbox on public.bil_friendships;
create trigger bil_friend_request_push_outbox after insert on public.bil_friendships
for each row execute function public.bil_enqueue_private_push();

create or replace function public.bil_list_open_community_reports()
returns setof public.bil_community_reports
language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from bil_community_moderators where user_id=auth.uid()) then
    raise exception 'moderator_required';
  end if;
  return query select * from bil_community_reports
    where status in ('open','reviewing') order by created_at asc limit 200;
end $$;

create or replace function public.bil_moderate_community_report(
  p_report_id uuid,
  p_resolution text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from bil_community_moderators where user_id=auth.uid()) then
    raise exception 'moderator_required';
  end if;
  if p_resolution not in ('reviewing','closed') then
    raise exception 'invalid_resolution';
  end if;
  update bil_community_reports set status=p_resolution where id=p_report_id;
  if not found then raise exception 'report_not_found'; end if;
end $$;

create or replace function public.bil_request_account_deletion(p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform bil_consume_rate_limit('account_deletion', 3, 86400);
  insert into bil_account_deletion_requests(user_id, reason) values(auth.uid(), left(nullif(trim(p_reason),''),500));
  update bil_push_device_tokens set enabled=false where user_id=auth.uid();
end $$;

revoke all on public.bil_push_outbox, public.bil_community_audit_events, public.bil_rate_limit_buckets from anon, authenticated;
grant execute on function public.bil_request_friendship(uuid), public.bil_follow_member(uuid), public.bil_unfollow_member(uuid), public.bil_delete_message(uuid), public.bil_register_push_token(text,text,text,boolean), public.bil_get_push_preferences(), public.bil_disable_push_tokens(), public.bil_set_sensitive_push_previews(boolean), public.bil_request_account_deletion(text), public.bil_list_open_community_reports(), public.bil_moderate_community_report(uuid,text) to authenticated;

-- Profile visibility is enforced at the database boundary.  A private profile
-- is visible only to its owner; a friends profile is visible to accepted
-- friends; a public profile must also be explicitly discoverable.  This
-- replaces the broader foundation policy.
alter table public.bil_public_profiles
  drop constraint if exists bil_public_profiles_visibility_check;
alter table public.bil_public_profiles
  add constraint bil_public_profiles_visibility_check
  check (profile_visibility in ('public','friends','private'));

drop policy if exists bil_profiles_read on public.bil_public_profiles;
drop policy if exists bil_profiles_privacy_read on public.bil_public_profiles;
create policy bil_profiles_privacy_read on public.bil_public_profiles
for select to authenticated using (
  user_id = auth.uid()
  or (
    profile_visibility = 'public'
    and discoverable = true
    and not exists (
      select 1 from public.bil_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = auth.uid())
    )
  )
  or (
    profile_visibility = 'friends'
    and exists (
      select 1 from public.bil_friendships f
      where f.status = 'accepted'
        and ((f.requester_id = auth.uid() and f.addressee_id = user_id)
          or (f.addressee_id = auth.uid() and f.requester_id = user_id))
    )
  )
);

-- Audit relationship, post and message lifecycle events without ever copying
-- post/message bodies, health values, or device tokens into the audit ledger.
drop trigger if exists bil_posts_audit on public.bil_community_posts;
create trigger bil_posts_audit after insert or update or delete on public.bil_community_posts
for each row execute function public.bil_audit_community_action();
drop trigger if exists bil_messages_audit on public.bil_messages;
create trigger bil_messages_audit after insert or update or delete on public.bil_messages
for each row execute function public.bil_audit_community_action();
drop trigger if exists bil_friendships_audit on public.bil_friendships;
create trigger bil_friendships_audit after insert or update or delete on public.bil_friendships
for each row execute function public.bil_audit_community_action();

-- Moderator actions remain explicit and auditable.  Closing a report can
-- optionally soft-delete a reported post/message; no arbitrary SQL or health
-- data is exposed to moderators.
drop function if exists public.bil_moderate_community_report(uuid,text);
create or replace function public.bil_moderate_community_report(
  p_report_id uuid,
  p_resolution text,
  p_action text default 'none'
) returns void language plpgsql security definer set search_path = public as $$
declare v_report public.bil_community_reports%rowtype;
begin
  if not exists(select 1 from bil_community_moderators where user_id=auth.uid()) then
    raise exception 'moderator_required';
  end if;
  if p_resolution not in ('reviewing','closed')
     or p_action not in ('none','remove_content') then
    raise exception 'invalid_moderation_action';
  end if;
  select * into v_report from bil_community_reports where id=p_report_id for update;
  if not found then raise exception 'report_not_found'; end if;
  if p_action='remove_content' and v_report.target_kind='post' then
    update bil_community_posts set deleted_at=now() where id=v_report.target_id;
  elsif p_action='remove_content' and v_report.target_kind='message' then
    update bil_messages set deleted_by_sender_at=now(), deleted_by_recipient_at=now()
    where id=v_report.target_id;
  end if;
  update bil_community_reports set status=p_resolution where id=p_report_id;
  insert into bil_community_audit_events(actor_id,event_kind,target_kind,target_id,metadata)
  values(auth.uid(),'MODERATE',v_report.target_kind,v_report.target_id,
         jsonb_build_object('report_id',p_report_id,'resolution',p_resolution,'action',p_action));
end $$;

grant execute on function public.bil_moderate_community_report(uuid,text,text) to authenticated;

commit;
