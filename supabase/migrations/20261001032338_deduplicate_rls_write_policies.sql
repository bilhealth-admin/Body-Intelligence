drop policy if exists bil_records_select_own on public.bil_cloud_records;
drop policy if exists bil_records_insert_own on public.bil_cloud_records;
drop policy if exists bil_records_update_own on public.bil_cloud_records;

drop policy if exists bil_follows_own_write on public.bil_follows;

create policy bil_follows_insert_own
on public.bil_follows
for insert
to authenticated
with check (follower_id = (select auth.uid()));

create policy bil_follows_update_own
on public.bil_follows
for update
to authenticated
using (follower_id = (select auth.uid()))
with check (follower_id = (select auth.uid()));

create policy bil_follows_delete_own
on public.bil_follows
for delete
to authenticated
using (follower_id = (select auth.uid()));
