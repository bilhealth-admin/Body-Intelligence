-- Prepared locally only: no Production deployment or live moderation is authorized.
-- Additive report-review contract. Keep the 32/35 RPC signatures and outcomes.
-- Source review: Supabase RLS/functions/migrations docs, 2026-10-13.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

create function private.bil_lock_community_admin_v1(p_actor uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' or p_actor is null then
    raise exception 'administrator_required' using errcode='42501';
  end if;
  perform 1 from private.bil_ai_coach_admins a
    where a.user_id=p_actor and a.active for share;
  if not found then raise exception 'administrator_required' using errcode='42501'; end if;
end $$;
revoke all on function private.bil_lock_community_admin_v1(uuid)
  from public,anon,authenticated,service_role;

create function private.bil_lock_community_authority_v1()
returns text language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode='42501';
  end if;
  perform 1 from private.bil_ai_coach_admins a
    where a.user_id=v_actor and a.active for share;
  if found then return 'admin'; end if;
  perform 1 from public.bil_community_moderators m where m.user_id=v_actor for share;
  if found then return 'moderator'; end if;
  raise exception 'moderator_or_administrator_required' using errcode='42501';
end $$;
revoke all on function private.bil_lock_community_authority_v1()
  from public,anon,authenticated,service_role;

-- Admission and withdrawal serialize on the existing authority row. Existing
-- authorized requests finish before revocation; withdrawal committed first denies.
-- No new membership, grant, subscription or client actor claim is introduced.
do $authority$
declare v_signature text; v_oid regprocedure; v_definition text; v_call text;
begin
  foreach v_signature in array array[
    'public.bil_add_community_moderator_by_email(uuid,text,text)',
    'public.bil_remove_community_moderator(uuid,uuid,text)',
    'public.bil_suspend_community_member_by_email(uuid,text,text,text)',
    'public.bil_reinstate_community_member(uuid,uuid,text)',
    'public.bil_moderate_community_post(uuid,text)',
    'public.bil_moderate_published_community_post(uuid,text,text)',
    'public.bil_moderate_community_report(uuid,text,text)',
    'public.bil_social_resolve_comment_report_v2(uuid,boolean)'
  ] loop
    v_oid:=to_regprocedure(v_signature);
    if v_oid is null then raise exception 'community_safety_dependency_missing: %',v_signature; end if;
    v_definition:=pg_get_functiondef(v_oid);
    v_call:=case when v_signature in (
      'public.bil_add_community_moderator_by_email(uuid,text,text)',
      'public.bil_remove_community_moderator(uuid,uuid,text)',
      'public.bil_suspend_community_member_by_email(uuid,text,text,text)',
      'public.bil_reinstate_community_member(uuid,uuid,text)'
    ) then 'perform private.bil_lock_community_admin_v1(p_actor_id);'
      else 'perform private.bil_lock_community_authority_v1();' end;
    if strpos(v_definition,v_call)=0 then
      if v_definition !~* E'\nBEGIN[[:space:]]*\n' then
        raise exception 'community_safety_definition_changed: %',v_signature;
      end if;
      execute regexp_replace(v_definition,E'(\nBEGIN[[:space:]]*\n)',
        E'\\1  '||v_call||E'\n','i');
    end if;
  end loop;
end $authority$;

create table private.bil_community_report_decisions_v1 (
  actor_id uuid not null, operation_id uuid not null, report_id uuid not null,
  source text not null check(source in ('community','comment')),
  request jsonb not null, receipt jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,operation_id)
);
alter table private.bil_community_report_decisions_v1 enable row level security;
revoke all on table private.bil_community_report_decisions_v1
  from public,anon,authenticated,service_role;

