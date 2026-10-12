CREATE OR REPLACE FUNCTION public.bil_has_community_moderators(p_excluded_user_id uuid DEFAULT NULL::uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$
