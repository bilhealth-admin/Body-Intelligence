-- Keep authoritative friendship rows visible even when the other account has
-- not created a public Community profile yet. The profile remains optional and
-- no private identity fields are exposed.

create or replace function public.bil_list_community_connections()
returns table(
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
as $function$
  with visible_friendships as (
    select
      f.*,
      case
        when f.requester_id = auth.uid() then f.addressee_id
        else f.requester_id
      end as other_user_id
    from public.bil_friendships f
    where auth.uid() is not null
      and auth.uid() in (f.requester_id, f.addressee_id)
      and f.status in ('pending', 'accepted')
  )
  select
    f.id,
    f.requester_id,
    f.addressee_id,
    f.status,
    f.created_at,
    f.responded_at,
    f.other_user_id,
    other_profile.display_name,
    other_profile.avatar_url
  from visible_friendships f
  left join public.bil_public_profiles other_profile
    on other_profile.user_id = f.other_user_id
  where not exists (
    select 1
    from public.bil_blocks b
    where (b.blocker_id = auth.uid() and b.blocked_id = f.other_user_id)
       or (b.blocker_id = f.other_user_id and b.blocked_id = auth.uid())
  )
  order by f.created_at desc;
$function$;