-- Return only the referenced content of an open report, never an entire chat,
-- health profile, reporter identity, administrative notes or account address.
create function private.bil_report_content_v1(p_report_id uuid,p_source text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_target uuid; v_kind text; v_reason text; v_status text;
  v_body text; v_parent_body text; v_owner uuid; v_available boolean:=false;
  v_post jsonb; v_media jsonb; v_poll jsonb; v_record jsonb; v_row record;
begin
  if p_report_id is null or p_source is null or p_source not in ('community','comment') then
    raise exception 'invalid_report_review' using errcode='22023';
  end if;
  -- Same report-first lock order as the retained legacy resolution RPCs.
  if p_source='comment' then
    select * into v_row from public.bil_social_comment_reports_v2
      where id=p_report_id for update;
    if not found or v_row.reviewed_at is not null then
      raise exception 'report_unavailable' using errcode='42501';
    end if;
    v_target:=v_row.comment_id; v_reason:=v_row.reason; v_status:='open';
    select * into v_row from public.bil_social_comments_v2 where id=v_target for update;
    if not found then raise exception 'report_unavailable' using errcode='42501'; end if;
    v_owner:=v_row.author_id;
    v_kind:=case when v_row.parent_id is null then 'comment' else 'reply' end;
    v_available:=v_row.deleted_at is null and v_row.removed_at is null;
    if v_available then
      v_body:=v_row.body;
      if v_row.parent_id is not null then
        select c.body into v_parent_body from public.bil_social_comments_v2 c
          where c.id=v_row.parent_id and c.post_id=v_row.post_id
            and c.deleted_at is null and c.removed_at is null for share;
      end if;
    end if;
  else
    select * into v_row from public.bil_community_reports where id=p_report_id for update;
    if not found or v_row.status not in ('open','reviewing') then
      raise exception 'report_unavailable' using errcode='42501';
    end if;
    v_target:=v_row.target_id; v_kind:=v_row.target_kind;
    v_reason:=v_row.reason; v_status:=v_row.status;
    if v_kind='post' then
      select * into v_row from public.bil_community_posts where id=v_target for update;
      if found then
        v_owner:=v_row.author_id; v_available:=v_row.deleted_at is null;
        if v_available then
          v_body:=v_row.body;
          v_post:=jsonb_build_object('id',v_row.id,'author_id',v_row.author_id,
            'body',v_row.body,'created_at',v_row.created_at,'visibility',v_row.visibility,
            'moderation_status',v_row.moderation_status,'moderation_visibility',v_row.moderation_visibility,
            'media_object_path',v_row.media_object_path,'media_mime_type',v_row.media_mime_type,
            'media_bytes',v_row.media_bytes,'media_width',v_row.media_width,'media_height',v_row.media_height);
          -- Freeze every existing reviewed component; the parent FOR UPDATE
          -- also excludes concurrent child inserts through its foreign keys.
          perform 1 from public.bil_community_post_media_v1 m
            where m.post_id=v_target order by m.position for update;
          perform 1 from public.bil_community_polls p where p.post_id=v_target for update;
          perform 1 from public.bil_community_poll_options o
            where o.post_id=v_target order by o.position for update;
          select coalesce(jsonb_agg(to_jsonb(m) order by m.position),'[]'::jsonb) into v_media
            from public.bil_community_post_media_v1 m where m.post_id=v_target;
          select jsonb_build_object('poll',to_jsonb(p),'options',coalesce((
            select jsonb_agg(to_jsonb(o) order by o.position)
              from public.bil_community_poll_options o where o.post_id=v_target),'[]'::jsonb))
            into v_poll from public.bil_community_polls p where p.post_id=v_target;
        end if;
      end if;
    elsif v_kind='message' then
      select * into v_row from public.bil_messages where id=v_target for update;
      if found then
        v_owner:=v_row.sender_id;
        v_available:=v_row.deleted_by_sender_at is null and v_row.deleted_by_recipient_at is null;
        if v_available then v_body:=v_row.body; end if;
      end if;
    elsif v_kind='food' then
      select * into v_row from public.bil_community_food_submissions where id=v_target for share;
      if found then v_owner:=v_row.contributor_id; v_body:=v_row.canonical_name; v_available:=true; end if;
    elsif v_kind='profile' then
      select * into v_row from public.bil_public_profiles where user_id=v_target for share;
      if found then v_owner:=v_row.user_id; v_body:=v_row.display_name||coalesce(E'\n'||v_row.bio,''); v_available:=true; end if;
    else
      raise exception 'report_target_unsupported' using errcode='22023';
    end if;
  end if;
  if v_owner=v_actor then raise exception 'moderator_cannot_review_own_content' using errcode='42501'; end if;
  v_record:=jsonb_build_object('contract_version',1,'report_id',p_report_id,'source',p_source,
    'target_id',v_target,'target_kind',v_kind,'reason',v_reason,'status',v_status,
    'available',v_available,'body',v_body,'parent_body',v_parent_body,'post',v_post,
    'can_remove',v_available and v_kind in ('post','message','comment','reply'));
  return v_record||jsonb_build_object('revision',encode(sha256(convert_to(
    (v_record||jsonb_build_object('media',v_media,'poll',v_poll))::text,'UTF8')),'hex'));
end $$;
revoke all on function private.bil_report_content_v1(uuid,text)
  from public,anon,authenticated,service_role;

create function public.bil_community_report_content_v1(p_report_id uuid,p_source text default 'community')
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.bil_lock_community_authority_v1();
  return private.bil_report_content_v1(p_report_id,p_source);
end $$;
revoke all on function public.bil_community_report_content_v1(uuid,text)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_community_report_content_v1(uuid,text) to authenticated;

create function public.bil_decide_community_report_v1(
  p_report_id uuid,p_source text,p_expected_revision text,p_remove boolean,p_operation_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request jsonb; v_prior record; v_snapshot jsonb;
  v_receipt jsonb; v_closed boolean; v_removed boolean:=false;
begin
  perform private.bil_lock_community_authority_v1();
  if p_operation_id is null or p_remove is null or p_expected_revision is null
     or p_expected_revision !~ '^[0-9a-f]{64}$' or p_report_id is null
     or p_source is null or p_source not in ('community','comment') then
    raise exception 'invalid_report_decision' using errcode='22023';
  end if;
  v_request:=jsonb_build_object('report_id',p_report_id,'source',p_source,
    'revision',p_expected_revision,'remove',p_remove);
  perform pg_advisory_xact_lock(hashtextextended('community-report:'||v_actor::text||':'||p_operation_id::text,0));
  select * into v_prior from private.bil_community_report_decisions_v1
    where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if v_prior.request<>v_request then raise exception 'idempotency_conflict' using errcode='22023'; end if;
    return v_prior.receipt||jsonb_build_object('duplicate',true);
  end if;
  v_snapshot:=private.bil_report_content_v1(p_report_id,p_source);
  if v_snapshot->>'revision'<>p_expected_revision then
    raise exception 'community_report_content_changed' using errcode='40001';
  end if;
  if p_remove and not (v_snapshot->>'can_remove')::boolean then
    raise exception 'reported_content_cannot_be_removed' using errcode='22023';
  end if;
  if p_source='comment' then
    perform public.bil_social_resolve_comment_report_v2(p_report_id,p_remove);
    select reviewed_at is not null into v_closed from public.bil_social_comment_reports_v2 where id=p_report_id;
    if p_remove then
      select removed_at is not null into v_removed from public.bil_social_comments_v2
        where id=(v_snapshot->>'target_id')::uuid;
    end if;
  else
    perform public.bil_moderate_community_report(p_report_id,'closed',case when p_remove then 'remove_content' else 'none' end);
    select status='closed' into v_closed from public.bil_community_reports where id=p_report_id;
    if p_remove and v_snapshot->>'target_kind'='post' then
      select deleted_at is not null into v_removed from public.bil_community_posts where id=(v_snapshot->>'target_id')::uuid;
    elsif p_remove and v_snapshot->>'target_kind'='message' then
      select deleted_by_sender_at is not null and deleted_by_recipient_at is not null
        into v_removed from public.bil_messages where id=(v_snapshot->>'target_id')::uuid;
    end if;
  end if;
  if v_closed is distinct from true or (p_remove and v_removed is distinct from true) then
    raise exception 'report_decision_readback_failed';
  end if;
  v_receipt:=jsonb_build_object('contract_version',1,'report_id',p_report_id,'source',p_source,
    'target_id',v_snapshot->>'target_id','reviewed_revision',p_expected_revision,
    'operation_id',p_operation_id,'status','closed','content_removed',v_removed,
    'duplicate',false,'receipt_state','executed');
  insert into private.bil_community_report_decisions_v1(actor_id,operation_id,report_id,source,request,receipt)
    values(v_actor,p_operation_id,p_report_id,p_source,v_request,v_receipt);
  return v_receipt;
end $$;
revoke all on function public.bil_decide_community_report_v1(uuid,text,text,boolean,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_decide_community_report_v1(uuid,text,text,boolean,uuid) to authenticated;

create function public.bil_get_community_report_decision_v1(p_operation_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_receipt jsonb;
begin
  perform private.bil_lock_community_authority_v1();
  select receipt into v_receipt from private.bil_community_report_decisions_v1
    where actor_id=auth.uid() and operation_id=p_operation_id;
  if not found then raise exception 'report_receipt_unavailable' using errcode='42501'; end if;
  return v_receipt;
end $$;
revoke all on function public.bil_get_community_report_decision_v1(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_get_community_report_decision_v1(uuid) to authenticated;

-- Own block rows only. A label needed to manage an existing block does not
-- expose the target's private profile, address, avatar or health information.
create function public.bil_my_blocked_members_v1()
returns table(blocked_id uuid,created_at timestamptz,display_name text)
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  return query select b.blocked_id,b.created_at,p.display_name from public.bil_blocks b
    left join public.bil_public_profiles p on p.user_id=b.blocked_id
    where b.blocker_id=auth.uid() order by b.created_at desc,b.blocked_id;
end $$;
revoke all on function public.bil_my_blocked_members_v1() from public,anon,authenticated,service_role;
grant execute on function public.bil_my_blocked_members_v1() to authenticated;
commit;
