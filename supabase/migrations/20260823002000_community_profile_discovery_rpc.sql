-- Allow authenticated members to discover a minimal public identity before
-- friendship exists. Detailed profile visibility remains enforced by the
-- bil_public_profiles RLS policy.
create or replace function public.bil_search_community_profiles(
  p_query text default '',
  p_limit integer default 30
)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  locale_code text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    p.user_id,
    p.display_name,
    p.avatar_url,
    p.locale_code
  from public.bil_public_profiles p
  where auth.uid() is not null
    and p.user_id <> auth.uid()
    and p.discoverable = true
    and p.allow_friend_requests = true
    and not exists (
      select 1
      from public.bil_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid())
    )
    and (
      nullif(btrim(p_query), '') is null
      or p.display_name ilike ('%' || btrim(p_query) || '%')
    )
  order by p.display_name, p.user_id
  limit least(greatest(coalesce(p_limit, 30), 1), 30);
$$;

revoke all on function public.bil_search_community_profiles(text, integer)
from public, anon;
grant execute on function public.bil_search_community_profiles(text, integer)
to authenticated;
