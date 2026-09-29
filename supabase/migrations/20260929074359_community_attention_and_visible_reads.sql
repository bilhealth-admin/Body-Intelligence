-- Additive: legacy clients and the successful QR resolver remain untouched.
-- No user ID is accepted from mobile clients for badge counts or read receipts.
create index if not exists bil_messages_recipient_unread_v1_idx
  on public.bil_messages (recipient_id, sender_id)
  where read_at is null and deleted_by_recipient_at is null;
create index if not exists bil_friendships_incoming_pending_v1_idx
  on public.bil_friendships (addressee_id, requester_id)
  where status = 'pending';

create or replace function private.bil_attention_snapshot_v1(p_owner uuid)
returns jsonb language sql stable security definer set search_path = ''
as $function$
  with eligible_owner as (
    select p_owner as user_id where p_owner is not null
      and not exists (select 1 from private.bil_community_member_access a
        where a.user_id=p_owner and a.suspended)
  ), unread as (
    select m.sender_id, count(*)::integer as amount
    from public.bil_messages m join eligible_owner o on o.user_id=m.recipient_id
    where m.read_at is null and m.deleted_by_recipient_at is null
      and not exists (select 1 from public.bil_blocks b where
        (b.blocker_id=p_owner and b.blocked_id=m.sender_id) or
        (b.blocker_id=m.sender_id and b.blocked_id=p_owner))
      and not exists (select 1 from private.bil_community_member_access a
        where a.user_id=m.sender_id and a.suspended)
    group by m.sender_id
  ), requests as (
    select count(*)::integer as amount from public.bil_friendships f
    join eligible_owner o on o.user_id=f.addressee_id
    where f.status='pending'
      and not exists (select 1 from public.bil_blocks b where
        (b.blocker_id=p_owner and b.blocked_id=f.requester_id) or
        (b.blocker_id=f.requester_id and b.blocked_id=p_owner))
      and not exists (select 1 from private.bil_community_member_access a
        where a.user_id=f.requester_id and a.suspended)
  )
  select jsonb_build_object(
    'unread_messages', coalesce((select sum(amount) from unread),0),
    'incoming_requests', (select amount from requests),
    'unread_by_sender', coalesce((select jsonb_object_agg(sender_id::text, amount)
      from unread),'{}'::jsonb));
$function$;
revoke all on function private.bil_attention_snapshot_v1(uuid) from public, anon, authenticated;

create or replace function public.bil_community_attention_v1()
returns jsonb language plpgsql stable security definer set search_path = ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  return private.bil_attention_snapshot_v1(auth.uid());
end;
$function$;
revoke all on function public.bil_community_attention_v1() from public, anon;
grant execute on function public.bil_community_attention_v1() to authenticated;

-- A delivery worker can query only a count; this endpoint is not executable
-- by mobile/anonymous roles. The worker must still validate its own secret.
create or replace function public.bil_push_badge_count_v1(p_owner_id uuid)
returns integer language sql stable security definer set search_path = ''
as $function$
  select ((s->>'unread_messages')::integer +
          (s->>'incoming_requests')::integer)
  from (select private.bil_attention_snapshot_v1(p_owner_id) as s) snapshot;
$function$;
revoke all on function public.bil_push_badge_count_v1(uuid) from public, anon, authenticated;
grant execute on function public.bil_push_badge_count_v1(uuid) to service_role;

create or replace function public.bil_mark_visible_messages_read_v1(p_message_ids uuid[])
returns integer language plpgsql security definer set search_path = ''
as $function$
declare v_count integer;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if coalesce(cardinality(p_message_ids),0)>200 then
    raise exception 'invalid_message_batch' using errcode='22023';
  end if;
  if not public.bil_can_use_community() then
    raise exception 'community_unavailable' using errcode='42501';
  end if;
  update public.bil_messages m set read_at=clock_timestamp()
  where m.id=any(coalesce(p_message_ids,'{}'::uuid[]))
    and m.recipient_id=auth.uid() and m.read_at is null
    and m.deleted_by_recipient_at is null
    and not exists (select 1 from public.bil_blocks b where
      (b.blocker_id=auth.uid() and b.blocked_id=m.sender_id) or
      (b.blocker_id=m.sender_id and b.blocked_id=auth.uid()));
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;
revoke all on function public.bil_mark_visible_messages_read_v1(uuid[]) from public, anon;
grant execute on function public.bil_mark_visible_messages_read_v1(uuid[]) to authenticated;

-- Existing RLS limits friendship rows to their two parties.
do $publication$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(select 1 from pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public'
         and tablename='bil_friendships') then
    alter publication supabase_realtime add table public.bil_friendships;
  end if;
end;
$publication$;
notify pgrst, 'reload schema';
