-- Complete the Social v2 product contract without replacing any existing
-- Community table or function. Saves are private to their owner. BIL public
-- codes are opaque, revocable discovery identifiers; they are never auth
-- tokens, user UUIDs, email addresses, or health data.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_social_post_visible_v2(uuid)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_profile_visible_v2(uuid)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_identity_v2()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_can_use_community()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_consume_rate_limit(text,integer,integer)'
     ) is null
     or pg_catalog.to_regnamespace('private') is null then
    raise exception 'community_social_v2_dependency_missing';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_proc procedure
    where procedure.oid =
      'public.bil_consume_rate_limit(text,integer,integer)'::regprocedure
      and procedure.prosecdef
      and procedure.provolatile = 'v'
      and procedure.prosrc like '%invalid_rate_limit_contract%'
      and exists (
        select 1
        from pg_catalog.unnest(procedure.proconfig) configuration(setting)
        where configuration.setting in ('search_path=', 'search_path=""')
      )
  ) then
    raise exception 'community_social_rate_limit_contract_missing'
      using errcode = '55000';
  end if;

  if pg_catalog.to_regclass('public.bil_social_post_saves_v2') is not null
     or pg_catalog.to_regclass('public.bil_social_public_codes_v2') is not null
     or pg_catalog.to_regprocedure(
       'public.bil_social_save_v2(uuid,boolean)'
     ) is not null
     or pg_catalog.to_regprocedure(
       'public.bil_social_saved_state_v2(uuid[])'
     ) is not null
     or pg_catalog.to_regprocedure(
       'public.bil_social_saved_posts_v2(timestamp with time zone,uuid,integer)'
     ) is not null
     or pg_catalog.to_regprocedure(
       'public.bil_social_public_code_v2()'
     ) is not null
     or pg_catalog.to_regprocedure(
       'public.bil_social_rotate_public_code_v2()'
     ) is not null
     or pg_catalog.to_regprocedure(
       'public.bil_social_resolve_public_code_v2(text)'
     ) is not null
     or pg_catalog.to_regprocedure(
       'private.bil_social_public_code_payload_v2(boolean)'
     ) is not null then
    raise exception 'community_social_saves_or_codes_already_exist';
  end if;
end
$preflight$;

create table public.bil_social_post_saves_v2 (
  user_id uuid not null
    references auth.users(id) on delete cascade,
  post_id uuid not null
    references public.bil_community_posts(id) on delete cascade,
  created_at timestamp with time zone not null default pg_catalog.now(),
  primary key (user_id, post_id)
);

create index bil_social_post_saves_post_v2
on public.bil_social_post_saves_v2 (post_id, user_id);

create index bil_social_post_saves_owner_feed_v2
on public.bil_social_post_saves_v2 (user_id, created_at desc, post_id desc);

create table public.bil_social_public_codes_v2 (
  user_id uuid primary key
    references public.bil_public_profiles(user_id) on delete cascade,
  code text not null unique,
  created_at timestamp with time zone not null default pg_catalog.now(),
  rotated_at timestamp with time zone not null default pg_catalog.now(),
  constraint bil_social_public_codes_format_v2
    check (code ~ '^[a-f0-9]{32}$')
);

alter table public.bil_social_post_saves_v2 enable row level security;
alter table public.bil_social_public_codes_v2 enable row level security;

-- These tables are RPC-only. RLS remains enabled as defense in depth, and no
-- Data API role receives direct table access or a permissive policy.
revoke all on table
  public.bil_social_post_saves_v2,
  public.bil_social_public_codes_v2
from public, anon, authenticated, service_role;

