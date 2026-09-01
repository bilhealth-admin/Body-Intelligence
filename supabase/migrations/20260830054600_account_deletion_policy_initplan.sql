drop policy if exists bil_deletion_request_own
  on public.bil_account_deletion_requests;

create policy bil_deletion_request_own
on public.bil_account_deletion_requests
for select
to authenticated
using (user_id = (select auth.uid()));
