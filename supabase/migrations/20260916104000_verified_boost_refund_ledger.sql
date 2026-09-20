begin;

do $migration$
declare
  v_oid oid := to_regprocedure('public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text)');
  v_body text;
begin
  if v_oid is null then raise exception 'required_boost_credit_missing'; end if;
  select lower(regexp_replace(prosrc,'\s+','','g')) into v_body from pg_proc where oid=v_oid;
  if not (position('v_boost_tokensconstantbigint:=2500;' in v_body)>0
          and position('insertintopublic.bil_ai_credit_balances(owner_id,granted)' in v_body)>0
          and position('purchase_owned_by_another_account' in v_body)>0
          and position('service_role_required' in v_body)>0)
     and v_body <> 'selectpublic.bil_credit_ai_boost_verified(p_owner_id,p_store,p_transaction_id,p_product_id,p_verified_at,p_raw_receipt_hash,null)' then
    raise exception 'unexpected_boost_credit_definition';
  end if;
end
$migration$;

alter table public.bil_ai_boost_purchases add column if not exists environment text
  check (environment is null or environment in ('sandbox','production'));
alter table public.bil_ai_credit_balances
  add column if not exists refund_debt bigint not null default 0 check (refund_debt>=0);

-- This is TOKEN debt, never money or a billing authorization. Consumed work is
-- not erased and in-flight reservations are not broken. Unspent available
-- credit is removed immediately; released reservations and future grants repay
-- the remainder before becoming spendable. The original balance CHECK stays.
create or replace function public.bil_collect_ai_credit_refund_debt()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_collect bigint;
begin
  v_collect := least(new.refund_debt,greatest(new.granted-new.used-new.reserved,0));
  new.granted := new.granted-v_collect;
  new.refund_debt := new.refund_debt-v_collect;
  return new;
end
$$;
revoke all on function public.bil_collect_ai_credit_refund_debt() from public,anon,authenticated;
drop trigger if exists bil_collect_ai_credit_refund_debt on public.bil_ai_credit_balances;
create trigger bil_collect_ai_credit_refund_debt before insert or update
  on public.bil_ai_credit_balances for each row
  execute function public.bil_collect_ai_credit_refund_debt();

create table if not exists public.bil_ai_boost_store_state (
  store text not null check(store in ('app_store','google_play')),
  transaction_id text not null,
  product_id text not null check(product_id='bil_ai_boost'),
  environment text not null check(environment in ('sandbox','production')),
  owner_id uuid references auth.users(id) on delete set null,
  purchase_credited boolean not null default false,
  state text not null check(state in ('refunded','refund_reversed')),
  event_at timestamptz not null,
  event_id text not null,
  updated_at timestamptz not null default now(),
  primary key(store,transaction_id)
);
create table if not exists public.bil_ai_boost_store_events (
  store text not null check(store in ('app_store','google_play')),
  event_id text not null,
  transaction_id text not null,
  product_id text not null check(product_id='bil_ai_boost'),
  environment text not null check(environment in ('sandbox','production')),
  event_type text not null check(event_type in ('refunded','refund_reversed')),
  event_at timestamptz not null,
  raw_receipt_hash text not null check(raw_receipt_hash ~ '^[0-9a-f]{64}$'),
  applied boolean not null default false,
  tokens_delta bigint not null default 0,
  created_at timestamptz not null default now(),
  primary key(store,event_id)
);
alter table public.bil_ai_boost_store_state enable row level security;
alter table public.bil_ai_boost_store_events enable row level security;
revoke all on public.bil_ai_boost_store_state,public.bil_ai_boost_store_events
  from public,anon,authenticated;

