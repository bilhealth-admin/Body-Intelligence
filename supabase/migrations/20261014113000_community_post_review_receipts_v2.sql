-- Restore the durable author receipt for every completed post review.
-- Additive: existing RPC signatures, reward rules, and legacy notification
-- kinds remain unchanged for Android 32 / iOS 35 clients.
begin;
set local lock_timeout='5s';
set local statement_timeout='30s';

do $$ begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_community_post_approval_grants') is null
     or to_regclass('public.bil_community_notifications') is null
     or to_regclass('public.bil_push_outbox') is null
     or to_regclass('private.bil_community_review_operations_v2') is null
     or to_regprocedure('private.bil_emit_community_activity_v2(uuid,uuid,text,text,text,text,text,text,jsonb)') is null then
    raise exception 'community_post_review_receipt_dependencies_missing';
  end if;
end $$;

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

  v_notification_id := private.bil_emit_community_activity_v2(
    p_owner,null,v_kind,v_source_key,'post',p_post_id::text,v_copy_key,
    '/community/post/'||p_post_id::text,v_metadata
  );

  -- The deferred review RPC already queues a push for its initial decision.
  -- Its durable in-app receipt is still written above; only the later reward
  -- result needs a second push.
  if not (p_event_kind='review' and p_reward_reason='deferred') then
    insert into public.bil_push_outbox(
      recipient_id,category,title,body,deep_link,copy_key,source_key
    ) values (
      p_owner,'community','BIL',v_body,
      'bil://community/post/'||p_post_id::text,v_copy_key,v_source_key
    )
    on conflict(recipient_id,source_key) where source_key is not null do nothing;
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

commit;
