set local lock_timeout='5s';
set local statement_timeout='30s';

do $preflight$
begin
  if to_regclass('public.bil_public_profiles') is null
     or to_regprocedure('public.bil_has_active_premium(uuid)') is null
     or to_regprocedure('public.bil_social_member_visible_v2(uuid)') is null then
    raise exception 'community_membership_tier_dependencies_missing';
  end if;
  if to_regprocedure(
    'public.bil_community_comment_membership_tiers_v1(uuid[])'
  ) is not null then
    raise exception 'community_membership_tier_v1_already_exists';
  end if;
end
$preflight$;

create or replace function public.bil_community_comment_membership_tiers_v1(
  p_user_ids uuid[]
)
returns table(
  user_id uuid,
  membership_tier text
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_uid uuid:=(select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode='42501';
  end if;
  if p_user_ids is null
     or cardinality(p_user_ids)<1
     or cardinality(p_user_ids)>100
     or cardinality(p_user_ids)<>(
       select count(distinct value) from unnest(p_user_ids) value
     ) then
    raise exception 'invalid_community_membership_tier_batch'
      using errcode='22023';
  end if;

  return query
  select
    p.user_id,
    case
      when public.bil_has_active_premium(p.user_id) then 'premium'
      else 'free'
    end
  from public.bil_public_profiles p
  where p.user_id=any(p_user_ids)
    and p.show_membership_tier
    and (
      p.user_id=v_uid
      or public.bil_social_member_visible_v2(p.user_id)
    )
  order by p.user_id;
end
$$;

revoke all on function public.bil_community_comment_membership_tiers_v1(uuid[])
  from public,anon,service_role;
grant execute on function public.bil_community_comment_membership_tiers_v1(uuid[])
  to authenticated;

do $postconditions$
begin
  if to_regprocedure(
    'public.bil_community_comment_membership_tiers_v1(uuid[])'
  ) is null then
    raise exception 'community_membership_tier_postcondition_failed';
  end if;
end
$postconditions$;
