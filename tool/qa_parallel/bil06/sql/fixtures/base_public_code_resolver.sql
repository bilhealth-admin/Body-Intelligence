-- EXACT BASE public-code table and resolver source; resolver receives the documented
-- 20260929050616 string replacement from bil06 BASE (member visibility for QR cards).
-- source blobs e2bd2d47ff170b3a96d72cbe0b8f9bf797eb9568 and cb8f164ac783b68dee7b6935836322e7514f82bf
create table public.bil_social_public_codes_v2 (
  user_id uuid primary key
    references public.bil_public_profiles(user_id) on delete cascade,
  code text not null unique,
  created_at timestamp with time zone not null default pg_catalog.now(),
  rotated_at timestamp with time zone not null default pg_catalog.now(),
  constraint bil_social_public_codes_format_v2
    check (code ~ '^[a-f0-9]{32}$')
);
alter table public.bil_social_public_codes_v2 enable row level security;
revoke all on table public.bil_social_public_codes_v2 from public,anon,authenticated,service_role;
create function public.bil_social_resolve_public_code_v2(p_code text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_code text;
  v_target_id uuid;
  v_handle text;
  v_display_name text;
  v_avatar_url text;
  v_relationship text := 'none';
  v_friendship public.bil_friendships%rowtype;
begin
  if v_actor_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode = '42501';
  end if;

  perform public.bil_consume_rate_limit(
    'community_public_code_resolve_v2',
    60,
    60
  );

  -- Invalid, rotated, undiscoverable, blocked, and suspended targets are
  -- intentionally indistinguishable to avoid an account-enumeration oracle.
  if p_code is null or pg_catalog.octet_length(p_code) <> 32 then
    return null;
  end if;
  v_code := pg_catalog.lower(pg_catalog.btrim(p_code));
  if pg_catalog.char_length(v_code) <> 32
     or v_code !~ '^[a-f0-9]{32}$' then
    return null;
  end if;

  select
    profile.user_id,
    handle.handle,
    profile.display_name,
    profile.avatar_url
  into v_target_id, v_handle, v_display_name, v_avatar_url
  from public.bil_social_public_codes_v2 public_code
  join public.bil_public_profiles profile
    on profile.user_id = public_code.user_id
  join public.bil_social_handles_v2 handle
    on handle.user_id = profile.user_id
  where public_code.code = v_code
    and (
      profile.user_id = v_actor_id
      or (
        profile.discoverable
        and profile.allow_friend_requests
        and profile.profile_visibility <> 'private'
        and public.bil_social_member_visible_v2(profile.user_id)
      )
    );

  if not found then
    return null;
  end if;

  if v_target_id = v_actor_id then
    v_relationship := 'self';
  else
    select friendship.*
    into v_friendship
    from public.bil_friendships friendship
    where (
      friendship.requester_id = v_actor_id
      and friendship.addressee_id = v_target_id
    ) or (
      friendship.requester_id = v_target_id
      and friendship.addressee_id = v_actor_id
    )
    order by friendship.created_at desc
    limit 1;

    if found and v_friendship.status = 'accepted' then
      v_relationship := 'accepted';
    elsif found and v_friendship.status = 'pending' then
      v_relationship := case
        when v_friendship.requester_id = v_actor_id then 'pending'
        else 'incoming'
      end;
    end if;
  end if;

  return pg_catalog.jsonb_build_object(
    'user_id', v_target_id,
    'handle', v_handle,
    'display_name', v_display_name,
    'avatar_url', v_avatar_url,
    'relationship', v_relationship
  );
end
$function$;
revoke all on function public.bil_social_resolve_public_code_v2(text) from public,anon,service_role;
grant execute on function public.bil_social_resolve_public_code_v2(text) to authenticated;
