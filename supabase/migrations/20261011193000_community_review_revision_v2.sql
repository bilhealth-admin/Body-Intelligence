-- Additive, unpublished. Legacy 32/35 RPCs, reward policy and store rights stay
-- intact. New clients require a reviewed revision; no new role is inferred
-- from Premium/credits. Publish-only remains disabled until an owner decision.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$ begin
  if to_regprocedure('public.bil_moderate_community_post(uuid,text)') is null
     or to_regprocedure('private.bil_resolve_community_moderation_authority(uuid)') is null
     or to_regclass('public.bil_community_post_media_v1') is null
     or to_regclass('public.bil_community_polls') is null
     or to_regclass('public.bil_community_poll_options') is null then
    raise exception 'community_review_v2_dependencies_missing';
  end if;
end $$;

create table private.bil_community_review_versions_v2 (
  post_id uuid primary key,
  revision bigint not null check (revision > 0)
);
-- No content is retained. The counter survives deletion/recreation of an ID.
alter table private.bil_community_review_versions_v2 enable row level security;
revoke all on table private.bil_community_review_versions_v2
  from public,anon,authenticated,service_role;

create table private.bil_community_review_policy_v2 (
  singleton boolean primary key default true check (singleton),
  allow_publish_only boolean not null default false
);
insert into private.bil_community_review_policy_v2 values(true,false);
alter table private.bil_community_review_policy_v2 enable row level security;
revoke all on table private.bil_community_review_policy_v2
  from public,anon,authenticated,service_role;

create table private.bil_community_review_operations_v2 (
  -- Immutable audit identities, not active memberships or cached user content.
  -- No FK may block account deletion or erase an idempotency receipt.
  actor_id uuid not null,
  operation_id uuid not null,
  post_id uuid not null,
  owner_id uuid not null,
  payload jsonb not null,
  receipt jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,operation_id)
);
alter table private.bil_community_review_operations_v2 enable row level security;
revoke all on table private.bil_community_review_operations_v2
  from public,anon,authenticated,service_role;
create index bil_community_review_operations_post_v2
  on private.bil_community_review_operations_v2(post_id,created_at);

create function private.bil_review_authority_lock_v2()
returns text language plpgsql security definer set search_path='' as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'authentication_required' using errcode='42501'; end if;
  perform 1 from private.bil_ai_coach_admins a
    where a.user_id=v_actor and a.active for share;
  if found then return 'admin'; end if;
  perform 1 from public.bil_community_moderators m
    where m.user_id=v_actor for share;
  if found then return 'moderator'; end if;
  raise exception 'community_moderator_required' using errcode='42501';
end $$;
revoke all on function private.bil_review_authority_lock_v2()
  from public,anon,authenticated,service_role;

create function private.bil_touch_review_version_v2()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_post uuid; v_parent public.bil_community_posts%rowtype;
begin
  if tg_table_name='bil_community_posts' then
    v_post := coalesce(new.id,old.id);
    if tg_op='UPDATE' and
       (to_jsonb(new)-array['moderation_status','reviewed_at','moderation_visibility'])=
       (to_jsonb(old)-array['moderation_status','reviewed_at','moderation_visibility']) then
      return new;
    end if;
  else
    v_post := coalesce(new.post_id,old.post_id);
    if tg_op='UPDATE' and new.post_id<>old.post_id then
      raise exception 'community_review_content_reparent_forbidden';
    end if;
    -- Child content edits and a moderation decision share the parent lock.
    select * into v_parent from public.bil_community_posts p where p.id=v_post for update;
    -- Recheck after acquiring the lock. A legacy owner RPC may have checked
    -- Pending before waiting while a moderator completed approval meanwhile.
    if found and auth.uid()=v_parent.author_id and tg_op<>'DELETE'
       and (v_parent.deleted_at is not null or v_parent.moderation_status<>'pending') then
      raise exception 'community_review_content_not_editable' using errcode='42501';
    end if;
  end if;
  insert into private.bil_community_review_versions_v2(post_id,revision)
    values(v_post,1) on conflict(post_id) do update
    set revision=private.bil_community_review_versions_v2.revision+1;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function private.bil_touch_review_version_v2()
  from public,anon,authenticated,service_role;

