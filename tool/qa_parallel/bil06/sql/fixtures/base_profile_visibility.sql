-- Exact function body from BASE source blob 08e726231da0167489aa53c096e2e4881090f48b.
create function public.bil_social_profile_visible_v2(p_member uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.bil_social_member_visible_v2(p_member) and exists(select 1 from public.bil_public_profiles p where p.user_id=p_member and (p.user_id=auth.uid() or (p.profile_visibility='public' and p.discoverable) or (p.profile_visibility='friends' and exists(select 1 from public.bil_friendships f where f.status='accepted' and ((f.requester_id=auth.uid() and f.addressee_id=p.user_id) or (f.addressee_id=auth.uid() and f.requester_id=p.user_id))))))
$$;
revoke all on function public.bil_social_profile_visible_v2(uuid) from public,anon,service_role;
grant execute on function public.bil_social_profile_visible_v2(uuid) to authenticated;
