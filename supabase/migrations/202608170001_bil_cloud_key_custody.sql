-- BIL cloud payload key custody and explicit cloud-sync consent.
-- The canonical account payload key is stored only in Supabase Vault.
-- Public application tables keep only the Vault secret UUID reference.
begin;

-- Extend the existing consent contract without weakening any prior purpose.
alter table public.bil_consent_receipts
  drop constraint if exists bil_consent_receipts_purpose_check;

alter table public.bil_consent_receipts
  add constraint bil_consent_receipts_purpose_check
  check (purpose in (
    'health','camera','microphone','photos','notifications','devices',
    'remote_ai','cloud_sync'
  ));

create or replace function public.bil_record_consent(
  p_purpose text, p_policy_version text, p_granted boolean
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_purpose not in (
      'health','camera','microphone','photos','notifications','devices',
      'remote_ai','cloud_sync'
    )
    or length(trim(p_policy_version)) not between 1 and 64 then
    raise exception 'invalid_consent';
  end if;
  insert into public.bil_consent_receipts(
    user_id, purpose, policy_version, granted
  ) values (
    auth.uid(), p_purpose, trim(p_policy_version), coalesce(p_granted, false)
  )
  on conflict(user_id, purpose, policy_version) do update
    set granted = excluded.granted, recorded_at = now();
end;
$$;

create table if not exists public.bil_cloud_key_refs (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  vault_secret_id uuid not null unique,
  key_version integer not null default 1 check (key_version > 0),
  created_at timestamptz not null default now(),
  rotated_at timestamptz
);

alter table public.bil_cloud_key_refs enable row level security;

-- No direct client policies are intentional. The authenticated RPC below is
-- the only application path to decrypted key material.
revoke all on public.bil_cloud_key_refs from public, anon, authenticated;

create or replace function public.bil_get_or_create_cloud_key()
returns text
language plpgsql
security definer
set search_path = public, vault, extensions, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_secret_id uuid;
  v_secret text;
begin
  if v_owner is null then
    raise exception 'authentication_required';
  end if;

  -- Serialize first-key creation for one owner without blocking other users.
  perform pg_advisory_xact_lock(hashtextextended(v_owner::text, 0));

  select vault_secret_id
    into v_secret_id
    from public.bil_cloud_key_refs
   where owner_id = v_owner;

  if v_secret_id is null then
    v_secret := encode(extensions.gen_random_bytes(32), 'base64');
    v_secret_id := vault.create_secret(
      v_secret,
      'bil_cloud_payload_' || replace(v_owner::text, '-', ''),
      'BIL account cloud payload key v1',
      null
    );
    insert into public.bil_cloud_key_refs(owner_id, vault_secret_id)
    values (v_owner, v_secret_id);
  end if;

  select decrypted_secret
    into v_secret
    from vault.decrypted_secrets
   where id = v_secret_id;

  if v_secret is null or length(v_secret) < 40 then
    raise exception 'cloud_key_unavailable';
  end if;

  return v_secret;
end;
$$;

revoke all on function public.bil_get_or_create_cloud_key() from public, anon;
grant execute on function public.bil_get_or_create_cloud_key() to authenticated;

revoke all on function public.bil_record_consent(text, text, boolean)
  from public, anon;
grant execute on function public.bil_record_consent(text, text, boolean)
  to authenticated;

commit;
