-- One immutable, owner-scoped publication intent survives lost RPC responses.
-- This journal is RPC-only. A receipt never substitutes for the live post.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

create table private.bil_community_publish_operations_v1 (
  operation_id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb,
  status text not null check (status in ('prepared','committed','aborted')),
  post_id uuid,
  committed_projection jsonb,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint bil_community_publish_operation_state_v1 check (
    (status='prepared' and payload is not null and post_id is null and committed_projection is null)
    or (status='committed' and payload is not null and post_id is not null and post_id=operation_id and committed_projection is not null)
    or (status='aborted' and post_id is null and committed_projection is null)
  )
);
alter table private.bil_community_publish_operations_v1 enable row level security;
revoke all on table private.bil_community_publish_operations_v1 from public,anon,authenticated,service_role;
create index bil_community_publish_operation_owner_v1
  on private.bil_community_publish_operations_v1(owner_id,created_at);
create index bil_community_publish_operation_prepared_v1
  on private.bil_community_publish_operations_v1(owner_id) where status='prepared';

create function private.bil_guard_community_publish_operation_v1()
returns trigger language plpgsql set search_path=''
as $$
begin
  if new.operation_id is distinct from old.operation_id
     or new.owner_id is distinct from old.owner_id
     or new.payload is distinct from old.payload
     or new.created_at is distinct from old.created_at
     or old.status<>'prepared'
     or new.status not in ('committed','aborted') then
    raise exception 'community_publish_operation_immutable' using errcode='42501';
  end if;
  return new;
end;
$$;
create trigger bil_community_publish_operation_immutable_v1
  before update on private.bil_community_publish_operations_v1
  for each row execute function private.bil_guard_community_publish_operation_v1();