create or replace function public.bil_credit_ai_boost_verified(
  p_owner_id uuid,p_store text,p_transaction_id text,p_product_id text,
  p_verified_at timestamptz,p_raw_receipt_hash text,p_environment text
) returns jsonb language plpgsql security definer set search_path=public
as $$
declare
  v_purchase public.bil_ai_boost_purchases%rowtype;
  v_state public.bil_ai_boost_store_state%rowtype;
  v_tokens constant bigint := 2500;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'service_role_required'; end if;
  if p_owner_id is null or p_product_id is distinct from 'bil_ai_boost'
     or p_store is null or p_store not in ('google_play','app_store')
     or p_transaction_id is null or length(trim(p_transaction_id)) not between 8 and 256
     or p_verified_at is null or p_verified_at>now()+interval '5 minutes'
     or p_raw_receipt_hash is null or p_raw_receipt_hash !~ '^[0-9a-f]{64}$'
     or (p_environment is not null and p_environment not in ('sandbox','production')) then
    raise exception 'invalid_verified_boost';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bil-ai-boost:'||p_store||':'||trim(p_transaction_id),0));
  select * into v_purchase from public.bil_ai_boost_purchases
    where store=p_store and transaction_id=trim(p_transaction_id) for update;
  if found then
    if v_purchase.owner_id is distinct from p_owner_id then raise exception 'purchase_owned_by_another_account'; end if;
    if v_purchase.environment is not null and p_environment is not null
       and v_purchase.environment<>p_environment then raise exception 'wrong_environment'; end if;
  end if;
  select * into v_state from public.bil_ai_boost_store_state
    where store=p_store and transaction_id=trim(p_transaction_id) for update;
  if found then
    if p_environment is not null and v_state.environment<>p_environment then raise exception 'wrong_environment'; end if;
    if v_state.owner_id is not null and v_state.owner_id<>p_owner_id then raise exception 'purchase_owned_by_another_account'; end if;
    if v_state.state='refunded' then
      return jsonb_build_object('credited',false,'refunded',true,'product_id',p_product_id,
        'unit','BIL AI Token','tokens_granted',0,'tokens_per_boost',v_tokens);
    end if;
    if v_state.purchase_credited and v_purchase.owner_id is null then
      raise exception 'prior_purchase_owner_unavailable';
    end if;
  end if;
  if v_purchase.owner_id is not null then
    return jsonb_build_object('credited',false,'product_id',p_product_id,
      'unit','BIL AI Token','tokens_granted',0,'tokens_per_boost',v_tokens);
  end if;
  insert into public.bil_ai_boost_purchases(
    store,transaction_id,owner_id,product_id,verified_at,raw_receipt_hash,environment
  ) values(p_store,trim(p_transaction_id),p_owner_id,p_product_id,p_verified_at,p_raw_receipt_hash,
    coalesce(p_environment,v_state.environment));
  insert into public.bil_ai_credit_balances(owner_id,granted)
    values(p_owner_id,v_tokens)
    on conflict(owner_id) do update set granted=bil_ai_credit_balances.granted+excluded.granted,updated_at=now();
  update public.bil_ai_boost_store_state set owner_id=p_owner_id,purchase_credited=true,updated_at=now()
    where store=p_store and transaction_id=trim(p_transaction_id);
  return jsonb_build_object('credited',true,'product_id',p_product_id,
    'unit','BIL AI Token','tokens_granted',v_tokens,'tokens_per_boost',v_tokens);
end
$$;

-- Compatibility keeps existing callers working. New verifiers must supply the
-- signed environment to the seven-argument overload; legacy null environment
-- never overrides a known store-event or purchase environment.
create or replace function public.bil_credit_ai_boost_verified(
  p_owner_id uuid,p_store text,p_transaction_id text,p_product_id text,
  p_verified_at timestamptz,p_raw_receipt_hash text
) returns jsonb language sql security definer set search_path=public
as $$
  select public.bil_credit_ai_boost_verified(
    p_owner_id,p_store,p_transaction_id,p_product_id,p_verified_at,p_raw_receipt_hash,null
  )
$$;

