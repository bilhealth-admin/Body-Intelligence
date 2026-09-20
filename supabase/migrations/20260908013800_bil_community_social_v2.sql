set local lock_timeout='5s'; set local statement_timeout='30s';
create table public.bil_social_handles_v2(user_id uuid primary key references public.bil_public_profiles(user_id) on delete cascade,handle text not null unique check(handle ~ '^[a-z][a-z0-9_]{2,29}$'),chosen boolean not null default false,created_at timestamptz not null default now());
create table public.bil_social_post_likes_v2(post_id uuid not null references public.bil_community_posts(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz not null default now(),primary key(post_id,user_id));
create index bil_social_likes_user_v2 on public.bil_social_post_likes_v2(user_id,post_id);
create table public.bil_social_comments_v2(id uuid primary key,post_id uuid not null references public.bil_community_posts(id) on delete cascade,author_id uuid not null references auth.users(id) on delete cascade,parent_id uuid references public.bil_social_comments_v2(id) on delete cascade,body text not null check(char_length(btrim(body)) between 1 and 1200),created_at timestamptz not null default now(),deleted_at timestamptz,removed_at timestamptz,removed_by uuid references auth.users(id) on delete set null,check(id is distinct from parent_id));
create index bil_social_comments_post_v2 on public.bil_social_comments_v2(post_id,created_at,id);
create index bil_social_comments_author_v2 on public.bil_social_comments_v2(author_id);
create index bil_social_comments_removed_by_v2 on public.bil_social_comments_v2(removed_by) where removed_by is not null;
create index bil_social_comments_parent_v2 on public.bil_social_comments_v2(parent_id);
create table public.bil_social_comment_likes_v2(comment_id uuid not null references public.bil_social_comments_v2(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz not null default now(),primary key(comment_id,user_id));
create index bil_social_comment_likes_user_v2 on public.bil_social_comment_likes_v2(user_id,comment_id);
create table public.bil_social_comment_reports_v2(id uuid primary key default gen_random_uuid(),comment_id uuid not null references public.bil_social_comments_v2(id) on delete cascade,reporter_id uuid not null references auth.users(id) on delete cascade,reason text not null check(char_length(btrim(reason)) between 3 and 500),created_at timestamptz not null default now(),reviewed_at timestamptz,reviewed_by uuid references auth.users(id) on delete set null,unique(comment_id,reporter_id));
create index bil_social_reports_reviewer_v2 on public.bil_social_comment_reports_v2(reviewed_by) where reviewed_by is not null;
create index bil_social_reports_reporter_v2 on public.bil_social_comment_reports_v2(reporter_id);
create index bil_social_reports_open_v2 on public.bil_social_comment_reports_v2(created_at) where reviewed_at is null;
alter table public.bil_social_handles_v2 enable row level security;
alter table public.bil_social_post_likes_v2 enable row level security;
alter table public.bil_social_comments_v2 enable row level security;
alter table public.bil_social_comment_reports_v2 enable row level security;
alter table public.bil_social_comment_likes_v2 enable row level security;
revoke all on public.bil_social_handles_v2,public.bil_social_post_likes_v2,public.bil_social_comments_v2,public.bil_social_comment_reports_v2,public.bil_social_comment_likes_v2 from public,anon,authenticated,service_role;
create function public.bil_social_member_visible_v2(p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and p_member is not null and not exists(select 1 from public.bil_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=p_member) or (b.blocker_id=p_member and b.blocked_id=auth.uid())) and not exists(select 1 from private.bil_community_member_access a where a.user_id=p_member and a.suspended)
$$;
create function public.bil_social_post_visible_v2(p_post uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.bil_community_posts p where p.id=p_post and p.deleted_at is null and p.moderation_status='approved' and public.bil_social_member_visible_v2(p.author_id) and not exists(select 1 from private.bil_community_member_access a where a.user_id=auth.uid() and a.suspended) and (p.visibility='community' or p.author_id=auth.uid() or exists(select 1 from public.bil_friendships f where f.status='accepted' and ((f.requester_id=auth.uid() and f.addressee_id=p.author_id) or (f.addressee_id=auth.uid() and f.requester_id=p.author_id)))))
$$;
create function public.bil_social_profile_visible_v2(p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.bil_social_member_visible_v2(p_member) and exists(select 1 from public.bil_public_profiles p where p.user_id=p_member and (p.user_id=auth.uid() or (p.profile_visibility='public' and p.discoverable) or (p.profile_visibility='friends' and exists(select 1 from public.bil_friendships f where f.status='accepted' and ((f.requester_id=auth.uid() and f.addressee_id=p.user_id) or (f.addressee_id=auth.uid() and f.requester_id=p.user_id))))))
$$;
create function public.bil_social_identity_v2() returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.bil_social_handles_v2%rowtype;
begin
 if not public.bil_can_use_community() then raise exception 'community_unavailable' using errcode='42501'; end if;
 if not exists(select 1 from public.bil_public_profiles where user_id=v_uid) then raise exception 'community_profile_required' using errcode='P0001'; end if;
 perform pg_advisory_xact_lock(hashtextextended('bil_handle:'||v_uid::text,0));
 select * into v_row from public.bil_social_handles_v2 where user_id=v_uid;
 if not found then insert into public.bil_social_handles_v2(user_id,handle) values(v_uid,'member_'||left(replace(gen_random_uuid()::text,'-',''),16)) returning * into v_row; end if;
 return jsonb_build_object('handle',v_row.handle,'chosen',v_row.chosen,'discoverable',(select discoverable and profile_visibility<>'private' and allow_friend_requests from public.bil_public_profiles where user_id=v_uid));
end; $$;
create function public.bil_social_claim_handle_v2(p_handle text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_handle text:=lower(btrim(p_handle)); v_uid uuid:=auth.uid(); v_old public.bil_social_handles_v2%rowtype;
begin
 if not public.bil_can_use_community() then raise exception 'community_unavailable' using errcode='42501'; end if;
 if left(v_handle,1)='@' then v_handle:=substr(v_handle,2); end if;
 if v_handle is null or v_handle !~ '^[a-z][a-z0-9_]{2,29}$' or v_handle in ('admin','administrator','support','bil','bilhealth','moderator','official') then raise exception 'invalid_community_handle' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('bil_handle:'||v_uid::text,0));
 select * into v_old from public.bil_social_handles_v2 where user_id=v_uid for update;
 if found and v_old.chosen and v_old.handle<>v_handle then raise exception 'community_handle_already_chosen' using errcode='P0001'; end if;
 if not exists(select 1 from public.bil_public_profiles where user_id=v_uid) then raise exception 'community_profile_required' using errcode='P0001'; end if;
 perform public.bil_consume_rate_limit('community_handle_claim_v2',10,3600);
 begin insert into public.bil_social_handles_v2(user_id,handle,chosen) values(v_uid,v_handle,true) on conflict(user_id) do update set handle=excluded.handle,chosen=true;
 exception when unique_violation then raise exception 'community_handle_taken' using errcode='23505'; end;
 return public.bil_social_identity_v2();
end; $$;
create function public.bil_social_search_handles_v2(p_query text,p_limit integer default 20) returns table(user_id uuid,handle text,display_name text,avatar_url text) language plpgsql security definer set search_path='' as $$
declare v_query text:=lower(ltrim(btrim(p_query),'@'));
begin
 if not public.bil_can_use_community() then raise exception 'community_unavailable' using errcode='42501'; end if;
 if v_query is null or v_query !~ '^[a-z][a-z0-9_]{2,29}$' then return; end if;
 perform public.bil_consume_rate_limit('community_handle_search_v2',60,60);
 return query select p.user_id,h.handle,p.display_name,p.avatar_url from public.bil_social_handles_v2 h join public.bil_public_profiles p on p.user_id=h.user_id where p.user_id<>auth.uid() and p.discoverable and p.allow_friend_requests and p.profile_visibility<>'private' and public.bil_social_member_visible_v2(p.user_id) and left(h.handle,char_length(v_query))=v_query order by (h.handle=v_query) desc,h.handle limit least(greatest(coalesce(p_limit,20),1),20);
end; $$;
create function public.bil_social_request_friend_v2(p_user_id uuid) returns text language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_f public.bil_friendships%rowtype;
begin
 if not public.bil_can_use_community() or v_uid=p_user_id or p_user_id is null then raise exception 'relationship_unavailable' using errcode='42501'; end if;
 if not public.bil_social_member_visible_v2(p_user_id) then raise exception 'relationship_unavailable' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('bil_friend_pair:'||least(v_uid::text,p_user_id::text)||greatest(v_uid::text,p_user_id::text),0));
 select * into v_f from public.bil_friendships where (requester_id=v_uid and addressee_id=p_user_id) or (requester_id=p_user_id and addressee_id=v_uid);
 if found then
  if v_f.status='accepted' then return 'accepted'; end if;
  if v_f.status='pending' then return case when v_f.requester_id=v_uid then 'pending' else 'incoming' end; end if;
  return 'declined';
 end if;
 begin perform public.bil_request_friendship(p_user_id);
 exception when unique_violation then
  select * into v_f from public.bil_friendships where (requester_id=v_uid and addressee_id=p_user_id) or (requester_id=p_user_id and addressee_id=v_uid);
  if not found then raise; end if;
  if v_f.status='accepted' then return 'accepted'; end if;
  if v_f.status='pending' then return case when v_f.requester_id=v_uid then 'pending' else 'incoming' end; end if;
  return 'declined';
 end;
 return 'pending';
end; $$;
create function public.bil_social_stats_v2(p_post_ids uuid[]) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
 if coalesce(cardinality(p_post_ids),0)>100 then raise exception 'too_many_posts' using errcode='22023'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('post_id',p.id,'like_count',(select count(*) from public.bil_social_post_likes_v2 l where l.post_id=p.id),'liked',exists(select 1 from public.bil_social_post_likes_v2 l where l.post_id=p.id and l.user_id=auth.uid()),'comment_count',(select count(*) from public.bil_social_comments_v2 c where c.post_id=p.id and c.deleted_at is null and c.removed_at is null and public.bil_social_member_visible_v2(c.author_id))) order by p.id) from public.bil_community_posts p where p.id=any(p_post_ids) and public.bil_social_post_visible_v2(p.id)),'[]'::jsonb);
