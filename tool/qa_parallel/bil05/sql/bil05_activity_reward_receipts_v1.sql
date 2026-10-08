-- BIL-05 forward-only QA overlay.
-- Purpose: durable author moderation receipts + moderator-only poll projection.
-- This file does NOT grant AI credits and must not be applied to Production by
-- this role. BIL-00 owns integration/deployment decisions.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

begin;

do $bil05_preflight$
begin
  if to_regclass('public.bil_community_posts') is null
     or to_regclass('public.bil_community_notifications') is null
     or to_regclass('public.bil_community_audit_events') is null
     or to_regclass('public.bil_community_post_approval_grants') is null
     or to_regclass('public.bil_community_polls') is null
     or to_regclass('public.bil_community_poll_options') is null
     or to_regprocedure('private.bil_resolve_community_moderation_authority(uuid)') is null
     or to_regprocedure('public.bil_moderate_community_post(uuid,text)') is null then
    raise exception 'bil05_activity_reward_dependencies_missing';
  end if;
end
$bil05_preflight$;

create or replace function private.bil_emit_post_moderation_author_receipt_v1(
  p_post_id uuid,
  p_metadata jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_owner uuid;
  v_decision text := p_metadata ->> 'decision';
  v_reward_reason text := p_metadata ->> 'reward_reason';
  v_tokens_text text := p_metadata ->> 'tokens_granted';
  v_tokens integer;
  v_kind text;
  v_copy_key text;
begin
  if p_post_id is null
     or p_metadata is null
     or pg_catalog.jsonb_typeof(p_metadata) <> 'object'
     or v_decision not in ('approved', 'rejected')
     or v_tokens_text is null
     or v_tokens_text !~ '^(0|5)$'
     or coalesce(v_reward_reason, '') = '' then
    raise exception 'invalid_post_moderation_receipt'
      using errcode = '22023';
  end if;

  v_tokens := v_tokens_text::integer;

  if v_decision = 'approved' and v_tokens = 5 then
    if v_reward_reason <> 'granted' then
      raise exception 'invalid_post_moderation_reward_receipt'
        using errcode = '22023';
    end if;
    v_kind := 'reward_earned';
    v_copy_key := 'post_approved_ai_tokens_v1';
  elsif v_decision = 'approved' and v_tokens = 0 then
    if v_reward_reason = 'granted' then
      raise exception 'invalid_post_moderation_reward_receipt'
        using errcode = '22023';
    end if;
    v_kind := 'challenge_update';
    v_copy_key := 'post_approved_no_ai_tokens_v1';
  elsif v_decision = 'rejected' and v_tokens = 0 then
    v_kind := 'challenge_update';
    v_copy_key := 'post_rejected_v1';
  else
    raise exception 'invalid_post_moderation_reward_receipt'
      using errcode = '22023';
  end if;

  select p.author_id
    into v_owner
  from public.bil_community_posts p
  where p.id = p_post_id
    and p.deleted_at is null;

  -- A hard-deleted post has no safe destination. The immutable approval grant
  -- remains the reward evidence; do not create a dangling Activity row.
  if v_owner is null then
    return;
  end if;

  insert into public.bil_community_notifications(
    recipient_id,
    actor_id,
    kind,
    source_key,
    entity_kind,
    entity_id,
    copy_key,
    deep_link_path,
    metadata
  ) values (
    v_owner,
    null,
    v_kind,
    'post_moderation:' || p_post_id::text || ':' || v_decision,
    'post',
    p_post_id::text,
    v_copy_key,
    '/community/post/' || p_post_id::text,
    pg_catalog.jsonb_build_object(
      'receipt_kind', 'post_moderation',
      'post_id', p_post_id::text,
      'decision', v_decision,
      'ai_tokens_granted', v_tokens,
      'reward_reason', v_reward_reason
    )
  )
  on conflict (source_key) do nothing;
end
$function$;

create or replace function private.bil_emit_post_moderation_author_receipt_trigger_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_post_id uuid;
begin
  if new.event_kind <> 'POST_REVIEW'
     or new.target_kind <> 'community_post' then
    return new;
  end if;

  if new.target_id is null
     or new.target_id !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' then
    raise exception 'invalid_post_review_target'
      using errcode = '22023';
  end if;
  v_post_id := new.target_id::uuid;
  perform private.bil_emit_post_moderation_author_receipt_v1(
    v_post_id,
    new.metadata
  );
  return new;
end
$function$;

revoke all on function private.bil_emit_post_moderation_author_receipt_v1(uuid,jsonb)
  from public, anon, authenticated, service_role;
revoke all on function private.bil_emit_post_moderation_author_receipt_trigger_v1()
  from public, anon, authenticated, service_role;

drop trigger if exists bil_emit_post_moderation_author_receipt_v1
  on public.bil_community_audit_events;
create trigger bil_emit_post_moderation_author_receipt_v1
after insert on public.bil_community_audit_events
for each row
when (
  new.event_kind = 'POST_REVIEW'
  and new.target_kind = 'community_post'
)
execute function private.bil_emit_post_moderation_author_receipt_trigger_v1();

-- Backfill only from the durable audit evidence already written by the existing
-- moderation RPC. This never calls or mutates the AI credit ledger.
do $bil05_backfill$
declare
  v_event record;
begin
  for v_event in
    select e.target_id, e.metadata
    from public.bil_community_audit_events e
    where e.event_kind = 'POST_REVIEW'
      and e.target_kind = 'community_post'
      and e.target_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
    order by e.created_at, e.id
  loop
    perform private.bil_emit_post_moderation_author_receipt_v1(
      v_event.target_id::uuid,
      v_event.metadata
    );
  end loop;
end
$bil05_backfill$;

-- Pending/hidden poll review projection. Vote identities and vote totals are not
-- required to moderate the authored content, so they are intentionally omitted.
create or replace function public.bil_community_moderation_polls_v1(
  p_post_ids uuid[]
)
returns table(
  post_id uuid,
  poll jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if private.bil_resolve_community_moderation_authority(v_uid) is null then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if p_post_ids is null
     or cardinality(p_post_ids) < 1
     or cardinality(p_post_ids) > 100
     or cardinality(p_post_ids) <> (
       select count(distinct value) from unnest(p_post_ids) value
     ) then
    raise exception 'invalid_moderation_poll_batch' using errcode = '22023';
  end if;

  return query
  select
    p.post_id,
    pg_catalog.jsonb_build_object(
      'post_id', p.post_id,
      'question', p.question,
      'allow_multiple', p.allow_multiple,
      'closes_at', p.closes_at,
      'closed', p.closes_at is not null and p.closes_at <= pg_catalog.clock_timestamp(),
      'total_votes', 0,
      'options', (
        select coalesce(
          pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'id', o.id,
              'position', o.position,
              'text', o.option_text,
              'vote_count', 0,
              'selected', false
            ) order by o.position
          ),
          '[]'::jsonb
        )
        from public.bil_community_poll_options o
        where o.post_id = p.post_id
      )
    )
  from public.bil_community_polls p
  join public.bil_community_posts post on post.id = p.post_id
  where p.post_id = any(p_post_ids)
    and post.deleted_at is null
  order by p.post_id;
end
$function$;

revoke all on function public.bil_community_moderation_polls_v1(uuid[])
  from public, anon, service_role;
grant execute on function public.bil_community_moderation_polls_v1(uuid[])
  to authenticated;

do $bil05_postcondition$
begin
  if to_regprocedure(
       'private.bil_emit_post_moderation_author_receipt_v1(uuid,jsonb)'
     ) is null
     or to_regprocedure(
       'private.bil_emit_post_moderation_author_receipt_trigger_v1()'
     ) is null
     or to_regprocedure(
       'public.bil_community_moderation_polls_v1(uuid[])'
     ) is null
     or not exists (
       select 1
       from pg_catalog.pg_trigger t
       join pg_catalog.pg_class c on c.oid = t.tgrelid
       join pg_catalog.pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public'
         and c.relname = 'bil_community_audit_events'
         and t.tgname = 'bil_emit_post_moderation_author_receipt_v1'
         and not t.tgisinternal
     ) then
    raise exception 'bil05_activity_reward_postcondition_failed';
  end if;
end
$bil05_postcondition$;

notify pgrst, 'reload schema';
commit;