-- Technical anti-abuse bound on NEW identifiers, including absent-abort
-- tombstones: 60/minute and 1000/rolling-24h per owner. Existing retries and
-- cancellation never spend this budget. No tombstone is expired/reused and
-- the existing genuine post quota is consumed only by its INSERT trigger.
create function private.bil_assert_community_publish_journal_budget_v1(p_owner uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare v_now timestamptz:=pg_catalog.clock_timestamp();
begin
  if (select count(*) from (select 1 from private.bil_community_publish_operations_v1
      where owner_id=p_owner and created_at>=v_now-interval '1 minute' limit 60) recent)>=60 then
    raise exception 'community_publish_new_operation_minute_limit' using errcode='54000';
  end if;
  if (select count(*) from (select 1 from private.bil_community_publish_operations_v1
      where owner_id=p_owner and created_at>=v_now-interval '24 hours' limit 1000) recent)>=1000 then
    raise exception 'community_publish_new_operation_day_limit' using errcode='54000';
  end if;
end;
$$;

create function private.bil_lock_community_publish_operation_v1(p_operation_id uuid)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_owner uuid:=(select auth.uid());
begin
  if v_owner is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_operation_id is null then
    raise exception 'invalid_community_publish_operation' using errcode='22023';
  end if;
  -- Original Storage RLS and canonical post/member guards acquire member_state
  -- first. Joining that order avoids a genuine Storage INSERT <-> begin RPC
  -- deadlock. Ignore the boolean here: a suspended owner must retain privacy
  -- cancellation/retry access; fresh publishing still asserts permission below.
  perform public.bil_can_use_community();
  -- Every begin/commit/abort/storage guard: member_state -> owner -> operation.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bil.community.publish.owner:'||v_owner::text,0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'bil.community.publish.operation:'||p_operation_id::text,0));
  return v_owner;
end;
$$;

create function private.bil_validate_community_publish_payload_v1(
  p_operation_id uuid,p_owner uuid,p_payload jsonb
)
returns void language plpgsql set search_path=''
as $$
declare
  v_key text;
  v_limit integer;
  v_item jsonb;
  v_media jsonb;
  v_mime text;
  v_path text;
  v_poll jsonb;
begin
  if p_payload is null or pg_catalog.jsonb_typeof(p_payload)<>'object'
     or pg_catalog.octet_length(p_payload::text)>65536
     or not (p_payload ?& array['body','media','topic_slugs','circle_slug',
       'location_label','mentioned_user_ids','title','hashtags',
       'collaborator_user_ids','poll','persistent_draft_id'])
     or (select count(*) from pg_catalog.jsonb_object_keys(p_payload))<>11
     or pg_catalog.jsonb_typeof(p_payload->'body')<>'string'
     or pg_catalog.char_length(pg_catalog.btrim(p_payload->>'body')) not between 1 and 1200 then
    raise exception 'invalid_community_publish_payload' using errcode='22023';
  end if;
  foreach v_key in array array['circle_slug','location_label','title','persistent_draft_id'] loop
    if pg_catalog.jsonb_typeof(p_payload->v_key) not in ('null','string') then
      raise exception 'invalid_community_publish_optional_text' using errcode='22023';
    end if;
  end loop;
  foreach v_key in array array['topic_slugs','mentioned_user_ids','hashtags','collaborator_user_ids'] loop
    v_limit:=case v_key when 'topic_slugs' then 3 when 'collaborator_user_ids' then 3 else 10 end;
    if pg_catalog.jsonb_typeof(p_payload->v_key)<>'array'
       or pg_catalog.jsonb_array_length(p_payload->v_key)>v_limit then
      raise exception 'invalid_community_publish_array' using errcode='22023';
    end if;
    if exists(select 1 from pg_catalog.jsonb_array_elements(p_payload->v_key) e
      where pg_catalog.jsonb_typeof(e)<>'string') then
      raise exception 'invalid_community_publish_array_item' using errcode='22023';
    end if;
    if v_key in ('mentioned_user_ids','collaborator_user_ids') then
      perform value::uuid from pg_catalog.jsonb_array_elements_text(p_payload->v_key);
    end if;
  end loop;
  if p_payload->>'persistent_draft_id' is not null then
    perform (p_payload->>'persistent_draft_id')::uuid;
  end if;
  v_media:=p_payload->'media';
  if pg_catalog.jsonb_typeof(v_media)<>'array' or pg_catalog.jsonb_array_length(v_media)>4 then
    raise exception 'invalid_community_publish_media' using errcode='22023';
  end if;
  for v_item in select value from pg_catalog.jsonb_array_elements(v_media) loop
    if pg_catalog.jsonb_typeof(v_item)<>'object'
       or not (v_item ?& array['object_path','mime_type','bytes','width','height'])
       or (select count(*) from pg_catalog.jsonb_object_keys(v_item))<>5
       or pg_catalog.jsonb_typeof(v_item->'object_path')<>'string'
       or pg_catalog.jsonb_typeof(v_item->'mime_type')<>'string'
       or pg_catalog.jsonb_typeof(v_item->'bytes')<>'number'
       or pg_catalog.jsonb_typeof(v_item->'width')<>'number'
       or pg_catalog.jsonb_typeof(v_item->'height')<>'number' then
      raise exception 'invalid_community_publish_media_item' using errcode='22023';
    end if;
    v_path:=v_item->>'object_path'; v_mime:=v_item->>'mime_type';
    if pg_catalog.split_part(v_path,'/',1)<>p_owner::text
       or pg_catalog.split_part(v_path,'/',2)<>p_operation_id::text
       or v_path !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(jpg|png|webp)$'
       or v_mime not in ('image/jpeg','image/png','image/webp')
       or (v_mime='image/jpeg' and pg_catalog.right(v_path,4)<>'.jpg')
       or (v_mime='image/png' and pg_catalog.right(v_path,4)<>'.png')
       or (v_mime='image/webp' and pg_catalog.right(v_path,5)<>'.webp')
       or (v_item->>'bytes')::numeric not between 1 and 5242880
       or (v_item->>'width')::numeric not between 1 and 8192
       or (v_item->>'height')::numeric not between 1 and 8192
       or (v_item->>'bytes')::numeric<>pg_catalog.trunc((v_item->>'bytes')::numeric)
       or (v_item->>'width')::numeric<>pg_catalog.trunc((v_item->>'width')::numeric)
       or (v_item->>'height')::numeric<>pg_catalog.trunc((v_item->>'height')::numeric)
       or (v_item->>'width')::numeric*(v_item->>'height')::numeric>40000000 then
      raise exception 'invalid_community_publish_media_item' using errcode='22023';
    end if;
  end loop;
  if (select count(distinct value->>'object_path') from pg_catalog.jsonb_array_elements(v_media))
       <>pg_catalog.jsonb_array_length(v_media) then
    raise exception 'duplicate_community_publish_media_path' using errcode='22023';
  end if;
  v_poll:=p_payload->'poll';
  if pg_catalog.jsonb_typeof(v_poll)<>'null' then
    if pg_catalog.jsonb_typeof(v_poll)<>'object'
       or not (v_poll ?& array['question','options','allow_multiple','closes_at'])
       or (select count(*) from pg_catalog.jsonb_object_keys(v_poll))<>4
       or pg_catalog.jsonb_typeof(v_poll->'question')<>'string'
       or pg_catalog.jsonb_typeof(v_poll->'options')<>'array'
       or pg_catalog.jsonb_array_length(v_poll->'options') not between 2 and 6
       or pg_catalog.jsonb_typeof(v_poll->'allow_multiple')<>'boolean'
       or pg_catalog.jsonb_typeof(v_poll->'closes_at') not in ('null','string')
       or exists(select 1 from pg_catalog.jsonb_array_elements(v_poll->'options') e
         where pg_catalog.jsonb_typeof(e)<>'string') then
      raise exception 'invalid_community_publish_poll' using errcode='22023';
    end if;
    if v_poll->>'closes_at' is not null then perform (v_poll->>'closes_at')::timestamptz; end if;
  end if;
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or datetime_field_overflow then
  raise exception 'invalid_community_publish_payload_value' using errcode='22023';
end;
$$;

-- Content only: human review, views, likes, votes and collaboration responses
-- may change after publication without pretending that the author changed it.
create function private.bil_community_publish_projection_v1(p_post_id uuid,p_owner uuid)
returns jsonb language sql security definer set search_path=''
as $$
  select pg_catalog.jsonb_build_object(
    'post',pg_catalog.jsonb_build_object('id',p.id,'author_id',p.author_id,
      'body',p.body,'title',p.title,'visibility',p.visibility,'location_label',p.location_label,
      'media_url',p.media_url,'media_object_path',p.media_object_path,'media_mime_type',p.media_mime_type,
      'media_bytes',p.media_bytes,'media_width',p.media_width,'media_height',p.media_height),
    'media',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'position',m.position,'object_path',m.object_path,'mime_type',m.mime_type,
      'bytes',m.bytes,'width',m.width,'height',m.height) order by m.position)
      from public.bil_community_post_media_v1 m where m.post_id=p.id),'[]'::jsonb),
    'storage',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'path',m.object_path,'object_id',o.id,'version',o.version,'etag',o.metadata->>'eTag',
      'owner_id',o.owner_id,'size',o.metadata->'size','mimetype',o.metadata->>'mimetype') order by m.position)
      from public.bil_community_post_media_v1 m left join storage.objects o
        on o.bucket_id='community-post-images' and o.name=m.object_path
      where m.post_id=p.id),'[]'::jsonb),
    'topics',coalesce((select pg_catalog.jsonb_agg(t.topic_id order by t.topic_id)
      from public.bil_community_post_topics t where t.post_id=p.id),'[]'::jsonb),
    'circles',coalesce((select pg_catalog.jsonb_agg(c.circle_id order by c.circle_id)
      from public.bil_community_post_circles c where c.post_id=p.id),'[]'::jsonb),
    'location',coalesce((select pg_catalog.jsonb_agg(l.label order by l.label)
      from public.bil_community_post_locations_v1 l where l.post_id=p.id),'[]'::jsonb),
    'mentions',coalesce((select pg_catalog.jsonb_agg(m.mentioned_user_id order by m.mentioned_user_id)
      from public.bil_community_post_mentions_v1 m where m.post_id=p.id),'[]'::jsonb),
    'hashtags',coalesce((select pg_catalog.jsonb_agg(h.hashtag order by h.hashtag)
      from public.bil_community_post_hashtags_v1 h where h.post_id=p.id),'[]'::jsonb),
    'collaborators',coalesce((select pg_catalog.jsonb_agg(c.collaborator_id order by c.collaborator_id)
      from public.bil_community_post_collaborators_v1 c where c.post_id=p.id),'[]'::jsonb),
    'poll',(select pg_catalog.jsonb_build_object('question',q.question,'allow_multiple',q.allow_multiple,
      'closes_at',q.closes_at,'options',(select pg_catalog.jsonb_agg(o.option_text order by o.position)
        from public.bil_community_poll_options o where o.post_id=p.id))
      from public.bil_community_polls q where q.post_id=p.id)
  ) from public.bil_community_posts p
  where p.id=p_post_id and p.author_id=p_owner and p.deleted_at is null;