create function public.bil_social_save_v2(
  p_post_id uuid,
  p_saved boolean
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_post_id is null or p_saved is null then
    raise exception 'invalid_save' using errcode = '22023';
  end if;
  if not public.bil_can_use_community()
     or not public.bil_social_post_visible_v2(p_post_id) then
    raise exception 'post_unavailable' using errcode = '42501';
  end if;

  perform public.bil_consume_rate_limit('community_post_save_v2', 120, 60);

  if p_saved then
    insert into public.bil_social_post_saves_v2 (user_id, post_id)
    values (v_actor_id, p_post_id)
    on conflict (user_id, post_id) do nothing;
  else
    delete from public.bil_social_post_saves_v2
    where user_id = v_actor_id
      and post_id = p_post_id;
  end if;

  return pg_catalog.jsonb_build_object(
    'post_id', p_post_id,
    'saved', exists (
      select 1
      from public.bil_social_post_saves_v2 saved_post
      where saved_post.user_id = v_actor_id
        and saved_post.post_id = p_post_id
    )
  );
end
$function$;

create function public.bil_social_saved_state_v2(p_post_ids uuid[])
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode = '42501';
  end if;
  if coalesce(pg_catalog.cardinality(p_post_ids), 0) > 100 then
    raise exception 'too_many_posts' using errcode = '22023';
  end if;

  return coalesce(
    (
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'post_id', requested.post_id,
          'saved', exists (
            select 1
            from public.bil_social_post_saves_v2 saved_post
            where saved_post.user_id = v_actor_id
              and saved_post.post_id = requested.post_id
          )
        )
        order by requested.ordinality
      )
      from pg_catalog.unnest(p_post_ids)
        with ordinality as requested(post_id, ordinality)
      where requested.post_id is not null
        and public.bil_social_post_visible_v2(requested.post_id)
    ),
    '[]'::jsonb
  );
end
$function$;

create function public.bil_social_saved_posts_v2(
  p_before timestamp with time zone default null,
  p_before_id uuid default null,
  p_limit integer default 30
)
returns table(post_id uuid, saved_at timestamp with time zone)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode = '42501';
  end if;
  if (p_before is null) <> (p_before_id is null) then
    raise exception 'invalid_cursor' using errcode = '22023';
  end if;

  return query
  select saved_post.post_id, saved_post.created_at
  from public.bil_social_post_saves_v2 saved_post
  where saved_post.user_id = v_actor_id
    and public.bil_social_post_visible_v2(saved_post.post_id)
    and (
      p_before is null
      or (saved_post.created_at, saved_post.post_id) < (p_before, p_before_id)
    )
  order by saved_post.created_at desc, saved_post.post_id desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end
$function$;

create function private.bil_social_public_code_payload_v2(p_rotate boolean)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $function$
declare
  v_actor_id uuid := (select auth.uid());
  v_code text;
  v_has_code boolean;
  v_attempt integer;
begin
  if v_actor_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.bil_public_profiles profile
    where profile.user_id = v_actor_id
  ) then
    raise exception 'community_profile_required' using errcode = 'P0001';
  end if;

  perform public.bil_social_identity_v2();
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'bil_public_code:' || v_actor_id::text,
      0
    )
  );

  select public_code.code
  into v_code
  from public.bil_social_public_codes_v2 public_code
  where public_code.user_id = v_actor_id
  for update;
  v_has_code := found;

  if not coalesce(p_rotate, false) and v_has_code then
    return pg_catalog.jsonb_build_object(
      'code', v_code,
      'uri', 'bil://community/member/' || v_code,
      'handle', (
        select handle.handle
        from public.bil_social_handles_v2 handle
        where handle.user_id = v_actor_id
      )
    );
  end if;

  if coalesce(p_rotate, false) then
    perform public.bil_consume_rate_limit(
      'community_public_code_rotate_v2',
      5,
      86400
    );
  end if;

  for v_attempt in 1..3 loop
    v_code := pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', '');
    begin
      if v_has_code then
        update public.bil_social_public_codes_v2
        set code = v_code,
            rotated_at = pg_catalog.now()
        where user_id = v_actor_id;
      else
        insert into public.bil_social_public_codes_v2 (user_id, code)
        values (v_actor_id, v_code);
      end if;
      exit;
    exception
      when unique_violation then
        if v_attempt = 3 then
          raise;
        end if;
    end;
  end loop;

  return pg_catalog.jsonb_build_object(
    'code', v_code,
    'uri', 'bil://community/member/' || v_code,
    'handle', (
      select handle.handle
      from public.bil_social_handles_v2 handle
      where handle.user_id = v_actor_id
    )
  );
end
$function$;

create function public.bil_social_public_code_v2()
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $function$
  select private.bil_social_public_code_payload_v2(false)
$function$;

create function public.bil_social_rotate_public_code_v2()
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $function$
  select private.bil_social_public_code_payload_v2(true)
$function$;

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
        and public.bil_social_profile_visible_v2(profile.user_id)
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

