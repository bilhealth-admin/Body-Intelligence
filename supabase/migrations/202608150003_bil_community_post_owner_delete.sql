-- BIL Community: authors must be able to remove their own posts.
-- The UI exposes this action and the repository scopes the mutation by both
-- post id and author id; RLS remains the authoritative boundary.

drop policy if exists bil_posts_delete_own on public.bil_community_posts;
create policy bil_posts_delete_own
on public.bil_community_posts
for delete
to authenticated
using (author_id = (select auth.uid()));
