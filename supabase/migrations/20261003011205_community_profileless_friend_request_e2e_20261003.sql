-- Allow authenticated Community members to send friend requests even when
-- they have not created a public Community profile yet. Keep the receiver's
-- allow_friend_requests preference, block checks, Community eligibility,
-- rate limiting, self-request protection, and authenticated-only RPC access.
--
-- This aligns the write path with bil_list_community_connections(), which
-- already LEFT JOINs bil_public_profiles so profile-less requesters remain
-- visible to the receiver without exposing private identity data.

set local lock_timeout='5s';
set local statement_timeout='30s';

do $pre$
declare v_def text;
begin
  if pg_catalog.to_regprocedure('public.bil_request_friendship(uuid)') is null then
    raise exception 'friend_request_rpc_missing';
  end if;

  select lower(pg_get_functiondef('public.bil_request_friendship(uuid)'::regprocedure))
    into v_def;

  if strpos(v_def,'community_profile_required')=0
     or strpos(v_def,'bil_consume_rate_limit')=0
     or strpos(v_def,'bil_blocks')=0
     or strpos(v_def,'allow_friend_requests')=0
     or strpos(v_def,'insert into public.bil_friendships')=0 then
    raise exception 'friend_request_rpc_drift';
  end if;
end
$pre$;

create or replace function public.bil_request_friendship(p_addressee_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if p_addressee_id is null or p_addressee_id = v_actor then
    raise exception 'cannot request self';
  end if;

  if not public.bil_can_use_community() then
    raise exception 'relationship unavailable' using errcode = '42501';
  end if;

  perform public.bil_consume_rate_limit('friend_request', 20, 3600);

  if exists (
    select 1
    from public.bil_blocks block_row
    where (block_row.blocker_id = v_actor and block_row.blocked_id = p_addressee_id)
       or (block_row.blocker_id = p_addressee_id and block_row.blocked_id = v_actor)
  ) then
    raise exception 'relationship unavailable';
  end if;

  if not coalesce((
    select profile.allow_friend_requests
    from public.bil_public_profiles profile
    where profile.user_id = p_addressee_id
  ), false) then
    raise exception 'friend requests disabled';
  end if;

  insert into public.bil_friendships(requester_id, addressee_id)
  values (v_actor, p_addressee_id);
end
$function$;

revoke all on function public.bil_request_friendship(uuid)
from public, anon, service_role;

grant execute on function public.bil_request_friendship(uuid)
to authenticated;

do $post$
declare v_def text;
begin
  select lower(pg_get_functiondef('public.bil_request_friendship(uuid)'::regprocedure))
    into v_def;

  if strpos(v_def,'community_profile_required')<>0
     or strpos(v_def,'bil_consume_rate_limit')=0
     or strpos(v_def,'bil_blocks')=0
     or strpos(v_def,'allow_friend_requests')=0
     or strpos(v_def,'insert into public.bil_friendships')=0 then
    raise exception 'friend_request_rpc_postcondition_failed';
  end if;

  if has_function_privilege(
       'anon','public.bil_request_friendship(uuid)','EXECUTE'
     )
     or not has_function_privilege(
       'authenticated','public.bil_request_friendship(uuid)','EXECUTE'
     ) then
    raise exception 'friend_request_rpc_acl_postcondition_failed';
  end if;
end
$post$;

notify pgrst, 'reload schema';
