begin;

-- A reviewer may already hold a legitimate Premium subscription. In that
-- case the closed-test grant is an additive AI Coach overlay and must not
-- replace the store record. This trigger keeps the server quota authority in
-- sync with that overlay while preserving any live store AI subscription.
create or replace function public.bil_sync_ai_closed_test_grant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner_id uuid := case when tg_op = 'DELETE' then old.owner_id else new.owner_id end;
  v_transaction_id text := 'closed-test:' || v_owner_id::text;
begin
  if tg_op <> 'DELETE' and new.active and new.expires_at > now() then
    insert into public.bil_ai_coach_subscriptions(
      owner_id, provider, product_id, lifecycle, original_transaction_id,
      latest_transaction_id, expires_at, verified_at
    ) values (
      v_owner_id, 'closed_test', 'bil_closed_test', 'active',
      v_transaction_id, v_transaction_id, new.expires_at, now()
    )
    on conflict (owner_id) do update set
      provider = excluded.provider,
      product_id = excluded.product_id,
      lifecycle = excluded.lifecycle,
      original_transaction_id = excluded.original_transaction_id,
      latest_transaction_id = excluded.latest_transaction_id,
      expires_at = excluded.expires_at,
      verified_at = excluded.verified_at
    where public.bil_ai_coach_subscriptions.provider = 'closed_test'
       or public.bil_ai_coach_subscriptions.lifecycle not in (
         'trial', 'active', 'grace_period'
       )
       or public.bil_ai_coach_subscriptions.expires_at <= now();
  else
    delete from public.bil_ai_coach_subscriptions
    where owner_id = v_owner_id and provider = 'closed_test';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function public.bil_sync_ai_closed_test_grant()
  from public, anon, authenticated;

drop trigger if exists bil_sync_ai_closed_test_grant_trigger
  on public.bil_ai_closed_test_grants;
create trigger bil_sync_ai_closed_test_grant_trigger
after insert or update or delete on public.bil_ai_closed_test_grants
for each row execute function public.bil_sync_ai_closed_test_grant();

insert into public.bil_ai_coach_subscriptions(
  owner_id, provider, product_id, lifecycle, original_transaction_id,
  latest_transaction_id, expires_at, verified_at
)
select
  g.owner_id, 'closed_test', 'bil_closed_test', 'active',
  'closed-test:' || g.owner_id::text,
  'closed-test:' || g.owner_id::text,
  g.expires_at, now()
from public.bil_ai_closed_test_grants g
where g.active and g.expires_at > now()
on conflict (owner_id) do update set
  provider = excluded.provider,
  product_id = excluded.product_id,
  lifecycle = excluded.lifecycle,
  original_transaction_id = excluded.original_transaction_id,
  latest_transaction_id = excluded.latest_transaction_id,
  expires_at = excluded.expires_at,
  verified_at = excluded.verified_at
where public.bil_ai_coach_subscriptions.provider = 'closed_test'
   or public.bil_ai_coach_subscriptions.lifecycle not in (
     'trial', 'active', 'grace_period'
   )
   or public.bil_ai_coach_subscriptions.expires_at <= now();

commit;
