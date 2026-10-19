-- Included in the same transaction as reviewed Circle management. No public table grants.
create unique index bil_circle_one_pending_slot_v1 on public.bil_circle_media_v1(circle_id,slot) where status='pending';
create index bil_circle_pending_text_review_v1 on public.bil_circle_metadata_v1(created_at,circle_id) where review_status='pending';
create index bil_circle_metadata_creator_v1 on public.bil_circle_metadata_v1(created_by);
create table public.bil_circle_reports_v1 (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references public.bil_community_circles(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  created_at timestamptz not null default clock_timestamp(),
  reviewed_at timestamptz,reviewed_by uuid references auth.users(id) on delete set null
);
create unique index bil_circle_open_report_v1 on public.bil_circle_reports_v1(circle_id,reporter_id) where reviewed_at is null;
create index bil_circle_report_rate_v1 on public.bil_circle_reports_v1(reporter_id,created_at);
alter table public.bil_circle_reports_v1 enable row level security;
revoke all on public.bil_circle_reports_v1 from public,anon,authenticated,service_role;
create table private.bil_circle_review_decisions_v1 (
  actor_id uuid not null,operation_id uuid not null,request jsonb not null,receipt jsonb not null,
  created_at timestamptz not null default clock_timestamp(),primary key(actor_id,operation_id)
);
alter table private.bil_circle_review_decisions_v1 enable row level security;
revoke all on private.bil_circle_review_decisions_v1 from public,anon,authenticated,service_role;

create function public.bil_report_circle_v1(p_slug text,p_reason text)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=private.bil_circle_member_v1();v_circle uuid;v_id uuid;
begin
  if p_reason is null or char_length(btrim(p_reason)) not between 3 and 500 or translate(p_reason,E'\n\r\t','') ~ '[[:cntrl:]]' then raise exception 'invalid_circle_report' using errcode='22023';end if;
  select c.id into v_circle from public.bil_community_circles c where c.slug=p_slug and c.active and private.bil_circle_visible_v1(c.id);
  if v_circle is null then raise exception 'circle_unavailable' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended('circle_report:'||v_uid::text,0));
  select id into v_id from public.bil_circle_reports_v1 where circle_id=v_circle and reporter_id=v_uid and reviewed_at is null;
  if found then return v_id;end if;
  if (select count(*) from public.bil_circle_reports_v1 where reporter_id=v_uid and created_at>statement_timestamp()-interval '1 hour')>=20 then raise exception 'circle_report_rate_limited' using errcode='P0001';end if;
  insert into public.bil_circle_reports_v1(circle_id,reporter_id,reason) values(v_circle,v_uid,btrim(p_reason)) returning id into v_id;
  return v_id;
end $$;

create function public.bil_circle_review_queue_v1(p_limit integer default 100)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_result jsonb;
begin
  perform private.bil_lock_community_authority_v1();
  if p_limit is null or p_limit not between 1 and 200 then raise exception 'invalid_circle_review_limit' using errcode='22023';end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at,q.kind,q.id),'[]'::jsonb) into v_result from (
    select x.* from (
      select 'circle'::text kind,m.circle_id id,c.slug,m.display_name title,m.created_at from public.bil_circle_metadata_v1 m join public.bil_community_circles c on c.id=m.circle_id where m.review_status='pending' and m.created_by is distinct from v_actor
      union all
      select 'media',m.id,c.slug,meta.display_name,m.updated_at from public.bil_circle_media_v1 m join public.bil_community_circles c on c.id=m.circle_id join public.bil_circle_metadata_v1 meta on meta.circle_id=c.id where m.status='pending' and meta.review_status in ('pending','approved') and m.owner_id is distinct from v_actor and meta.created_by is distinct from v_actor
      union all
      select 'report',r.id,c.slug,coalesce(m.display_name,c.title_copy_key),r.created_at from public.bil_circle_reports_v1 r join public.bil_community_circles c on c.id=r.circle_id left join public.bil_circle_metadata_v1 m on m.circle_id=c.id where r.reviewed_at is null and m.created_by is distinct from v_actor
    ) x order by x.created_at,x.kind,x.id limit p_limit
  ) q;
  return v_result;