revoke all on function
  private.bil_social_public_code_payload_v2(boolean)
from public, anon, authenticated, service_role;

revoke all on function
  public.bil_social_save_v2(uuid, boolean),
  public.bil_social_saved_state_v2(uuid[]),
  public.bil_social_saved_posts_v2(timestamp with time zone, uuid, integer),
  public.bil_social_public_code_v2(),
  public.bil_social_rotate_public_code_v2(),
  public.bil_social_resolve_public_code_v2(text)
from public, anon, authenticated, service_role;

grant execute on function
  public.bil_social_save_v2(uuid, boolean),
  public.bil_social_saved_state_v2(uuid[]),
  public.bil_social_saved_posts_v2(timestamp with time zone, uuid, integer),
  public.bil_social_public_code_v2(),
  public.bil_social_rotate_public_code_v2(),
  public.bil_social_resolve_public_code_v2(text)
to authenticated;

do $postconditions$
declare
  v_relation regclass;
  v_function regprocedure;
begin
  foreach v_relation in array array[
    'public.bil_social_post_saves_v2'::regclass,
    'public.bil_social_public_codes_v2'::regclass
  ] loop
    if not (
      select relation.relrowsecurity
      from pg_catalog.pg_class relation
      where relation.oid = v_relation
    ) then
      raise exception 'community_social_extension_rls_missing';
    end if;

    if pg_catalog.has_table_privilege(
         'anon', v_relation, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN'
       )
       or pg_catalog.has_table_privilege(
         'authenticated', v_relation, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN'
       )
       or pg_catalog.has_table_privilege(
         'service_role', v_relation, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN'
       ) then
      raise exception 'community_social_extension_table_grant_unexpected';
    end if;
  end loop;

  foreach v_function in array array[
    'public.bil_social_save_v2(uuid,boolean)'::regprocedure,
    'public.bil_social_saved_state_v2(uuid[])'::regprocedure,
    'public.bil_social_saved_posts_v2(timestamp with time zone,uuid,integer)'::regprocedure,
    'public.bil_social_public_code_v2()'::regprocedure,
    'public.bil_social_rotate_public_code_v2()'::regprocedure,
    'public.bil_social_resolve_public_code_v2(text)'::regprocedure
  ] loop
    if not (
         select procedure.prosecdef
         from pg_catalog.pg_proc procedure
         where procedure.oid = v_function
       )
       or not exists (
         select 1
         from pg_catalog.pg_proc procedure
         cross join lateral pg_catalog.unnest(procedure.proconfig)
           configuration(setting)
         where procedure.oid = v_function
           and configuration.setting in ('search_path=', 'search_path=""')
       )
       or not pg_catalog.has_function_privilege(
         'authenticated', v_function, 'EXECUTE'
       )
       or pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE')
       or pg_catalog.has_function_privilege('service_role', v_function, 'EXECUTE')
       or exists (
         select 1
         from pg_catalog.pg_proc procedure
         cross join lateral pg_catalog.aclexplode(
           coalesce(
             procedure.proacl,
             pg_catalog.acldefault('f', procedure.proowner)
           )
         ) privilege
         where procedure.oid = v_function
           and privilege.grantee = 0
           and privilege.privilege_type = 'EXECUTE'
       ) then
      raise exception 'community_social_extension_function_acl_invalid';
    end if;
  end loop;

  v_function :=
    'private.bil_social_public_code_payload_v2(boolean)'::regprocedure;
  if (
       select procedure.prosecdef
       from pg_catalog.pg_proc procedure
       where procedure.oid = v_function
     )
     or not exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.unnest(procedure.proconfig)
         configuration(setting)
       where procedure.oid = v_function
         and configuration.setting in ('search_path=', 'search_path=""')
     )
     or pg_catalog.has_function_privilege(
       'anon', v_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated', v_function, 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role', v_function, 'EXECUTE'
     )
     or exists (
       select 1
       from pg_catalog.pg_proc procedure
       cross join lateral pg_catalog.aclexplode(
         coalesce(
           procedure.proacl,
           pg_catalog.acldefault('f', procedure.proowner)
         )
       ) privilege
       where procedure.oid = v_function
         and privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     ) then
    raise exception 'community_social_extension_helper_acl_invalid';
  end if;
end
$postconditions$;

notify pgrst, 'reload schema';

commit;
