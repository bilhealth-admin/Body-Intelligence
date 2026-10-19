-- Account deletion removes the creator's Circle text and dependent records.
-- Physical files are removed first by account-data-deletion's owner-prefix
-- Storage API traversal (already includes community-circle-media).
begin;
set local lock_timeout='5s';
create function private.bil_remove_owned_circles_before_account_delete_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  delete from public.bil_community_circles c
  using public.bil_circle_metadata_v1 m
  where m.circle_id=c.id and m.created_by=old.id;
  return old;
end $$;
revoke all on function private.bil_remove_owned_circles_before_account_delete_v1()
from public,anon,authenticated,service_role;
create trigger bil_remove_owned_circles_before_account_delete_v1
before delete on auth.users for each row
execute function private.bil_remove_owned_circles_before_account_delete_v1();
commit;
