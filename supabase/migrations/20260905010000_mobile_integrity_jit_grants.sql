-- One-use grants bind a server-verified mobile attestation to one exact
-- sensitive request. Raw Play Integrity tokens and App Attest assertions are
-- intentionally never persisted.

begin;

create table if not exists public.bil_mobile_integrity_challenges (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios')),
  purpose text not null check (purpose in ('registration', 'assertion')),
  action text not null check (action ~ '^[a-z][a-z0-9_.:-]{1,79}$'),
  payload_digest text not null check (payload_digest ~ '^[0-9a-f]{64}$'),
  key_id text not null check (char_length(key_id) between 40 and 256),
  challenge text not null unique check (char_length(challenge) between 43 and 128),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  consumed_at timestamptz,
  check (expires_at > created_at)
);

create index if not exists bil_mobile_integrity_challenges_owner_created_idx
  on public.bil_mobile_integrity_challenges (owner_id, created_at desc);
create index if not exists bil_mobile_integrity_challenges_expiry_idx
  on public.bil_mobile_integrity_challenges (expires_at)
  where consumed_at is null;

create table if not exists public.bil_app_attest_keys (
  owner_id uuid not null references auth.users(id) on delete cascade,
  key_id text not null unique check (char_length(key_id) between 40 and 256),
  public_key_jwk jsonb not null,
  receipt_base64 text check (
    receipt_base64 is null or
    octet_length(receipt_base64) between 1 and 262144
  ),
  receipt_purge_after timestamptz not null default
    (now() + interval '30 days'),
  receipt_purged_at timestamptz,
  environment text not null check (environment in ('development', 'production')),
  bundle_version text not null check (char_length(bundle_version) between 1 and 64),
  sign_count bigint not null default 0 check (sign_count >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  primary key (owner_id, key_id),
  check (
    (receipt_base64 is not null and receipt_purged_at is null)
    or
    (receipt_base64 is null and receipt_purged_at is not null)
  ),
  check (receipt_purge_after > created_at)
);

create index if not exists bil_app_attest_keys_receipt_purge_idx
  on public.bil_app_attest_keys (receipt_purge_after)
  where receipt_base64 is not null;

create table if not exists public.bil_mobile_integrity_grants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  action text not null check (action ~ '^[a-z][a-z0-9_.:-]{1,79}$'),
  payload_digest text not null check (payload_digest ~ '^[0-9a-f]{64}$'),
  source_id text not null check (char_length(source_id) between 8 and 128),
  key_id text check (key_id is null or char_length(key_id) between 40 and 256),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 seconds'),
  consumed_at timestamptz,
  unique (owner_id, platform, source_id),
  check (expires_at > created_at)
);

create index if not exists bil_mobile_integrity_grants_owner_expiry_idx
  on public.bil_mobile_integrity_grants (owner_id, expires_at)
  where consumed_at is null;

alter table public.bil_mobile_integrity_challenges enable row level security;
alter table public.bil_app_attest_keys enable row level security;
alter table public.bil_mobile_integrity_grants enable row level security;

revoke all on table public.bil_mobile_integrity_challenges
  from public, anon, authenticated, service_role;
revoke all on table public.bil_app_attest_keys
  from public, anon, authenticated, service_role;
revoke all on table public.bil_mobile_integrity_grants
  from public, anon, authenticated, service_role;
grant select, insert, update
  on table public.bil_mobile_integrity_challenges to service_role;
grant select, insert, update
  on table public.bil_app_attest_keys to service_role;
grant select, insert, update
  on table public.bil_mobile_integrity_grants to service_role;

create or replace function public.bil_consume_mobile_integrity_grant(
  p_grant_id uuid,
  p_owner_id uuid,
  p_action text,
  p_payload_digest text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  consumed_id uuid;
begin
  update public.bil_mobile_integrity_grants
  set consumed_at = pg_catalog.clock_timestamp()
  where id = p_grant_id
    and owner_id = p_owner_id
    and action = p_action
    and payload_digest = p_payload_digest
    and consumed_at is null
    and expires_at > pg_catalog.clock_timestamp()
  returning id into consumed_id;

  return consumed_id is not null;
end;
$$;

revoke all on function public.bil_consume_mobile_integrity_grant(uuid, uuid, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.bil_consume_mobile_integrity_grant(uuid, uuid, text, text)
  to service_role;

-- A scheduler or a service-role maintenance invocation can call this in small
-- batches. Expired one-use artifacts retain only a 24-hour troubleshooting
-- window; the App Attest key remains active while its large receipt is scrubbed
-- after 30 days. No raw assertion or Play Integrity token is stored here.
create or replace function public.bil_cleanup_mobile_integrity_artifacts(
  p_now timestamptz default pg_catalog.clock_timestamp(),
  p_batch_size integer default 1000
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := coalesce(
    p_now,
    pg_catalog.clock_timestamp()
  );
  v_batch_size integer := least(
    greatest(coalesce(p_batch_size, 1000), 1),
    5000
  );
  v_challenges_deleted integer := 0;
  v_grants_deleted integer := 0;
  v_receipts_scrubbed integer := 0;
begin
  with doomed as (
    select challenge.id
    from public.bil_mobile_integrity_challenges challenge
    where challenge.expires_at <= v_now - interval '24 hours'
      or challenge.consumed_at <= v_now - interval '24 hours'
    order by challenge.created_at
    limit v_batch_size
  )
  delete from public.bil_mobile_integrity_challenges challenge
  using doomed
  where challenge.id = doomed.id;
  get diagnostics v_challenges_deleted = row_count;

  with doomed as (
    select integrity_grant.id
    from public.bil_mobile_integrity_grants integrity_grant
    where integrity_grant.expires_at <= v_now - interval '24 hours'
      or integrity_grant.consumed_at <= v_now - interval '24 hours'
    order by integrity_grant.created_at
    limit v_batch_size
  )
  delete from public.bil_mobile_integrity_grants integrity_grant
  using doomed
  where integrity_grant.id = doomed.id;
  get diagnostics v_grants_deleted = row_count;

  with purgeable as (
    select attest_key.owner_id, attest_key.key_id
    from public.bil_app_attest_keys attest_key
    where attest_key.receipt_base64 is not null
      and attest_key.receipt_purge_after <= v_now
    order by attest_key.receipt_purge_after
    limit v_batch_size
  )
  update public.bil_app_attest_keys attest_key
     set receipt_base64 = null,
         receipt_purged_at = v_now
    from purgeable
   where attest_key.owner_id = purgeable.owner_id
     and attest_key.key_id = purgeable.key_id;
  get diagnostics v_receipts_scrubbed = row_count;

  return pg_catalog.jsonb_build_object(
    'challenges_deleted', v_challenges_deleted,
    'grants_deleted', v_grants_deleted,
    'receipts_scrubbed', v_receipts_scrubbed,
    'batch_limit', v_batch_size
  );
end;
$$;

revoke all on function public.bil_cleanup_mobile_integrity_artifacts(timestamptz, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.bil_cleanup_mobile_integrity_artifacts(timestamptz, integer)
  to service_role;

comment on table public.bil_mobile_integrity_grants is
  'Short-lived, one-use server-verification grants bound to an owner, action, and semantic payload digest.';

comment on column public.bil_app_attest_keys.receipt_base64 is
  'Apple App Attest receipt retained for at most 30 days, then scrubbed without removing the registered public key.';

commit;
