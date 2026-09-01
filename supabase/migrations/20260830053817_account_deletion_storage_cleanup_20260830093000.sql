begin;

-- A deletion claim is recoverable after an interrupted Edge Function run.
alter table public.bil_account_deletion_requests
  add column if not exists processing_started_at timestamptz,
  add column if not exists failure_code text;

-- The hosted Edge Function uses the service-role client to claim and inspect
-- deletion requests. RLS bypass alone does not replace table privileges.
grant select, update on table public.bil_account_deletion_requests
  to service_role;

-- Preserve owner-only visibility while evaluating auth.uid() once per query.
drop policy if exists bil_deletion_request_own
  on public.bil_account_deletion_requests;
create policy bil_deletion_request_own
on public.bil_account_deletion_requests
for select
to authenticated
using (user_id = (select auth.uid()));

-- Claims created by the superseded database-only worker are safe to retry.
update public.bil_account_deletion_requests
set status = 'pending',
    processing_started_at = null,
    failure_code = 'storage_worker_upgrade_retry'
where status = 'processing';

-- The old pg_cron worker deleted auth.users directly. That is unsafe once an
-- account can own Storage objects: Supabase requires the Storage API to remove
-- underlying bytes before Auth deletion. Disable the old job and make direct
-- execution fail closed.
do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname in (
      'bil-account-data-deletion-15m',
      'bil-account-data-deletion-storage-first-15m'
    )
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
  'Deprecated fail-closed guard. Account deletion must run through the Storage API Edge Function before auth.users deletion.';

create extension if not exists pg_net with schema extensions;

-- The Edge Function uses its default service-role credential to validate the
-- cron header without copying the shared secret out of Vault. PostgREST can
-- see this public-schema RPC, but only service_role is allowed to execute it.
create or replace function public.bil_validate_account_deletion_secret(
  p_presented text
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, vault, extensions, pg_temp
as $$
declare
  v_configured text;
begin
  if nullif(p_presented, '') is null then
    return false;
  end if;

  select decrypted_secret into v_configured
  from vault.decrypted_secrets
  where name = 'bil_internal_deletion_secret'
  order by created_at desc
  limit 1;

  if nullif(v_configured, '') is null then
    return false;
  end if;

  return extensions.digest(convert_to(p_presented, 'UTF8'), 'sha256') =
    extensions.digest(convert_to(v_configured, 'UTF8'), 'sha256');
end;
$$;

revoke all on function public.bil_validate_account_deletion_secret(text)
  from public, anon, authenticated;
grant execute on function public.bil_validate_account_deletion_secret(text)
  to service_role;

comment on function public.bil_validate_account_deletion_secret(text) is
  'Service-role-only validation for the Vault-held account deletion cron secret.';

-- Required Vault entries (values are never committed to source):
--   bil_account_deletion_worker_url =
--     https://<project-ref>.supabase.co/functions/v1/account-data-deletion
--   bil_internal_deletion_secret = random value retained only in Vault; the
--     Edge Function validates it through a service-role-only database RPC
--   bil_supabase_anon_key = the project publishable/anon JWT used only to pass
--     the platform JWT gate; the private x-bil-deletion-secret authorizes work.
create or replace function private.bil_dispatch_account_deletion_worker()
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public, vault, net, pg_temp
as $$
declare
  v_worker_url text;
  v_internal_secret text;
  v_anon_key text;
  v_request_id bigint;
begin
  select decrypted_secret into v_worker_url
  from vault.decrypted_secrets
  where name = 'bil_account_deletion_worker_url'
  order by created_at desc
  limit 1;

  select decrypted_secret into v_internal_secret
  from vault.decrypted_secrets
  where name = 'bil_internal_deletion_secret'
  order by created_at desc
  limit 1;

  select decrypted_secret into v_anon_key
  from vault.decrypted_secrets
  where name = 'bil_supabase_anon_key'
  order by created_at desc
  limit 1;

  if nullif(trim(v_worker_url), '') is null
     or v_worker_url !~ '^https://[^/]+/functions/v1/account-data-deletion$'
     or nullif(v_internal_secret, '') is null
     or nullif(v_anon_key, '') is null then
    raise exception 'account_deletion_worker_credentials_unavailable';
  end if;

  select net.http_post(
    url := v_worker_url,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'authorization', 'Bearer ' || v_anon_key,
      'x-bil-deletion-secret', v_internal_secret
    ),
    body := jsonb_build_object('source', 'pg_cron'),
    timeout_milliseconds := 120000
  ) into v_request_id;

  if v_request_id is null then
    raise exception 'account_deletion_worker_dispatch_failed';
  end if;
  return v_request_id;
end;
$$;

revoke all on function private.bil_dispatch_account_deletion_worker()
  from public, anon, authenticated;

comment on function private.bil_dispatch_account_deletion_worker() is
  'Dispatches the secret-protected Storage-first account deletion Edge Function. Missing Vault configuration fails closed.';

do $$
begin
  perform cron.schedule(
    'bil-account-data-deletion-storage-first-15m',
    '*/15 * * * *',
    'select private.bil_dispatch_account_deletion_worker();'
  );
end;
$$;

commit;
