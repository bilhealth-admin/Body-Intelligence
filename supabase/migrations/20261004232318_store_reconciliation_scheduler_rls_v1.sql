begin;

alter table private.bil_store_reconciliation_scheduler_state
  enable row level security;

revoke all on table private.bil_store_reconciliation_scheduler_state
  from public, anon, authenticated, service_role;

commit;
