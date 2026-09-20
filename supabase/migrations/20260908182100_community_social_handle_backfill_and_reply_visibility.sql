begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if pg_catalog.to_regclass('public.bil_public_profiles') is null
     or pg_catalog.to_regclass('public.bil_social_handles_v2') is null
     or pg_catalog.to_regclass('public.bil_social_comments_v2') is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_comments_v2(uuid,timestamp with time zone,uuid,integer)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_stats_v2(uuid[])'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_like_comment_v2(uuid,boolean)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_report_comment_v2(uuid,text)'
     ) is null then
    raise exception 'community_social_integrity_dependencies_missing';
  end if;

  if pg_catalog.to_regprocedure(
       'private.bil_social_create_handle_for_profile_v2()'
     ) is not null then
    raise exception 'community_social_handle_trigger_function_already_exists';
  end if;
end;
$preflight$;

create function private.bil_social_create_handle_for_profile_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_attempt integer;
begin
  if exists (
    select 1
    from public.bil_social_handles_v2 as social_handle
    where social_handle.user_id = new.user_id
  ) then
    return new;
  end if;

  for v_attempt in 1..10 loop
    begin
      insert into public.bil_social_handles_v2(user_id, handle, chosen)
      values (
        new.user_id,
        'member_' || pg_catalog.left(
          pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''),
          16
        ),
        false
      )
      on conflict (user_id) do nothing;

      if exists (
        select 1
        from public.bil_social_handles_v2 as social_handle
        where social_handle.user_id = new.user_id
      ) then
        return new;
      end if;
    exception
      when unique_violation then
        -- An opaque random handle collided; retry without exposing internals.
        null;
    end;
  end loop;

  raise exception 'community_handle_generation_failed';
end;
$function$;

revoke all on function private.bil_social_create_handle_for_profile_v2()
  from public, anon, authenticated, service_role;

create trigger bil_social_profile_handle_v2
after insert on public.bil_public_profiles
for each row
execute function private.bil_social_create_handle_for_profile_v2();

-- Backfill only missing generated identities. Existing chosen/generated handles
-- are immutable here, and no policy acceptance or entitlement row is touched.
do $backfill$
declare
  v_profile record;
  v_attempt integer;
begin
  for v_profile in
    select profile.user_id
    from public.bil_public_profiles as profile
    left join public.bil_social_handles_v2 as social_handle
      on social_handle.user_id = profile.user_id
    where social_handle.user_id is null
    order by profile.user_id
  loop
    for v_attempt in 1..10 loop
      begin
        insert into public.bil_social_handles_v2(user_id, handle, chosen)
        values (
          v_profile.user_id,
          'member_' || pg_catalog.left(
            pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''),
            16
          ),
          false
        )
        on conflict (user_id) do nothing;

        if exists (
          select 1
          from public.bil_social_handles_v2 as social_handle
          where social_handle.user_id = v_profile.user_id
        ) then
          exit;
        end if;
      exception
        when unique_violation then null;
      end;
    end loop;

    if not exists (
      select 1
      from public.bil_social_handles_v2 as social_handle
      where social_handle.user_id = v_profile.user_id
    ) then
      raise exception 'community_handle_backfill_failed';
    end if;
  end loop;
end;
$backfill$;

create or replace function public.bil_social_stats_v2(p_post_ids uuid[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if coalesce(cardinality(p_post_ids), 0) > 100 then
    raise exception 'too_many_posts' using errcode = '22023';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'post_id', post.id,
        'like_count', (
          select count(*)
          from public.bil_social_post_likes_v2 as post_like
          where post_like.post_id = post.id
        ),
        'liked', exists (
          select 1
          from public.bil_social_post_likes_v2 as post_like
          where post_like.post_id = post.id
            and post_like.user_id = auth.uid()
        ),
        'comment_count', (
          select count(*)
          from public.bil_social_comments_v2 as comment
          where comment.post_id = post.id
            and comment.deleted_at is null
            and comment.removed_at is null
            and public.bil_social_member_visible_v2(comment.author_id)
            and (
              comment.parent_id is null
              or exists (
                select 1
                from public.bil_social_comments_v2 as root
                where root.id = comment.parent_id
                  and root.post_id = comment.post_id
                  and root.parent_id is null
                  and root.deleted_at is null
                  and root.removed_at is null
                  and public.bil_social_member_visible_v2(root.author_id)
              )
            )
        )
      )
      order by post.id
    )
    from public.bil_community_posts as post
    where post.id = any(p_post_ids)
      and public.bil_social_post_visible_v2(post.id)
  ), '[]'::jsonb);
