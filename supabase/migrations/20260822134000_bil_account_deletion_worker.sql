-- Process authenticated account-deletion requests without a public service
-- credential or a client-triggered privileged endpoint. The worker lives in
-- a non-exposed schema and is invoked only by pg_cron as the database owner.

create extension if not exists pg_cron with schema pg_catalog;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.bil_process_account_deletions(
  p_batch_size integer default 25
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  v_user_id uuid;
  v_processed integer := 0;
begin
  if p_batch_size < 1 or p_batch_size > 100 then
    raise exception 'invalid_batch_size';
  end if;

  for v_user_id in
    select request.user_id
    from public.bil_account_deletion_requests as request
    where request.status = 'pending'
    order by request.requested_at, request.id
    for update skip locked
    limit p_batch_size
  loop
    update public.bil_account_deletion_requests
    set status = 'processing'
    where user_id = v_user_id and status = 'pending';

    -- Every user-owned BIL foreign key is CASCADE (audit identities are
    -- SET NULL), so one hard Auth deletion removes the account and its
    -- developer-controlled cloud data in the same transaction.
    delete from auth.users where id = v_user_id;
    v_processed := v_processed + 1;
  end loop;

  return v_processed;
end;
$$;

revoke all on function private.bil_process_account_deletions(integer)
  from public, anon, authenticated;

comment on function private.bil_process_account_deletions(integer) is
  'Hard-deletes queued BIL Auth users and CASCADE-owned cloud data; cron only.';

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'bil-account-data-deletion-15m';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'bil-account-data-deletion-15m',
    '*/15 * * * *',
    'select private.bil_process_account_deletions(25);'
  );
end;
$$;
