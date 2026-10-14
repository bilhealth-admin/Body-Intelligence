-- Execute grantees match current published ACL. Original postgres owner maps
-- to the local isolated DB creator; no LOGIN/user privileges are added.
revoke all on function public.bil_add_community_moderator_by_email(uuid, text, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_add_community_moderator_by_email(uuid, text, text) to service_role;
revoke all on function public.bil_moderate_community_post(uuid, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_moderate_community_post(uuid, text) to authenticated;
revoke all on function public.bil_moderate_community_report(uuid, text, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_moderate_community_report(uuid, text, text) to authenticated,service_role;
revoke all on function public.bil_moderate_published_community_post(uuid, text, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_moderate_published_community_post(uuid, text, text) to authenticated;
revoke all on function public.bil_reinstate_community_member(uuid, uuid, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_reinstate_community_member(uuid, uuid, text) to service_role;
revoke all on function public.bil_remove_community_moderator(uuid, uuid, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_remove_community_moderator(uuid, uuid, text) to service_role;
revoke all on function public.bil_social_resolve_comment_report_v2(uuid, boolean) from public,anon,authenticated,service_role;
grant execute on function public.bil_social_resolve_comment_report_v2(uuid, boolean) to authenticated;
revoke all on function public.bil_suspend_community_member_by_email(uuid, text, text, text) from public,anon,authenticated,service_role;
grant execute on function public.bil_suspend_community_member_by_email(uuid, text, text, text) to service_role;
