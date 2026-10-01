create or replace function public.bil_has_community_moderators(
  p_excluded_user_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_role text := coalesce((select auth.jwt()->>'role'), '');
begin
  if v_role <> 'service_role' then
    if v_actor_id is null
       or p_excluded_user_id is distinct from v_actor_id then
      raise exception 'community_moderator_lookup_scope_denied'
        using errcode = '42501';
    end if;
  end if;

  return exists (
    select 1
    from public.bil_community_moderators moderator
    where p_excluded_user_id is null
       or moderator.user_id <> p_excluded_user_id
  );
end
$function$;

create or replace function public.bil_recipient_allows_community_message(
  p_recipient_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_role text := coalesce((select auth.jwt()->>'role'), '');
begin
  if p_recipient_id is null then
    return false;
  end if;

  if v_role <> 'service_role' then
    if v_actor_id is null then
      return false;
    end if;

    if not exists (
      select 1
      from public.bil_friendships friendship
      where friendship.status = 'accepted'
        and (
          (friendship.requester_id = v_actor_id
           and friendship.addressee_id = p_recipient_id)
          or
          (friendship.addressee_id = v_actor_id
           and friendship.requester_id = p_recipient_id)
        )
    ) then
      return false;
    end if;
  end if;

  return coalesce(
    (
      select profile.allow_messages_from = 'friends'
      from public.bil_public_profiles profile
      where profile.user_id = p_recipient_id
    ),
    true
  );
end
$function$;