create or replace function public.bil_apply_ai_boost_store_event(
  p_store text,p_transaction_id text,p_product_id text,p_environment text,
  p_event_id text,p_event_type text,p_event_at timestamptz,p_raw_receipt_hash text
) returns jsonb language plpgsql security definer set search_path=public
as $$
declare
  v_purchase public.bil_ai_boost_purchases%rowtype;
  v_state public.bil_ai_boost_store_state%rowtype;
  v_event public.bil_ai_boost_store_events%rowtype;
  v_balance public.bil_ai_credit_balances%rowtype;
  v_tokens constant bigint := 2500;
  v_delta bigint := 0;
  v_cancel_debt bigint := 0;
  v_inserted boolean;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'service_role_required'; end if;
  if p_product_id is distinct from 'bil_ai_boost' or p_store is null or p_store not in ('app_store','google_play')
     or p_transaction_id is null or length(trim(p_transaction_id)) not between 8 and 256
     or p_environment is null or p_environment not in ('sandbox','production')
     or p_event_id is null or length(trim(p_event_id)) not between 1 and 256
     or p_event_type is null or p_event_type not in ('refunded','refund_reversed')
     or p_event_at is null or p_event_at>now()+interval '5 minutes'
     or p_raw_receipt_hash is null or p_raw_receipt_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_verified_boost_event';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('bil-ai-boost:'||p_store||':'||trim(p_transaction_id),0));
  insert into public.bil_ai_boost_store_events(
    store,event_id,transaction_id,product_id,environment,event_type,event_at,raw_receipt_hash
  ) values(p_store,trim(p_event_id),trim(p_transaction_id),p_product_id,p_environment,p_event_type,p_event_at,p_raw_receipt_hash)
  on conflict(store,event_id) do nothing;
  v_inserted := found;
  if not v_inserted then
    select * into v_event from public.bil_ai_boost_store_events where store=p_store and event_id=trim(p_event_id);
    if v_event.transaction_id<>trim(p_transaction_id) or v_event.product_id<>p_product_id
       or v_event.environment<>p_environment or v_event.event_type<>p_event_type then
      raise exception 'boost_event_identity_conflict';
    end if;
    return jsonb_build_object('duplicate',true,'applied',v_event.applied,'tokens_delta',0);
  end if;
  select * into v_purchase from public.bil_ai_boost_purchases
    where store=p_store and transaction_id=trim(p_transaction_id) for update;
  if found and v_purchase.environment is not null and v_purchase.environment<>p_environment then
    raise exception 'wrong_environment';
  end if;
  select * into v_state from public.bil_ai_boost_store_state
    where store=p_store and transaction_id=trim(p_transaction_id) for update;
  if found then
    if v_state.environment<>p_environment then raise exception 'wrong_environment'; end if;
    if p_event_at<v_state.event_at or
       (p_event_at=v_state.event_at and (v_state.state='refunded' or p_event_type<>'refunded')) then
      return jsonb_build_object('duplicate',false,'applied',false,'stale',true,'tokens_delta',0);
    end if;
  end if;
  if v_purchase.owner_id is not null and p_event_type is distinct from v_state.state then
    insert into public.bil_ai_credit_balances(owner_id) values(v_purchase.owner_id) on conflict do nothing;
    select * into v_balance from public.bil_ai_credit_balances where owner_id=v_purchase.owner_id for update;
    if p_event_type='refunded' then
      -- The balance trigger collects what is unreserved and carries the rest.
      update public.bil_ai_credit_balances set refund_debt=refund_debt+v_tokens,updated_at=now()
        where owner_id=v_purchase.owner_id;
      v_delta := -v_tokens;
    elsif v_state.state='refunded' and v_state.purchase_credited then
      v_cancel_debt := least(v_balance.refund_debt,v_tokens);
      update public.bil_ai_credit_balances set refund_debt=refund_debt-v_cancel_debt,
        granted=granted+v_tokens-v_cancel_debt,updated_at=now()
        where owner_id=v_purchase.owner_id;
      v_delta := v_tokens;
    end if;
  end if;
  insert into public.bil_ai_boost_store_state(
    store,transaction_id,product_id,environment,owner_id,purchase_credited,state,event_at,event_id
  ) values(p_store,trim(p_transaction_id),p_product_id,p_environment,v_purchase.owner_id,
    v_purchase.owner_id is not null,p_event_type,p_event_at,trim(p_event_id))
  on conflict(store,transaction_id) do update set
    state=excluded.state,event_at=excluded.event_at,event_id=excluded.event_id,updated_at=now();
  update public.bil_ai_boost_purchases set environment=p_environment
    where store=p_store and transaction_id=trim(p_transaction_id) and environment is null;
  update public.bil_ai_boost_store_events set applied=true,tokens_delta=v_delta
    where store=p_store and event_id=trim(p_event_id);
  return jsonb_build_object('duplicate',false,'applied',true,'state',p_event_type,
    'tokens_delta',v_delta,'purchase_found',v_purchase.owner_id is not null);
end
$$;

revoke all on function public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text),
  public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text,text),
  public.bil_apply_ai_boost_store_event(text,text,text,text,text,text,timestamptz,text)
  from public,anon,authenticated;
grant execute on function public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text),
  public.bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text,text),
  public.bil_apply_ai_boost_store_event(text,text,text,text,text,text,timestamptz,text) to service_role;

commit;
