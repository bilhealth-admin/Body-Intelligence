create table if not exists private.bil_push_dispatch_scheduler_config (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into private.bil_push_dispatch_scheduler_config (singleton, enabled)
values (true, false)
on conflict (singleton) do nothing;

create table if not exists private.bil_push_dispatch_scheduler_audit (
  id bigint generated always as identity primary key,
  attempted_at timestamptz not null default now(),
  status text not null check (status in ('queued', 'configuration_error', 'dispatch_error')),
  request_id bigint,
  failure_code text
);

revoke all on table private.bil_push_dispatch_scheduler_config
  from public, anon, authenticated, service_role;
revoke all on table private.bil_push_dispatch_scheduler_audit
  from public, anon, authenticated, service_role;

create or replace function private.bil_dispatch_community_push()
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, private, vault, net, pg_temp
as $$
declare
  v_enabled boolean := false;
  v_internal_secret text;
  v_request_id bigint;
begin
  select enabled into v_enabled
  from private.bil_push_dispatch_scheduler_config
  where singleton = true;

  if not coalesce(v_enabled, false) then
    return null;
  end if;

  -- Only one scheduler transaction may enqueue a dispatch at a time. The
  -- Edge function and delivery ledger retain their existing idempotency and
  -- leases for retries after the HTTP request has been accepted.
  if not pg_try_advisory_xact_lock(20260925, 50000) then
    return null;
  end if;

  select decrypted_secret into v_internal_secret
  from vault.decrypted_secrets
  where name = 'BIL_INTERNAL_DISPATCH_SECRET'
  order by created_at desc
  limit 1;

  if nullif(v_internal_secret, '') is null then
    insert into private.bil_push_dispatch_scheduler_audit(status, failure_code)
    values ('configuration_error', 'dispatch_secret_unavailable');
    return null;
  end if;

  begin
    select net.http_post(
      url := 'https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/community-push-dispatch',
      headers := jsonb_build_object(
        'content-type', 'application/json',
        'x-bil-dispatch-secret', v_internal_secret
      ),
      body := jsonb_build_object('source', 'pg_cron'),
      timeout_milliseconds := 15000
    ) into v_request_id;

    if v_request_id is null then
      insert into private.bil_push_dispatch_scheduler_audit(status, failure_code)
      values ('dispatch_error', 'http_request_not_queued');
      return null;
    end if;

    insert into private.bil_push_dispatch_scheduler_audit(status, request_id)
    values ('queued', v_request_id);
    return v_request_id;
  exception when others then
    insert into private.bil_push_dispatch_scheduler_audit(status, failure_code)
    values ('dispatch_error', 'http_dispatch_exception');
    return null;
  end;
end;
$$;

revoke all on function private.bil_dispatch_community_push()
  from public, anon, authenticated, service_role;

comment on function private.bil_dispatch_community_push() is
  'Cron-only, fail-closed dispatcher. Disabled until provider and shared secret readiness are proven.';

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'bil-community-push-dispatch-1m';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'bil-community-push-dispatch-1m',
    '* * * * *',
    'select private.bil_dispatch_community_push();'
  );
end;
$$;
