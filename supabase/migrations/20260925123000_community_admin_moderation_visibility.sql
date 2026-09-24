begin;

alter table public.bil_community_posts
  add column if not exists moderation_visibility text not null default 'visible';

alter table public.bil_community_posts
  drop constraint if exists bil_community_posts_moderation_visibility_check;
alter table public.bil_community_posts
  add constraint bil_community_posts_moderation_visibility_check
  check (moderation_visibility in (
    'visible', 'hidden_by_moderator', 'removed_by_moderator'
  ));

create or replace function private.bil_resolve_community_moderation_authority(
  p_actor uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function private.bil_resolve_community_moderation_authority(uuid)
from public, anon, authenticated, service_role;

create or replace function public.bil_is_community_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.bil_resolve_community_moderation_authority(
    (select auth.uid())
  ) is not null
$$;

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
$$;

drop policy if exists bil_posts_read on public.bil_community_posts;
create policy bil_posts_read on public.bil_community_posts
for select to authenticated
using (
  deleted_at is null
  and moderation_visibility = 'visible'
  and (
    author_id = (select auth.uid())
    or (
      moderation_status = 'approved'
      and not exists (
        select 1 from public.bil_blocks b
        where (b.blocker_id = (select auth.uid()) and b.blocked_id = author_id)
           or (b.blocker_id = author_id and b.blocked_id = (select auth.uid()))
      )
      and (
        visibility = 'community'
        or exists (
          select 1 from public.bil_friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = author_id and f.addressee_id = (select auth.uid()))
              or
              (f.addressee_id = author_id and f.requester_id = (select auth.uid()))
            )
        )
      )
    )
  )
);

create or replace function public.bil_social_post_visible_v2(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists(
    select 1 from public.bil_community_posts p
    where p.id = p_post
      and p.deleted_at is null
      and p.moderation_status = 'approved'
      and p.moderation_visibility = 'visible'
      and public.bil_social_member_visible_v2(p.author_id)
      and not exists(
        select 1 from private.bil_community_member_access a
        where a.user_id = auth.uid() and a.suspended
      )
      and (
        p.visibility = 'community'
        or p.author_id = auth.uid()
        or exists(
          select 1 from public.bil_friendships f
          where f.status = 'accepted'
            and (
              (f.requester_id = auth.uid() and f.addressee_id = p.author_id)
              or
              (f.addressee_id = auth.uid() and f.requester_id = p.author_id)
            )
        )
      )
  )
$$;

create or replace function public.bil_moderate_published_community_post(
  p_post_id uuid,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

create or replace function public.bil_remove_published_community_post(
  p_post_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.bil_moderate_published_community_post(
    p_post_id, 'remove', p_reason
  );
end
$$;

create or replace function public.bil_list_hidden_community_posts(
  p_limit integer default 100
)
returns table (
  id uuid, author_id uuid, body text, created_at timestamptz,
  media_object_path text, media_mime_type text, media_bytes integer,
  media_width integer, media_height integer, moderation_status text,
  moderation_visibility text, reviewed_at timestamptz,
  author_name text, author_avatar_url text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if private.bil_resolve_community_moderation_authority(
    (select auth.uid())
  ) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if p_limit not between 1 and 100 then
    raise exception 'invalid_limit' using errcode = '22023';
  end if;

  return query
  select p.id, p.author_id, p.body, p.created_at,
    p.media_object_path, p.media_mime_type, p.media_bytes,
    p.media_width, p.media_height, p.moderation_status,
    p.moderation_visibility, p.reviewed_at,
    profile.display_name, profile.avatar_url
  from public.bil_community_posts p
  left join public.bil_public_profiles profile on profile.user_id = p.author_id
  where p.moderation_status = 'approved'
    and p.moderation_visibility = 'hidden_by_moderator'
    and p.deleted_at is null
  order by p.created_at desc, p.id desc
  limit p_limit;
end
$$;

revoke all on function public.bil_moderate_published_community_post(uuid, text, text),
  public.bil_remove_published_community_post(uuid, text),
  public.bil_list_hidden_community_posts(integer)
from public, anon, authenticated, service_role;
grant execute on function public.bil_moderate_published_community_post(uuid, text, text),
  public.bil_remove_published_community_post(uuid, text),
  public.bil_list_hidden_community_posts(integer)
to authenticated;

commit;
