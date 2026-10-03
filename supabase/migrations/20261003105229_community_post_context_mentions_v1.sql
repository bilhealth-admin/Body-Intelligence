set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_social_handles_v2') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null
     or to_regprocedure(
       'private.bil_emit_community_activity_v2(uuid,uuid,text,text,text,text,text,text,jsonb)'
     ) is null
     or to_regprocedure('private.bil_activity_pair_allowed_v1(uuid,uuid)') is null then
    raise exception 'community_post_context_dependencies_missing';
  end if;
  if to_regclass('public.bil_community_post_mentions_v1') is not null then
    raise exception 'community_post_context_v1_already_exists';
  end if;
end
$$;

alter table public.bil_community_posts
  add column if not exists location_label text;

alter table public.bil_community_posts
  drop constraint if exists bil_community_posts_location_label_check;
alter table public.bil_community_posts
  add constraint bil_community_posts_location_label_check
  check (
    location_label is null
    or (
      char_length(location_label) between 1 and 80
      and location_label=btrim(location_label)
      and location_label !~ '[[:cntrl:]]'
    )
  );

create table public.bil_community_post_mentions_v1 (
  post_id uuid not null references public.bil_community_posts(id) on delete cascade,
  mentioned_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(post_id,mentioned_user_id)
);

create index bil_community_post_mentions_user_idx
  on public.bil_community_post_mentions_v1(
    mentioned_user_id,created_at desc,post_id
  );

alter table public.bil_community_post_mentions_v1 enable row level security;
revoke all on table public.bil_community_post_mentions_v1
  from public,anon,authenticated,service_role;

alter table public.bil_community_notifications
  drop constraint if exists bil_community_notifications_kind_check;
alter table public.bil_community_notifications
  add constraint bil_community_notifications_kind_check
  check (
    kind = any(array[
      'friend_request'::text,
      'friend_accepted'::text,
      'post_like'::text,
      'post_save'::text,
      'comment'::text,
      'reply'::text,
      'follow'::text,
      'mention'::text,
      'reward_earned'::text,
      'quest_completed'::text,
      'badge_earned'::text,
      'challenge_update'::text
    ])
  );

create or replace function public.bil_search_community_mentions_v1(
  p_query text,
  p_limit integer default 12
)
returns table(
  user_id uuid,
  handle text,
  display_name text,
  avatar_url text
)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_query text:=lower(ltrim(btrim(p_query),'@'));
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if v_query is null
     or v_query !~ '^[a-z][a-z0-9_]{0,29}$'
     or p_limit is null
     or p_limit<1
     or p_limit>20 then
    return;
  end if;

  perform public.bil_consume_rate_limit(
    'community_mention_search_v1',60,60
  );

  return query
  select
    p.user_id,h.handle,p.display_name,p.avatar_url
  from public.bil_social_handles_v2 h
  join public.bil_public_profiles p on p.user_id=h.user_id
  where h.chosen
    and p.user_id<>v_uid
    and p.discoverable
    and p.profile_visibility<>'private'
    and public.bil_social_member_visible_v2(p.user_id)
    and left(h.handle,char_length(v_query))=v_query
  order by (h.handle=v_query) desc,h.handle
  limit p_limit;
end
$$;

