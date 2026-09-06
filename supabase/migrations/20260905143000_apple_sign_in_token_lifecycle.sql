-- Server-side Sign in with Apple token custody and deletion/revocation
-- lifecycle. Authorization codes and provider tokens are never exposed to
-- authenticated clients after the initial HTTPS hand-off.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.bil_apple_sign_in_credentials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apple_subject_hash text not null unique check (
    apple_subject_hash ~ '^[0-9a-f]{64}$'
  ),
  refresh_token_ciphertext text not null check (
    octet_length(refresh_token_ciphertext) between 1 and 16384
  ),
  refresh_token_iv text not null check (
    octet_length(refresh_token_iv) between 12 and 128
  ),
  client_id text not null check (char_length(client_id) between 3 and 255),
  encryption_key_version integer not null default 1 check (
    encryption_key_version > 0
  ),
  last_validated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table private.bil_apple_sign_in_credentials enable row level security;
revoke all on table private.bil_apple_sign_in_credentials
  from public, anon, authenticated, service_role;

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

  insert into private.bil_apple_sign_in_credentials (
    user_id,
    apple_subject_hash,
    refresh_token_ciphertext,
    refresh_token_iv,
    client_id,
    encryption_key_version,
    last_validated_at,
    updated_at
  ) values (
    p_user_id,
    p_apple_subject_hash,
    p_refresh_token_ciphertext,
    p_refresh_token_iv,
    trim(p_client_id),
    p_encryption_key_version,
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
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.bil_read_apple_sign_in_credential(
  p_user_id uuid
)
returns table (
  user_id uuid,
  apple_subject_hash text,
  refresh_token_ciphertext text,
  refresh_token_iv text,
  client_id text,
  encryption_key_version integer,
  last_validated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    credential.user_id,
    credential.apple_subject_hash,
    credential.refresh_token_ciphertext,
    credential.refresh_token_iv,
    credential.client_id,
    credential.encryption_key_version,
    credential.last_validated_at
  from private.bil_apple_sign_in_credentials credential
  where credential.user_id = p_user_id
  limit 1;
$$;

create or replace function public.bil_read_apple_sign_in_owner_by_subject_hash(
  p_apple_subject_hash text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select credential.user_id
  from private.bil_apple_sign_in_credentials credential
  where credential.apple_subject_hash = p_apple_subject_hash
    and coalesce(p_apple_subject_hash, '') ~ '^[0-9a-f]{64}$'
  limit 1;
$$;

create or replace function public.bil_delete_apple_sign_in_credential(
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_removed uuid;
begin
  delete from private.bil_apple_sign_in_credentials
  where user_id = p_user_id
  returning user_id into v_removed;
  return v_removed is not null;
end;
$$;

create or replace function public.bil_queue_apple_account_deletion(
  p_user_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.bil_account_deletion_requests%rowtype;
  v_reason text := case trim(coalesce(p_reason, ''))
    when 'apple_consent_revoked' then 'apple_consent_revoked'
    when 'apple_account_deleted' then 'apple_account_deleted'
    else null
  end;
begin
  if p_user_id is null or v_reason is null then
    raise exception 'invalid_apple_deletion_event';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  select * into v_request
  from public.bil_account_deletion_requests
  where user_id = p_user_id and status in ('pending', 'processing')
  order by requested_at, id
  limit 1;

  if not found then
    insert into public.bil_account_deletion_requests(user_id, reason)
    values (p_user_id, v_reason)
    returning * into v_request;
  end if;

  update public.bil_push_device_tokens
  set enabled = false
  where user_id = p_user_id;

  return pg_catalog.jsonb_build_object(
    'request_id', v_request.id,
    'status', v_request.status
  );
end;
$$;

revoke all on function public.bil_store_apple_sign_in_credential(
  uuid, text, text, text, text, integer
) from public, anon, authenticated, service_role;
revoke all on function public.bil_read_apple_sign_in_credential(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.bil_read_apple_sign_in_owner_by_subject_hash(text)
  from public, anon, authenticated, service_role;
revoke all on function public.bil_delete_apple_sign_in_credential(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.bil_queue_apple_account_deletion(uuid, text)
  from public, anon, authenticated, service_role;

grant execute on function public.bil_store_apple_sign_in_credential(
  uuid, text, text, text, text, integer
) to service_role;
grant execute on function public.bil_read_apple_sign_in_credential(uuid)
  to service_role;
grant execute on function public.bil_read_apple_sign_in_owner_by_subject_hash(text)
  to service_role;
grant execute on function public.bil_delete_apple_sign_in_credential(uuid)
  to service_role;
grant execute on function public.bil_queue_apple_account_deletion(uuid, text)
  to service_role;

comment on table private.bil_apple_sign_in_credentials is
  'AES-GCM encrypted Apple refresh-token custody. Accessible only through service-role-only SECURITY DEFINER RPCs.';

commit;
