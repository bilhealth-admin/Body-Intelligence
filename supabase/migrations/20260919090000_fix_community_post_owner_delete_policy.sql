-- Delete a member's own post through one atomic, owner-checked operation.
--
-- The client previously performed a direct UPDATE after reading the row. That
-- path is vulnerable to a production ACL/RLS mismatch and gives PostgREST no
-- reliable affected-row signal when the row is hidden by the read policy.
-- Keep the public row soft-deleted (the established community contract), but
-- make the owner check and mutation authoritative in the database.
create or replace function public.bil_delete_community_post(p_post_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_rows integer;
begin
  if auth.uid() is null then
    raise exception 'community_authentication_required' using errcode = '42501';
  end if;

  update public.bil_community_posts
  set deleted_at = pg_catalog.now(),
      media_url = null,
      media_object_path = null,
      media_mime_type = null,
      media_bytes = null,
      media_width = null,
      media_height = null
  where id = p_post_id
    and author_id = auth.uid()
    and deleted_at is null;

  get diagnostics v_rows = row_count;
  return v_rows > 0;
end
$$;

revoke all on function public.bil_delete_community_post(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.bil_delete_community_post(uuid)
to authenticated;
