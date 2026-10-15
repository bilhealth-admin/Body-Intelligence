-- Restore the durable author receipt for every completed post review.
-- Additive: existing RPC signatures, reward rules, and legacy notification
-- kinds remain unchanged for Android 32 / iOS 35 clients.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';
set local search_path=public,pg_catalog;

do $$ begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_community_post_approval_grants') is null
     or to_regclass('public.bil_community_notifications') is null
     or to_regclass('public.bil_push_outbox') is null
     or to_regclass('private.bil_community_review_operations_v2') is null
     or to_regprocedure('private.bil_emit_community_activity_v2(uuid,uuid,text,text,text,text,text,text,jsonb)') is null
     or to_regprocedure('public.bil_mark_community_activity_seen_v2(uuid[])') is null
     or to_regprocedure('public.bil_mark_community_notifications_seen(uuid[])') is null then
    raise exception 'community_post_review_receipt_dependencies_missing';
  end if;
end $$;

-- The October5 receipt extension exists on deployed databases only. Accept the
-- captured complete contract or a clean installation; reject partial/drifted
-- legacy state before installing any new function or trigger.
do $legacy_guard$
declare v_legacy boolean; v_signature text; v_expected text; v_definition text; v_lock text; v_predicate text;
begin
  v_legacy := to_regclass('private.bil_community_post_events_v1') is not null
    or to_regprocedure('private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean)') is not null;
  if v_legacy then
    if to_regclass('private.bil_community_post_events_v1') is null
       or not exists(select 1 from pg_class where oid=to_regclass('private.bil_community_post_events_v1') and relrowsecurity)
       or to_regprocedure('private.bil_sync_post_receipt_seen_v1()') is null
       or to_regprocedure('private.bil_requeue_post_notices_for_owner_v1(uuid)') is null
       or to_regprocedure('public.bil_mark_my_post_events_seen_v1(uuid[])') is null then
      raise exception 'post_review_legacy_contract_changed';
    end if;
    if (select array_agg(a.attname||':'||format_type(a.atttypid,a.atttypmod)||':'||
        case when a.attnotnull then '1' else '0' end order by a.attnum)
        from pg_attribute a where a.attrelid='private.bil_community_post_events_v1'::regclass
          and a.attnum>0 and not a.attisdropped) is distinct from array[
      'id:uuid:1','owner_id:uuid:1','event_kind:text:1','entity_kind:text:1',
      'entity_id:uuid:1','event_key:text:1','ai_tokens:integer:1','reward_reason:text:1',
      'created_at:timestamp with time zone:1','seen_at:timestamp with time zone:0'
    ] or not exists(select 1 from pg_constraint c
      where c.conrelid='private.bil_community_post_events_v1'::regclass
        and c.contype='u' and c.convalidated
        and pg_get_constraintdef(c.oid,true)='UNIQUE (event_key)') then
      raise exception 'post_review_legacy_contract_changed';
    end if;
    if (select array_agg(coalesce(pg_get_expr(d.adbin,d.adrelid),'[none]') order by a.attnum)
        from pg_attribute a left join pg_attrdef d
          on d.adrelid=a.attrelid and d.adnum=a.attnum
        where a.attrelid='private.bil_community_post_events_v1'::regclass
          and a.attnum>0 and not a.attisdropped) is distinct from array[
      'gen_random_uuid()','[none]','[none]','[none]','[none]','[none]',
      '0','''not_applicable''::text','clock_timestamp()','[none]'
    ] then
      raise exception 'post_review_legacy_contract_changed';
    end if;
    for v_signature,v_expected in select * from (values
      ('private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean)',
       'd89003128960bd5def9825390177f66b8d78685f3bdbced32c5b714dbe0346b9'),
      ('private.bil_post_approval_receipt_trigger_v1()',
       '376a58c5d559b598ac7f58263c0dcd4ea9e2f871efb038d491077483b424e447'),
      ('private.bil_post_rejection_receipt_trigger_v1()',
       '87d266f61b12c26a7a3358616141745d2e7d9272525c32f9718637c3123be222'),
      ('private.bil_sync_post_receipt_seen_v1()',
       'cc41e9129608859987e8090580215d585912fbaf104836a3c4d12ed779812fa5'),
      ('private.bil_requeue_post_notices_for_owner_v1(uuid)',
       'fc227e8ced1f1a54ed4d164dbb5dc517ec15b01b5277690fdae27618043961f3')
    ) expected(signature,sha256) loop
      v_definition := pg_get_functiondef(to_regprocedure(v_signature));
      if v_signature='private.bil_requeue_post_notices_for_owner_v1(uuid)' then
        v_lock := ' perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''bil.post_receipt.seen.''||p_owner::text,0));';
        v_predicate := '(a.delivered_at is not null or a.terminal_at is not null or a.leased_until>pg_catalog.clock_timestamp())';
        if (strpos(v_definition,v_lock)>0)<>(strpos(v_definition,v_predicate)>0)
           or length(v_definition)-length(replace(v_definition,v_lock,''))>length(v_lock)
           or (strpos(v_definition,v_lock)>0 and strpos(v_definition,v_lock||' with eligible as (')=0) then
          raise exception 'post_review_legacy_contract_changed: %',v_signature;
        end if;
        v_definition := replace(v_definition,
          ' perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''bil.post_receipt.seen.''||p_owner::text,0));','');
        v_definition := replace(v_definition,
          '(a.delivered_at is not null or a.terminal_at is not null or a.leased_until>pg_catalog.clock_timestamp())',
          'a.delivered_at is not null');
      end if;
      if to_regprocedure(v_signature) is null
         or encode(sha256(convert_to(v_definition,'UTF8')),'hex')<>v_expected
         or has_function_privilege('anon',to_regprocedure(v_signature),'execute')
         or has_function_privilege('authenticated',to_regprocedure(v_signature),'execute')
         or has_function_privilege('service_role',to_regprocedure(v_signature),'execute') then
        raise exception 'post_review_legacy_contract_changed: %',v_signature;
      end if;
    end loop;
    if exists(select 1 from (values
      ('public.bil_community_post_approval_grants','bil_post_approval_receipt_v1',
       '4167f57b0629ef52e7af6fc8fb9ff8351991c6e2208f4e8a7d034c5d130b8780'),
      ('public.bil_community_posts','bil_post_rejection_receipt_v1',
       'a051c9a4bcf1e17598ba414bd606f9a0ffc74cd05ffa6ff848b9d03133ff9d83'),
      ('public.bil_community_notifications','bil_sync_post_receipt_seen_v1',
       '935c97b980b59c205ec09559fd183c37eb73addaa1421e821e7b1714810f174c')
    ) expected(relation,name,sha256) left join pg_trigger t
      on t.tgrelid=to_regclass(expected.relation) and t.tgname=expected.name
      where t.oid is null or t.tgisinternal or t.tgenabled<>'O'
        or encode(sha256(convert_to(pg_get_triggerdef(t.oid,true),'UTF8')),'hex')<>expected.sha256) then
      raise exception 'post_review_legacy_contract_changed';
    end if;
    if (select count(*) from pg_trigger where not tgisinternal and tgenabled='O'
        and ((tgrelid='public.bil_community_post_approval_grants'::regclass
          and tgname='bil_post_approval_receipt_v1' and tgtype=5
          and tgfoid='private.bil_post_approval_receipt_trigger_v1()'::regprocedure)
        or (tgrelid='public.bil_community_posts'::regclass
          and tgname='bil_post_rejection_receipt_v1' and tgtype=17
          and tgfoid='private.bil_post_rejection_receipt_trigger_v1()'::regprocedure)))<>2 then
      raise exception 'post_review_legacy_contract_changed';
    end if;
  elsif to_regprocedure('private.bil_post_approval_receipt_trigger_v1()') is not null
     or to_regprocedure('private.bil_post_rejection_receipt_trigger_v1()') is not null
     or to_regprocedure('private.bil_sync_post_receipt_seen_v1()') is not null
     or to_regprocedure('private.bil_requeue_post_notices_for_owner_v1(uuid)') is not null
     or to_regprocedure('public.bil_mark_my_post_events_seen_v1(uuid[])') is not null then
    raise exception 'post_review_legacy_contract_changed';
  end if;
end $legacy_guard$;

-- Keep the exact public identities/ACL. The only accepted change is our
-- shared owner lock BEFORE any of the three APIs executes its first UPDATE.
do $seen_api_guard$
declare v_signature text; v_expected text; v_definition text; v_lock text; v_owner text; v_anchor text;
begin
  for v_signature,v_expected,v_owner in select * from (values
    ('public.bil_mark_community_activity_seen_v2(uuid[])',
     '668f167505c502aa916035cc36c743c670c35b13e7a1e4e2309e79b18bbc326d','v_uid'),
    ('public.bil_mark_community_notifications_seen(uuid[])',
     '7233d976a91b8fb177dcdbc8e1bfe52bcd98f8bb2b8fdd0b84babb3b96a4f7c0','v_uid'),
    ('public.bil_mark_my_post_events_seen_v1(uuid[])',
     'a1133f3fda0fad24a8596cab4718daa3d7e0ee71aaaf1eaf4aa9d79fd2153918','v_owner')
  ) expected(signature,sha256,owner_variable) loop
    if v_owner='v_owner' and to_regclass('private.bil_community_post_events_v1') is null then continue; end if;
    v_definition := pg_get_functiondef(to_regprocedure(v_signature));
    v_lock := E'\n  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''bil.post_receipt.seen.''||'||v_owner||'::text,0));';
    v_anchor := case when v_owner='v_uid' then E'\n  update public.bil_community_notifications'
      else E'\n  update private.bil_community_post_events_v1' end;
    if v_definition is null
       or (strpos(v_definition,v_lock)>0 and strpos(v_definition,v_lock||v_anchor)=0)
       or length(v_definition)-length(replace(v_definition,v_lock,''))>length(v_lock)
       or encode(sha256(convert_to(replace(v_definition,v_lock,''),'UTF8')),'hex')<>v_expected
       or has_function_privilege('anon',to_regprocedure(v_signature),'execute')
       or not has_function_privilege('authenticated',to_regprocedure(v_signature),'execute')
       or has_function_privilege('service_role',to_regprocedure(v_signature),'execute') then
      raise exception 'post_review_seen_api_changed: %',v_signature;
    end if;
  end loop;
end $seen_api_guard$;

create or replace function private.bil_emit_community_post_review_receipt_v2(
  p_owner uuid,
  p_post_id uuid,
  p_decision text,
  p_ai_tokens integer,
  p_reward_reason text,
  p_event_kind text default 'review'
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
  v_kind text;
  v_copy_key text;
  v_source_key text;
  v_body text;
  v_metadata jsonb;
  v_notification_id uuid;
  v_event_id uuid;
  v_event_kind text;
  v_push_source text;
  v_legacy boolean;
  v_existing public.bil_community_notifications%rowtype;
  v_original_metadata jsonb;
begin
  if p_owner is null or p_post_id is null
     or p_decision not in ('approved','rejected') or p_decision is null
     or p_ai_tokens not in (0,5) or p_ai_tokens is null
     or p_reward_reason is null
     or p_event_kind not in ('review','reward') or p_event_kind is null then
    raise exception 'post_review_receipt_invalid' using errcode='22023';
  end if;
  if p_decision='rejected'
     and (p_ai_tokens<>0 or p_reward_reason<>'not_applicable') then
    raise exception 'post_review_receipt_invalid' using errcode='22023';
  end if;
  if p_decision='approved' and (
    (p_ai_tokens=5 and p_reward_reason<>'granted')
    or (p_ai_tokens=0 and p_reward_reason not in ('daily_cap_reached','deferred'))
  ) then
    raise exception 'post_review_receipt_invalid' using errcode='22023';
  end if;
  if p_event_kind='reward'
     and (p_decision<>'approved'
       or not ((p_ai_tokens=5 and p_reward_reason='granted')
         or (p_ai_tokens=0 and p_reward_reason='daily_cap_reached'))) then
    raise exception 'post_review_receipt_invalid' using errcode='22023';
  end if;
  if not exists(select 1 from auth.users u where u.id=p_owner) then
    raise exception 'post_review_receipt_owner_missing' using errcode='22023';
  end if;

  v_kind := case when p_decision='approved' then 'reward_earned' else 'comment' end;
  v_copy_key := case
    when p_decision='rejected' then 'post_rejected_v1'
    when p_ai_tokens=5 then 'post_approved_ai_tokens_v1'
    else 'post_approved_no_ai_tokens_v1'
  end;
  v_source_key := case when p_event_kind='reward'
    then 'post-reward-result-v2:' else 'post-moderation-receipt-v2:' end||p_post_id::text;
  v_metadata := pg_catalog.jsonb_build_object(
    'receipt_kind','post_moderation',
    'post_id',p_post_id::text,
    'decision',p_decision,
    'ai_tokens_granted',p_ai_tokens,
    'reward_reason',p_reward_reason
  );
  v_body := case
    when p_decision='rejected' then 'منشورك يحتاج تعديلات. Your post needs changes.'
    when p_reward_reason='daily_cap_reached' then 'تم اعتماد منشورك، لكن حد المكافأة اليومي اكتمل. Post approved; the daily reward limit was reached.'
    when p_ai_tokens=5 then 'تم اعتماد منشورك وأُكدت مكافأة 5 توكنات AI. Post approved; +5 AI tokens confirmed.'
    else 'تم اعتماد منشورك. لم تُؤكد مكافأة توكنات AI. Post approved; no AI token reward was confirmed.'
  end;

  v_legacy := to_regprocedure('private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean)') is not null
    and p_reward_reason<>'deferred';
  v_push_source := v_source_key;
  if v_legacy then
    v_event_kind := case when p_decision='approved' then 'post_approved' else 'post_rejected' end;
    -- A repeated legacy event returns before either fan-out. With either
    -- trigger order there is one ledger row and at most one positive Activity.
    v_event_id := private.bil_emit_post_receipt_v1(
      p_owner,v_event_kind,'post',p_post_id,p_ai_tokens,p_reward_reason,false
    );
    v_push_source := 'post-event:'||v_event_kind||':'||p_post_id::text||':'||p_owner::text;
    v_metadata := v_metadata||jsonb_build_object('receipt_id',v_event_id);
  end if;

  if v_legacy and p_ai_tokens=5 then
    -- Keep the keys consumed by old clients and the existing seen-sync hook.
    -- Enrich the one canonical Activity; never invoke its strict emitter with
    -- a changed payload for an already-created source key.
    v_source_key := 'post-ai-reward:'||p_post_id::text;
    v_copy_key := 'community_post_ai_reward_v1';
    v_original_metadata := jsonb_build_object(
      'currency','ai_tokens','tokens',5,'decision','approved','receipt_id',v_event_id);
    select * into v_existing from public.bil_community_notifications
      where source_key=v_source_key for update;
    if not found or v_existing.recipient_id is distinct from p_owner
       or v_existing.actor_id is not null or v_existing.kind<>'reward_earned'
       or v_existing.entity_kind<>'post' or v_existing.entity_id<>p_post_id::text
       or v_existing.copy_key<>v_copy_key
       or v_existing.deep_link_path not in ('/community','/community/post/'||p_post_id::text)
       or not (v_original_metadata <@ v_existing.metadata)
       or not (v_existing.metadata <@ (v_original_metadata||v_metadata)) then
      raise exception 'post_review_legacy_activity_changed';
    end if;
    update public.bil_community_notifications
      set metadata=v_original_metadata||v_metadata,
          deep_link_path='/community/post/'||p_post_id::text
      where id=v_existing.id;
    v_notification_id := v_existing.id;
  else
    v_notification_id := private.bil_emit_community_activity_v2(
      p_owner,null,v_kind,v_source_key,'post',p_post_id::text,v_copy_key,
      '/community/post/'||p_post_id::text,v_metadata
    );
  end if;

  -- The deferred review RPC already queues a push for its initial decision.
  -- Its durable in-app receipt is still written above; only the later reward
  -- result needs a second push.
  if not (p_event_kind='review' and p_reward_reason='deferred') then
    insert into public.bil_push_outbox(
      recipient_id,category,title,body,deep_link,copy_key,source_key
    ) values (
      p_owner,'community','BIL',v_body,
      'bil://community/post/'||p_post_id::text,v_copy_key,v_push_source
    )
    on conflict(recipient_id,source_key) where source_key is not null do update
      set title=excluded.title,body=excluded.body,
          deep_link=excluded.deep_link,copy_key=excluded.copy_key
      -- An old hook may have queued this same event earlier in this transaction.
      -- Never reset a lease, delivery outcome, timestamp or previously sent row.
      where public.bil_push_outbox.dispatched_at is null;
  end if;

  return v_notification_id;
end
$$;
revoke all on function private.bil_emit_community_post_review_receipt_v2(uuid,uuid,text,integer,text,text)
  from public,anon,authenticated,service_role;

create or replace function private.bil_emit_community_post_review_grant_receipt_v2()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_event_kind text := 'review';
begin
  if new.reward_reason in ('granted','daily_cap_reached') and exists(
    select 1 from public.bil_community_notifications n
    where n.recipient_id=new.owner_id
      and n.source_key='post-moderation-receipt-v2:'||new.post_id::text
      and n.metadata->>'reward_reason'='deferred'
  ) then
    v_event_kind := 'reward';
  end if;
  perform private.bil_emit_community_post_review_receipt_v2(
    new.owner_id,new.post_id,'approved',new.tokens,new.reward_reason,v_event_kind
  );
  return new;
end
$$;
revoke all on function private.bil_emit_community_post_review_grant_receipt_v2()
  from public,anon,authenticated,service_role;

create or replace function private.bil_emit_community_post_review_rejection_receipt_v2()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if old.moderation_status='pending' and new.moderation_status='rejected' then
    perform private.bil_emit_community_post_review_receipt_v2(
      new.author_id,new.id,'rejected',0,'not_applicable'
    );
  end if;
  return new;
end
$$;
revoke all on function private.bil_emit_community_post_review_rejection_receipt_v2()
  from public,anon,authenticated,service_role;

create or replace function private.bil_emit_community_post_review_operation_receipt_v2()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_decision text := new.receipt->>'decision';
  v_tokens integer := (new.receipt->>'tokens_granted')::integer;
  v_reason text := new.receipt->>'reward_reason';
begin
  if v_decision is null or v_tokens is null or v_reason is null then
    raise exception 'post_review_operation_receipt_invalid' using errcode='22023';
  end if;
  -- A new operation ID can replay a V1 decision or find an immutable grant.
  -- Keep its operation receipt, without emitting a second author notification.
  if v_tokens=0 and v_reason in ('duplicate_decision','duplicate_receipt') then
    return new;
  end if;
  perform private.bil_emit_community_post_review_receipt_v2(
    new.owner_id,new.post_id,v_decision,v_tokens,v_reason
  );
  return new;
end
$$;
revoke all on function private.bil_emit_community_post_review_operation_receipt_v2()
  from public,anon,authenticated,service_role;

drop trigger if exists bil_community_post_review_grant_receipt_v2
  on public.bil_community_post_approval_grants;
create trigger bil_community_post_review_grant_receipt_v2
  after insert on public.bil_community_post_approval_grants
  for each row execute function private.bil_emit_community_post_review_grant_receipt_v2();

drop trigger if exists bil_community_post_review_rejection_receipt_v2
  on public.bil_community_posts;
create trigger bil_community_post_review_rejection_receipt_v2
  after update of moderation_status on public.bil_community_posts
  for each row execute function private.bil_emit_community_post_review_rejection_receipt_v2();

drop trigger if exists bil_community_post_review_operation_receipt_v2
  on private.bil_community_review_operations_v2;
create trigger bil_community_post_review_operation_receipt_v2
  after insert on private.bil_community_review_operations_v2
  for each row execute function private.bil_emit_community_post_review_operation_receipt_v2();


-- Serialize BOTH real seen RPCs before target-row locks. Locking from an
-- AFTER trigger would retain the opposing Activity->event/event->Activity
-- deadlock. No advisory lock is acquired by the bridge AFTER triggers below.
do $seen_api_lock$
declare v_signature text; v_owner text; v_anchor text; v_lock text; v_definition text;
begin
  for v_signature,v_owner,v_anchor in select * from (values
    ('public.bil_mark_community_activity_seen_v2(uuid[])','v_uid',
      E'\n  update public.bil_community_notifications'),
    ('public.bil_mark_community_notifications_seen(uuid[])','v_uid',
      E'\n  update public.bil_community_notifications'),
    ('public.bil_mark_my_post_events_seen_v1(uuid[])','v_owner',
      E'\n  update private.bil_community_post_events_v1')
  ) targets(signature,owner_variable,anchor) loop
    if v_owner='v_owner' and to_regclass('private.bil_community_post_events_v1') is null then continue; end if;
    v_definition := pg_get_functiondef(to_regprocedure(v_signature));
    v_lock := E'\n  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''bil.post_receipt.seen.''||'||v_owner||'::text,0));';
    if strpos(v_definition,v_lock)=0 then
      if length(v_definition)-length(replace(v_definition,v_anchor,''))<>length(v_anchor) then
        raise exception 'post_review_seen_api_changed: %',v_signature;
      end if;
      execute replace(v_definition,v_anchor,v_lock||v_anchor);
    end if;
  end loop;
  if to_regclass('private.bil_community_post_events_v1') is not null then
    v_definition := pg_get_functiondef('private.bil_requeue_post_notices_for_owner_v1(uuid)'::regprocedure);
    v_lock := ' perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(''bil.post_receipt.seen.''||p_owner::text,0));';
    if strpos(v_definition,v_lock)=0 then
      v_definition := replace(v_definition,' with eligible as (',v_lock||' with eligible as (');
      v_definition := replace(v_definition,'a.delivered_at is not null',
        '(a.delivered_at is not null or a.terminal_at is not null or a.leased_until>pg_catalog.clock_timestamp())');
      execute v_definition;
    end if;
  end if;
end $seen_api_lock$;

-- The original positive-only seen hook and public V1 RPC ABI/ACL remain.
-- Link new zero/rejected Activity to the SAME legacy event in both directions.
create or replace function private.bil_sync_post_review_activity_seen_v2()
returns trigger language plpgsql security definer set search_path='' as $seen_activity$
begin
  if old.seen_at is null and new.seen_at is not null
     and new.entity_kind='post'
     and new.metadata->>'receipt_kind'='post_moderation'
     and new.metadata->>'post_id'=new.entity_id
     and ((new.copy_key='community_post_ai_reward_v1'
       and new.source_key='post-ai-reward:'||new.entity_id)
       or (new.copy_key in ('post_approved_no_ai_tokens_v1','post_rejected_v1')
         and new.source_key in ('post-moderation-receipt-v2:'||new.entity_id,
           'post-reward-result-v2:'||new.entity_id)))
     and to_regclass('private.bil_community_post_events_v1') is not null then
    update private.bil_community_post_events_v1 e set seen_at=new.seen_at
      where e.owner_id=new.recipient_id and e.entity_kind='post'
        and e.id::text=new.metadata->>'receipt_id'
        and e.entity_id::text=new.entity_id and e.seen_at is null
        and e.ai_tokens::text=new.metadata->>'ai_tokens_granted'
        and e.reward_reason=new.metadata->>'reward_reason'
        and e.event_kind=case new.metadata->>'decision'
          when 'approved' then 'post_approved' when 'rejected' then 'post_rejected' end;
  end if;
  return new;
end $seen_activity$;
revoke all on function private.bil_sync_post_review_activity_seen_v2()
  from public,anon,authenticated,service_role;

create or replace function private.bil_sync_post_review_event_seen_v2()
returns trigger language plpgsql security definer set search_path='' as $seen_event$
begin
  if old.seen_at is null and new.seen_at is not null and new.entity_kind='post' then
    update public.bil_community_notifications n set seen_at=new.seen_at
      where n.recipient_id=new.owner_id and n.entity_kind='post'
        and n.entity_id=new.entity_id::text and n.seen_at is null
        and n.metadata->>'receipt_kind'='post_moderation'
        and n.metadata->>'receipt_id'=new.id::text
        and n.metadata->>'post_id'=new.entity_id::text
        and ((n.copy_key='community_post_ai_reward_v1'
          and n.source_key='post-ai-reward:'||new.entity_id::text)
          or (n.copy_key in ('post_approved_no_ai_tokens_v1','post_rejected_v1')
            and n.source_key in ('post-moderation-receipt-v2:'||new.entity_id::text,
              'post-reward-result-v2:'||new.entity_id::text)))
        and n.metadata->>'ai_tokens_granted'=new.ai_tokens::text
        and n.metadata->>'reward_reason'=new.reward_reason
        and n.metadata->>'decision'=case new.event_kind
          when 'post_approved' then 'approved' when 'post_rejected' then 'rejected' end;
  end if;
  return new;
end $seen_event$;
revoke all on function private.bil_sync_post_review_event_seen_v2()
  from public,anon,authenticated,service_role;

drop trigger if exists bil_post_review_activity_seen_v2 on public.bil_community_notifications;
create trigger bil_post_review_activity_seen_v2 after update of seen_at
  on public.bil_community_notifications for each row
  execute function private.bil_sync_post_review_activity_seen_v2();

do $legacy_seen$
begin
  if to_regclass('private.bil_community_post_events_v1') is not null then
    execute 'drop trigger if exists bil_post_review_event_seen_v2 on private.bil_community_post_events_v1';
    execute 'create trigger bil_post_review_event_seen_v2 after update of seen_at on private.bil_community_post_events_v1 for each row execute function private.bil_sync_post_review_event_seen_v2()';
  end if;
end $legacy_seen$;

commit;