create trigger bil_review_post_version_v2 after insert or update or delete
  on public.bil_community_posts for each row
  execute function private.bil_touch_review_version_v2();
create trigger bil_review_media_version_v2 before insert or update or delete
  on public.bil_community_post_media_v1 for each row
  execute function private.bil_touch_review_version_v2();
create trigger bil_review_poll_version_v2 before insert or update or delete
  on public.bil_community_polls for each row
  execute function private.bil_touch_review_version_v2();
create trigger bil_review_option_version_v2 before insert or update or delete
  on public.bil_community_poll_options for each row
  execute function private.bil_touch_review_version_v2();

create function private.bil_review_version_v2(p_post_id uuid,p_owner_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select encode(sha256(convert_to(p_post_id::text||':'||p_owner_id::text||':'||
    coalesce((select revision::text from private.bil_community_review_versions_v2
      where post_id=p_post_id),'0'),'UTF8')),'hex')
$$;
revoke all on function private.bil_review_version_v2(uuid,uuid)
  from public,anon,authenticated,service_role;

create function public.bil_community_review_snapshots_v2(p_post_ids uuid[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_rows jsonb;
begin
  v_role := private.bil_review_authority_lock_v2();
  if p_post_ids is null or cardinality(p_post_ids)>100 then
    raise exception 'invalid_community_review_batch' using errcode='22023';
  end if;
  -- The returned post and revision come from the same locked snapshot.
  perform 1 from public.bil_community_posts p
    where p.id=any(p_post_ids) and p.deleted_at is null order by p.id for share;
  select coalesce(jsonb_agg(jsonb_build_object(
    'post',to_jsonb(p),
    'revision',private.bil_review_version_v2(p.id,p.author_id),
    'can_publish_only',v_role='admin' and exists(
      select 1 from private.bil_community_review_policy_v2 where allow_publish_only)
  ) order by p.id),'[]'::jsonb) into v_rows
  from public.bil_community_posts p where p.id=any(p_post_ids) and p.deleted_at is null;
  return v_rows;
end $$;
revoke all on function public.bil_community_review_snapshots_v2(uuid[])
  from public,anon,authenticated,service_role;
grant execute on function public.bil_community_review_snapshots_v2(uuid[])
  to authenticated;

create function public.bil_moderate_community_post_v2(
  p_post_id uuid,p_expected_revision text,p_decision text,
  p_operation_id uuid,p_reason text default '',p_reward_mode text default 'eligible'
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid := auth.uid(); v_role text; v_post public.bil_community_posts%rowtype;
  v_payload jsonb; v_prior private.bil_community_review_operations_v2%rowtype;
  v_result jsonb; v_revision text;
begin
  v_role := private.bil_review_authority_lock_v2();
  if p_operation_id is null or p_post_id is null or p_expected_revision is null
     or p_expected_revision !~ '^[0-9a-f]{64}$'
     or p_decision not in ('approved','rejected') or p_decision is null
     or p_reward_mode not in ('eligible','deferred') or p_reward_mode is null
     or char_length(coalesce(p_reason,''))>160 or p_reason ~ '[[:cntrl:]]'
     or (p_decision='rejected' and btrim(coalesce(p_reason,''))='') then
    raise exception 'invalid_community_review_decision' using errcode='22023';
  end if;
  if p_reward_mode='deferred' and (p_decision<>'approved' or v_role<>'admin'
      or not exists(select 1 from private.bil_community_review_policy_v2
        where allow_publish_only)) then
    raise exception 'community_publish_only_not_authorized' using errcode='42501';
  end if;
  v_payload := jsonb_build_object('post_id',p_post_id,'revision',p_expected_revision,
    'decision',p_decision,'reason',coalesce(p_reason,''),'reward_mode',p_reward_mode);
  perform pg_advisory_xact_lock(hashtextextended(v_actor::text||':'||p_operation_id::text,112));
  select * into v_prior from private.bil_community_review_operations_v2
    where actor_id=v_actor and operation_id=p_operation_id;
  if found then
    if v_prior.payload<>v_payload then raise exception 'idempotency_conflict' using errcode='22023'; end if;
    return v_prior.receipt||jsonb_build_object('duplicate',true,'tokens_granted',0);
  end if;
  select * into v_post from public.bil_community_posts where id=p_post_id for update;
  if not found or v_post.deleted_at is not null then
    raise exception 'community_post_not_found' using errcode='22023';
  end if;
  if v_post.author_id=v_actor then raise exception 'cannot_review_own_post' using errcode='42501'; end if;
  v_revision := private.bil_review_version_v2(v_post.id,v_post.author_id);
  if v_revision<>p_expected_revision then
    raise exception 'community_review_content_changed' using errcode='40001';
  end if;
  if p_reward_mode='eligible' then
    -- Same legacy policy/unique receipt/balance transaction; no second award
    -- trigger and no caller-supplied beneficiary, amount or administrative role.
    v_result := public.bil_moderate_community_post(p_post_id,p_decision);
  else
    if v_post.moderation_status<>'pending' then
      raise exception 'community_post_already_reviewed' using errcode='22023';
    end if;
    update public.bil_community_posts set moderation_status='approved',reviewed_at=now()
      where id=p_post_id;
    v_result := jsonb_build_object('post_id',p_post_id,'decision','approved',
      'duplicate',false,'tokens_granted',0,'reward_reason','deferred');
    -- Existing durable dispatcher, separate from any financial action. Retry
    -- of delivery cannot re-enter moderation or add a second base reward.
    insert into public.bil_push_outbox(recipient_id,category,body,deep_link,source_key)
      values(v_post.author_id,'community',
        'تم اعتماد منشورك. لم تُنفّذ مكافأة بعد. Post approved; no reward has been issued yet.',
        'bil://community','post-published-only-v2:'||v_post.id::text)
      on conflict do nothing;
  end if;
  v_result := v_result||jsonb_build_object('contract_version',2,
    'reviewed_revision',v_revision,'owner_id',v_post.author_id,
    'reward_mode',p_reward_mode,'receipt_state','executed');
  insert into private.bil_community_review_operations_v2
    (actor_id,operation_id,post_id,owner_id,payload,receipt)
    values(v_actor,p_operation_id,p_post_id,v_post.author_id,v_payload,v_result);
  return v_result;
end $$;
revoke all on function public.bil_moderate_community_post_v2(uuid,text,text,uuid,text,text)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_moderate_community_post_v2(uuid,text,text,uuid,text,text)
  to authenticated;

-- A pending request is not a credit balance or an executed award. This ledger
-- is RPC-only; it cannot be edited by a content moderator or a service client.
create table private.bil_community_post_reward_requests_v2 (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null unique,
  owner_id uuid not null,
  requested_by uuid not null,
  reviewed_revision text not null,
  status text not null default 'requested'
    check(status in ('requested','executed','rejected','not_eligible')),
  reason text not null default '',
  decided_by uuid,
  receipt jsonb,
  created_at timestamptz not null default clock_timestamp(),
  decided_at timestamptz
);
alter table private.bil_community_post_reward_requests_v2 enable row level security;
revoke all on table private.bil_community_post_reward_requests_v2
  from public,anon,authenticated,service_role;

create function public.bil_request_community_post_reward_v2(
  p_post_id uuid,p_expected_revision text
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_post public.bil_community_posts%rowtype;
  v_request private.bil_community_post_reward_requests_v2%rowtype;
  v_grant public.bil_community_post_approval_grants%rowtype;
begin
  perform private.bil_review_authority_lock_v2();
  select * into v_post from public.bil_community_posts where id=p_post_id for update;
  if not found or v_post.deleted_at is not null
     or v_post.moderation_status<>'approved'
     or v_post.moderation_visibility<>'visible' then
    raise exception 'community_reward_post_unavailable' using errcode='22023';
  end if;
  if v_post.author_id=v_actor then raise exception 'cannot_reward_own_post' using errcode='42501'; end if;
  if p_expected_revision is null or
     private.bil_review_version_v2(v_post.id,v_post.author_id)<>p_expected_revision then
    raise exception 'community_review_content_changed' using errcode='40001';
  end if;
  select * into v_grant from public.bil_community_post_approval_grants where post_id=p_post_id;
  if found then
    return jsonb_build_object('post_id',p_post_id,'status',
      case when v_grant.tokens>0 then 'executed' else 'not_eligible' end,
      'duplicate',true,'tokens_granted',0,'owner_id',v_grant.owner_id);
  end if;
  insert into private.bil_community_post_reward_requests_v2
    (post_id,owner_id,requested_by,reviewed_revision)
    values(p_post_id,v_post.author_id,v_actor,p_expected_revision)
    on conflict(post_id) do nothing;
  select * into strict v_request from private.bil_community_post_reward_requests_v2
    where post_id=p_post_id;
  if v_request.owner_id<>v_post.author_id then raise exception 'community_reward_owner_changed'; end if;
  return jsonb_build_object('request_id',v_request.id,'post_id',p_post_id,
    'status',v_request.status,'tokens_granted',0,'owner_id',v_request.owner_id);
end $$;
revoke all on function public.bil_request_community_post_reward_v2(uuid,text)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_request_community_post_reward_v2(uuid,text) to authenticated;

create function public.bil_decide_community_post_reward_v2(
  p_request_id uuid,p_approve boolean,p_reason text default ''
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_post public.bil_community_posts%rowtype;
  v_request private.bil_community_post_reward_requests_v2%rowtype;
  v_policy public.bil_community_post_reward_policy%rowtype;
  v_usage public.bil_community_post_reward_usage%rowtype;
  v_grant public.bil_community_post_approval_grants%rowtype;
  v_day date; v_tokens integer:=0; v_reason text:='daily_cap_reached'; v_result jsonb;
begin
  if private.bil_review_authority_lock_v2()<>'admin' then
    raise exception 'administrator_required' using errcode='42501';
  end if;
  if p_request_id is null or p_approve is null or char_length(coalesce(p_reason,''))>160
     or p_reason ~ '[[:cntrl:]]' or (not p_approve and btrim(coalesce(p_reason,''))='') then
    raise exception 'invalid_community_reward_decision' using errcode='22023';
  end if;
  -- Parent first is the same lock order as publishing and base rewards.
  select post_id into v_request.post_id from private.bil_community_post_reward_requests_v2
    where id=p_request_id;
  select * into v_post from public.bil_community_posts where id=v_request.post_id for update;
  if not found or v_post.deleted_at is not null or v_post.moderation_status<>'approved'
     or v_post.moderation_visibility<>'visible' then
    raise exception 'community_reward_post_unavailable' using errcode='22023';
  end if;
  select * into strict v_request from private.bil_community_post_reward_requests_v2
    where id=p_request_id for update;
  if v_request.owner_id<>v_post.author_id or v_request.owner_id=v_actor then
    raise exception 'community_reward_owner_invalid' using errcode='42501';
  end if;
  if v_request.status<>'requested' then
    return v_request.receipt||jsonb_build_object('duplicate',true,'tokens_granted',0);
  end if;
  if private.bil_review_version_v2(v_post.id,v_post.author_id)<>v_request.reviewed_revision then
    raise exception 'community_review_content_changed' using errcode='40001';
  end if;
  if not p_approve then
    v_result:=jsonb_build_object('request_id',v_request.id,'post_id',v_post.id,
      'owner_id',v_request.owner_id,'status','rejected','duplicate',false,'tokens_granted',0);
  else
    select * into v_grant from public.bil_community_post_approval_grants where post_id=v_post.id;
    if not found then
      -- The approval day remains the quota day. Deferral cannot evade the cap
      -- by granting on a later day, or restore an earlier ineligible receipt.
      v_day:=timezone('UTC',v_post.reviewed_at)::date;
      if v_day is null then raise exception 'community_reward_approval_missing'; end if;
      select * into strict v_policy from public.bil_community_post_reward_policy
        where singleton for share;
      insert into public.bil_community_post_reward_usage(owner_id,reward_day)
        values(v_request.owner_id,v_day) on conflict do nothing;
      select * into strict v_usage from public.bil_community_post_reward_usage
        where owner_id=v_request.owner_id and reward_day=v_day for update;
      if v_usage.rewarded_posts<v_policy.max_rewarded_posts_per_owner_per_utc_day then
        v_tokens:=v_policy.tokens_per_approval; v_reason:='granted';
      end if;
      insert into public.bil_community_post_approval_grants
        (post_id,owner_id,approved_by,reward_day,tokens,reward_reason)
        values(v_post.id,v_request.owner_id,v_actor,v_day,v_tokens,v_reason)
        on conflict(post_id) do nothing returning * into v_grant;
      if found and v_tokens>0 then
        update public.bil_community_post_reward_usage
          set rewarded_posts=rewarded_posts+1,granted_tokens=granted_tokens+v_tokens,updated_at=now()
          where owner_id=v_request.owner_id and reward_day=v_day;
        insert into public.bil_ai_credit_balances(owner_id,granted,used)
          values(v_request.owner_id,v_tokens,0) on conflict(owner_id) do update
          set granted=public.bil_ai_credit_balances.granted+excluded.granted,updated_at=now();
      end if;
    end if;
    v_result:=jsonb_build_object('request_id',v_request.id,'post_id',v_post.id,
      'owner_id',v_request.owner_id,'status',case when v_grant.tokens>0 then 'executed' else 'not_eligible' end,
      'duplicate',false,'tokens_granted',v_tokens,'reward_reason',v_grant.reward_reason);
  end if;
  update private.bil_community_post_reward_requests_v2
    set status=v_result->>'status',reason=coalesce(p_reason,''),decided_by=v_actor,
      decided_at=clock_timestamp(),receipt=v_result where id=v_request.id;
  return v_result;
end $$;
revoke all on function public.bil_decide_community_post_reward_v2(uuid,boolean,text)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_decide_community_post_reward_v2(uuid,boolean,text) to authenticated;

-- An explicitly separate reward queue; no client reads private grant ledgers.
create function public.bil_community_reward_review_queue_v2(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_rows jsonb;
begin
  v_role:=private.bil_review_authority_lock_v2();
  if p_limit is null or p_limit<1 or p_limit>100 then
    raise exception 'invalid_community_review_batch' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) into v_rows from (
    select to_jsonb(p) as post,
      private.bil_review_version_v2(p.id,p.author_id) as revision,
      false as can_publish_only,v_role='admin' as can_grant,
      r.id as request_id,coalesce(r.status,'not_requested') as status
    from public.bil_community_posts p
    left join private.bil_community_post_reward_requests_v2 r on r.post_id=p.id
    where p.deleted_at is null and p.moderation_status='approved'
      and p.moderation_visibility='visible' and p.author_id<>auth.uid()
      and (r.id is not null or not exists(
        select 1 from public.bil_community_post_approval_grants g where g.post_id=p.id))
    order by p.reviewed_at desc,p.id limit p_limit
  ) q;
  return v_rows;
end $$;
revoke all on function public.bil_community_reward_review_queue_v2(integer)
  from public,anon,authenticated,service_role;
grant execute on function public.bil_community_reward_review_queue_v2(integer) to authenticated;

-- Author-only explanation of the decision on the CURRENT content revision.
-- No actor identity, private audit notes, balance or other author's data.
create function public.bil_get_my_post_review_v2(p_post_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_post public.bil_community_posts%rowtype; v_revision text; v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_post from public.bil_community_posts
    where id=p_post_id and author_id=auth.uid() and deleted_at is null for share;
  if not found then raise exception 'community_post_not_found' using errcode='42501'; end if;
  if v_post.moderation_status <> 'rejected' then return null; end if;
  v_revision:=private.bil_review_version_v2(v_post.id,v_post.author_id);
  select jsonb_build_object('contract_version',2,'post_id',v_post.id,
    'owner_id',v_post.author_id,'decision','rejected','reason',o.payload->>'reason',
    'reviewed_revision',v_revision,'decided_at',o.created_at,
    'post_body',v_post.body,'post_created_at',v_post.created_at)
  into v_result from private.bil_community_review_operations_v2 o
  where o.post_id=v_post.id and o.owner_id=v_post.author_id
    and o.payload->>'revision'=v_revision and o.payload->>'decision'='rejected'
  order by o.created_at desc limit 1;
  return v_result;
end $$;
revoke all on function public.bil_get_my_post_review_v2(uuid) from public,anon,authenticated,service_role;
grant execute on function public.bil_get_my_post_review_v2(uuid) to authenticated;
commit;
