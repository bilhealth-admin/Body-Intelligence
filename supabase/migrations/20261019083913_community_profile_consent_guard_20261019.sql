-- Public profile content is UGC. Consent cannot depend on the mobile gate.
-- Keep owner privacy changes and content removal available without renewed
-- participation consent. Existing profiles and acceptance rows are untouched.
begin;

create or replace function private.bil_guard_profile_content_policy_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := (select auth.uid());
  v_content_write boolean;
begin
  -- Trusted server maintenance is not an end-user publication. The Data API
  -- sets role=authenticated/anon; callers cannot obtain these database roles.
  if v_actor is null
     and pg_catalog.current_setting('role', true) in ('none', 'service_role') then
    return new;
  end if;
  if v_actor is null or new.user_id is distinct from v_actor then
    raise exception 'community_profile_owner_required' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' then
    v_content_write := true;
  else
    if new.user_id is distinct from old.user_id then
      raise exception 'community_profile_owner_required' using errcode = '42501';
    end if;
    v_content_write :=
      new.display_name is distinct from old.display_name
      or (new.bio is not null and new.bio is distinct from old.bio)
      or (new.avatar_url is not null and new.avatar_url is distinct from old.avatar_url)
      or (new.cover_object_path is not null and new.cover_object_path is distinct from old.cover_object_path)
      or (new.country_code is not null and new.country_code is distinct from old.country_code)
      or (new.discoverable and not old.discoverable)
      or (new.profile_visibility = 'public' and old.profile_visibility <> 'public')
      or (new.profile_visibility = 'friends' and old.profile_visibility = 'private')
      or (new.allow_friend_requests and not old.allow_friend_requests)
      or (new.allow_follows and not old.allow_follows)
      or (new.allow_messages_from <> 'nobody' and old.allow_messages_from = 'nobody')
      or (new.show_followers and not old.show_followers)
      or (new.show_following and not old.show_following)
      or (new.show_friends and not old.show_friends)
      or (new.show_posts and not old.show_posts)
      or (new.show_membership_tier and not old.show_membership_tier);
  end if;
  if v_content_write then
    if not public.bil_can_use_community() then
      raise exception 'community_access_suspended' using errcode = '42501';
    end if;
    perform private.bil_assert_current_community_policy();
  end if;
  return new;
end;
$function$;

revoke all on function private.bil_guard_profile_content_policy_v1()
from public, anon, authenticated, service_role;

drop trigger if exists bil_01_profiles_policy_guard on public.bil_public_profiles;
create trigger bil_01_profiles_policy_guard
before insert or update on public.bil_public_profiles
for each row execute function private.bil_guard_profile_content_policy_v1();

commit;
