CREATE OR REPLACE FUNCTION private.bil_resolve_community_moderation_authority(p_actor uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION private.bil_lock_community_authority_v1()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode='42501';
  end if;
  perform 1 from private.bil_ai_coach_admins a
    where a.user_id=v_actor and a.active for share;
  if found then return 'admin'; end if;
  perform 1 from public.bil_community_moderators m where m.user_id=v_actor for share;
  if found then return 'moderator'; end if;
  raise exception 'moderator_or_administrator_required' using errcode='42501';
end $function$;
