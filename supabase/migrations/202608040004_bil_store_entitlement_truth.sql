begin;

create table if not exists public.bil_store_product_registry (
  product_id text primary key,
  provider text not null check (provider in ('google','apple')),
  package_or_bundle_id text not null,
  plan_id text not null check (plan_id in ('plus','pro')),
  billing_term text not null check (billing_term in ('monthly','annual')),
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.bil_subscriptions (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  provider text not null check (provider in ('google','apple')),
  product_id text not null references public.bil_store_product_registry(product_id),
  plan_id text not null check (plan_id in ('plus','pro')),
  lifecycle text not null check (lifecycle in (
    'pending','trial','active','grace_period','billing_retry','account_hold',
    'paused','suspended','deferred','cancelled','expired','refunded','revoked'
  )),
  original_transaction_id text not null,
  latest_transaction_id text not null,
  environment text not null check (environment in ('sandbox','production')),
  started_at timestamptz,
  expires_at timestamptz,
  grace_period_ends_at timestamptz,
  auto_renews boolean,
  verified_at timestamptz not null,
  revision bigint not null default 1,
  unique (provider, original_transaction_id)
);

create table if not exists public.bil_store_notification_inbox (
  provider text not null check (provider in ('google','apple')),
  notification_id text not null,
  payload_digest text not null,
  environment text,
  status text not null default 'received' check (status in ('received','processed','rejected','error')),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  primary key (provider, notification_id)
);

create table if not exists public.bil_store_entitlement_audit (
  id bigint generated always as identity primary key,
  owner_id uuid references auth.users(id) on delete set null,
  provider text not null,
  product_id text,
  lifecycle text not null,
  reason text not null,
  transaction_fingerprint text,
  occurred_at timestamptz not null default now()
);

alter table public.bil_store_product_registry enable row level security;
alter table public.bil_subscriptions enable row level security;
alter table public.bil_store_notification_inbox enable row level security;
alter table public.bil_store_entitlement_audit enable row level security;

drop policy if exists bil_subscriptions_read_own on public.bil_subscriptions;
create policy bil_subscriptions_read_own on public.bil_subscriptions
for select to authenticated using (owner_id = (select auth.uid()));

revoke all on public.bil_store_product_registry,
  public.bil_subscriptions,
  public.bil_store_notification_inbox,
  public.bil_store_entitlement_audit from anon, authenticated;
grant select on public.bil_subscriptions to authenticated;

create or replace function public.bil_claim_store_notification(
  p_provider text,
  p_notification_id text,
  p_payload_digest text,
  p_environment text default null
) returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.bil_store_notification_inbox(
    provider, notification_id, payload_digest, environment
  ) values (p_provider, p_notification_id, p_payload_digest, p_environment)
  on conflict (provider, notification_id) do nothing;
  return found;
end;
$$;

revoke all on function public.bil_claim_store_notification(text,text,text,text)
from public, anon, authenticated;

commit;
