begin;

create unique index if not exists bil_friendships_unordered_pair_idx
on public.bil_friendships (
  least(requester_id::text, addressee_id::text),
  greatest(requester_id::text, addressee_id::text)
);

drop policy if exists bil_messages_update_recipient on public.bil_messages;
revoke update on public.bil_messages from authenticated;
create or replace function public.bil_mark_message_read(message_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.bil_messages set read_at = coalesce(read_at, now())
  where id = message_id and recipient_id = auth.uid();
$$;
grant execute on function public.bil_mark_message_read(uuid) to authenticated;

create table if not exists public.bil_community_moderators (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.bil_community_moderators enable row level security;
revoke all on public.bil_community_moderators from anon, authenticated;

create or replace function public.bil_finalize_food_submission(submission_id uuid, decision text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.bil_community_moderators where user_id = auth.uid()) then
    raise exception 'moderator_required';
  end if;
  if decision not in ('approved', 'needs_changes', 'rejected') then
    raise exception 'invalid_decision';
  end if;
  update public.bil_community_food_submissions
  set status = decision, reviewed_at = now() where id = submission_id;
end;
$$;
grant execute on function public.bil_finalize_food_submission(uuid, text) to authenticated;

commit;
