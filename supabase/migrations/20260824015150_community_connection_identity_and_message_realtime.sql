-- Resolve the minimal identity needed to render a friendship without making a
-- private profile generally discoverable. Only a relationship participant can
-- receive the other participant's display name and avatar.
create or replace function public.bil_list_community_connections()
returns table (
  id uuid,
  requester_id uuid,
  addressee_id uuid,
  status text,
  created_at timestamptz,
  responded_at timestamptz,
  other_user_id uuid,
  display_name text,
  avatar_url text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    f.id,
    f.requester_id,
    f.addressee_id,
    f.status,
    f.created_at,
    f.responded_at,
    other_profile.user_id,
    other_profile.display_name,
    other_profile.avatar_url
  from public.bil_friendships f
  join public.bil_public_profiles other_profile
    on other_profile.user_id = case
      when f.requester_id = auth.uid() then f.addressee_id
      else f.requester_id
    end
  where auth.uid() is not null
    and auth.uid() in (f.requester_id, f.addressee_id)
    and f.status in ('pending', 'accepted')
    and not exists (
      select 1
      from public.bil_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = other_profile.user_id)
         or (b.blocker_id = other_profile.user_id and b.blocked_id = auth.uid())
    )
  order by f.created_at desc;
$$;

revoke all on function public.bil_list_community_connections()
from public, anon;
grant execute on function public.bil_list_community_connections()
to authenticated;

-- Postgres Changes subscriptions still pass through bil_messages RLS, so a
-- client receives only message rows in which it is a party.
do $$
begin
  alter publication supabase_realtime add table public.bil_messages;
exception
  when duplicate_object then null;
end
$$;

;