$$;

create function private.bil_community_publish_receipt_v1(
  p_row private.bil_community_publish_operations_v1
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_projection jsonb; v_paths jsonb;
begin
  if p_row.owner_id is distinct from (select auth.uid()) then
    raise exception 'community_publish_operation_not_owned' using errcode='42501';
  end if;
  if p_row.status='committed' then
    -- The projection is one SQL statement / one MVCC snapshot. Do not take a
    -- post row lock here: legacy canonical delete/moderator UPDATE locks that
    -- row before its member-state trigger. Holding member then FOR SHARE here
    -- reproduced real deadlocks against BOTH genuine endpoints. The receipt
    -- attests current snapshot content, never that a post cannot change later.
    v_projection:=private.bil_community_publish_projection_v1(p_row.operation_id,p_row.owner_id);
    if v_projection is null or v_projection is distinct from p_row.committed_projection then
      -- A lost commit response followed by canonical owner deletion must not
      -- trap the device's durable journal forever. This is historical evidence
      -- only: NEVER a currently committed/publish-success or cleanup receipt.
      -- The user may explicitly abandon ONLY the local pending intent. Keep the
      -- server journal terminal/immutable and never return image cleanup paths.
      return pg_catalog.jsonb_build_object('operation_id',p_row.operation_id,
        'owner_id',p_row.owner_id,'status','unavailable','payload',p_row.payload,
        'post_id',p_row.operation_id,'committed',false,'aborted',false,
        'was_committed',true,'post_available',false,'cleanup_allowed',false,
        'media_paths','[]'::jsonb);
    end if;
  end if;
  select coalesce(pg_catalog.jsonb_agg(e.value->>'object_path' order by e.ord),'[]'::jsonb)
    into v_paths from pg_catalog.jsonb_array_elements(coalesce(p_row.payload->'media','[]'::jsonb))
      with ordinality e(value,ord);
  return pg_catalog.jsonb_build_object('operation_id',p_row.operation_id,'owner_id',p_row.owner_id,
    'status',p_row.status,'payload',p_row.payload,'post_id',p_row.post_id,
    'committed',p_row.status='committed','aborted',p_row.status='aborted','media_paths',v_paths);
end;
$$;

create function public.bil_begin_my_community_publish_operation_v1(p_operation_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_owner uuid; v_row private.bil_community_publish_operations_v1%rowtype;
begin
  v_owner:=private.bil_lock_community_publish_operation_v1(p_operation_id);
  select * into v_row from private.bil_community_publish_operations_v1
    where operation_id=p_operation_id for update;
  if found then
    if v_row.owner_id<>v_owner then
      raise exception 'community_publish_operation_not_owned' using errcode='42501';
    end if;
    if v_row.payload is not null and v_row.payload is distinct from p_payload then
      raise exception 'community_publish_payload_conflict' using errcode='22023';
    end if;
    return private.bil_community_publish_receipt_v1(v_row);
  end if;
  perform public.bil_assert_community_publish_ready();
  perform private.bil_validate_community_publish_payload_v1(p_operation_id,v_owner,p_payload);
  if exists(select 1 from public.bil_community_posts where id=p_operation_id) then
    raise exception 'community_publish_post_id_conflict' using errcode='23505';
  end if;
  if (select count(*) from private.bil_community_publish_operations_v1
      where owner_id=v_owner and status='prepared')>=8 then
    raise exception 'community_publish_prepared_limit' using errcode='54000';
  end if;
  perform private.bil_assert_community_publish_journal_budget_v1(v_owner);
  insert into private.bil_community_publish_operations_v1(operation_id,owner_id,payload,status)
    values(p_operation_id,v_owner,p_payload,'prepared') returning * into v_row;
  return private.bil_community_publish_receipt_v1(v_row);
end;
$$;

create function public.bil_publish_community_post_operation_v1(p_operation_id uuid,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_owner uuid; v_row private.bil_community_publish_operations_v1%rowtype;
  v_media jsonb; v_item jsonb; v_object storage.objects%rowtype; v_poll jsonb;
  v_projection jsonb; v_draft uuid;
begin
  v_owner:=private.bil_lock_community_publish_operation_v1(p_operation_id);
  select * into v_row from private.bil_community_publish_operations_v1
    where operation_id=p_operation_id for update;
  if not found or v_row.owner_id<>v_owner then
    raise exception 'community_publish_operation_not_owned' using errcode='42501';
  end if;
  if v_row.payload is null or v_row.payload is distinct from p_payload then
    raise exception 'community_publish_payload_conflict' using errcode='22023';
  end if;
  if v_row.status<>'prepared' then return private.bil_community_publish_receipt_v1(v_row); end if;
  perform public.bil_assert_community_publish_ready();
  perform private.bil_validate_community_publish_payload_v1(p_operation_id,v_owner,p_payload);
  v_media:=p_payload->'media';
  for v_item in select value from pg_catalog.jsonb_array_elements(v_media) loop
    select * into v_object from storage.objects o
      where o.bucket_id='community-post-images' and o.name=v_item->>'object_path' for share;
    if not found or v_object.owner_id is distinct from v_owner::text
       or v_object.is_delete_marker or v_object.archived_at is not null
       or pg_catalog.jsonb_typeof(v_object.metadata->'size') is distinct from 'number'
       or v_object.metadata->>'mimetype' is distinct from v_item->>'mime_type' then
      raise exception 'community_publish_media_unverified' using errcode='42501';
    end if;
    if (v_object.metadata->>'size')::numeric is distinct from (v_item->>'bytes')::numeric then
      raise exception 'community_publish_media_unverified' using errcode='42501';
    end if;
  end loop;
  -- Actual table triggers retain policy, post rate limit and human moderation.
  insert into public.bil_community_posts(id,author_id,body,visibility,moderation_status)
    values(p_operation_id,v_owner,pg_catalog.btrim(p_payload->>'body'),'community','pending');
  if pg_catalog.jsonb_array_length(v_media)>0 then
    perform public.bil_set_my_community_post_media_v1(p_operation_id,v_media);
  end if;
  perform public.bil_set_my_community_post_reference_metadata_v1(p_operation_id,
    p_payload->>'title',array(select value from pg_catalog.jsonb_array_elements_text(p_payload->'hashtags')),
    array(select value::uuid from pg_catalog.jsonb_array_elements_text(p_payload->'collaborator_user_ids')));
  perform public.bil_set_my_community_post_topics_v1(p_operation_id,
    array(select value from pg_catalog.jsonb_array_elements_text(p_payload->'topic_slugs')));
  perform public.bil_set_my_community_post_circle_v1(p_operation_id,p_payload->>'circle_slug');
  perform public.bil_set_my_community_post_context_v1(p_operation_id,p_payload->>'location_label',
    array(select value::uuid from pg_catalog.jsonb_array_elements_text(p_payload->'mentioned_user_ids')));
  v_poll:=p_payload->'poll';
  if pg_catalog.jsonb_typeof(v_poll)<>'null' then
    perform public.bil_create_my_community_poll_v1(p_operation_id,v_poll->>'question',
      array(select value from pg_catalog.jsonb_array_elements_text(v_poll->'options')),
      (v_poll->>'allow_multiple')::boolean,(v_poll->>'closes_at')::timestamptz);
  end if;
  v_draft:=(p_payload->>'persistent_draft_id')::uuid;
  if v_draft is not null then
    perform public.bil_consume_my_community_post_draft_v1(v_draft,p_operation_id);
  end if;
  v_projection:=private.bil_community_publish_projection_v1(p_operation_id,v_owner);
  if v_projection is null then raise exception 'community_publish_projection_unavailable'; end if;
  update private.bil_community_publish_operations_v1 set status='committed',post_id=p_operation_id,
    committed_projection=v_projection,updated_at=pg_catalog.clock_timestamp()
    where operation_id=p_operation_id and owner_id=v_owner and status='prepared' returning * into v_row;
  return private.bil_community_publish_receipt_v1(v_row);
end;
$$;

create function public.bil_abort_my_community_publish_operation_v1(p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_owner uuid; v_row private.bil_community_publish_operations_v1%rowtype;
begin
  -- Privacy cleanup does not require renewed policy acceptance or access.
  v_owner:=private.bil_lock_community_publish_operation_v1(p_operation_id);
  select * into v_row from private.bil_community_publish_operations_v1
    where operation_id=p_operation_id for update;
  if not found then
    -- A missing row is not a committed/absent success. Persist a tombstone so
    -- a delayed begin/commit/upload cannot revive this operation.
    if exists(select 1 from public.bil_community_posts where id=p_operation_id) then
      raise exception 'community_publish_post_id_conflict' using errcode='42501';
    end if;
    perform private.bil_assert_community_publish_journal_budget_v1(v_owner);
    insert into private.bil_community_publish_operations_v1(operation_id,owner_id,status)
      values(p_operation_id,v_owner,'aborted') returning * into v_row;
  elsif v_row.owner_id<>v_owner then
    raise exception 'community_publish_operation_not_owned' using errcode='42501';
  elsif v_row.status='prepared' then
    update private.bil_community_publish_operations_v1 set status='aborted',updated_at=pg_catalog.clock_timestamp()
      where operation_id=p_operation_id and owner_id=v_owner returning * into v_row;
  end if;
  -- Committed abort returns the same full, currently verified receipt.
  return private.bil_community_publish_receipt_v1(v_row);
end;
$$;

-- Original LIVE Storage INSERT+DELETE policies reproduced an approved-image
-- replacement without human review. Keep them intact; add a restrictive guard.
-- Storage INSERT takes the SAME member->owner->operation locks as RPCs.
-- Thus an abort cannot finish before an in-flight INSERT, and a late INSERT
-- cannot create orphaned media after an abort tombstone was acknowledged.
create function public.bil_guard_community_publish_image_insert_v1(p_path text,p_owner_id text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare v_owner uuid:=(select auth.uid()); v_operation uuid;
  v_row private.bil_community_publish_operations_v1%rowtype;
begin
  if v_owner is null or p_owner_id is distinct from v_owner::text
     or pg_catalog.split_part(p_path,'/',1) is distinct from v_owner::text
     or pg_catalog.split_part(p_path,'/',2) !~
       '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return false;
  end if;
  v_operation:=pg_catalog.split_part(p_path,'/',2)::uuid;
  perform private.bil_lock_community_publish_operation_v1(v_operation);
  -- Any existing post, including soft-deleted/pending/approved, makes the path
  -- immutable. Legacy clients still upload before their initial post INSERT.
  if exists(select 1 from public.bil_community_posts where id=v_operation) then return false; end if;
  select * into v_row from private.bil_community_publish_operations_v1
    where operation_id=v_operation;
  if not found then return true; end if; -- preserve pre-journal legacy uploads
  return v_row.owner_id=v_owner and v_row.status='prepared' and exists(
    select 1 from pg_catalog.jsonb_array_elements(v_row.payload->'media') e
    where e.value->>'object_path'=p_path);
end;
$$;
revoke all on function public.bil_guard_community_publish_image_insert_v1(text,text) from public,anon,authenticated,service_role;
grant execute on function public.bil_guard_community_publish_image_insert_v1(text,text) to authenticated;
create policy community_publish_image_operation_guard_v1 on storage.objects
  as restrictive for insert to authenticated
  with check(case when bucket_id='community-post-images'
    then public.bil_guard_community_publish_image_insert_v1(name,owner_id) else true end);

revoke all on function private.bil_lock_community_publish_operation_v1(uuid),
  private.bil_guard_community_publish_operation_v1(),
  private.bil_assert_community_publish_journal_budget_v1(uuid),
  private.bil_validate_community_publish_payload_v1(uuid,uuid,jsonb),
  private.bil_community_publish_projection_v1(uuid,uuid),
  private.bil_community_publish_receipt_v1(private.bil_community_publish_operations_v1)
  from public,anon,authenticated,service_role;
revoke all on function public.bil_begin_my_community_publish_operation_v1(uuid,jsonb),
  public.bil_publish_community_post_operation_v1(uuid,jsonb),
  public.bil_abort_my_community_publish_operation_v1(uuid) from public,anon,authenticated,service_role;
grant execute on function public.bil_begin_my_community_publish_operation_v1(uuid,jsonb),
  public.bil_publish_community_post_operation_v1(uuid,jsonb),
  public.bil_abort_my_community_publish_operation_v1(uuid) to authenticated;

commit;
