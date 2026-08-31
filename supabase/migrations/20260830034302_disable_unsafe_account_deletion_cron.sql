begin;

-- Emergency fail-safe: the superseded SQL-only worker deleted auth.users
-- without first removing the user's Supabase Storage objects through the
-- Storage API. Leave new deletion requests pending until the storage-first
-- Edge worker and its secrets are deployed together.
do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'bil-account-data-deletion-15m'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

create or replace function private.bil_process_account_deletions(
  p_batch_size integer default 25
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
begin
  raise exception 'storage_api_account_deletion_worker_required';
end;
$$;

revoke all on function private.bil_process_account_deletions(integer)
  from public, anon, authenticated;

comment on function private.bil_process_account_deletions(integer) is
  'Deprecated fail-closed guard. Pending requests require the Storage-first Edge worker before auth.users deletion.';

commit;
