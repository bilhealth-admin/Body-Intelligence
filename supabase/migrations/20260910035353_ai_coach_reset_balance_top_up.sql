begin;

-- A reset fills the existing Boost balance to 2,500; it is not a repeatable
-- 2,500-token gift. Historical grants and balances above the target stay intact.
-- Keep the original (reset_id, owner_id) ledger and record the actual increment,
-- including zero, so replay after later consumption cannot grant again.
alter table private.bil_ai_coach_reset_token_grants
  drop constraint bil_ai_coach_reset_token_grants_tokens_check;
alter table private.bil_ai_coach_reset_token_grants
  alter column tokens set default 0,
  add constraint bil_ai_coach_reset_token_grants_tokens_check
    check (tokens between 0 and 2500);

create or replace function private.bil_grant_ai_coach_reset_tokens()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_remaining bigint;
  v_top_up bigint;
  v_inserted integer := 0;
begin
  insert into public.bil_ai_credit_balances(owner_id, granted)
  values (new.owner_id, 0)
  on conflict (owner_id) do nothing;

  -- Serialize against other resets, purchases and settlement on this balance.
  -- Reserved tokens are still owned, not consumed: topping those up would mint
  -- extra credit when a pending request is cancelled and its hold is released.
  select b.granted - b.used into strict v_remaining
  from public.bil_ai_credit_balances b
  where b.owner_id = new.owner_id
  for update;
  v_top_up := greatest(0::bigint, 2500::bigint - v_remaining);

  insert into private.bil_ai_coach_reset_token_grants(
    reset_id, owner_id, tokens
  ) values (
    new.reset_id, new.owner_id, v_top_up
  )
  on conflict (reset_id, owner_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 1 and v_top_up > 0 then
    update public.bil_ai_credit_balances
    set granted = granted + v_top_up,
        updated_at = now()
    where owner_id = new.owner_id;
  end if;
  return new;
end
$$;

-- This is an internal notice trigger, not a new client-callable credit API.
revoke all on function private.bil_grant_ai_coach_reset_tokens()
  from public, anon, authenticated, service_role;
revoke all on table private.bil_ai_coach_reset_token_grants
  from public, anon, authenticated, service_role;
alter table private.bil_ai_coach_reset_token_grants enable row level security;

comment on column private.bil_ai_coach_reset_token_grants.tokens is
  'Actual reset top-up, 0..2500. Existing historical fixed grants remain unchanged.';
-- Preserve the established RPC receipts for installed clients. Their legacy
-- boost_tokens_per_recipient value is the maximum/target, not a claimed delta.
comment on function public.bil_global_reset_ai_coach(uuid, text, text) is
  'Atomic current-period usage reset and idempotent Boost top-up to 2500, preserving higher balances and the administrator-authored notice.';
comment on function public.bil_individual_reset_ai_coach(uuid, uuid, text, text, text) is
  'Atomic individual usage reset and idempotent Boost top-up to 2500, preserving higher balances and the administrator-authored notice.';

commit;
