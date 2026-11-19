-- The Storage API remove endpoint needs SELECT as well as DELETE.
-- Permit only the object's owner, within that same owner's first folder,
-- while Storage evaluates the exact single/batch delete operations.
-- Existing read visibility, DELETE policies, grants and bucket settings remain.
begin;

create policy community_post_image_owner_delete_select_v1
on storage.objects
for select
to authenticated
using (
  bucket_id = 'community-post-images'
  and storage.allow_any_operation(array[
    'storage.object.delete',
    'storage.object.delete_many'
  ])
  and owner_id = (select auth.uid()::text)
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

comment on policy community_post_image_owner_delete_select_v1 on storage.objects is
  'Owner and first-folder SELECT only for Storage delete/delete_many authorization; does not grant list/public reads or replace DELETE policy.';

commit;