end; $$;
create function public.bil_social_like_v2(p_post_id uuid,p_liked boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.bil_can_use_community() or not public.bil_social_post_visible_v2(p_post_id) then raise exception 'post_unavailable' using errcode='42501'; end if;
 if p_liked is null then raise exception 'invalid_like' using errcode='22023'; end if;
 perform public.bil_consume_rate_limit('community_like_v2',120,60);
 if p_liked then insert into public.bil_social_post_likes_v2(post_id,user_id) values(p_post_id,auth.uid()) on conflict do nothing;
 else delete from public.bil_social_post_likes_v2 where post_id=p_post_id and user_id=auth.uid(); end if;
 return (public.bil_social_stats_v2(array[p_post_id]))->0;
end; $$;
create function public.bil_social_comments_v2(p_post_id uuid,p_after timestamptz default null,p_after_id uuid default null,p_limit integer default 30) returns table(id uuid,author_id uuid,parent_id uuid,body text,created_at timestamptz,author_name text,avatar_url text,handle text,like_count bigint,liked boolean) language plpgsql stable security definer set search_path='' as $$
begin
 if not public.bil_social_post_visible_v2(p_post_id) then raise exception 'post_unavailable' using errcode='42501'; end if;
 if (p_after is null)<>(p_after_id is null) then raise exception 'invalid_cursor' using errcode='22023'; end if;
 return query select c.id,c.author_id,c.parent_id,c.body,c.created_at,p.display_name,p.avatar_url,h.handle,(select count(*) from public.bil_social_comment_likes_v2 l where l.comment_id=c.id),exists(select 1 from public.bil_social_comment_likes_v2 l where l.comment_id=c.id and l.user_id=auth.uid()) from public.bil_social_comments_v2 c left join public.bil_public_profiles p on p.user_id=c.author_id and public.bil_social_profile_visible_v2(p.user_id) left join public.bil_social_handles_v2 h on h.user_id=p.user_id where c.post_id=p_post_id and c.deleted_at is null and c.removed_at is null and public.bil_social_member_visible_v2(c.author_id) and (p_after is null or (c.created_at,c.id)>(p_after,p_after_id)) order by c.created_at,c.id limit least(greatest(coalesce(p_limit,30),1),100);
end; $$;
create function public.bil_social_add_comment_v2(p_post_id uuid,p_body text,p_parent_id uuid,p_client_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_text text:=btrim(p_body); v_parent uuid; v_old public.bil_social_comments_v2%rowtype;
begin
 if not public.bil_can_use_community() or not public.bil_social_post_visible_v2(p_post_id) then raise exception 'post_unavailable' using errcode='42501'; end if;
 if p_client_id is null or v_text is null or char_length(v_text) not between 1 and 1200 or translate(v_text,E'\n\r\t','') ~ '[[:cntrl:]]' then raise exception 'invalid_comment' using errcode='22023'; end if;
 if public.bil_community_contact_exchange_violation(v_text) is not null then raise exception 'community_contact_exchange_not_allowed' using errcode='P0001'; end if;
 if exists(select 1 from public.bil_content_policies where active) and not exists(select 1 from public.bil_content_policy_acceptances a join public.bil_content_policies p on p.version=a.policy_version and p.active where a.user_id=v_uid) then raise exception 'content policy acceptance required' using errcode='P0001'; end if;
 if p_parent_id is not null then
  select coalesce(c.parent_id,c.id) into v_parent from public.bil_social_comments_v2 c where c.id=p_parent_id and c.post_id=p_post_id and c.deleted_at is null and c.removed_at is null and public.bil_social_member_visible_v2(c.author_id);
  if not found or not exists(select 1 from public.bil_social_comments_v2 root where root.id=v_parent and root.post_id=p_post_id and root.deleted_at is null and root.removed_at is null and public.bil_social_member_visible_v2(root.author_id)) then raise exception 'reply_unavailable' using errcode='42501'; end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('bil_comment_request:'||p_client_id::text,0));
 select * into v_old from public.bil_social_comments_v2 where id=p_client_id;
 if found then
  if v_old.author_id<>v_uid or v_old.post_id<>p_post_id or v_old.body<>v_text or v_old.parent_id is distinct from v_parent or v_old.deleted_at is not null or v_old.removed_at is not null then raise exception 'idempotency_mismatch' using errcode='42501'; end if;
 else
  perform public.bil_consume_rate_limit('community_comment_v2',60,3600);
  insert into public.bil_social_comments_v2(id,post_id,author_id,parent_id,body) values(p_client_id,p_post_id,v_uid,v_parent,v_text) returning * into v_old;
 end if;
 return jsonb_build_object('id',v_old.id,'author_id',v_old.author_id,'parent_id',v_old.parent_id,'body',v_old.body,'created_at',v_old.created_at,'author_name',(select display_name from public.bil_public_profiles where user_id=v_uid),'avatar_url',(select avatar_url from public.bil_public_profiles where user_id=v_uid),'handle',(select handle from public.bil_social_handles_v2 where user_id=v_uid),'like_count',(select count(*) from public.bil_social_comment_likes_v2 where comment_id=v_old.id),'liked',exists(select 1 from public.bil_social_comment_likes_v2 where comment_id=v_old.id and user_id=v_uid));
end; $$;
create function public.bil_social_like_comment_v2(p_comment_id uuid,p_liked boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.bil_can_use_community() or not exists(select 1 from public.bil_social_comments_v2 c where c.id=p_comment_id and c.deleted_at is null and c.removed_at is null and public.bil_social_post_visible_v2(c.post_id) and public.bil_social_member_visible_v2(c.author_id)) then raise exception 'comment_unavailable' using errcode='42501'; end if;
 if p_liked is null then raise exception 'invalid_like' using errcode='22023'; end if;
 perform public.bil_consume_rate_limit('community_like_v2',120,60);
 if p_liked then insert into public.bil_social_comment_likes_v2(comment_id,user_id) values(p_comment_id,auth.uid()) on conflict do nothing;
 else delete from public.bil_social_comment_likes_v2 where comment_id=p_comment_id and user_id=auth.uid(); end if;
 return jsonb_build_object('like_count',(select count(*) from public.bil_social_comment_likes_v2 where comment_id=p_comment_id),'liked',exists(select 1 from public.bil_social_comment_likes_v2 where comment_id=p_comment_id and user_id=auth.uid()));
end; $$;
create function public.bil_social_delete_comment_v2(p_comment_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.bil_can_use_community() then raise exception 'community_unavailable' using errcode='42501'; end if;
 update public.bil_social_comments_v2 set deleted_at=coalesce(deleted_at,now()) where id=p_comment_id and author_id=auth.uid();
 if not found then raise exception 'comment_unavailable' using errcode='42501'; end if;
end; $$;
create function public.bil_social_report_comment_v2(p_comment_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.bil_can_use_community() or not exists(select 1 from public.bil_social_comments_v2 c where c.id=p_comment_id and c.deleted_at is null and c.removed_at is null and public.bil_social_post_visible_v2(c.post_id) and public.bil_social_member_visible_v2(c.author_id)) then raise exception 'comment_unavailable' using errcode='42501'; end if;
 if p_reason is null or char_length(btrim(p_reason)) not between 3 and 500 then raise exception 'invalid_report' using errcode='22023'; end if;
 perform public.bil_consume_rate_limit('community_comment_report_v2',20,3600);
 insert into public.bil_social_comment_reports_v2(comment_id,reporter_id,reason) values(p_comment_id,auth.uid(),btrim(p_reason)) on conflict(comment_id,reporter_id) do nothing;
end; $$;
create function public.bil_social_comment_reports_v2(p_limit integer default 50) returns table(report_id uuid,comment_id uuid,body text,reason text,created_at timestamptz) language plpgsql stable security definer set search_path='' as $$
begin
 if not public.bil_is_community_moderator() then raise exception 'moderator_required' using errcode='42501'; end if;
 if exists(select 1 from private.bil_community_member_access where user_id=auth.uid() and suspended) then raise exception 'community_unavailable' using errcode='42501'; end if;
 return query select r.id,c.id,c.body,r.reason,r.created_at from public.bil_social_comment_reports_v2 r join public.bil_social_comments_v2 c on c.id=r.comment_id where r.reviewed_at is null and c.author_id<>auth.uid() order by r.created_at,r.id limit least(greatest(coalesce(p_limit,50),1),100);
end; $$;
create function public.bil_social_resolve_comment_report_v2(p_report_id uuid,p_remove boolean) returns void language plpgsql security definer set search_path='' as $$
declare v_comment uuid; v_author uuid;
begin
 if not public.bil_can_use_community() or not public.bil_is_community_moderator() then raise exception 'moderator_required' using errcode='42501'; end if;
 if p_remove is null then raise exception 'invalid_decision' using errcode='22023'; end if;
 select r.comment_id,c.author_id into v_comment,v_author from public.bil_social_comment_reports_v2 r join public.bil_social_comments_v2 c on c.id=r.comment_id where r.id=p_report_id and r.reviewed_at is null for update of r;
 if not found then raise exception 'report_unavailable' using errcode='42501'; end if;
 if v_author=auth.uid() then raise exception 'moderator_cannot_review_own_comment' using errcode='42501'; end if;
 if p_remove then update public.bil_social_comments_v2 set removed_at=now(),removed_by=auth.uid() where id=v_comment; end if;
 update public.bil_social_comment_reports_v2 set reviewed_at=now(),reviewed_by=auth.uid() where id=p_report_id;
end; $$;
create function public.bil_social_api_version_v2() returns integer language sql stable security invoker set search_path='' as $$ select case when auth.uid() is not null then 2 else null end; $$;
do $acl$ declare r record; begin
 for r in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('bil_social_member_visible_v2','bil_social_post_visible_v2','bil_social_profile_visible_v2','bil_social_identity_v2','bil_social_claim_handle_v2','bil_social_search_handles_v2','bil_social_request_friend_v2','bil_social_stats_v2','bil_social_like_v2','bil_social_comments_v2','bil_social_add_comment_v2','bil_social_delete_comment_v2','bil_social_like_comment_v2','bil_social_report_comment_v2','bil_social_comment_reports_v2','bil_social_resolve_comment_report_v2','bil_social_api_version_v2') loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',r.signature);
 if r.signature::text !~ 'bil_social_(member|post|profile)_visible_v2' then execute format('grant execute on function %s to authenticated',r.signature); end if;
 end loop;
end; $acl$;
do $verify$ declare r record; v_count integer; begin
 select count(*) into v_count from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('bil_social_handles_v2','bil_social_post_likes_v2','bil_social_comments_v2','bil_social_comment_likes_v2','bil_social_comment_reports_v2') and c.relrowsecurity;
 if v_count<>5 then raise exception 'social_v2_rls_check_failed'; end if;
 for r in select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('bil_social_handles_v2','bil_social_post_likes_v2','bil_social_comments_v2','bil_social_comment_likes_v2','bil_social_comment_reports_v2') loop
 if has_table_privilege('anon',r.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER,REFERENCES,MAINTAIN') or has_table_privilege('authenticated',r.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER,REFERENCES,MAINTAIN') or has_table_privilege('service_role',r.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER,REFERENCES,MAINTAIN') then raise exception 'social_v2_unexpected_table_grant'; end if;
 end loop;
end; $verify$;
notify pgrst,'reload schema';
