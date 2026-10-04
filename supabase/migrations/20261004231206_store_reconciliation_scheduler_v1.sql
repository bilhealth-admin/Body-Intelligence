begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault;

-- The scheduler secret is generated inside Production and never enters Git,
-- migration output, an Edge Function environment variable, or client code.
do $$
begin
  if not exists (
    select 1 from vault.secrets
    where name = 'BIL_RECONCILIATION_SECRET'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'BIL_RECONCILIATION_SECRET',
      'Secret for the server-owned store reconciliation scheduler'
    );
  end if;
end;
$$;

create table if not exists private.bil_store_reconciliation_scheduler_state (
  singleton boolean primary key default true check (singleton),
  next_cursor text,
  last_request_id bigint,
  last_started_at timestamptz,
  last_finished_at timestamptz,
  last_status text not null default 'never'
    check (last_status in ('never', 'queued', 'success', 'partial')),
  last_examined integer not null default 0 check (last_examined >= 0),
  last_reconciled integer not null default 0 check (last_reconciled >= 0),
  last_superseded integer not null default 0 check (last_superseded >= 0),
  last_failed integer not null default 0 check (last_failed >= 0),
  last_boost_refunds_reconciled integer not null default 0
    check (last_boost_refunds_reconciled >= 0),
  last_boost_refunds_failed integer not null default 0
    check (last_boost_refunds_failed >= 0),
  updated_at timestamptz not null default now()
);

insert into private.bil_store_reconciliation_scheduler_state (singleton)
values (true)
on conflict (singleton) do nothing;

revoke all on table private.bil_store_reconciliation_scheduler_state
  from public, anon, authenticated, service_role;

create or replace function public.bil_validate_store_reconciliation_secret(
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
  where name = 'BIL_RECONCILIATION_SECRET'
  order by created_at desc
  limit 1;

  if nullif(v_configured, '') is null then
    return false;
  end if;

  return extensions.digest(convert_to(p_presented, 'UTF8'), 'sha256') =
    extensions.digest(convert_to(v_configured, 'UTF8'), 'sha256');
end;
$$;

revoke all on function public.bil_validate_store_reconciliation_secret(text)
  from public, anon, authenticated, service_role;
grant execute on function public.bil_validate_store_reconciliation_secret(text)
  to service_role;

create or replace function public.bil_get_store_reconciliation_scheduler_cursor()
returns text
language sql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
  select next_cursor
  from private.bil_store_reconciliation_scheduler_state
  where singleton = true;
$$;

revoke all on function public.bil_get_store_reconciliation_scheduler_cursor()
  from public, anon, authenticated, service_role;
grant execute on function public.bil_get_store_reconciliation_scheduler_cursor()
  to service_role;

create or replace function public.bil_finish_store_reconciliation_scheduler_run(
  p_next_cursor text,
  p_has_more boolean,
  p_examined integer,
  p_reconciled integer,
  p_superseded integer,
  p_failed integer,
  p_boost_refunds_reconciled integer,
  p_boost_refunds_failed integer
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private, pg_temp
as $$
begin
  if p_has_more and nullif(p_next_cursor, '') is null then
    raise exception 'store_reconciliation_cursor_required';
  end if;
  if least(
    p_examined,
    p_reconciled,
    p_superseded,
    p_failed,
    p_boost_refunds_reconciled,
    p_boost_refunds_failed
  ) < 0 then
    raise exception 'store_reconciliation_count_invalid';
  end if;

  update private.bil_store_reconciliation_scheduler_state
  set next_cursor = case when p_has_more then p_next_cursor else null end,
      last_finished_at = now(),
      last_status = case
        when p_failed > 0 or p_boost_refunds_failed > 0 then 'partial'
        else 'success'
      end,
      last_examined = p_examined,
      last_reconciled = p_reconciled,
      last_superseded = p_superseded,
      last_failed = p_failed,
      last_boost_refunds_reconciled = p_boost_refunds_reconciled,
      last_boost_refunds_failed = p_boost_refunds_failed,
      updated_at = now()
  where singleton = true;

  return found;
end;
$$;

revoke all on function public.bil_finish_store_reconciliation_scheduler_run(
  text, boolean, integer, integer, integer, integer, integer, integer
) from public, anon, authenticated, service_role;
grant execute on function public.bil_finish_store_reconciliation_scheduler_run(
  text, boolean, integer, integer, integer, integer, integer, integer
) to service_role;

create or replace function private.bil_dispatch_store_reconciliation()
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, private, vault, net, pg_temp
as $$
declare
  v_internal_secret text;
  v_anon_key text;
  v_request_id bigint;
begin
  if not pg_try_advisory_xact_lock(20261005, 100) then
    return null;
  end if;

  select decrypted_secret into v_internal_secret
  from vault.decrypted_secrets
  where name = 'BIL_RECONCILIATION_SECRET'
  order by created_at desc
  limit 1;

  select decrypted_secret into v_anon_key
  from vault.decrypted_secrets
  where name = 'bil_supabase_anon_key'
  order by created_at desc
  limit 1;

  if nullif(v_internal_secret, '') is null or nullif(v_anon_key, '') is null then
    raise exception 'store_reconciliation_credentials_unavailable';
  end if;

  select net.http_post(
    url := 'https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/verify-store-purchase',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'apikey', v_anon_key,
      'authorization', 'Bearer ' || v_anon_key,
      'x-bil-reconciliation-secret', v_internal_secret
    ),
    body := jsonb_build_object('action', 'reconcile', 'source', 'pg_cron'),
    timeout_milliseconds := 120000
  ) into v_request_id;

  if v_request_id is null then
    raise exception 'store_reconciliation_dispatch_failed';
  end if;

  update private.bil_store_reconciliation_scheduler_state
  set last_request_id = v_request_id,
      last_started_at = now(),
      last_status = 'queued',
      updated_at = now()
  where singleton = true;

  return v_request_id;
end;
$$;

revoke all on function private.bil_dispatch_store_reconciliation()
  from public, anon, authenticated, service_role;

comment on function private.bil_dispatch_store_reconciliation() is
  'Hourly Vault-authenticated store reconciliation. Cursor state guarantees every subscription page is eventually covered.';

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'bil-store-reconciliation-hourly';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'bil-store-reconciliation-hourly',
    '7 * * * *',
    'select private.bil_dispatch_store_reconciliation();'
  );
end;
$$;

commit;
