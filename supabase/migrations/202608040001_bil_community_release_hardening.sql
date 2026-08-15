begin;

-- Mark only messages addressed to the caller. The client never receives
-- update privileges for arbitrary message rows.
create or replace function public.bil_mark_conversation_read(p_sender_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.bil_messages
  set read_at = coalesce(read_at, now())
  where sender_id = p_sender_id
    and recipient_id = auth.uid()
    and read_at is null
    and deleted_by_recipient_at is null;
$$;

grant execute on function public.bil_mark_conversation_read(uuid) to authenticated;

-- Blocking is atomic: it removes an existing relationship and prevents an
-- old accepted friendship from continuing to authorize messages.
create or replace function public.bil_block_community_member(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_blocked_id = auth.uid() then
    raise exception 'cannot_block_self';
  end if;

  insert into public.bil_blocks (blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict (blocker_id, blocked_id) do nothing;

  delete from public.bil_friendships
  where (requester_id = auth.uid() and addressee_id = p_blocked_id)
     or (requester_id = p_blocked_id and addressee_id = auth.uid());
end;
$$;

grant execute on function public.bil_block_community_member(uuid) to authenticated;

-- Do not expose messages a participant has hidden for themselves.
drop policy if exists bil_messages_read_parties on public.bil_messages;
create policy bil_messages_read_parties
on public.bil_messages
for select
to authenticated
using (
  (sender_id = auth.uid() and deleted_by_sender_at is null)
  or (recipient_id = auth.uid() and deleted_by_recipient_at is null)
);

commit;