end $$;

create function public.bil_circle_review_content_v1(p_kind text,p_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_circle uuid;v_result jsonb;v_media public.bil_circle_media_v1%rowtype;v_meta public.bil_circle_metadata_v1%rowtype;v_base public.bil_community_circles%rowtype;v_report public.bil_circle_reports_v1%rowtype;v_images jsonb:='[]';
begin
  perform private.bil_lock_community_authority_v1();
  if p_kind not in ('circle','media','report') or p_kind is null or p_id is null then raise exception 'invalid_circle_review' using errcode='22023';end if;
  if p_kind='circle' then v_circle:=p_id;
  elsif p_kind='media' then select circle_id into v_circle from public.bil_circle_media_v1 where id=p_id;
  else select circle_id into v_circle from public.bil_circle_reports_v1 where id=p_id;end if;
  if v_circle is null then raise exception 'circle_review_unavailable' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended('bil06:circle:'||v_circle::text,0));
  select * into v_base from public.bil_community_circles where id=v_circle for share;
  select * into v_meta from public.bil_circle_metadata_v1 where circle_id=v_circle for share;
  if v_meta.created_by=v_actor then raise exception 'moderator_cannot_review_own_content' using errcode='42501';end if;
  if p_kind='circle' and v_meta.review_status is distinct from 'pending' then raise exception 'circle_review_unavailable' using errcode='42501';end if;
  if p_kind='media' then
    select * into v_media from public.bil_circle_media_v1 where id=p_id for share;
    if v_media.owner_id=v_actor then raise exception 'moderator_cannot_review_own_content' using errcode='42501';end if;
    if v_media.status is distinct from 'pending' or v_meta.review_status not in ('pending','approved') then raise exception 'circle_review_unavailable' using errcode='42501';end if;
    select coalesce(jsonb_agg(jsonb_build_object('id',v_media.id,'object_path',o.name,'mime_type',v_media.mime_type,'bytes',v_media.bytes,'width',v_media.width,'height',v_media.height,'object_id',o.id,'metadata',o.metadata)),'[]') into v_images from storage.objects o where o.bucket_id='community-circle-media' and o.name=v_media.object_path and o.owner_id=v_media.owner_id::text and o.metadata->>'size'=v_media.bytes::text and o.metadata->>'mimetype'=v_media.mime_type;
  elsif p_kind='report' then
    select * into v_report from public.bil_circle_reports_v1 where id=p_id for share;
    if v_report.reviewed_at is not null then raise exception 'circle_review_unavailable' using errcode='42501';end if;
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'object_path',m.object_path,'mime_type',m.mime_type,'bytes',m.bytes,'width',m.width,'height',m.height,'object_id',o.id,'metadata',o.metadata) order by m.slot),'[]') into v_images from public.bil_circle_media_v1 m join storage.objects o on o.bucket_id='community-circle-media' and o.name=m.object_path where m.circle_id=v_circle and m.status='published' and m.id in (v_meta.avatar_media_id,v_meta.cover_media_id);
  end if;
  v_result:=jsonb_build_object('kind',p_kind,'id',p_id,'circle_id',v_circle,'slug',v_base.slug,'circle',to_jsonb(v_base),'metadata',to_jsonb(v_meta),'media',case when p_kind='media' then to_jsonb(v_media) end,'report',case when p_kind='report' then jsonb_build_object('id',v_report.id,'reason',v_report.reason,'created_at',v_report.created_at) end,'images',v_images,'available',p_kind<>'media' or jsonb_array_length(v_images)=1);
  return v_result||jsonb_build_object('revision',encode(extensions.digest(v_result::text,'sha256'),'hex'));
end $$;

