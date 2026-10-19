-- Forward repair: genuine hosted Storage preflight used metadata without size.
-- Preserve immutable reservations, RLS, final authoritative metadata and review.
begin;
do $guard$
begin
  if md5(replace(pg_get_functiondef('public.bil_circle_media_access_v1(text,text,text,jsonb)'::regprocedure),chr(13)||chr(10),chr(10))) <> 'ff3e763a04c251e6fbcfaf6c673f5b4c' then
    raise exception 'circle_media_access_dependency_drift';
  end if;
end
$guard$;
create or replace function public.bil_circle_media_access_v1(p_object_path text,p_mode text,p_owner_id text default null,p_metadata jsonb default null)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid()); v_media public.bil_circle_media_v1%rowtype; v_slug text;
begin
  if v_uid is null or not exists(select 1 from auth.users where id=v_uid) or p_mode is null or p_mode not in ('read','insert','delete') then return false; end if;
  select * into v_media from public.bil_circle_media_v1 where object_path=p_object_path;
  if not found then return false; end if;
  if p_mode='read' then
    if v_media.owner_id=v_uid and v_media.status in ('reserved','pending','rejected','cancelled','superseded') then return true; end if;
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
    return v_media.status in ('reserved','rejected','cancelled','superseded')
      and (v_media.owner_id=v_uid or private.bil_circle_manager_v1(v_media.circle_id,true))
      and not exists(select 1 from public.bil_circle_metadata_v1 where avatar_media_id=v_media.id or cover_media_id=v_media.id);
  end if;
  if v_media.owner_id<>v_uid or p_owner_id is distinct from v_uid::text or v_media.status<>'reserved'
    or (p_metadata is not null and jsonb_typeof(p_metadata)<>'object')
    or (p_metadata ? 'size' and p_metadata->>'size' is distinct from v_media.bytes::text)
    or (p_metadata->>'contentLength' is not null and p_metadata->>'contentLength' is distinct from v_media.bytes::text)
    or (p_metadata ? 'mimetype' and p_metadata->>'mimetype' is distinct from v_media.mime_type) then return false; end if;
  -- Storage probes INSERT before bytes exist. Older versions omit metadata;
  -- current versions use contentLength instead of the final metadata.size.
  -- Reservation/owner/path/policy/manager checks still authorize only one asset.
  -- bil_circle_media_finish_v1 separately requires final size + MIME equality;
  -- the upload alone never publishes a Circle image or changes an approved slot.
  begin
    perform private.bil_circle_write_ready_v1();
  exception when insufficient_privilege then return false;
  end;
  return private.bil_circle_manager_v1(v_media.circle_id,true);
end $$;
commit;
