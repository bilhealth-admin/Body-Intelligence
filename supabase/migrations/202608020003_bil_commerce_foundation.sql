begin;

create table if not exists public.bil_store_receipts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('apple','google')),
  product_id text not null,
  transaction_id text not null,
  original_transaction_id text,
  verification_status text not null check (verification_status in ('verified','rejected','pending','error')),
  purchased_at timestamptz,
  expires_at timestamptz,
  environment text not null default 'production',
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, transaction_id)
);

create table if not exists public.bil_entitlements (
  owner_id uuid not null references auth.users(id) on delete cascade,
  entitlement_id text not null,
  product_id text not null,
  provider text not null check (provider in ('apple','google')),
  active boolean not null default false,
  starts_at timestamptz not null,
  expires_at timestamptz,
  source_transaction_id text not null,
  server_updated_at timestamptz not null default now(),
  primary key (owner_id, entitlement_id)
);

alter table public.bil_store_receipts enable row level security;
alter table public.bil_entitlements enable row level security;

create policy bil_receipts_read_own on public.bil_store_receipts for select to authenticated
using (owner_id = (select auth.uid()));
create policy bil_entitlements_read_own on public.bil_entitlements for select to authenticated
using (owner_id = (select auth.uid()));

revoke all on public.bil_store_receipts, public.bil_entitlements from anon, authenticated;
grant select on public.bil_store_receipts, public.bil_entitlements to authenticated;

commit;
