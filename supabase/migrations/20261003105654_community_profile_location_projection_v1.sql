set local lock_timeout='5s';
set local statement_timeout='30s';

drop function if exists public.bil_community_profile_posts_v1(
  uuid,timestamptz,uuid,integer
);

create function public.bil_community_profile_posts_v1(
  p_user_id uuid,
  p_before timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 24
)
returns table(
  id uuid,
  author_id uuid,
  body text,
  created_at timestamptz,
  media_object_path text,
  media_mime_type text,
  media_bytes integer,
  media_width integer,
  media_height integer,
  moderation_status text,
  moderation_visibility text,
  reviewed_at timestamptz,
  location_label text
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_viewer uuid:=(select auth.uid());
  v_show_posts boolean;
begin
  if v_viewer is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_id is null
     or (p_before is null)<>(p_before_id is null)
     or p_limit is null or p_limit<1 or p_limit>60 then
    raise exception 'invalid_profile_post_request' using errcode='22023';
  end if;

  select p.show_posts into v_show_posts
  from public.bil_public_profiles p
  where p.user_id=p_user_id;

  if not found then
    raise exception 'community_profile_not_found' using errcode='P0002';
  end if;

  if p_user_id<>v_viewer then
    if not public.bil_social_profile_visible_v2(p_user_id)
       or not v_show_posts then
      return;
    end if;
  end if;

  return query
  select
    p.id,p.author_id,p.body,p.created_at,
    p.media_object_path,p.media_mime_type,p.media_bytes,
    p.media_width,p.media_height,p.moderation_status,
    p.moderation_visibility,p.reviewed_at,p.location_label
  from public.bil_community_posts p
  where p.author_id=p_user_id
    and p.deleted_at is null
    and (
      p_user_id=v_viewer
      or public.bil_social_post_visible_v2(p.id)
    )
    and (
      p_before is null
      or (p.created_at,p.id)<(p_before,p_before_id)
    )
  order by p.created_at desc,p.id desc
  limit p_limit;
end
$$;

revoke all on function public.bil_community_profile_posts_v1(
  uuid,timestamptz,uuid,integer
) from public,anon,service_role;
grant execute on function public.bil_community_profile_posts_v1(
  uuid,timestamptz,uuid,integer
) to authenticated;

do $$
begin
  if to_regprocedure(
    'public.bil_community_profile_posts_v1(uuid,timestamptz,uuid,integer)'
  ) is null then
    raise exception 'community_profile_location_projection_failed';
  end if;
end
$$;
