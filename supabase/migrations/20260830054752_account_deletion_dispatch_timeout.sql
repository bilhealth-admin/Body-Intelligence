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
