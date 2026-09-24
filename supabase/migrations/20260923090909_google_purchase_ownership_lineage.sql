create table if not exists private.bil_google_purchase_token_lineage (
  purchase_token_hash text primary key check (purchase_token_hash ~ '^[0-9a-f]{64}$'),
  purchase_token text not null unique check (length(purchase_token) between 8 and 256),
  linked_purchase_token_hash text check (linked_purchase_token_hash is null or linked_purchase_token_hash ~ '^[0-9a-f]{64}$'),
  root_purchase_token text not null check (length(root_purchase_token) between 8 and 256),
  owner_id uuid not null references auth.users(id) on delete cascade,
  account_hash text not null check (account_hash ~ '^[0-9a-f]{64}$'),
  environment text not null check (environment in ('sandbox','production')),
  created_at timestamptz not null default now()
);

create index if not exists bil_google_purchase_lineage_linked_idx
  on private.bil_google_purchase_token_lineage(linked_purchase_token_hash);
create index if not exists bil_google_purchase_lineage_account_idx
  on private.bil_google_purchase_token_lineage(account_hash, environment);
revoke all on private.bil_google_purchase_token_lineage from public, anon, authenticated;

create or replace function public.bil_resolve_google_purchase_owner(
  p_purchase_token_hash text,
  p_purchase_token text,
  p_linked_purchase_token_hash text,
  p_linked_purchase_token text,
  p_account_hash text,
  p_environment text
) returns table(owner_id uuid, environment text, root_purchase_token text)
language plpgsql security definer set search_path = public, private, pg_temp
as $$
declare v_count integer;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'service_role_required'; end if;
  if p_purchase_token_hash !~ '^[0-9a-f]{64}$' or p_environment not in ('sandbox','production') then
    raise exception 'invalid_google_owner_lookup';
  end if;
  select count(distinct c.owner_id) into v_count from (
    select l.owner_id from private.bil_google_purchase_token_lineage l
      where l.environment=p_environment and (l.purchase_token_hash=p_purchase_token_hash
        or (p_linked_purchase_token_hash is not null and l.purchase_token_hash=p_linked_purchase_token_hash)
        or (coalesce(p_account_hash,'') ~ '^[0-9a-f]{64}$' and l.account_hash=p_account_hash))
    union all
    select s.owner_id from public.bil_subscriptions s
      where s.provider='google' and s.environment=p_environment
        and (s.original_transaction_id in (p_purchase_token,p_linked_purchase_token)
          or s.latest_transaction_id in (p_purchase_token,p_linked_purchase_token))
  ) c;
  if v_count > 1 then raise exception 'purchase_owned_by_another_account'; end if;
  return query
    select c.owner_id, p_environment, c.root_purchase_token from (
      select l.owner_id,l.root_purchase_token,1 as priority from private.bil_google_purchase_token_lineage l
        where l.environment=p_environment and l.purchase_token_hash=p_purchase_token_hash
      union all
      select l.owner_id,l.root_purchase_token,2 from private.bil_google_purchase_token_lineage l
        where l.environment=p_environment and p_linked_purchase_token_hash is not null
          and l.purchase_token_hash=p_linked_purchase_token_hash
      union all
      select s.owner_id,s.original_transaction_id,3 from public.bil_subscriptions s
        where s.provider='google' and s.environment=p_environment
          and (s.original_transaction_id in (p_purchase_token,p_linked_purchase_token)
            or s.latest_transaction_id in (p_purchase_token,p_linked_purchase_token))
      union all
      select l.owner_id,l.root_purchase_token,4 from private.bil_google_purchase_token_lineage l
        where l.environment=p_environment and coalesce(p_account_hash,'') ~ '^[0-9a-f]{64}$'
          and l.account_hash=p_account_hash
    ) c order by c.priority limit 1;
end $$;

create or replace function public.bil_bind_google_purchase_token(
  p_owner_id uuid, p_purchase_token_hash text, p_purchase_token text,
  p_linked_purchase_token_hash text, p_root_purchase_token text,
  p_account_hash text, p_environment text
) returns boolean language plpgsql security definer set search_path = public, private, pg_temp
as $$
declare v_owner uuid;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'service_role_required'; end if;
  select owner_id into v_owner from private.bil_google_purchase_token_lineage
    where purchase_token_hash=p_purchase_token_hash or
      (p_linked_purchase_token_hash is not null and purchase_token_hash=p_linked_purchase_token_hash)
    limit 1;
  if v_owner is not null and v_owner <> p_owner_id then raise exception 'purchase_owned_by_another_account'; end if;
  insert into private.bil_google_purchase_token_lineage(
    purchase_token_hash,purchase_token,linked_purchase_token_hash,root_purchase_token,
    owner_id,account_hash,environment)
  values (p_purchase_token_hash,p_purchase_token,p_linked_purchase_token_hash,
    p_root_purchase_token,p_owner_id,p_account_hash,p_environment)
  on conflict (purchase_token_hash) do update set
    linked_purchase_token_hash=excluded.linked_purchase_token_hash,
    root_purchase_token=excluded.root_purchase_token,
    account_hash=excluded.account_hash
  where private.bil_google_purchase_token_lineage.owner_id=excluded.owner_id
    and private.bil_google_purchase_token_lineage.environment=excluded.environment;
  if not found then raise exception 'purchase_owned_by_another_account'; end if;
  return true;
end $$;

create or replace function public.bil_lookup_ai_boost_owner(p_store text,p_transaction_id text)
returns table(owner_id uuid) language plpgsql security definer set search_path=public,pg_temp
as $$ begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then raise exception 'service_role_required'; end if;
  return query select p.owner_id from public.bil_ai_boost_purchases p
    where p.store=p_store and p.transaction_id=trim(p_transaction_id) limit 1;
end $$;

revoke all on function public.bil_resolve_google_purchase_owner(text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.bil_bind_google_purchase_token(uuid,text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.bil_lookup_ai_boost_owner(text,text) from public,anon,authenticated;
grant execute on function public.bil_resolve_google_purchase_owner(text,text,text,text,text,text) to service_role;
grant execute on function public.bil_bind_google_purchase_token(uuid,text,text,text,text,text,text) to service_role;
grant execute on function public.bil_lookup_ai_boost_owner(text,text) to service_role;

;
