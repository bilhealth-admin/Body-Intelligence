-- Synthetic isolated PostgreSQL fixture. Table/credit RPC shapes come from
-- migrations 202608110004, 20260821080542 and 20260821102504. The existing
-- 20260916104000 refund migration is applied unchanged by the local runner.
create schema auth;
create table auth.users(id uuid primary key);
create function auth.jwt() returns jsonb language sql stable as
  $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
grant usage on schema auth, public to anon, authenticated, service_role;
create table public.bil_ai_boost_purchases (
  store text not null check (store in ('google_play','app_store')),
  transaction_id text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null check (product_id='bil_ai_boost'),
  verified_at timestamptz not null,
  credited_at timestamptz not null default now(),
  raw_receipt_hash text not null check (raw_receipt_hash ~ '^[0-9a-f]{64}$'),
  primary key(store,transaction_id)
);
create table public.bil_ai_credit_balances (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  granted bigint not null default 0 check (granted >= 0),
  used bigint not null default 0 check (used >= 0),
  reserved bigint not null default 0 check (reserved >= 0),
  updated_at timestamptz not null default now(),
  constraint bil_ai_credit_balance_not_overdrawn check (used + reserved <= granted)
);
alter table public.bil_ai_boost_purchases enable row level security;
alter table public.bil_ai_credit_balances enable row level security;
revoke all on public.bil_ai_boost_purchases, public.bil_ai_credit_balances from public,anon,authenticated;
insert into auth.users values ('72000000-0000-4000-8000-000000000001'),('72000000-0000-4000-8000-000000000002');

create or replace function public.bil_credit_ai_boost_verified(
  p_owner_id uuid,
  p_store text,
  p_transaction_id text,
  p_product_id text,
  p_verified_at timestamptz,
  p_raw_receipt_hash text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer;
  v_existing_owner uuid;
  v_boost_tokens constant bigint := 2500;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_product_id <> 'bil_ai_boost'
     or p_store not in ('google_play','app_store')
     or length(trim(p_transaction_id)) < 8
     or p_verified_at is null or p_verified_at > now() + interval '5 minutes'
     or p_raw_receipt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_verified_boost';
  end if;
  insert into public.bil_ai_boost_purchases(
    store,transaction_id,owner_id,product_id,verified_at,raw_receipt_hash
  ) values (
    p_store,trim(p_transaction_id),p_owner_id,p_product_id,
    p_verified_at,p_raw_receipt_hash
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select owner_id into v_existing_owner from public.bil_ai_boost_purchases
    where store = p_store and transaction_id = trim(p_transaction_id);
    if v_existing_owner is distinct from p_owner_id then
      raise exception 'purchase_owned_by_another_account';
    end if;
  else
    insert into public.bil_ai_credit_balances(owner_id, granted)
      values(p_owner_id, v_boost_tokens)
    on conflict(owner_id) do update set
      granted = public.bil_ai_credit_balances.granted + excluded.granted,
      updated_at = now();
  end if;
  return jsonb_build_object(
    'credited',v_inserted = 1,'product_id',p_product_id,
    'unit','BIL AI Token','tokens_granted',
    case when v_inserted = 1 then v_boost_tokens else 0 end,
    'tokens_per_boost',v_boost_tokens
  );
end
$$;
revoke all on function public.bil_credit_ai_boost_verified(
  uuid,text,text,text,timestamptz,text
) from public, anon, authenticated;
grant execute on function public.bil_credit_ai_boost_verified(
  uuid,text,text,text,timestamptz,text
) to service_role;
