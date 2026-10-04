-- Forward-only bounded moderator list contract. The genuine unchanged RPC
-- returned125 qualifying local rows for NULL, versus100 for explicit100.
-- PostgreSQL LIMIT NULL is unbounded; three-valued NOT BETWEEN missed NULL.
-- Only that invalid-input predicate changes. No privileges, policies, schema,
-- default limit, moderation authority, filters, ordering or projection changes.
set local lock_timeout='3s';
set local statement_timeout='30s';

do $hidden_posts_source_guard$
begin
  if not exists(select 1 from pg_catalog.pg_proc p
      where p.oid=pg_catalog.to_regprocedure('public.bil_list_hidden_community_posts(integer)')
        and pg_catalog.md5(p.prosrc)='23779f162caf3fe13dde7870089aa3c9'
        and pg_catalog.md5(pg_catalog.pg_get_functiondef(p.oid))='7bbe39e1f8484ce8d0282ab6cc805374'
        and p.prosecdef and p.provolatile='s'
        and p.proowner='postgres'::regrole
        and p.proconfig=array['search_path=""'])
     or not exists(select 1 from pg_catalog.pg_proc p
      where p.oid=pg_catalog.to_regprocedure('private.bil_resolve_community_moderation_authority(uuid)')
        and pg_catalog.md5(p.prosrc)='f28b6e4ee92d8aa59f3a5c9f982dfe9d') then
    raise exception 'community_hidden_posts_limit_source_drift' using errcode='55000';
  end if;
end
$hidden_posts_source_guard$;

CREATE OR REPLACE FUNCTION public.bil_list_hidden_community_posts(p_limit integer DEFAULT 100)
 RETURNS TABLE(id uuid, author_id uuid, body text, created_at timestamp with time zone, media_object_path text, media_mime_type text, media_bytes integer, media_width integer, media_height integer, moderation_status text, moderation_visibility text, reviewed_at timestamp with time zone, author_name text, author_avatar_url text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if private.bil_resolve_community_moderation_authority(
    (select auth.uid())
  ) is null then
    raise exception 'moderator_or_administrator_required' using errcode = '42501';
  end if;
  if p_limit is null or p_limit not between 1 and 100 then
    raise exception 'invalid_limit' using errcode = '22023';
  end if;

  return query
  select p.id, p.author_id, p.body, p.created_at,
    p.media_object_path, p.media_mime_type, p.media_bytes,
    p.media_width, p.media_height, p.moderation_status,
    p.moderation_visibility, p.reviewed_at,
    profile.display_name, profile.avatar_url
  from public.bil_community_posts p
  left join public.bil_public_profiles profile on profile.user_id = p.author_id
  where p.moderation_status = 'approved'
    and p.moderation_visibility = 'hidden_by_moderator'
    and p.deleted_at is null
  order by p.created_at desc, p.id desc
  limit p_limit;
end
$function$;
