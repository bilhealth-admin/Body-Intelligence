create or replace function public.bil_remove_published_community_post(
  p_post_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, private, pg_catalog
as $function$
declare
  v_actor uuid := auth.uid();
  v_reason text := pg_catalog.lower(pg_catalog.btrim(p_reason));
begin
  if v_actor is null or not exists (
    select 1 from public.bil_community_moderators m where m.user_id = v_actor
  ) then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if v_reason not in ('spam', 'abuse', 'misleading', 'other') then
    raise exception 'invalid_moderation_reason' using errcode = '22023';
  end if;

  update public.bil_community_posts
  set deleted_at = pg_catalog.now()
  where id = p_post_id
    and moderation_status = 'approved'
    and deleted_at is null;
  if not found then
    raise exception 'published_post_not_found' using errcode = 'P0002';
  end if;

  insert into public.bil_community_audit_events(
    actor_id, event_kind, target_kind, target_id, metadata
  ) values (
    v_actor, 'moderator_remove', 'post', p_post_id,
    pg_catalog.jsonb_build_object('reason', v_reason)
  );
end;
$function$;

revoke all on function public.bil_remove_published_community_post(uuid, text)
  from public, anon;
grant execute on function public.bil_remove_published_community_post(uuid, text)
  to authenticated;
