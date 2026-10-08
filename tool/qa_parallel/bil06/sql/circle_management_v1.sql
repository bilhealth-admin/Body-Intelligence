-- BIL-06 FORWARD-ONLY LOCAL PROPOSAL. NOT a timestamped production migration.
-- Apply only after review, in ONE transaction, to a disposable local database.
-- BASE 1744788e6bfbdffc3a168bbaf36b3abf3e2c698a. No existing join/leave/post RPC is replaced.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $preflight$
begin
  if to_regclass('public.bil_community_circles') is null
     or to_regclass('public.bil_community_circle_memberships') is null
     or to_regclass('public.bil_social_public_codes_v2') is null
     or to_regprocedure('public.bil_assert_community_publish_ready()') is null
     or to_regprocedure('public.bil_social_resolve_public_code_v2(text)') is null
     or to_regprocedure('public.bil_social_post_visible_v2(uuid)') is null
     or to_regclass('storage.objects') is null then
    raise exception 'bil06_dependency_missing' using errcode = '55000';
  end if;
  if to_regclass('public.bil_circle_metadata_v1') is not null then
    raise exception 'bil06_already_installed' using errcode = '55000';
  end if;
end
$preflight$;

create table public.bil_circle_metadata_v1 (
  circle_id uuid primary key references public.bil_community_circles(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 80 and display_name !~ '[[:cntrl:]]'),
  description text not null default '' check (char_length(description) <= 1000 and translate(description,E'\n\r\t','') !~ '[[:cntrl:]]'),
  rules text not null default '' check (char_length(rules) <= 2000 and translate(rules,E'\n\r\t','') !~ '[[:cntrl:]]'),
  avatar_media_id uuid,
  cover_media_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table public.bil_circle_invites_v1 (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.bil_community_circles(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null default (clock_timestamp() + interval '14 days'),
  check (inviter_id <> invitee_id),
  check (expires_at > created_at)
);
-- One unresolved invitation, including an expired pending row, per recipient/circle.
-- A new explicit send retires an expired pending row before inserting its successor.
create unique index bil06_invites_pending_unique on public.bil_circle_invites_v1(circle_id,invitee_id) where status='pending';
create index bil06_invites_incoming_page on public.bil_circle_invites_v1(invitee_id,id);
create index bil06_invites_circle_page on public.bil_circle_invites_v1(circle_id,id);
create index bil06_invites_inviter_page on public.bil_circle_invites_v1(inviter_id,id);

create table public.bil_circle_media_v1 (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.bil_community_circles(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  slot text not null check (slot in ('avatar','cover')),
  object_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  bytes integer not null check (bytes between 1 and 5242880),
  width integer not null check (width between 1 and 8192),
  height integer not null check (height between 1 and 8192),
  status text not null default 'reserved' check (status in ('reserved','published','cancelled','superseded')),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (width::bigint * height::bigint <= 40000000),
  check (object_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[a-z0-9]+(-[a-z0-9]+)*/(avatar|cover)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'),
  unique(circle_id,id)
);
create index bil06_media_owner_idx on public.bil_circle_media_v1(owner_id,status,id);
create index bil06_media_circle_idx on public.bil_circle_media_v1(circle_id,status,id);
alter table public.bil_circle_metadata_v1 add constraint bil06_avatar_same_circle_fk
  foreign key (circle_id,avatar_media_id) references public.bil_circle_media_v1(circle_id,id) on delete set null (avatar_media_id);
alter table public.bil_circle_metadata_v1 add constraint bil06_cover_same_circle_fk
  foreign key (circle_id,cover_media_id) references public.bil_circle_media_v1(circle_id,id) on delete set null (cover_media_id);

create table public.bil_circle_operations_v1 (
  owner_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  operation text not null check (operation in ('create','invite_send','invite_accept','invite_decline','invite_cancel','media_prepare','media_finish','media_cancel')),
  payload jsonb not null check (jsonb_typeof(payload)='object'),
  circle_id uuid references public.bil_community_circles(id) on delete set null,
  circle_slug text not null,
  -- Immutable historical identities. Do not foreign-key these two columns:
  -- deleting/superseding the current projection must never erase which invite
  -- or media object an already committed idempotent operation targeted.
  invite_id uuid,
  media_id uuid,
  committed_at timestamptz not null default clock_timestamp(),
  primary key (owner_id,request_id)
);
create index bil06_operations_circle_idx on public.bil_circle_operations_v1(circle_id);
create index bil06_operations_invite_idx on public.bil_circle_operations_v1(invite_id);
create index bil06_operations_media_idx on public.bil_circle_operations_v1(media_id);

alter table public.bil_circle_metadata_v1 enable row level security;
alter table public.bil_circle_invites_v1 enable row level security;
alter table public.bil_circle_media_v1 enable row level security;
alter table public.bil_circle_operations_v1 enable row level security;
revoke all on table public.bil_circle_metadata_v1,public.bil_circle_invites_v1,
  public.bil_circle_media_v1,public.bil_circle_operations_v1 from public,anon,authenticated,service_role;
-- RPC-only tables, matching BASE circles. No mobile direct DML grants/policies.

create function private.bil_circle_member_v1()
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not exists(select 1 from auth.users u where u.id=v_uid) then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  -- This BASE helper obtains community_member_state:<actor> BEFORE all BIL06 locks.
  if not public.bil_can_use_community() then
    raise exception 'community_access_suspended' using errcode='42501';
  end if;
  return v_uid;
end $$;

create function private.bil_circle_write_ready_v1()
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := private.bil_circle_member_v1();
begin
  perform public.bil_assert_community_publish_ready();
  -- R5 saved name + actual BIL Code; bio and a manually chosen handle are NOT required.
  perform p.user_id from public.bil_public_profiles p
    join public.bil_social_public_codes_v2 code on code.user_id=p.user_id
    where p.user_id=v_uid and char_length(btrim(p.display_name))>=2
    for share of p,code;
  if not found then raise exception 'community_profile_required' using errcode='42501'; end if;
  return v_uid;
end $$;

create function private.bil_circle_manager_v1(p_circle uuid,p_lock boolean default false)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_role text;
begin
  if v_uid is null or exists(select 1 from private.bil_community_member_access a where a.user_id=v_uid and a.suspended) then return false; end if;
  if p_lock then
    select m.role into v_role from public.bil_community_circle_memberships m
      where m.circle_id=p_circle and m.owner_id=v_uid and m.status='active' for share;
  else
    select m.role into v_role from public.bil_community_circle_memberships m
      where m.circle_id=p_circle and m.owner_id=v_uid and m.status='active';
  end if;
  return coalesce(v_role='moderator',false);
end $$;

create function private.bil_circle_invite_usable_v1(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.bil_circle_invites_v1 i
    join public.bil_community_circles c on c.id=i.circle_id and c.active
    join public.bil_community_circle_memberships manager on manager.circle_id=i.circle_id
      and manager.owner_id=i.inviter_id and manager.status='active' and manager.role='moderator'
    where i.id=p_id and i.status='pending' and i.expires_at>statement_timestamp()
      and not exists(select 1 from private.bil_community_member_access a where a.user_id in (i.inviter_id,i.invitee_id) and a.suspended)
      and not exists(select 1 from public.bil_blocks b where (b.blocker_id=i.inviter_id and b.blocked_id=i.invitee_id) or (b.blocker_id=i.invitee_id and b.blocked_id=i.inviter_id))
      and not exists(select 1 from public.bil_community_circle_memberships m where m.circle_id=i.circle_id and m.owner_id=i.invitee_id and m.status='banned')
  )
$$;

create function private.bil_circle_visible_v1(p_circle uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid()) is not null
    and exists(select 1 from auth.users u where u.id=(select auth.uid()))
    and not exists(select 1 from private.bil_community_member_access a where a.user_id=(select auth.uid()) and a.suspended)
    and exists(
      select 1 from public.bil_community_circles c where c.id=p_circle and c.active
      and (c.access='public'
        or exists(select 1 from public.bil_community_circle_memberships m where m.circle_id=c.id and m.owner_id=(select auth.uid()) and m.status='active')
        or exists(select 1 from public.bil_circle_invites_v1 i where i.circle_id=c.id and i.invitee_id=(select auth.uid()) and private.bil_circle_invite_usable_v1(i.id)))
    )
$$;

create function private.bil_circle_media_json_v1(p_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',m.id,'owner_id',m.owner_id,'circle_slug',c.slug,'slot',m.slot,'object_path',m.object_path,
    'mime_type',m.mime_type,'bytes',m.bytes,'width',m.width,'height',m.height,
    'dimensions_verified',false,'status',m.status)
  from public.bil_circle_media_v1 m join public.bil_community_circles c on c.id=m.circle_id
  where m.id=p_id and (m.owner_id=(select auth.uid()) or private.bil_circle_visible_v1(m.circle_id))
$$;

create function private.bil_circle_projection_v1(p_circle uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'slug',c.slug,'title_copy_key',c.title_copy_key,'description_copy_key',c.description_copy_key,'rules_copy_key',c.rules_copy_key,
    'access',c.access,'join_policy',c.join_policy,'featured',c.featured,
    'member_count',(select count(*) from public.bil_community_circle_memberships x where x.circle_id=c.id and x.status='active' and not exists(select 1 from private.bil_community_member_access a where a.user_id=x.owner_id and a.suspended)),
    'post_count',(select count(*) from public.bil_community_post_circles pc join public.bil_community_posts p on p.id=pc.post_id where pc.circle_id=c.id and p.deleted_at is null and p.moderation_status='approved' and public.bil_social_post_visible_v2(p.id)),
    'membership_status',member.status,'membership_role',member.role,
    'display_name',meta.display_name,'description',meta.description,'rules',meta.rules,
    'avatar',case when exists(select 1 from public.bil_circle_media_v1 a join storage.objects o on o.bucket_id='community-circle-media' and o.name=a.object_path where a.id=meta.avatar_media_id and a.status='published') then private.bil_circle_media_json_v1(meta.avatar_media_id) end,
    'cover',case when exists(select 1 from public.bil_circle_media_v1 a join storage.objects o on o.bucket_id='community-circle-media' and o.name=a.object_path where a.id=meta.cover_media_id and a.status='published') then private.bil_circle_media_json_v1(meta.cover_media_id) end
  )
  from public.bil_community_circles c
  left join public.bil_circle_metadata_v1 meta on meta.circle_id=c.id
  left join public.bil_community_circle_memberships member on member.circle_id=c.id and member.owner_id=(select auth.uid())
  where c.id=p_circle and private.bil_circle_visible_v1(c.id)
$$;

create function private.bil_circle_invite_json_v1(p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_i public.bil_circle_invites_v1%rowtype;
  v_manager boolean; v_usable boolean; v_name text; v_slug text;
begin
  select * into v_i from public.bil_circle_invites_v1 where id=p_id;
  if not found then return null; end if;
  v_manager := private.bil_circle_manager_v1(v_i.circle_id);
  if v_uid is null or (v_uid<>v_i.invitee_id and v_uid<>v_i.inviter_id and not v_manager) then return null; end if;
  if exists(select 1 from private.bil_community_member_access a where a.user_id=v_uid and a.suspended) then return null; end if;
  select c.slug,m.display_name into v_slug,v_name from public.bil_community_circles c left join public.bil_circle_metadata_v1 m on m.circle_id=c.id where c.id=v_i.circle_id;
  v_usable := private.bil_circle_invite_usable_v1(v_i.id);
  return jsonb_build_object('id',v_i.id,'circle_slug',v_slug,'circle_name',v_name,
    'inviter_id',v_i.inviter_id,'invitee_id',v_i.invitee_id,'recipient_code',null,
    'inviter_name',(select p.display_name from public.bil_public_profiles p where p.user_id=v_i.inviter_id and (p.user_id=v_uid or public.bil_social_profile_visible_v2(p.user_id))),
    'invitee_name',(select p.display_name from public.bil_public_profiles p where p.user_id=v_i.invitee_id and (p.user_id=v_uid or public.bil_social_profile_visible_v2(p.user_id))),
    'status',case when v_i.status='pending' and v_i.expires_at<=statement_timestamp() then 'expired' else v_i.status end,
    'created_at',v_i.created_at,'updated_at',v_i.updated_at,'expires_at',v_i.expires_at,
    'can_accept',v_uid=v_i.invitee_id and v_usable,
    'can_decline',v_uid=v_i.invitee_id and v_i.status='pending' and v_i.expires_at>statement_timestamp(),
    'can_cancel',v_manager and v_i.status='pending' and v_i.expires_at>statement_timestamp());
end $$;

create function public.bil_circle_operation_v1(p_request_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_op public.bil_circle_operations_v1%rowtype;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'invalid_circle_request' using errcode='22023'; end if;
  select * into v_op from public.bil_circle_operations_v1 where owner_id=v_uid and request_id=p_request_id;
  if not found then return null; end if;
  return jsonb_build_object('owner_id',v_uid,'request_id',v_op.request_id,'operation',v_op.operation,
    'committed',true,'committed_at',v_op.committed_at,'circle_slug',v_op.circle_slug,
    'invite_id',v_op.invite_id,'media_id',v_op.media_id,
    'circle',private.bil_circle_projection_v1(v_op.circle_id),
    'invite',private.bil_circle_invite_json_v1(v_op.invite_id),
    'media',private.bil_circle_media_json_v1(v_op.media_id));
end $$;

create function private.bil_circle_request_v1(p_request_id uuid,p_operation text,p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_op public.bil_circle_operations_v1%rowtype;
begin
  if p_request_id is null then raise exception 'invalid_circle_request' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bil06:request:'||v_uid::text||':'||p_request_id::text,0));
  select * into v_op from public.bil_circle_operations_v1 where owner_id=v_uid and request_id=p_request_id;
  if not found then return null; end if;
  if v_op.operation<>p_operation or v_op.payload is distinct from p_payload then
    raise exception 'circle_request_payload_conflict' using errcode='22023';
  end if;
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_capabilities_v1(p_slug text default null)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid := (select auth.uid()); v_ready boolean:=false; v_access boolean:=false;
  v_reason text; v_circle uuid; v_role text; v_status text; v_manager boolean:=false; v_create boolean;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  begin
    perform private.bil_circle_member_v1(); v_access:=true;
    perform private.bil_circle_write_ready_v1(); v_ready:=true;
  exception when insufficient_privilege then get stacked diagnostics v_reason=message_text;
  end;
  if p_slug is not null then
    select c.id into v_circle from public.bil_community_circles c where c.slug=p_slug and c.active;
    if v_circle is not null and private.bil_circle_visible_v1(v_circle) then
      select m.role,m.status into v_role,v_status from public.bil_community_circle_memberships m where m.circle_id=v_circle and m.owner_id=v_uid;
      v_manager := private.bil_circle_manager_v1(v_circle);
    end if;
  end if;
  v_create:=v_ready and (select count(*) from public.bil_community_circle_memberships where owner_id=v_uid and status in ('active','pending'))<100;
  if v_ready and not v_create then v_reason:='community_circle_membership_limit'; end if;
  return jsonb_build_object('owner_id',v_uid,'circle_slug',p_slug,'available',true,
    'can_create',v_create,'can_search',v_access,'can_read_invites',v_access,
    'can_invite',v_ready and v_manager,'can_manage_media',v_ready and v_manager and exists(select 1 from public.bil_circle_metadata_v1 where circle_id=v_circle),
    'is_member',coalesce(v_status='active',false),'role',v_role,'reason',v_reason);
end $$;

create function public.bil_circle_membership_v1(p_slug text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_circle uuid; v_role text; v_status text; v_publish boolean:=false;
begin
  select c.id into v_circle from public.bil_community_circles c where c.slug=p_slug and private.bil_circle_visible_v1(c.id);
  if v_circle is null then return jsonb_build_object('owner_id',v_uid,'circle_slug',p_slug,'visible',false,'is_member',false,'can_read_posts',false,'can_post',false,'can_manage',false,'role',null,'status',null); end if;
  select m.role,m.status into v_role,v_status from public.bil_community_circle_memberships m where m.circle_id=v_circle and m.owner_id=v_uid;
  if v_status='active' then
    begin
      perform private.bil_circle_write_ready_v1(); v_publish:=true;
    exception when insufficient_privilege or object_not_in_prerequisite_state then null;
    end;
  end if;
  return jsonb_build_object('owner_id',v_uid,'circle_slug',p_slug,'visible',true,'role',v_role,'status',v_status,
    'is_member',coalesce(v_status='active',false),
    'can_read_posts',exists(select 1 from public.bil_community_circles c where c.id=v_circle and (c.access='public' or v_status='active')),
    'can_post',v_publish,'can_manage',private.bil_circle_manager_v1(v_circle));
end $$;

create function public.bil_circle_search_v1(p_query text default '',p_mine boolean default false,p_after_slug text default null,p_limit integer default 30)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_query text:=btrim(coalesce(p_query,''));
  v_rows jsonb:='[]'; v_next text; v_count integer;
begin
  if p_limit is null or p_limit not between 1 and 60 or p_mine is null or char_length(v_query)>120 or v_query ~ '[[:cntrl:]]'
    or (p_after_slug is not null and (char_length(p_after_slug)>48 or p_after_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$')) then
    raise exception 'invalid_circle_search' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(x.row order by x.slug collate "C"),'[]'::jsonb) into v_rows from (
    select c.slug,private.bil_circle_projection_v1(c.id) as row
    from public.bil_community_circles c left join public.bil_circle_metadata_v1 meta on meta.circle_id=c.id
    where private.bil_circle_visible_v1(c.id)
      and (not p_mine or exists(select 1 from public.bil_community_circle_memberships m where m.circle_id=c.id and m.owner_id=v_uid and m.status in ('active','pending')))
      and (p_after_slug is null or c.slug collate "C">p_after_slug collate "C")
      and (v_query='' or strpos(lower(concat_ws(' ',c.slug,meta.display_name,meta.description)),lower(v_query))>0)
    order by c.slug collate "C" limit p_limit+1
  ) x;
  v_count:=jsonb_array_length(v_rows);
  if v_count>p_limit then v_rows:=v_rows-(v_count-1); v_next:=v_rows->(p_limit-1)->>'slug'; end if;
  return jsonb_build_object('owner_id',v_uid,'query',v_query,'mine',p_mine,'circles',v_rows,'next_after_slug',v_next);
end $$;

create function public.bil_circle_invite_v1(p_invite_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1();
begin
  if p_invite_id is null then raise exception 'invalid_circle_invite' using errcode='22023'; end if;
  return jsonb_build_object('owner_id',v_uid,'invite',private.bil_circle_invite_json_v1(p_invite_id));
end $$;

create function public.bil_circle_invites_v1(p_slug text default null,p_after_id uuid default null,p_limit integer default 30)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_rows jsonb; v_count integer; v_next uuid;
begin
  if p_limit is null or p_limit not between 1 and 60 then raise exception 'invalid_circle_invite_page' using errcode='22023'; end if;
  select coalesce(jsonb_agg(x.row order by x.id),'[]'::jsonb) into v_rows from (
    select i.id,private.bil_circle_invite_json_v1(i.id) as row from public.bil_circle_invites_v1 i
    join public.bil_community_circles c on c.id=i.circle_id
    where (i.inviter_id=v_uid or i.invitee_id=v_uid or private.bil_circle_manager_v1(i.circle_id))
      and (p_slug is null or c.slug=p_slug) and (p_after_id is null or i.id>p_after_id)
    order by i.id limit p_limit+1
  ) x;
  v_count:=jsonb_array_length(v_rows);
  if v_count>p_limit then v_rows:=v_rows-(v_count-1); v_next:=(v_rows->(p_limit-1)->>'id')::uuid; end if;
  return jsonb_build_object('owner_id',v_uid,'invites',v_rows,'next_after_id',v_next);
end $$;

create function public.bil_circle_read_v1(p_slug text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_circle uuid;
begin
  select c.id into v_circle from public.bil_community_circles c where c.slug=p_slug;
  return jsonb_build_object('owner_id',v_uid,'circle',private.bil_circle_projection_v1(v_circle));
end $$;

create function private.bil_circle_lock_v1(p_slug text)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_circle uuid;
begin
  select c.id into v_circle from public.bil_community_circles c where c.slug=p_slug and c.active;
  if v_circle is null then raise exception 'circle_unavailable' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bil06:circle:'||v_circle::text,0));
  perform 1 from public.bil_community_circles c where c.id=v_circle and c.active for share;
  if not found then raise exception 'circle_unavailable' using errcode='42501'; end if;
  return v_circle;
end $$;

create function public.bil_circle_create_v1(p_request_id uuid,p_display_name text,p_description text,p_rules text,p_access text,p_join_policy text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_payload jsonb; v_existing jsonb;
  v_id uuid:=gen_random_uuid(); v_slug text; v_name text:=btrim(p_display_name);
begin
  if v_name is null or char_length(v_name) not between 2 and 80 or v_name ~ '[[:cntrl:]]'
    or p_description is null or char_length(p_description)>1000 or translate(p_description,E'\n\r\t','') ~ '[[:cntrl:]]'
    or p_rules is null or char_length(p_rules)>2000 or translate(p_rules,E'\n\r\t','') ~ '[[:cntrl:]]'
    or p_access is null or p_access not in ('public','private') or p_join_policy is null or p_join_policy not in ('open','request','invite')
    or (p_access='private' and p_join_policy='open') then
    raise exception 'invalid_circle_create' using errcode='22023';
  end if;
  v_payload:=jsonb_build_object('display_name',v_name,'description',p_description,'rules',p_rules,'access',p_access,'join_policy',p_join_policy);
  v_existing:=private.bil_circle_request_v1(p_request_id,'create',v_payload);
  if v_existing is not null then return v_existing; end if;
  perform private.bil_circle_write_ready_v1();
  if (select count(*) from public.bil_community_circle_memberships m where m.owner_id=v_uid and m.status in ('active','pending'))>=100 then
    raise exception 'community_circle_membership_limit' using errcode='22023';
  end if;
  v_slug:='c-'||replace(v_id::text,'-','');
  insert into public.bil_community_circles(id,slug,title_copy_key,description_copy_key,rules_copy_key,access,join_policy)
    values(v_id,v_slug,'community_circle_custom_title','community_circle_custom_description','community_circle_custom_rules',p_access,p_join_policy);
  insert into public.bil_circle_metadata_v1(circle_id,created_by,display_name,description,rules)
    values(v_id,v_uid,v_name,p_description,p_rules);
  -- The creator becomes the one actual managing member; no other users are enrolled.
  insert into public.bil_community_circle_memberships(circle_id,owner_id,role,status) values(v_id,v_uid,'moderator','active');
  insert into public.bil_circle_operations_v1(owner_id,request_id,operation,payload,circle_id,circle_slug)
    values(v_uid,p_request_id,'create',v_payload,v_id,v_slug);
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_invite_send_v1(p_request_id uuid,p_slug text,p_invitee_code text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_payload jsonb; v_existing jsonb; v_circle uuid;
  v_target jsonb; v_invitee uuid; v_invite uuid; v_code text:=lower(btrim(p_invitee_code)); v_old public.bil_circle_invites_v1%rowtype;
begin
  if v_code is null or v_code !~ '^[a-f0-9]{32}$' or p_slug is null then
    raise exception 'circle_invitee_unavailable' using errcode='42501';
  end if;
  v_payload:=jsonb_build_object('circle_slug',p_slug,'invitee_code',v_code);
  v_existing:=private.bil_circle_request_v1(p_request_id,'invite_send',v_payload);
  if v_existing is not null then return v_existing; end if;
  perform private.bil_circle_write_ready_v1();
  v_circle:=private.bil_circle_lock_v1(p_slug);
  if not private.bil_circle_manager_v1(v_circle,true) then raise exception 'circle_manager_required' using errcode='42501'; end if;
  -- Canonical revocable BIL Code resolver enforces profile discoverability, blocks,
  -- suspension and its existing lookup quota. No new friendship/follow is created.
  v_target:=public.bil_social_resolve_public_code_v2(v_code);
  v_invitee:=(v_target->>'user_id')::uuid;
  if v_invitee is null or v_invitee=v_uid then raise exception 'circle_invitee_unavailable' using errcode='42501'; end if;
  if exists(select 1 from public.bil_community_circle_memberships m where m.circle_id=v_circle and m.owner_id=v_invitee and m.status in ('active','banned')) then
    raise exception 'circle_invitee_unavailable' using errcode='42501';
  end if;
  select * into v_old from public.bil_circle_invites_v1 i where i.circle_id=v_circle and i.invitee_id=v_invitee and i.status='pending' for update;
  if found and v_old.expires_at>clock_timestamp() and private.bil_circle_invite_usable_v1(v_old.id) then
    v_invite:=v_old.id;
  else
    if v_old.id is not null then update public.bil_circle_invites_v1 set status='cancelled',updated_at=clock_timestamp() where id=v_old.id; end if;
    insert into public.bil_circle_invites_v1(circle_id,inviter_id,invitee_id) values(v_circle,v_uid,v_invitee) returning id into v_invite;
  end if;
  insert into public.bil_circle_operations_v1(owner_id,request_id,operation,payload,circle_id,circle_slug,invite_id)
    values(v_uid,p_request_id,'invite_send',v_payload,v_circle,p_slug,v_invite);
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_invite_action_v1(p_request_id uuid,p_invite_id uuid,p_action text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_payload jsonb; v_existing jsonb;
  v_i public.bil_circle_invites_v1%rowtype; v_slug text; v_status text; v_current text; v_manager uuid;
begin
  if p_invite_id is null or p_action is null or p_action not in ('accept','decline','cancel') then raise exception 'invalid_circle_invite_action' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('invite_id',p_invite_id,'action',p_action);
  v_existing:=private.bil_circle_request_v1(p_request_id,'invite_'||p_action,v_payload);
  if v_existing is not null then return v_existing; end if;
  select * into v_i from public.bil_circle_invites_v1 where id=p_invite_id;
  if not found then raise exception 'circle_invite_unavailable' using errcode='42501'; end if;
  select slug into v_slug from public.bil_community_circles where id=v_i.circle_id;
  perform private.bil_circle_lock_v1(v_slug);
  select * into v_i from public.bil_circle_invites_v1 where id=p_invite_id for update;
  if p_action='cancel' then
    if not private.bil_circle_manager_v1(v_i.circle_id,true) then raise exception 'circle_manager_required' using errcode='42501'; end if;
  elsif v_i.invitee_id<>v_uid then
    raise exception 'circle_invite_unavailable' using errcode='42501';
  end if;
  v_status:=case p_action when 'accept' then 'accepted' when 'decline' then 'declined' else 'cancelled' end;
  if v_i.status<>v_status then
    if v_i.status<>'pending' or v_i.expires_at<=clock_timestamp() then raise exception 'circle_invite_not_pending' using errcode='55000'; end if;
    if p_action='accept' then
      perform private.bil_circle_write_ready_v1();
      -- Hold issuer's existing membership row through commit, so role revocation
      -- cannot commit between the authorization read and this transition.
      select m.owner_id into v_manager from public.bil_community_circle_memberships m
        where m.circle_id=v_i.circle_id and m.owner_id=v_i.inviter_id and m.status='active' and m.role='moderator' for share;
      if v_manager is null or not private.bil_circle_invite_usable_v1(v_i.id) then raise exception 'circle_invite_unavailable' using errcode='42501'; end if;
      select m.status into v_current from public.bil_community_circle_memberships m where m.circle_id=v_i.circle_id and m.owner_id=v_uid for update;
      if v_current='banned' then raise exception 'circle_invite_unavailable' using errcode='42501'; end if;
      if coalesce(v_current,'') not in ('active','pending') and (select count(*) from public.bil_community_circle_memberships m where m.owner_id=v_uid and m.status in ('active','pending'))>=100 then raise exception 'community_circle_membership_limit' using errcode='22023'; end if;
      insert into public.bil_community_circle_memberships(circle_id,owner_id,role,status)
        values(v_i.circle_id,v_uid,'member','active')
        on conflict(circle_id,owner_id) do update set status='active',updated_at=clock_timestamp()
        where public.bil_community_circle_memberships.status<>'banned';
      if not found then raise exception 'circle_invite_unavailable' using errcode='42501'; end if;
    end if;
    update public.bil_circle_invites_v1 set status=v_status,updated_at=clock_timestamp() where id=v_i.id;
  end if;
  -- Same terminal action is idempotent; accepting an old accepted invite AFTER
  -- leaving never recreates membership. A different terminal action is rejected.
  insert into public.bil_circle_operations_v1(owner_id,request_id,operation,payload,circle_id,circle_slug,invite_id)
    values(v_uid,p_request_id,'invite_'||p_action,v_payload,v_i.circle_id,v_slug,v_i.id);
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_media_prepare_v1(p_request_id uuid,p_slug text,p_slot text,p_mime_type text,p_bytes integer,p_width integer,p_height integer)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_payload jsonb; v_existing jsonb; v_circle uuid;
  v_id uuid:=gen_random_uuid(); v_path text;
begin
  if p_slot is null or p_slot not in ('avatar','cover') or p_mime_type is null or p_mime_type not in ('image/jpeg','image/png','image/webp')
    or p_bytes is null or p_bytes not between 1 and 5242880 or p_width is null or p_width not between 1 and 8192 or p_height is null or p_height not between 1 and 8192
    or p_width::bigint*p_height::bigint>40000000 then
    raise exception 'invalid_circle_media' using errcode='22023';
  end if;
  v_payload:=jsonb_build_object('circle_slug',p_slug,'slot',p_slot,'mime_type',p_mime_type,'bytes',p_bytes,'width',p_width,'height',p_height);
  v_existing:=private.bil_circle_request_v1(p_request_id,'media_prepare',v_payload);
  if v_existing is not null then return v_existing; end if;
  perform private.bil_circle_write_ready_v1();
  v_circle:=private.bil_circle_lock_v1(p_slug);
  if not private.bil_circle_manager_v1(v_circle,true) then raise exception 'circle_manager_required' using errcode='42501'; end if;
  if not exists(select 1 from public.bil_circle_metadata_v1 where circle_id=v_circle) then
    raise exception 'circle_metadata_unavailable' using errcode='55000';
  end if;
  v_path:=v_uid::text||'/'||p_slug||'/'||p_slot||'/'||v_id::text||case p_mime_type when 'image/jpeg' then '.jpg' when 'image/png' then '.png' else '.webp' end;
  insert into public.bil_circle_media_v1(id,circle_id,owner_id,slot,object_path,mime_type,bytes,width,height)
    values(v_id,v_circle,v_uid,p_slot,v_path,p_mime_type,p_bytes,p_width,p_height);
  insert into public.bil_circle_operations_v1(owner_id,request_id,operation,payload,circle_id,circle_slug,media_id)
    values(v_uid,p_request_id,'media_prepare',v_payload,v_circle,p_slug,v_id);
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_media_finish_v1(p_request_id uuid,p_media_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1(); v_payload jsonb; v_existing jsonb;
  v_media public.bil_circle_media_v1%rowtype; v_slug text; v_old uuid;
begin
  v_payload:=jsonb_build_object('media_id',p_media_id);
  v_existing:=private.bil_circle_request_v1(p_request_id,'media_finish',v_payload);
  if v_existing is not null then return v_existing; end if;
  perform private.bil_circle_write_ready_v1();
  select * into v_media from public.bil_circle_media_v1 where id=p_media_id and owner_id=v_uid;
  if not found then raise exception 'circle_media_unavailable' using errcode='42501'; end if;
  select slug into v_slug from public.bil_community_circles where id=v_media.circle_id;
  perform private.bil_circle_lock_v1(v_slug);
  if not private.bil_circle_manager_v1(v_media.circle_id,true) then raise exception 'circle_manager_required' using errcode='42501'; end if;
  select * into v_media from public.bil_circle_media_v1 where id=p_media_id for update;
  if v_media.status not in ('reserved','published') then raise exception 'circle_media_cancelled' using errcode='55000'; end if;
  if v_media.status='reserved' then
    -- Storage's authoritative object metadata, not the client's upload return,
    -- proves presence + byte length + MIME type. Dimensions remain client reported.
    perform o.id from storage.objects o where o.bucket_id='community-circle-media' and o.name=v_media.object_path
      and o.owner_id=v_uid::text and o.metadata->>'size'=v_media.bytes::text and o.metadata->>'mimetype'=v_media.mime_type for share;
    if not found then raise exception 'circle_media_upload_unconfirmed' using errcode='55000'; end if;
    select case v_media.slot when 'avatar' then avatar_media_id else cover_media_id end into v_old
      from public.bil_circle_metadata_v1 where circle_id=v_media.circle_id for update;
    update public.bil_circle_media_v1 set status='published',updated_at=clock_timestamp() where id=v_media.id;
    update public.bil_circle_metadata_v1 set
      avatar_media_id=case when v_media.slot='avatar' then v_media.id else avatar_media_id end,
      cover_media_id=case when v_media.slot='cover' then v_media.id else cover_media_id end,
      updated_at=clock_timestamp() where circle_id=v_media.circle_id;
    if v_old is not null then update public.bil_circle_media_v1 set status='superseded',updated_at=clock_timestamp() where id=v_old; end if;
  end if;
  insert into public.bil_circle_operations_v1(owner_id,request_id,operation,payload,circle_id,circle_slug,media_id)
    values(v_uid,p_request_id,'media_finish',v_payload,v_media.circle_id,v_slug,v_media.id);
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_media_cancel_v1(p_request_id uuid,p_media_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid()); v_payload jsonb; v_existing jsonb;
  v_media public.bil_circle_media_v1%rowtype; v_slug text;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  -- Acquire canonical actor lock; cleanup of one's unfinished upload survives suspension.
  perform public.bil_can_use_community();
  v_payload:=jsonb_build_object('media_id',p_media_id);
  v_existing:=private.bil_circle_request_v1(p_request_id,'media_cancel',v_payload);
  if v_existing is not null then return v_existing; end if;
  select * into v_media from public.bil_circle_media_v1 where id=p_media_id;
  if not found then raise exception 'circle_media_unavailable' using errcode='42501'; end if;
  select slug into v_slug from public.bil_community_circles where id=v_media.circle_id;
  perform private.bil_circle_lock_v1(v_slug);
  select * into v_media from public.bil_circle_media_v1 where id=p_media_id for update;
  if v_media.status='published' or v_media.owner_id<>v_uid then
    perform private.bil_circle_write_ready_v1();
    if not private.bil_circle_manager_v1(v_media.circle_id,true) then raise exception 'circle_manager_required' using errcode='42501'; end if;
  end if;
  update public.bil_circle_metadata_v1 set
    avatar_media_id=case when avatar_media_id=v_media.id then null else avatar_media_id end,
    cover_media_id=case when cover_media_id=v_media.id then null else cover_media_id end,
    updated_at=clock_timestamp() where circle_id=v_media.circle_id and (avatar_media_id=v_media.id or cover_media_id=v_media.id);
  update public.bil_circle_media_v1 set status='cancelled',updated_at=clock_timestamp() where id=v_media.id and status<>'cancelled';
  insert into public.bil_circle_operations_v1(owner_id,request_id,operation,payload,circle_id,circle_slug,media_id)
    values(v_uid,p_request_id,'media_cancel',v_payload,v_media.circle_id,v_slug,v_media.id);
  return public.bil_circle_operation_v1(p_request_id);
end $$;

create function public.bil_circle_media_access_v1(p_object_path text,p_mode text,p_owner_id text default null,p_metadata jsonb default null)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid()); v_media public.bil_circle_media_v1%rowtype; v_slug text;
begin
  if v_uid is null or not exists(select 1 from auth.users where id=v_uid) or p_mode is null or p_mode not in ('read','insert','delete') then return false; end if;
  select * into v_media from public.bil_circle_media_v1 where object_path=p_object_path;
  if not found then return false; end if;
  if p_mode='read' then
    if v_media.owner_id=v_uid and v_media.status in ('reserved','cancelled','superseded') then return true; end if;
    return v_media.status='published' and private.bil_circle_visible_v1(v_media.circle_id)
      and exists(select 1 from public.bil_circle_metadata_v1 where circle_id=v_media.circle_id and (avatar_media_id=v_media.id or cover_media_id=v_media.id));
  end if;
  -- Same actor -> circle -> asset lock order as finish/cancel. This prevents an
  -- upload that checked 'reserved' from committing after cancellation.
  perform public.bil_can_use_community();
  select slug into v_slug from public.bil_community_circles where id=v_media.circle_id;
  perform private.bil_circle_lock_v1(v_slug);
  select * into v_media from public.bil_circle_media_v1 where id=v_media.id for update;
  if p_mode='delete' then
    return v_media.status in ('reserved','cancelled','superseded')
      and (v_media.owner_id=v_uid or private.bil_circle_manager_v1(v_media.circle_id,true))
      and not exists(select 1 from public.bil_circle_metadata_v1 where avatar_media_id=v_media.id or cover_media_id=v_media.id);
  end if;
  if v_media.owner_id<>v_uid or p_owner_id is distinct from v_uid::text or v_media.status<>'reserved'
    or p_metadata->>'size' is distinct from v_media.bytes::text or p_metadata->>'mimetype' is distinct from v_media.mime_type then return false; end if;
  begin
    perform private.bil_circle_write_ready_v1();
  exception when insufficient_privilege then return false;
  end;
  return private.bil_circle_manager_v1(v_media.circle_id,true);
end $$;

-- A private bucket for BOTH public and private circles. Never getPublicUrl().
-- Reservation rows authorize exact immutable paths; upsert/replacement is forbidden.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('community-circle-media','community-circle-media',false,5242880,array['image/jpeg','image/png','image/webp']);

create policy bil06_circle_media_select on storage.objects as permissive for select to authenticated
  using(bucket_id='community-circle-media' and public.bil_circle_media_access_v1(name,'read'));
create policy bil06_circle_media_select_gate on storage.objects as restrictive for select to authenticated
  using(bucket_id<>'community-circle-media' or public.bil_circle_media_access_v1(name,'read'));
create policy bil06_circle_media_insert on storage.objects as permissive for insert to authenticated
  with check(bucket_id='community-circle-media' and public.bil_circle_media_access_v1(name,'insert',owner_id,metadata));
create policy bil06_circle_media_insert_gate on storage.objects as restrictive for insert to authenticated
  with check(bucket_id<>'community-circle-media' or public.bil_circle_media_access_v1(name,'insert',owner_id,metadata));
create policy bil06_circle_media_update_gate on storage.objects as restrictive for update to authenticated
  using(bucket_id<>'community-circle-media') with check(bucket_id<>'community-circle-media');
create policy bil06_circle_media_delete on storage.objects as permissive for delete to authenticated
  using(bucket_id='community-circle-media' and public.bil_circle_media_access_v1(name,'delete'));
create policy bil06_circle_media_delete_gate on storage.objects as restrictive for delete to authenticated
  using(bucket_id<>'community-circle-media' or public.bil_circle_media_access_v1(name,'delete'));
-- Existing Storage grants are preserved. Every new permission is bucket scoped.

revoke all on function
  private.bil_circle_member_v1(),private.bil_circle_write_ready_v1(),private.bil_circle_manager_v1(uuid,boolean),
  private.bil_circle_invite_usable_v1(uuid),private.bil_circle_visible_v1(uuid),private.bil_circle_media_json_v1(uuid),
  private.bil_circle_projection_v1(uuid),private.bil_circle_invite_json_v1(uuid),private.bil_circle_request_v1(uuid,text,jsonb),private.bil_circle_lock_v1(text)
  from public,anon,authenticated,service_role;
revoke all on function
  public.bil_circle_operation_v1(uuid),public.bil_circle_capabilities_v1(text),public.bil_circle_membership_v1(text),
  public.bil_circle_search_v1(text,boolean,text,integer),public.bil_circle_read_v1(text),
  public.bil_circle_invites_v1(text,uuid,integer),public.bil_circle_invite_v1(uuid),
  public.bil_circle_create_v1(uuid,text,text,text,text,text),public.bil_circle_invite_send_v1(uuid,text,text),public.bil_circle_invite_action_v1(uuid,uuid,text),
  public.bil_circle_media_prepare_v1(uuid,text,text,text,integer,integer,integer),public.bil_circle_media_finish_v1(uuid,uuid),public.bil_circle_media_cancel_v1(uuid,uuid),
  public.bil_circle_media_access_v1(text,text,text,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function
  public.bil_circle_operation_v1(uuid),public.bil_circle_capabilities_v1(text),public.bil_circle_membership_v1(text),
  public.bil_circle_search_v1(text,boolean,text,integer),public.bil_circle_read_v1(text),
  public.bil_circle_invites_v1(text,uuid,integer),public.bil_circle_invite_v1(uuid),
  public.bil_circle_create_v1(uuid,text,text,text,text,text),public.bil_circle_invite_send_v1(uuid,text,text),public.bil_circle_invite_action_v1(uuid,uuid,text),
  public.bil_circle_media_prepare_v1(uuid,text,text,text,integer,integer,integer),public.bil_circle_media_finish_v1(uuid,uuid),public.bil_circle_media_cancel_v1(uuid,uuid),
  public.bil_circle_media_access_v1(text,text,text,jsonb)
  to authenticated;

do $postconditions$
declare v_relation regclass; v_function record;
begin
  foreach v_relation in array array['public.bil_circle_metadata_v1'::regclass,'public.bil_circle_invites_v1'::regclass,'public.bil_circle_media_v1'::regclass,'public.bil_circle_operations_v1'::regclass] loop
    if not (select relrowsecurity from pg_class where oid=v_relation)
      or has_table_privilege('anon',v_relation,'SELECT,INSERT,UPDATE,DELETE')
      or has_table_privilege('authenticated',v_relation,'SELECT,INSERT,UPDATE,DELETE')
      or has_table_privilege('service_role',v_relation,'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'bil06_table_acl_invalid' using errcode='55000';
    end if;
  end loop;
  for v_function in select p.oid,n.nspname,p.prosecdef,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname like 'bil_circle_%_v1' loop
    if not v_function.prosecdef or not (v_function.proconfig && array['search_path=','search_path=""'])
      or has_function_privilege('anon',v_function.oid,'EXECUTE') or has_function_privilege('service_role',v_function.oid,'EXECUTE')
      or has_function_privilege('authenticated',v_function.oid,'EXECUTE')<>(v_function.nspname='public') then
      raise exception 'bil06_function_acl_invalid' using errcode='55000';
    end if;
  end loop;
  if exists(select 1 from storage.buckets where id='community-circle-media' and public) then raise exception 'bil06_public_bucket_forbidden'; end if;
end
$postconditions$;
commit;
