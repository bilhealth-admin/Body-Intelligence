-- Bind verified Sign in with Apple account events to the authorization that
-- existed when the event occurred. Event receipts survive credential/account
-- removal so a redelivery cannot target a later BIL account.

begin;

alter table private.bil_apple_sign_in_credentials
  add column if not exists authorization_started_at timestamptz;

update private.bil_apple_sign_in_credentials
set authorization_started_at = created_at
where authorization_started_at is null;

alter table private.bil_apple_sign_in_credentials
  alter column authorization_started_at set default pg_catalog.clock_timestamp(),
  alter column authorization_started_at set not null;

create table if not exists private.bil_apple_account_event_receipts (
  event_id_hash text primary key check (event_id_hash ~ '^[0-9a-f]{64}$'),
  apple_subject_hash text not null check (
    apple_subject_hash ~ '^[0-9a-f]{64}$'
  ),
  event_type text not null check (
    event_type in ('consent-revoked', 'account-deleted')
  ),
  event_occurred_at timestamptz not null,
  outcome text not null check (
    outcome in (
      'processing',
      'deletion_queued',
      'unknown_subject',
      'stale_authorization'
    )
  ),
  affected_user_id uuid null,
  received_at timestamptz not null default pg_catalog.clock_timestamp(),
  completed_at timestamptz null
);

alter table private.bil_apple_account_event_receipts enable row level security;
revoke all on table private.bil_apple_account_event_receipts
  from public, anon, authenticated, service_role;

create index if not exists bil_apple_account_event_receipts_subject_time_idx
  on private.bil_apple_account_event_receipts (
    apple_subject_hash,
    event_occurred_at desc
  );

create or replace function public.bil_store_apple_sign_in_credential(
  p_user_id uuid,
  p_apple_subject_hash text,
  p_refresh_token_ciphertext text,
  p_refresh_token_iv text,
  p_client_id text,
  p_encryption_key_version integer default 1
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null or not exists (
    select 1 from auth.users where id = p_user_id
  ) then
    raise exception 'apple_credential_owner_not_found';
  end if;
  if coalesce(p_apple_subject_hash, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_apple_subject_hash';
  end if;
  if octet_length(coalesce(p_refresh_token_ciphertext, '')) not between 1 and 16384
     or octet_length(coalesce(p_refresh_token_iv, '')) not between 12 and 128
     or char_length(trim(coalesce(p_client_id, ''))) not between 3 and 255
     or coalesce(p_encryption_key_version, 0) <= 0 then
    raise exception 'invalid_apple_credential_envelope';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_apple_subject_hash, 0)
  );

  insert into private.bil_apple_sign_in_credentials (
    user_id,
    apple_subject_hash,
    refresh_token_ciphertext,
    refresh_token_iv,
    client_id,
    encryption_key_version,
    last_validated_at,
    authorization_started_at,
    updated_at
  ) values (
    p_user_id,
    p_apple_subject_hash,
    p_refresh_token_ciphertext,
    p_refresh_token_iv,
    trim(p_client_id),
    p_encryption_key_version,
    pg_catalog.clock_timestamp(),
    pg_catalog.clock_timestamp(),
    pg_catalog.clock_timestamp()
  )
  on conflict (user_id) do update set
    apple_subject_hash = excluded.apple_subject_hash,
    refresh_token_ciphertext = excluded.refresh_token_ciphertext,
    refresh_token_iv = excluded.refresh_token_iv,
    client_id = excluded.client_id,
    encryption_key_version = excluded.encryption_key_version,
    last_validated_at = excluded.last_validated_at,
    authorization_started_at = excluded.authorization_started_at,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.bil_apply_apple_account_event(
  p_event_id_hash text,
  p_event_occurred_at timestamptz,
  p_apple_subject_hash text,
  p_event_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_credential private.bil_apple_sign_in_credentials%rowtype;
  v_reason text := case trim(coalesce(p_event_type, ''))
    when 'consent-revoked' then 'apple_consent_revoked'
    when 'account-deleted' then 'apple_account_deleted'
    else null
  end;
  v_inserted_hash text;
begin
  if coalesce(p_event_id_hash, '') !~ '^[0-9a-f]{64}$'
     or coalesce(p_apple_subject_hash, '') !~ '^[0-9a-f]{64}$'
     or p_event_occurred_at is null
     or v_reason is null then
    raise exception 'invalid_apple_account_event';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_apple_subject_hash, 0)
  );

  insert into private.bil_apple_account_event_receipts (
    event_id_hash,
    apple_subject_hash,
    event_type,
    event_occurred_at,
    outcome
  ) values (
    p_event_id_hash,
    p_apple_subject_hash,
    trim(p_event_type),
    p_event_occurred_at,
    'processing'
  )
  on conflict (event_id_hash) do nothing
  returning event_id_hash into v_inserted_hash;

  if v_inserted_hash is null then
    return pg_catalog.jsonb_build_object('status', 'duplicate_event');
  end if;

  select * into v_credential
  from private.bil_apple_sign_in_credentials
  where apple_subject_hash = p_apple_subject_hash
  for update;

  if not found then
    update private.bil_apple_account_event_receipts
    set outcome = 'unknown_subject',
        completed_at = pg_catalog.clock_timestamp()
    where event_id_hash = p_event_id_hash;
    return pg_catalog.jsonb_build_object('status', 'unknown_subject');
  end if;

  if p_event_occurred_at < v_credential.authorization_started_at then
    update private.bil_apple_account_event_receipts
    set outcome = 'stale_authorization',
        affected_user_id = v_credential.user_id,
        completed_at = pg_catalog.clock_timestamp()
    where event_id_hash = p_event_id_hash;
    return pg_catalog.jsonb_build_object('status', 'stale_authorization');
  end if;

  perform public.bil_queue_apple_account_deletion(
    v_credential.user_id,
    v_reason
  );

  delete from private.bil_apple_sign_in_credentials
  where user_id = v_credential.user_id
    and apple_subject_hash = p_apple_subject_hash
    and authorization_started_at = v_credential.authorization_started_at;

  if not found then
    raise exception 'apple_credential_generation_changed';
  end if;

  update private.bil_apple_account_event_receipts
  set outcome = 'deletion_queued',
      affected_user_id = v_credential.user_id,
      completed_at = pg_catalog.clock_timestamp()
  where event_id_hash = p_event_id_hash;

  return pg_catalog.jsonb_build_object(
    'status', 'deletion_queued',
    'user_id', v_credential.user_id
  );
end;
$$;

revoke all on function public.bil_apply_apple_account_event(
  text, timestamptz, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.bil_apply_apple_account_event(
  text, timestamptz, text, text
) to service_role;

comment on table private.bil_apple_account_event_receipts is
  'Minimal durable replay receipts for verified Sign in with Apple account events; stores hashes and lifecycle outcomes, never provider tokens.';
comment on function public.bil_apply_apple_account_event(
  text, timestamptz, text, text
) is
  'Atomically deduplicates a verified Apple event, rejects events older than the current authorization, queues deletion, and removes only the matched credential generation.';

commit;
