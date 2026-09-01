grant select, update on table public.bil_account_deletion_requests
  to service_role;

comment on table public.bil_account_deletion_requests is
  'Account deletion queue; service_role access is limited to worker reads and claim/status updates.';
