CREATE OR REPLACE FUNCTION public.bil_mark_community_activity_seen_v2(p_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid:=(select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_ids is null or cardinality(p_ids)=0 or cardinality(p_ids)>100 then
    raise exception 'invalid_activity_ids' using errcode='22023';
  end if;

  update public.bil_community_notifications
  set seen_at=coalesce(seen_at,pg_catalog.clock_timestamp())
  where recipient_id=v_uid
    and id=any(p_ids)
    and seen_at is null;
  get diagnostics v_count=row_count;
  return v_count;
end
$function$
;
revoke all on function public.bil_mark_community_activity_seen_v2(uuid[]) from public,anon,service_role;
grant execute on function public.bil_mark_community_activity_seen_v2(uuid[]) to authenticated;

CREATE OR REPLACE FUNCTION public.bil_mark_community_notifications_seen(p_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid:=(select auth.uid()); v_count integer;
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_ids is null or cardinality(p_ids)=0 or cardinality(p_ids)>100 then
    raise exception 'invalid_notification_ids' using errcode='22023';
  end if;
  update public.bil_community_notifications
  set seen_at=coalesce(seen_at,pg_catalog.clock_timestamp())
  where recipient_id=v_uid and id=any(p_ids) and seen_at is null;
  get diagnostics v_count=row_count;
  return v_count;
end
$function$
;
revoke all on function public.bil_mark_community_notifications_seen(uuid[]) from public,anon,service_role;
grant execute on function public.bil_mark_community_notifications_seen(uuid[]) to authenticated;

-- LEGACY ONLY BELOW
-- Safe schema/function catalog slice captured 2026-10-16. No live rows.
-- Existing baseline includes the V1 emitter/event table but omitted its hooks.
-- This fixture installs the ACTUAL deployed hooks and seen/requeue functions.
create table public.bil_push_device_tokens (
  "id" uuid default gen_random_uuid() not null,
  "user_id" uuid not null,
  "token_ciphertext" text not null,
  "token_fingerprint" text not null,
  "platform" text not null,
  "timezone" text default 'UTC'::text not null,
  "enabled" boolean default true not null,
  "sensitive_preview_allowed" boolean default false not null,
  "last_seen_at" timestamp with time zone default now() not null,
  "created_at" timestamp with time zone default now() not null,
  "message_enabled" boolean default true not null,
  "friend_request_enabled" boolean default true not null,
  "friend_accepted_enabled" boolean default true not null
);
create table public.bil_push_delivery_attempts (
  "outbox_id" uuid not null,
  "device_token_id" uuid not null,
  "attempt_count" integer default 0 not null,
  "leased_until" timestamp with time zone,
  "last_attempt_at" timestamp with time zone,
  "next_attempt_at" timestamp with time zone default now() not null,
  "delivered_at" timestamp with time zone,
  "terminal_at" timestamp with time zone,
  "permanent_token_failure" boolean default false not null,
  "failure_code" text,
  "created_at" timestamp with time zone default now() not null
);
alter table public.bil_push_device_tokens add constraint "bil_push_device_tokens_pkey" PRIMARY KEY (id);
alter table public.bil_push_device_tokens add constraint "bil_push_device_tokens_platform_check" CHECK (platform = ANY (ARRAY['fcm'::text, 'apns'::text]));
alter table public.bil_push_device_tokens add constraint "bil_push_device_tokens_token_fingerprint_key" UNIQUE (token_fingerprint);
alter table public.bil_push_device_tokens add constraint "bil_push_device_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.bil_push_device_tokens enable row level security;
revoke all on table public.bil_push_device_tokens from public,anon,authenticated,service_role;
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_attempt_count_check" CHECK (attempt_count >= 0);
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_check" CHECK (delivered_at IS NULL OR terminal_at IS NULL);
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_check1" CHECK (NOT permanent_token_failure OR terminal_at IS NOT NULL);
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_device_token_id_fkey" FOREIGN KEY (device_token_id) REFERENCES bil_push_device_tokens(id) ON DELETE CASCADE;
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_failure_code_check" CHECK (failure_code IS NULL OR char_length(failure_code) >= 1 AND char_length(failure_code) <= 120);
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_outbox_id_fkey" FOREIGN KEY (outbox_id) REFERENCES bil_push_outbox(id) ON DELETE CASCADE;
alter table public.bil_push_delivery_attempts add constraint "bil_push_delivery_attempts_pkey" PRIMARY KEY (outbox_id, device_token_id);
alter table public.bil_push_delivery_attempts enable row level security;
revoke all on table public.bil_push_delivery_attempts from public,anon,authenticated,service_role;

-- Column projections of unrelated report targets referenced by the SQL
-- review-notice predicate. No rows or report/message behavior is exercised.
create table public.bil_community_reports (
  "id" uuid,
  "status" text,
  "reporter_id" uuid,
  "target_kind" text,
  "target_id" uuid
);
alter table public.bil_community_reports enable row level security;
revoke all on table public.bil_community_reports from public,anon,authenticated,service_role;
create table public.bil_messages (
  "id" uuid,
  "sender_id" uuid
);
alter table public.bil_messages enable row level security;
revoke all on table public.bil_messages from public,anon,authenticated,service_role;
create table public.bil_community_food_submissions (
  "id" uuid,
  "contributor_id" uuid
);
alter table public.bil_community_food_submissions enable row level security;
revoke all on table public.bil_community_food_submissions from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.bil_can_receive_review_notice_v1(p_reviewer uuid, p_entity_kind text, p_entity_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select coalesce(p_reviewer is not null and p_entity_id is not null and private.bil_resolve_community_moderation_authority(p_reviewer) is not null and not exists(select 1 from private.bil_community_member_access a where a.user_id=p_reviewer and a.suspended) and ((p_entity_kind='post' and exists(select 1 from public.bil_community_posts p where p.id=p_entity_id and p.moderation_status='pending' and p.deleted_at is null and p.author_id<>p_reviewer)) or (p_entity_kind='report' and exists(select 1 from public.bil_community_reports r where r.id=p_entity_id and r.status in ('open','reviewing') and r.reporter_id<>p_reviewer and not ((r.target_kind='post' and exists(select 1 from public.bil_community_posts p where p.id=r.target_id and p.author_id=p_reviewer)) or (r.target_kind='message' and exists(select 1 from public.bil_messages m where m.id=r.target_id and m.sender_id=p_reviewer)) or (r.target_kind='food' and exists(select 1 from public.bil_community_food_submissions f where f.id=r.target_id and f.contributor_id=p_reviewer)) or (r.target_kind='profile' and r.target_id=p_reviewer))))),false); $function$
;

CREATE OR REPLACE FUNCTION private.bil_requeue_post_notices_for_owner_v1(p_owner uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ declare v_count integer; begin if p_owner is null or not exists(select 1 from public.bil_push_device_tokens t where t.user_id=p_owner and t.enabled) then return 0; end if; with eligible as (select o.id from public.bil_push_outbox o join private.bil_community_post_events_v1 e on e.event_key=o.source_key and e.owner_id=o.recipient_id where o.recipient_id=p_owner and o.category='community' and o.dispatched_at is not null and o.failure_code='no_eligible_tokens' and o.created_at>=pg_catalog.now()-interval '24 hours' and e.seen_at is null and not exists(select 1 from public.bil_push_delivery_attempts a where a.outbox_id=o.id and a.delivered_at is not null) and ((e.event_kind in ('post_submitted','post_approved','post_rejected') and e.entity_kind='post' and exists(select 1 from public.bil_community_posts p where p.id=e.entity_id and p.author_id=p_owner and p.deleted_at is null and p.moderation_status=case e.event_kind when 'post_submitted' then 'pending' when 'post_approved' then 'approved' else 'rejected' end)) or (e.event_kind='review_requested' and private.bil_can_receive_review_notice_v1(p_owner,e.entity_kind,e.entity_id))) order by o.created_at desc,o.id desc limit 10 for update of o skip locked) update public.bil_push_outbox o set dispatched_at=null,failure_code=null from eligible e where o.id=e.id; get diagnostics v_count=row_count; return v_count; end $function$
;

CREATE OR REPLACE FUNCTION private.bil_sync_post_receipt_seen_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if old.seen_at is null and new.seen_at is not null
    and new.kind='reward_earned' and new.copy_key='community_post_ai_reward_v1'
  then
    update private.bil_community_post_events_v1 e set seen_at=new.seen_at
      where e.owner_id=new.recipient_id and e.id::text=new.metadata->>'receipt_id'
        and new.source_key='post-ai-reward:'||e.entity_id::text
        and e.event_kind='post_approved' and e.ai_tokens>0 and e.seen_at is null;
  end if;
  return new;
end
$function$
;

CREATE OR REPLACE FUNCTION public.bil_list_my_post_events_v1(p_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owner uuid:=(select auth.uid()); v_result jsonb;
begin
  if v_owner is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if (p_before is null)<>(p_before_id is null) or p_limit is null or p_limit<1 or p_limit>100 then raise exception 'post_event_cursor_invalid' using errcode='22023'; end if;
  select coalesce(jsonb_agg(s.value order by s.created_at desc,s.id desc),'[]'::jsonb) into v_result
  from (select e.id,e.created_at,pg_catalog.jsonb_build_object('id',e.id,'kind',e.event_kind,'entity_kind',e.entity_kind,'entity_id',e.entity_id,'ai_tokens',e.ai_tokens,'reward_reason',e.reward_reason,'created_at',e.created_at,'seen_at',e.seen_at,'target',case when e.event_kind='review_requested' then 'moderation' else 'my_posts' end) as value
    from private.bil_community_post_events_v1 e where e.owner_id=v_owner and (e.event_kind<>'review_requested' or (private.bil_resolve_community_moderation_authority(v_owner) is not null and not exists(select 1 from private.bil_community_member_access a where a.user_id=v_owner and a.suspended)))
      and (p_before is null or (e.created_at,e.id)<(p_before,p_before_id)) order by e.created_at desc,e.id desc limit p_limit) s;
  return v_result;
end
$function$
;

CREATE OR REPLACE FUNCTION public.bil_mark_my_post_events_seen_v1(p_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_owner uuid:=(select auth.uid()); v_count integer;
begin
  if v_owner is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_ids is null or cardinality(p_ids)>100 then raise exception 'post_event_ids_invalid' using errcode='22023'; end if;
  update private.bil_community_post_events_v1 e set seen_at=pg_catalog.now()
    where e.owner_id=v_owner and e.id=any(p_ids) and e.seen_at is null
    and (e.event_kind<>'review_requested' or (private.bil_resolve_community_moderation_authority(v_owner) is not null
      and not exists(select 1 from private.bil_community_member_access a where a.user_id=v_owner and a.suspended)));
  get diagnostics v_count=row_count;
  update public.bil_community_notifications n set seen_at=pg_catalog.now()
    where n.recipient_id=v_owner and n.seen_at is null
      and n.kind='reward_earned' and n.copy_key='community_post_ai_reward_v1'
      and exists(select 1 from private.bil_community_post_events_v1 e
        where e.owner_id=v_owner and e.id=any(p_ids) and e.seen_at is not null
          and e.event_kind='post_approved' and e.ai_tokens>0
          and n.source_key='post-ai-reward:'||e.entity_id::text
          and n.metadata->>'receipt_id'=e.id::text);
  return v_count;
end
$function$
;

CREATE TRIGGER bil_post_approval_receipt_v1 AFTER INSERT ON bil_community_post_approval_grants FOR EACH ROW EXECUTE FUNCTION private.bil_post_approval_receipt_trigger_v1();
CREATE TRIGGER bil_post_rejection_receipt_v1 AFTER UPDATE OF moderation_status ON bil_community_posts FOR EACH ROW EXECUTE FUNCTION private.bil_post_rejection_receipt_trigger_v1();
CREATE TRIGGER bil_sync_post_receipt_seen_v1 AFTER UPDATE OF seen_at ON bil_community_notifications FOR EACH ROW EXECUTE FUNCTION private.bil_sync_post_receipt_seen_v1();
revoke all on function private.bil_emit_post_receipt_v1(uuid,text,text,uuid,integer,text,boolean) from public,anon,authenticated,service_role;
revoke all on function private.bil_post_approval_receipt_trigger_v1() from public,anon,authenticated,service_role;
revoke all on function private.bil_post_rejection_receipt_trigger_v1() from public,anon,authenticated,service_role;
revoke all on function private.bil_sync_post_receipt_seen_v1() from public,anon,authenticated,service_role;
revoke all on function private.bil_requeue_post_notices_for_owner_v1(uuid) from public,anon,authenticated,service_role;
revoke all on function private.bil_can_receive_review_notice_v1(uuid,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.bil_list_my_post_events_v1(timestamptz,uuid,integer), public.bil_mark_my_post_events_seen_v1(uuid[]) from public,anon,service_role;
grant execute on function public.bil_list_my_post_events_v1(timestamptz,uuid,integer), public.bil_mark_my_post_events_seen_v1(uuid[]) to authenticated;
