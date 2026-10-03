set local lock_timeout='5s';
set local statement_timeout='30s';

do $$
begin
  if to_regprocedure(
    'private.bil_emit_community_activity_v2(uuid,uuid,text,text,text,text,text,text,jsonb)'
  ) is null then
    raise exception 'community_activity_v2_emitter_missing';
  end if;
  if to_regclass('public.bil_social_post_likes_v2') is null
     or to_regclass('public.bil_social_post_saves_v2') is null
     or to_regclass('public.bil_social_comments_v2') is null
     or to_regclass('public.bil_follows') is null then
    raise exception 'community_social_activity_tables_missing';
  end if;
end
$$;

create or replace function private.bil_activity_pair_allowed_v1(
  p_recipient uuid,
  p_actor uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select
    p_recipient is not null
    and p_actor is not null
    and p_recipient<>p_actor
    and not exists(
      select 1
      from private.bil_community_member_access a
      where a.user_id in(p_recipient,p_actor)
        and a.suspended
    )
    and not exists(
      select 1
      from public.bil_blocks b
      where (b.blocker_id=p_recipient and b.blocked_id=p_actor)
         or (b.blocker_id=p_actor and b.blocked_id=p_recipient)
    );
$$;

revoke all on function private.bil_activity_pair_allowed_v1(uuid,uuid)
  from public,anon,authenticated,service_role;

create or replace function private.bil_emit_post_like_activity_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_recipient uuid;
begin
  select p.author_id into v_recipient
  from public.bil_community_posts p
  where p.id=new.post_id
    and p.deleted_at is null;

  if private.bil_activity_pair_allowed_v1(v_recipient,new.user_id) then
    perform private.bil_emit_community_activity_v2(
      v_recipient,new.user_id,'post_like',
      'post_like:'||new.post_id::text||':'||new.user_id::text,
      'post',new.post_id::text,'post_like_v1','/community',
      pg_catalog.jsonb_build_object('post_id',new.post_id::text)
    );
  end if;
  return new;
end
$$;

create or replace function private.bil_emit_post_save_activity_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_recipient uuid;
begin
  select p.author_id into v_recipient
  from public.bil_community_posts p
  where p.id=new.post_id
    and p.deleted_at is null;

  if private.bil_activity_pair_allowed_v1(v_recipient,new.user_id) then
    perform private.bil_emit_community_activity_v2(
      v_recipient,null,'post_save',
      'post_save:'||new.post_id::text||':'||new.user_id::text,
      'post',new.post_id::text,'post_save_v1','/community',
      pg_catalog.jsonb_build_object('post_id',new.post_id::text)
    );
  end if;
  return new;
end
$$;

create or replace function private.bil_emit_comment_activity_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_recipient uuid;
  v_kind text;
  v_copy_key text;
begin
  if new.parent_id is null then
    select p.author_id into v_recipient
    from public.bil_community_posts p
    where p.id=new.post_id
      and p.deleted_at is null;
    v_kind:='comment';
    v_copy_key:='post_comment_v1';
  else
    select c.author_id into v_recipient
    from public.bil_social_comments_v2 c
    where c.id=new.parent_id
      and c.deleted_at is null
      and c.removed_at is null;
    v_kind:='reply';
    v_copy_key:='comment_reply_v1';
  end if;

  if private.bil_activity_pair_allowed_v1(v_recipient,new.author_id) then
    perform private.bil_emit_community_activity_v2(
      v_recipient,new.author_id,v_kind,
      v_kind||':'||new.id::text,
      'comment',new.id::text,v_copy_key,'/community',
      pg_catalog.jsonb_build_object(
        'post_id',new.post_id::text,
        'comment_id',new.id::text,
        'parent_id',case
          when new.parent_id is null then null
          else new.parent_id::text
        end
      )
    );
  end if;
  return new;
end
$$;

create or replace function private.bil_emit_follow_activity_v1()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if private.bil_activity_pair_allowed_v1(new.followed_id,new.follower_id) then
    perform private.bil_emit_community_activity_v2(
      new.followed_id,new.follower_id,'follow',
      'profile_follow:'||new.follower_id::text||':'||new.followed_id::text,
      'profile',new.follower_id::text,'profile_follow_v1',
      '/community/profile/'||new.follower_id::text,
      '{}'::jsonb
    );
  end if;
  return new;
end
$$;

revoke all on function private.bil_emit_post_like_activity_v1()
  from public,anon,authenticated,service_role;
revoke all on function private.bil_emit_post_save_activity_v1()
  from public,anon,authenticated,service_role;
revoke all on function private.bil_emit_comment_activity_v1()
  from public,anon,authenticated,service_role;
revoke all on function private.bil_emit_follow_activity_v1()
  from public,anon,authenticated,service_role;

drop trigger if exists bil_social_post_like_activity_v1
  on public.bil_social_post_likes_v2;
create trigger bil_social_post_like_activity_v1
after insert on public.bil_social_post_likes_v2
for each row execute function private.bil_emit_post_like_activity_v1();

drop trigger if exists bil_social_post_save_activity_v1
  on public.bil_social_post_saves_v2;
create trigger bil_social_post_save_activity_v1
after insert on public.bil_social_post_saves_v2
for each row execute function private.bil_emit_post_save_activity_v1();

drop trigger if exists bil_social_comment_activity_v1
  on public.bil_social_comments_v2;
create trigger bil_social_comment_activity_v1
after insert on public.bil_social_comments_v2
for each row execute function private.bil_emit_comment_activity_v1();

drop trigger if exists bil_follow_activity_v1
  on public.bil_follows;
create trigger bil_follow_activity_v1
after insert on public.bil_follows
for each row execute function private.bil_emit_follow_activity_v1();

do $$
begin
  if (
    select count(*)
    from pg_trigger t
    where not t.tgisinternal
      and t.tgname in(
        'bil_social_post_like_activity_v1',
        'bil_social_post_save_activity_v1',
        'bil_social_comment_activity_v1',
        'bil_follow_activity_v1'
      )
  )<>4 then
    raise exception 'community_social_activity_trigger_postcondition_failed';
  end if;
end
$$;
