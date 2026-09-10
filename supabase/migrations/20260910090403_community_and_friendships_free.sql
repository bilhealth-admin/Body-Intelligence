begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Community and friendships are Free account features. Remove only the old
-- commerce gate; ownership, suspension, privacy, moderation, rate limits and
-- every existing relationship remain under their existing server contracts.
do $free_friendships_preflight$
begin
  if not exists (
    select 1 from pg_catalog.pg_class
    where oid = pg_catalog.to_regclass('public.bil_friendships')
      and relrowsecurity
  ) then
    raise exception 'free_friendships_rls_required';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_trigger
    where tgrelid = 'public.bil_friendships'::regclass
      and tgname = 'bil_000_friendships_write_contract'
      and tgfoid = pg_catalog.to_regprocedure(
        'public.bil_enforce_friendship_write_contract()'
      )
      and not tgisinternal and tgenabled = 'O'
  ) or not exists (
    select 1 from pg_catalog.pg_trigger
    where tgrelid = 'public.bil_friendships'::regclass
      and tgname = 'bil_00_friendships_member_access'
      and tgfoid = pg_catalog.to_regprocedure(
        'public.bil_guard_community_member_access()'
      )
      and not tgisinternal and tgenabled = 'O'
  ) then
    raise exception 'free_friendships_safety_guards_required';
  end if;

  if pg_catalog.to_regprocedure('public.bil_request_friendship(uuid)') is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_request_friend_v2(uuid)'
     ) is null then
    raise exception 'free_friendships_rpcs_required';
  end if;
  if pg_catalog.has_function_privilege(
       'anon', 'public.bil_request_friendship(uuid)', 'EXECUTE'
     ) or pg_catalog.has_function_privilege(
       'anon', 'public.bil_social_request_friend_v2(uuid)', 'EXECUTE'
     ) or not pg_catalog.has_function_privilege(
       'authenticated', 'public.bil_request_friendship(uuid)', 'EXECUTE'
     ) or not pg_catalog.has_function_privilege(
       'authenticated', 'public.bil_social_request_friend_v2(uuid)', 'EXECUTE'
     ) then
    raise exception 'free_friendships_rpc_acl_drift';
  end if;
end
$free_friendships_preflight$;

drop trigger if exists bil_friendships_require_premium
on public.bil_friendships;
drop function if exists public.bil_require_premium_friendship();

-- Do not change bil_has_active_premium: purchases and all remaining paid
-- features must continue to use real entitlements, not Community membership.
commit;
