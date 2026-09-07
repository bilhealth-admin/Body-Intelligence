begin;

-- The protected owner is deliberately not allowed to review their own posts.
-- Keep an independent, existing store-review account enrolled so ordinary
-- community submissions have a valid human-review path in production.
do $$
declare
  v_reviewer_id uuid;
begin
  select account.id
    into v_reviewer_id
  from auth.users account
  where lower(account.email) = 'play-review@bilhealth.com'
  limit 1;

  if v_reviewer_id is null then
    raise exception 'community_moderation_reviewer_missing';
  end if;

  insert into public.bil_community_moderators(user_id)
  values (v_reviewer_id)
  on conflict (user_id) do nothing;
end
$$;

-- The profile setting existed but was not part of the message INSERT policy.
-- Read it through a locked-down helper so a private recipient profile is not
-- exposed through the policy subquery.
create or replace function public.bil_recipient_allows_community_message(
  p_recipient_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select profile.allow_messages_from = 'friends'
      from public.bil_public_profiles profile
      where profile.user_id = p_recipient_id
    ),
    true
  );
$$;

revoke all on function public.bil_recipient_allows_community_message(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.bil_recipient_allows_community_message(uuid)
to authenticated;

drop policy if exists bil_messages_send_friends on public.bil_messages;
create policy bil_messages_send_friends on public.bil_messages
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and public.bil_recipient_allows_community_message(recipient_id)
  and not exists (
    select 1
    from public.bil_blocks b
    where (b.blocker_id = sender_id and b.blocked_id = recipient_id)
       or (b.blocker_id = recipient_id and b.blocked_id = sender_id)
  )
  and exists (
    select 1
    from public.bil_friendships f
    where f.status = 'accepted'
      and (
        (f.requester_id = sender_id and f.addressee_id = recipient_id)
        or (f.addressee_id = sender_id and f.requester_id = recipient_id)
      )
  )
);

commit;
