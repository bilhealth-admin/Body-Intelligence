-- Durable Community acceptance notifications, authoritative in-app attention,
-- Realtime refresh, push outbox delivery, and per-device Community push
-- category controls. Existing request/message push behavior remains compatible.
set local lock_timeout='5s';
set local statement_timeout='30s';

create table if not exists public.bil_community_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  kind text not null check (kind in ('friend_accepted')),
  friendship_id uuid references public.bil_friendships(id) on delete set null,
  source_key text not null unique check (char_length(source_key) between 16 and 128),
  created_at timestamptz not null default now(),
  seen_at timestamptz
);
alter table public.bil_community_notifications enable row level security;
revoke all on table public.bil_community_notifications from public,anon,authenticated,service_role;
grant select on table public.bil_community_notifications to authenticated;
drop policy if exists bil_community_notifications_read_own on public.bil_community_notifications;
create policy bil_community_notifications_read_own
on public.bil_community_notifications for select to authenticated
using (recipient_id=(select auth.uid()));
create index if not exists bil_community_notifications_recipient_unseen_idx
on public.bil_community_notifications(recipient_id,created_at desc,id)
where seen_at is null;

create or replace function public.bil_list_community_notifications(p_limit integer default 30)
returns table(
  id uuid,
  kind text,
  actor_id uuid,
  actor_display_name text,
  actor_avatar_url text,
  friendship_id uuid,
  created_at timestamptz,
  seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid_notification_limit' using errcode='22023';
  end if;
  return query
  select n.id,n.kind,n.actor_id,p.display_name,p.avatar_url,n.friendship_id,n.created_at,n.seen_at
  from public.bil_community_notifications n
  left join public.bil_public_profiles p on p.user_id=n.actor_id
  where n.recipient_id=v_uid
  order by n.created_at desc,n.id desc
  limit p_limit;
end
$$;

create or replace function public.bil_mark_community_notifications_seen(p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path=''
as $$
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
$$;

revoke all on function public.bil_list_community_notifications(integer) from public,anon,service_role;
grant execute on function public.bil_list_community_notifications(integer) to authenticated;
revoke all on function public.bil_mark_community_notifications_seen(uuid[]) from public,anon,service_role;
grant execute on function public.bil_mark_community_notifications_seen(uuid[]) to authenticated;

create or replace function public.bil_enqueue_friendship_acceptance_notification()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare v_notification_id uuid;
begin
  if old.status='pending' and new.status='accepted' then
    insert into public.bil_community_notifications(
      recipient_id,actor_id,kind,friendship_id,source_key
    )
    values(
      new.requester_id,new.addressee_id,'friend_accepted',new.id,
      'friend_accepted:'||new.id::text
    )
    on conflict(source_key) do nothing
    returning id into v_notification_id;

    if v_notification_id is not null then
      insert into public.bil_push_outbox(
        recipient_id,category,title,body,deep_link,copy_key,source_key
      )
      values(
        new.requester_id,'community','BIL',
        'Your friend request was accepted.',
        'bil://community/notifications',
        'friend_accepted_v1',
        'friend_accepted:'||new.id::text
      )
      on conflict(recipient_id,source_key) where source_key is not null do nothing;
    end if;
  end if;
  return new;
end
$$;
revoke all on function public.bil_enqueue_friendship_acceptance_notification()
from public,anon,authenticated,service_role;

drop trigger if exists bil_friendship_acceptance_notification on public.bil_friendships;
create trigger bil_friendship_acceptance_notification
after update of status on public.bil_friendships
for each row execute function public.bil_enqueue_friendship_acceptance_notification();

create or replace function private.bil_attention_snapshot_v1(p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
with eligible_owner as (
  select p_owner as user_id
  where p_owner is not null
    and not exists(
      select 1 from private.bil_community_member_access a
      where a.user_id=p_owner and a.suspended
    )
),
unread as (
  select m.sender_id,count(*)::integer as amount
  from public.bil_messages m
  join eligible_owner o on o.user_id=m.recipient_id
  where m.read_at is null
    and m.deleted_by_recipient_at is null
    and not exists(
      select 1 from public.bil_blocks b
      where (b.blocker_id=p_owner and b.blocked_id=m.sender_id)
         or (b.blocker_id=m.sender_id and b.blocked_id=p_owner)
    )
    and not exists(
      select 1 from private.bil_community_member_access a
      where a.user_id=m.sender_id and a.suspended
    )
  group by m.sender_id
),
requests as (
  select count(*)::integer as amount
  from public.bil_friendships f
  join eligible_owner o on o.user_id=f.addressee_id
  where f.status='pending'
    and not exists(
      select 1 from public.bil_blocks b
      where (b.blocker_id=p_owner and b.blocked_id=f.requester_id)
         or (b.blocker_id=f.requester_id and b.blocked_id=p_owner)
    )
    and not exists(
      select 1 from private.bil_community_member_access a
      where a.user_id=f.requester_id and a.suspended
    )
),
updates as (
  select count(*)::integer as amount
  from public.bil_community_notifications n
  join eligible_owner o on o.user_id=n.recipient_id
  where n.seen_at is null
)
select jsonb_build_object(
  'unread_messages',coalesce((select sum(amount) from unread),0),
  'incoming_requests',coalesce((select amount from requests),0),
  'community_updates',coalesce((select amount from updates),0),
  'unread_by_sender',coalesce(
    (select jsonb_object_agg(sender_id::text,amount) from unread),
    '{}'::jsonb
  )
);
$$;

alter table public.bil_push_device_tokens
  add column if not exists message_enabled boolean not null default true,
  add column if not exists friend_request_enabled boolean not null default true,
  add column if not exists friend_accepted_enabled boolean not null default true;

create or replace function public.bil_register_push_token_v2(
  p_token text,
  p_platform text,
  p_timezone text,
  p_sensitive_preview_allowed boolean default false,
  p_message_enabled boolean default true,
  p_friend_request_enabled boolean default true,
  p_friend_accepted_enabled boolean default true
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='42501'; end if;
  if length(p_token)<20 or p_platform not in ('fcm','apns') then
    raise exception 'invalid push token';
  end if;
  if p_message_enabled is null or p_friend_request_enabled is null or p_friend_accepted_enabled is null then
    raise exception 'invalid push categories' using errcode='22023';
  end if;
  insert into public.bil_push_device_tokens(
    user_id,token_ciphertext,token_fingerprint,platform,timezone,
    sensitive_preview_allowed,message_enabled,friend_request_enabled,
    friend_accepted_enabled
  ) values(
    auth.uid(),p_token,encode(extensions.digest(p_token,'sha256'),'hex'),
    p_platform,p_timezone,false,p_message_enabled,p_friend_request_enabled,
    p_friend_accepted_enabled
  )
  on conflict(token_fingerprint) do update
    set user_id=auth.uid(),
        enabled=true,
        timezone=excluded.timezone,
        last_seen_at=now(),
        sensitive_preview_allowed=false,
        message_enabled=excluded.message_enabled,
        friend_request_enabled=excluded.friend_request_enabled,
        friend_accepted_enabled=excluded.friend_accepted_enabled;
end
$$;

create or replace function public.bil_set_push_delivery_categories_v2(
  p_message_enabled boolean,
  p_friend_request_enabled boolean,
  p_friend_accepted_enabled boolean
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode='42501'; end if;
  if p_message_enabled is null or p_friend_request_enabled is null or p_friend_accepted_enabled is null then
    raise exception 'invalid push categories' using errcode='22023';
  end if;
  update public.bil_push_device_tokens
  set message_enabled=p_message_enabled,
      friend_request_enabled=p_friend_request_enabled,
      friend_accepted_enabled=p_friend_accepted_enabled,
      last_seen_at=now()
  where user_id=auth.uid() and enabled;
end
$$;
revoke all on function public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean)
from public,anon,service_role;
grant execute on function public.bil_register_push_token_v2(text,text,text,boolean,boolean,boolean,boolean)
to authenticated;
revoke all on function public.bil_set_push_delivery_categories_v2(boolean,boolean,boolean)
from public,anon,service_role;
grant execute on function public.bil_set_push_delivery_categories_v2(boolean,boolean,boolean)
to authenticated;

create or replace function public.bil_claim_push_deliveries(
  p_outbox_id uuid,p_lease_seconds integer default 60
)
returns table(
  device_token_id uuid,provider_token text,platform text,
  sensitive_preview_allowed boolean,delivery_key text
)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_recipient_id uuid;
  v_category text;
  v_copy_key text;
  v_max_attempts integer;
  v_lease_seconds integer:=least(greatest(coalesce(p_lease_seconds,60),15),300);
begin
  select policy.max_attempts into v_max_attempts
  from public.bil_push_delivery_policy policy where policy.singleton;
  if v_max_attempts is null then raise exception 'push_delivery_policy_unavailable'; end if;

  select outbox.recipient_id,outbox.category,outbox.copy_key
  into v_recipient_id,v_category,v_copy_key
  from public.bil_push_outbox outbox
  where outbox.id=p_outbox_id and outbox.dispatched_at is null
  for update;
  if v_recipient_id is null then return; end if;

  insert into public.bil_push_delivery_attempts(outbox_id,device_token_id)
  select p_outbox_id,token.id
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id
    and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end
  on conflict on constraint bil_push_delivery_attempts_pkey do nothing;

  return query
  with eligible as (
    select attempt.outbox_id,attempt.device_token_id
    from public.bil_push_delivery_attempts attempt
    join public.bil_push_device_tokens token on token.id=attempt.device_token_id
    where attempt.outbox_id=p_outbox_id
      and token.user_id=v_recipient_id
      and token.enabled
      and attempt.delivered_at is null
      and attempt.terminal_at is null
      and attempt.attempt_count<v_max_attempts
      and attempt.next_attempt_at<=pg_catalog.clock_timestamp()
      and (attempt.leased_until is null or attempt.leased_until<=pg_catalog.clock_timestamp())
    order by attempt.device_token_id
    limit 100
    for update of attempt skip locked
  ),
  claimed as (
    update public.bil_push_delivery_attempts attempt
    set leased_until=pg_catalog.clock_timestamp()+pg_catalog.make_interval(secs=>v_lease_seconds),
        last_attempt_at=pg_catalog.clock_timestamp(),
        attempt_count=attempt.attempt_count+1
    from eligible
    where attempt.outbox_id=eligible.outbox_id
      and attempt.device_token_id=eligible.device_token_id
    returning attempt.device_token_id
  )
  select token.id,token.token_ciphertext,token.platform,
         token.sensitive_preview_allowed,
         p_outbox_id::text||':'||token.id::text
  from claimed
  join public.bil_push_device_tokens token on token.id=claimed.device_token_id;
end
$$;

create or replace function public.bil_finalize_push_outbox(p_outbox_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_recipient_id uuid;
  v_category text;
  v_copy_key text;
  v_enabled_tokens integer:=0;
  v_enabled_without_attempt integer:=0;
  v_unresolved_enabled integer:=0;
  v_attempted_tokens integer:=0;
  v_delivered_tokens integer:=0;
  v_terminal_tokens integer:=0;
  v_failure_code text;
  v_reason text;
begin
  select o.recipient_id,o.category,o.copy_key
  into v_recipient_id,v_category,v_copy_key
  from public.bil_push_outbox o
  where o.id=p_outbox_id and o.dispatched_at is null
  for update;

  if v_recipient_id is null then
    return jsonb_build_object('finalized',true,'reason','already_finalized');
  end if;

  select count(*)::integer into v_enabled_tokens
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end;

  select count(*)::integer,
         count(*) filter(where attempt.delivered_at is not null)::integer,
         count(*) filter(where attempt.delivered_at is null and attempt.terminal_at is not null)::integer
  into v_attempted_tokens,v_delivered_tokens,v_terminal_tokens
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token on token.id=attempt.device_token_id
  where attempt.outbox_id=p_outbox_id
    and token.user_id=v_recipient_id
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end;

  select count(*)::integer into v_enabled_without_attempt
  from public.bil_push_device_tokens token
  where token.user_id=v_recipient_id and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end
    and not exists(
      select 1 from public.bil_push_delivery_attempts attempt
      where attempt.outbox_id=p_outbox_id and attempt.device_token_id=token.id
    );

  select count(*)::integer into v_unresolved_enabled
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token on token.id=attempt.device_token_id
  where attempt.outbox_id=p_outbox_id
    and token.user_id=v_recipient_id
    and token.enabled
    and case
      when v_category='message' then token.message_enabled
      when v_category='friend_request' then token.friend_request_enabled
      when v_category='community' and v_copy_key='friend_accepted_v1'
        then token.friend_accepted_enabled
      else true
    end
    and attempt.delivered_at is null
    and attempt.terminal_at is null;

  if v_enabled_tokens=0 and v_attempted_tokens=0 then
    update public.bil_push_outbox
    set dispatched_at=pg_catalog.clock_timestamp(),
        failure_code='no_eligible_tokens'
    where id=p_outbox_id;
    return jsonb_build_object(
      'finalized',true,'reason','no_eligible_tokens','delivered',0,'expected',0
    );
  end if;

  if v_enabled_without_attempt=0 and v_unresolved_enabled=0 then
    v_reason:=case
      when v_delivered_tokens=v_attempted_tokens then 'delivered'
      when v_delivered_tokens>0 then 'partial_delivery'
      else 'delivery_failed'
    end;
    update public.bil_push_outbox
    set dispatched_at=pg_catalog.clock_timestamp(),
        failure_code=case when v_reason='delivered' then null else v_reason end
    where id=p_outbox_id;
    return jsonb_build_object(
      'finalized',true,'reason',v_reason,'delivered',v_delivered_tokens,
      'terminal',v_terminal_tokens,'expected',v_attempted_tokens
    );
  end if;

  select attempt.failure_code into v_failure_code
  from public.bil_push_delivery_attempts attempt
  join public.bil_push_device_tokens token on token.id=attempt.device_token_id
  where attempt.outbox_id=p_outbox_id
    and token.user_id=v_recipient_id
    and token.enabled
    and attempt.delivered_at is null
    and attempt.terminal_at is null
    and attempt.failure_code is not null
  order by attempt.last_attempt_at desc nulls last
  limit 1;

  update public.bil_push_outbox
  set dispatched_at=null,failure_code=coalesce(v_failure_code,'delivery_pending')
  where id=p_outbox_id;

  return jsonb_build_object(
    'finalized',false,'reason',coalesce(v_failure_code,'delivery_pending'),
    'delivered',v_delivered_tokens,'terminal',v_terminal_tokens,
    'expected',v_attempted_tokens+v_enabled_without_attempt
  );
end
$$;

do $publication$
begin
  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='bil_community_notifications'
  ) then
    alter publication supabase_realtime add table public.bil_community_notifications;
  end if;
end
$publication$;

do $post$
begin
  if not exists(
    select 1 from pg_trigger
    where tgrelid='public.bil_friendships'::regclass
      and tgname='bil_friendship_acceptance_notification'
      and not tgisinternal
  ) then raise exception 'friend_acceptance_trigger_missing'; end if;

  if not has_function_privilege(
    'authenticated','public.bil_list_community_notifications(integer)','EXECUTE'
  ) or has_function_privilege(
    'anon','public.bil_list_community_notifications(integer)','EXECUTE'
  ) then raise exception 'community_notification_rpc_acl_failed'; end if;

  if not exists(
    select 1 from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='bil_community_notifications'
  ) then raise exception 'community_notification_realtime_missing'; end if;
end
$post$;

notify pgrst,'reload schema';