end;
$function$;

create or replace function public.bil_social_comments_v2(
  p_post_id uuid,
  p_after timestamp with time zone default null,
  p_after_id uuid default null,
  p_limit integer default 30
)
returns table (
  id uuid,
  author_id uuid,
  parent_id uuid,
  body text,
  created_at timestamp with time zone,
  author_name text,
  avatar_url text,
  handle text,
  like_count bigint,
  liked boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not public.bil_social_post_visible_v2(p_post_id) then
    raise exception 'post_unavailable' using errcode = '42501';
  end if;
  if (p_after is null) <> (p_after_id is null) then
    raise exception 'invalid_cursor' using errcode = '22023';
  end if;

  return query
  select
    comment.id,
    comment.author_id,
    comment.parent_id,
    comment.body,
    comment.created_at,
    profile.display_name,
    profile.avatar_url,
    social_handle.handle,
    (
      select count(*)
      from public.bil_social_comment_likes_v2 as comment_like
      where comment_like.comment_id = comment.id
    ),
    exists (
      select 1
      from public.bil_social_comment_likes_v2 as comment_like
      where comment_like.comment_id = comment.id
        and comment_like.user_id = auth.uid()
    )
  from public.bil_social_comments_v2 as comment
  left join public.bil_public_profiles as profile
    on profile.user_id = comment.author_id
    and public.bil_social_profile_visible_v2(profile.user_id)
  left join public.bil_social_handles_v2 as social_handle
    on social_handle.user_id = profile.user_id
  where comment.post_id = p_post_id
    and comment.deleted_at is null
    and comment.removed_at is null
    and public.bil_social_member_visible_v2(comment.author_id)
    and (
      comment.parent_id is null
      or exists (
        select 1
        from public.bil_social_comments_v2 as root
        where root.id = comment.parent_id
          and root.post_id = comment.post_id
          and root.parent_id is null
          and root.deleted_at is null
          and root.removed_at is null
          and public.bil_social_member_visible_v2(root.author_id)
      )
    )
    and (
      p_after is null
      or (comment.created_at, comment.id) > (p_after, p_after_id)
    )
  order by comment.created_at, comment.id
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
end;
$function$;

create or replace function public.bil_social_like_comment_v2(
  p_comment_id uuid,
  p_liked boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not public.bil_can_use_community()
     or not exists (
       select 1
       from public.bil_social_comments_v2 as comment
       where comment.id = p_comment_id
         and comment.deleted_at is null
         and comment.removed_at is null
         and public.bil_social_post_visible_v2(comment.post_id)
         and public.bil_social_member_visible_v2(comment.author_id)
         and (
           comment.parent_id is null
           or exists (
             select 1
             from public.bil_social_comments_v2 as root
             where root.id = comment.parent_id
               and root.post_id = comment.post_id
               and root.parent_id is null
               and root.deleted_at is null
               and root.removed_at is null
               and public.bil_social_member_visible_v2(root.author_id)
           )
         )
     ) then
    raise exception 'comment_unavailable' using errcode = '42501';
  end if;
  if p_liked is null then
    raise exception 'invalid_like' using errcode = '22023';
  end if;

  perform public.bil_consume_rate_limit('community_like_v2', 120, 60);
  if p_liked then
    insert into public.bil_social_comment_likes_v2(comment_id, user_id)
    values (p_comment_id, auth.uid())
    on conflict do nothing;
  else
    delete from public.bil_social_comment_likes_v2
    where comment_id = p_comment_id
      and user_id = auth.uid();
  end if;

  return jsonb_build_object(
    'like_count', (
      select count(*)
      from public.bil_social_comment_likes_v2
      where comment_id = p_comment_id
    ),
    'liked', exists (
      select 1
      from public.bil_social_comment_likes_v2
      where comment_id = p_comment_id
        and user_id = auth.uid()
    )
  );
end;
$function$;

create or replace function public.bil_social_report_comment_v2(
  p_comment_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not public.bil_can_use_community()
     or not exists (
       select 1
       from public.bil_social_comments_v2 as comment
       where comment.id = p_comment_id
         and comment.deleted_at is null
         and comment.removed_at is null
         and public.bil_social_post_visible_v2(comment.post_id)
         and public.bil_social_member_visible_v2(comment.author_id)
         and (
           comment.parent_id is null
           or exists (
             select 1
             from public.bil_social_comments_v2 as root
             where root.id = comment.parent_id
               and root.post_id = comment.post_id
               and root.parent_id is null
               and root.deleted_at is null
               and root.removed_at is null
               and public.bil_social_member_visible_v2(root.author_id)
           )
         )
     ) then
    raise exception 'comment_unavailable' using errcode = '42501';
  end if;
  if p_reason is null
     or char_length(btrim(p_reason)) not between 3 and 500 then
    raise exception 'invalid_report' using errcode = '22023';
  end if;

  perform public.bil_consume_rate_limit(
    'community_comment_report_v2', 20, 3600
  );
  insert into public.bil_social_comment_reports_v2(
    comment_id, reporter_id, reason
  ) values (p_comment_id, auth.uid(), btrim(p_reason))
  on conflict (comment_id, reporter_id) do nothing;
end;
$function$;

revoke all on function
  public.bil_social_stats_v2(uuid[]),
  public.bil_social_comments_v2(
    uuid, timestamp with time zone, uuid, integer
  ),
  public.bil_social_like_comment_v2(uuid, boolean),
  public.bil_social_report_comment_v2(uuid, text)
from public, anon, authenticated, service_role;

grant execute on function
  public.bil_social_stats_v2(uuid[]),
  public.bil_social_comments_v2(
    uuid, timestamp with time zone, uuid, integer
  ),
  public.bil_social_like_comment_v2(uuid, boolean),
  public.bil_social_report_comment_v2(uuid, text)
to authenticated;

do $postconditions$
declare
  v_function regprocedure;
begin
  if exists (
    select 1
    from public.bil_public_profiles as profile
    left join public.bil_social_handles_v2 as social_handle
      on social_handle.user_id = profile.user_id
    where social_handle.user_id is null
  ) then
    raise exception 'community_profile_without_handle';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger as trigger
    where trigger.tgrelid = 'public.bil_public_profiles'::regclass
      and trigger.tgname = 'bil_social_profile_handle_v2'
      and not trigger.tgisinternal
  ) then
    raise exception 'community_social_handle_trigger_missing';
  end if;

  for v_function in
    select signature
    from unnest(array[
      'public.bil_social_stats_v2(uuid[])'::regprocedure,
      'public.bil_social_comments_v2(uuid,timestamp with time zone,uuid,integer)'::regprocedure,
      'public.bil_social_like_comment_v2(uuid,boolean)'::regprocedure,
      'public.bil_social_report_comment_v2(uuid,text)'::regprocedure
    ]) as signature
  loop
    if not pg_catalog.has_function_privilege(
         'authenticated', v_function, 'EXECUTE'
       )
       or pg_catalog.has_function_privilege('anon', v_function, 'EXECUTE')
       or pg_catalog.has_function_privilege(
         'service_role', v_function, 'EXECUTE'
       )
       or not exists (
         select 1
         from pg_catalog.pg_proc as procedure
         cross join lateral pg_catalog.unnest(procedure.proconfig)
           as configuration(setting)
         where procedure.oid = v_function::oid
           and procedure.prosecdef
           and configuration.setting in ('search_path=', 'search_path=""')
       ) then
      raise exception 'community_social_function_contract_invalid';
    end if;
  end loop;
end;
$postconditions$;

commit;
