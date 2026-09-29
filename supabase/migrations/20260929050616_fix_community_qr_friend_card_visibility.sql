-- Applied to body-intelligence-log, migration 20260929050616.
-- Scope: QR friend-card resolution only. No profile settings, RLS policies,
-- friendships, auth providers, or mobile binaries are changed.
-- A current, explicitly shared code can reveal the existing limited card
-- for a discoverable friends-only member who allows friend requests.
-- Private/undiscoverable profiles, blocks, suspensions and rate limits remain enforced.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $migration$
declare
  v_oid oid := 'public.bil_social_resolve_public_code_v2(text)'::regprocedure;
  v_before text;
  v_after text;
  v_acl aclitem[];
  v_owner oid;
  v_config text[];
  v_definer boolean;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('bil_migration:qr_friend_card_visibility', 0)
  );
  select pg_catalog.pg_get_functiondef(p.oid), p.proacl, p.proowner,
         p.proconfig, p.prosecdef
    into v_before, v_acl, v_owner, v_config, v_definer
    from pg_catalog.pg_proc p where p.oid = v_oid;

  if pg_catalog.md5(v_before) = '182c3d571716f548eb35e0232e4c302e' then
    return;
  end if;
  if pg_catalog.md5(v_before) <> '6f4923b07c4e1c0b5ba3f7dee2581f96' then
    raise exception 'QR resolver changed since inspection; refusing to overwrite it';
  end if;
  if pg_catalog.md5(pg_catalog.pg_get_functiondef(
       'public.bil_social_member_visible_v2(uuid)'::regprocedure))
       <> 'bff4a47d46555d2856374ce5b0f97317'
     or pg_catalog.md5(pg_catalog.pg_get_functiondef(
       'public.bil_social_profile_visible_v2(uuid)'::regprocedure))
       <> '5b8631f8adb24ac5107c6190cb9137e7' then
    raise exception 'Community safety dependency changed; re-review required';
  end if;

  v_after := pg_catalog.replace(
    v_before,
    'public.bil_social_profile_visible_v2(profile.user_id)',
    'public.bil_social_member_visible_v2(profile.user_id)'
  );
  if pg_catalog.md5(v_after) <> '182c3d571716f548eb35e0232e4c302e' then
    raise exception 'Unexpected QR resolver patch';
  end if;
  execute v_after;

  if exists (
    select 1 from pg_catalog.pg_proc p
    where p.oid = v_oid and (
      p.proacl is distinct from v_acl
      or p.proowner is distinct from v_owner
      or p.proconfig is distinct from v_config
      or p.prosecdef is distinct from v_definer
      or pg_catalog.md5(pg_catalog.pg_get_functiondef(p.oid))
         <> '182c3d571716f548eb35e0232e4c302e'
    )
  ) then
    raise exception 'QR patch failed function/permission preservation checks';
  end if;
  if not pg_catalog.has_function_privilege('authenticated', v_oid, 'EXECUTE')
     or pg_catalog.has_function_privilege('anon', v_oid, 'EXECUTE') then
    raise exception 'Unexpected QR function execute privileges';
  end if;
end;
$migration$;

notify pgrst, 'reload schema';