create or replace function public.bil_set_my_community_post_context_v1(
  p_post_id uuid,
  p_location_label text default null,
  p_mentioned_user_ids uuid[] default array[]::uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
  v_location text:=nullif(btrim(p_location_label),'');
  v_requested integer:=cardinality(coalesce(p_mentioned_user_ids,array[]::uuid[]));
  v_valid integer:=0;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;

  perform public.bil_assert_community_publish_ready();

  if p_post_id is null
     or v_requested>10
     or cardinality(coalesce(p_mentioned_user_ids,array[]::uuid[]))<>(
       select count(distinct value)
       from unnest(coalesce(p_mentioned_user_ids,array[]::uuid[])) value
     )
     or v_uid=any(coalesce(p_mentioned_user_ids,array[]::uuid[])) then
    raise exception 'invalid_community_post_context' using errcode='22023';
  end if;

  if v_location is not null and (
    char_length(v_location)>80
    or v_location ~ '[[:cntrl:]]'
  ) then
    raise exception 'invalid_community_location_label' using errcode='22023';
  end if;

  if not exists(
    select 1
    from public.bil_community_posts p
    where p.id=p_post_id
      and p.author_id=v_uid
      and p.deleted_at is null
      and p.moderation_status='pending'
  ) then
    raise exception 'community_post_context_not_editable'
      using errcode='42501';
  end if;

  if v_requested>0 then
    select count(*)::integer into v_valid
    from public.bil_social_handles_v2 h
    join public.bil_public_profiles p on p.user_id=h.user_id
    where h.chosen
      and h.user_id=any(p_mentioned_user_ids)
      and p.discoverable
      and p.profile_visibility<>'private'
      and public.bil_social_member_visible_v2(h.user_id);

    if v_valid<>v_requested then
      raise exception 'community_mention_target_unavailable'
        using errcode='42501';
    end if;
  end if;

  update public.bil_community_posts
  set location_label=v_location
  where id=p_post_id and author_id=v_uid;

  delete from public.bil_community_post_mentions_v1
  where post_id=p_post_id;

  if v_requested>0 then
    insert into public.bil_community_post_mentions_v1(
      post_id,mentioned_user_id
    )
    select p_post_id,value
    from unnest(p_mentioned_user_ids) value;
  end if;

  return pg_catalog.jsonb_build_object(
    'post_id',p_post_id,
    'location_label',v_location,
    'mention_count',v_requested
  );
end
$$;

create or replace function private.bil_emit_post_mentions_on_approval_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_mention record;
begin
  if old.moderation_status is distinct from 'approved'
     and new.moderation_status='approved'
     and new.deleted_at is null then
    for v_mention in
      select m.mentioned_user_id
      from public.bil_community_post_mentions_v1 m
      where m.post_id=new.id
    loop
      if private.bil_activity_pair_allowed_v1(
        v_mention.mentioned_user_id,new.author_id
      ) then
        perform private.bil_emit_community_activity_v2(
          v_mention.mentioned_user_id,
          new.author_id,
          'mention',
          'post_mention:'||new.id::text||':'||
            v_mention.mentioned_user_id::text,
          'post',
          new.id::text,
          'post_mention_v1',
          '/community',
          pg_catalog.jsonb_build_object('post_id',new.id::text)
        );
      end if;
    end loop;
  end if;
  return new;
end
$$;

revoke all on function private.bil_emit_post_mentions_on_approval_v1()
  from public,anon,authenticated,service_role;

drop trigger if exists bil_community_post_mention_activity_v1
  on public.bil_community_posts;
create trigger bil_community_post_mention_activity_v1
after update of moderation_status on public.bil_community_posts
for each row
execute function private.bil_emit_post_mentions_on_approval_v1();

revoke all on function public.bil_search_community_mentions_v1(text,integer)
  from public,anon,service_role;
grant execute on function public.bil_search_community_mentions_v1(text,integer)
  to authenticated;

revoke all on function public.bil_set_my_community_post_context_v1(
  uuid,text,uuid[]
) from public,anon,service_role;
grant execute on function public.bil_set_my_community_post_context_v1(
  uuid,text,uuid[]
) to authenticated;

do $$
begin
  if to_regprocedure(
      'public.bil_search_community_mentions_v1(text,integer)'
    ) is null
     or to_regprocedure(
       'public.bil_set_my_community_post_context_v1(uuid,text,uuid[])'
     ) is null
     or not exists(
       select 1
       from pg_trigger t
       where t.tgrelid='public.bil_community_posts'::regclass
         and t.tgname='bil_community_post_mention_activity_v1'
         and not t.tgisinternal
     ) then
    raise exception 'community_post_context_v1_postcondition_failed';
  end if;
end
$$;