create function public.bil_decide_circle_review_v1(p_kind text,p_id uuid,p_expected_revision text,p_decision text,p_operation_id uuid,p_reason text default '')
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_request jsonb;v_prior private.bil_circle_review_decisions_v1%rowtype;v_snapshot jsonb;v_circle uuid;v_media public.bil_circle_media_v1%rowtype;v_old uuid;v_receipt jsonb;
begin
  perform private.bil_lock_community_authority_v1();
  if p_operation_id is null or p_expected_revision is null or p_expected_revision !~ '^[0-9a-f]{64}$' or p_reason is null or char_length(p_reason)>500 or translate(p_reason,E'\n\r\t','') ~ '[[:cntrl:]]' or p_decision is null or not ((p_kind in ('circle','media') and p_decision in ('approve','reject')) or (p_kind='report' and p_decision in ('remove','dismiss'))) or (p_decision='reject' and char_length(btrim(p_reason))<3) then raise exception 'invalid_circle_decision' using errcode='22023';end if;
  v_request:=jsonb_build_object('kind',p_kind,'id',p_id,'revision',p_expected_revision,'decision',p_decision,'reason',p_reason);
  perform pg_advisory_xact_lock(hashtextextended('circle_review_request:'||v_actor::text||':'||p_operation_id::text,0));
  select * into v_prior from private.bil_circle_review_decisions_v1 where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if v_prior.request is distinct from v_request then raise exception 'circle_review_request_conflict' using errcode='22023';end if;
    return v_prior.receipt||jsonb_build_object('duplicate',true);
  end if;
  v_snapshot:=public.bil_circle_review_content_v1(p_kind,p_id);v_circle:=(v_snapshot->>'circle_id')::uuid;
  if v_snapshot->>'revision' is distinct from p_expected_revision then raise exception 'circle_review_content_changed' using errcode='40001';end if;
  if p_decision='approve' and not (v_snapshot->>'available')::boolean then raise exception 'circle_review_media_missing' using errcode='55000';end if;
  if p_kind='circle' then
    update public.bil_circle_metadata_v1 set review_status=case when p_decision='approve' then 'approved' else 'rejected' end,reviewed_by=v_actor,reviewed_at=clock_timestamp(),review_reason=p_reason where circle_id=v_circle;
    update public.bil_community_circles set active=p_decision='approve',updated_at=clock_timestamp() where id=v_circle;
  elsif p_kind='media' then
    select * into v_media from public.bil_circle_media_v1 where id=p_id for update;
    if p_decision='approve' then
      select case v_media.slot when 'avatar' then avatar_media_id else cover_media_id end into v_old from public.bil_circle_metadata_v1 where circle_id=v_circle for update;
      update public.bil_circle_metadata_v1 set avatar_media_id=case when v_media.slot='avatar' then v_media.id else avatar_media_id end,cover_media_id=case when v_media.slot='cover' then v_media.id else cover_media_id end,updated_at=clock_timestamp() where circle_id=v_circle;
      if v_old is not null then update public.bil_circle_media_v1 set status='superseded',updated_at=clock_timestamp() where id=v_old;end if;
    end if;
    update public.bil_circle_media_v1 set status=case when p_decision='approve' then 'published' else 'rejected' end,updated_at=clock_timestamp() where id=p_id;
  else
    if p_decision='remove' then
      update public.bil_community_circles set active=false,updated_at=clock_timestamp() where id=v_circle;
      update public.bil_circle_metadata_v1 set review_status='removed',reviewed_at=clock_timestamp(),reviewed_by=v_actor,review_reason=p_reason where circle_id=v_circle;
    end if;
    update public.bil_circle_reports_v1 set reviewed_at=clock_timestamp(),reviewed_by=v_actor where id=p_id;
  end if;
  v_receipt:=jsonb_build_object('kind',p_kind,'id',p_id,'circle_id',v_circle,'decision',p_decision,'operation_id',p_operation_id,'duplicate',false);
  insert into private.bil_circle_review_decisions_v1(actor_id,operation_id,request,receipt) values(v_actor,p_operation_id,v_request,v_receipt);
  return v_receipt;
end $$;

revoke all on function public.bil_report_circle_v1(text,text),public.bil_circle_review_queue_v1(integer),public.bil_circle_review_content_v1(text,uuid),public.bil_decide_circle_review_v1(text,uuid,text,text,uuid,text) from public,anon,service_role;
grant execute on function public.bil_report_circle_v1(text,text),public.bil_circle_review_queue_v1(integer),public.bil_circle_review_content_v1(text,uuid),public.bil_decide_circle_review_v1(text,uuid,text,text,uuid,text) to authenticated;
