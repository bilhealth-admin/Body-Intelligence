-- Auditable, idempotent QA credit for BIL-owned agent accounts. This is not a
-- store purchase or subscription entitlement and cannot target customer email.

create table if not exists public.bil_ai_qa_grants (
  grant_id text primary key check (grant_id ~ '^[a-z0-9][a-z0-9._:-]{7,127}$'),
  owner_id uuid not null references auth.users(id) on delete cascade,
  text_units numeric(12,3) not null check (text_units between 0 and 250),
  vision_units numeric(12,3) not null check (vision_units between 0 and 50),
  reason text not null check (length(reason) between 8 and 200),
  granted_at timestamptz not null default now(),
  check (text_units > 0 or vision_units > 0)
);

alter table public.bil_ai_qa_grants enable row level security;
revoke all on public.bil_ai_qa_grants from public, anon, authenticated;

create or replace function public.bil_grant_ai_agent_qa_balance(
  p_grant_id text,
  p_owner_id uuid,
  p_text_units numeric,
  p_vision_units numeric,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_inserted integer;
  v_existing public.bil_ai_qa_grants%rowtype;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_grant_id !~ '^[a-z0-9][a-z0-9._:-]{7,127}$'
     or p_text_units not between 0 and 250
     or p_vision_units not between 0 and 50
     or p_text_units + p_vision_units <= 0
     or length(trim(p_reason)) not between 8 and 200 then
    raise exception 'invalid_qa_grant';
  end if;

  select lower(email) into v_email from auth.users where id = p_owner_id;
  if v_email is null or v_email !~ '^[^@]+@bilhealth[.]invalid$' then
    raise exception 'qa_agent_account_required';
  end if;

  insert into public.bil_ai_qa_grants(
    grant_id, owner_id, text_units, vision_units, reason
  ) values (
    trim(p_grant_id), p_owner_id, p_text_units, p_vision_units, trim(p_reason)
  ) on conflict do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select * into v_existing from public.bil_ai_qa_grants
    where grant_id = trim(p_grant_id);
    if v_existing.owner_id is distinct from p_owner_id
       or v_existing.text_units is distinct from p_text_units
       or v_existing.vision_units is distinct from p_vision_units
       or v_existing.reason is distinct from trim(p_reason) then
      raise exception 'qa_grant_replay_conflict';
    end if;
  else
    insert into public.bil_ai_paid_balances(owner_id, capability, granted)
    values
      (p_owner_id, 'text', p_text_units),
      (p_owner_id, 'vision', p_vision_units)
    on conflict(owner_id, capability) do update set
      granted = public.bil_ai_paid_balances.granted + excluded.granted,
      updated_at = now();
  end if;

  return jsonb_build_object(
    'credited', v_inserted = 1,
    'grant_id', trim(p_grant_id),
    'text_units', p_text_units,
    'vision_units', p_vision_units
  );
end $$;

revoke all on function public.bil_grant_ai_agent_qa_balance(
  text, uuid, numeric, numeric, text
) from public, anon, authenticated;
grant execute on function public.bil_grant_ai_agent_qa_balance(
  text, uuid, numeric, numeric, text
) to service_role;
