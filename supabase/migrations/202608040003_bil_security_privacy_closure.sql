-- Epic 12: consent versioning, replay protection, and least-privilege closure.
begin;

create table if not exists public.bil_consent_receipts (
  user_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('health','camera','microphone','photos','notifications','devices','remote_ai')),
  policy_version text not null,
  granted boolean not null,
  recorded_at timestamptz not null default now(),
  primary key (user_id, purpose, policy_version)
);

create table if not exists public.bil_sensitive_request_receipts (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  idempotency_key text not null,
  payload_digest text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, action, idempotency_key),
  check (length(idempotency_key) between 16 and 128),
  check (payload_digest ~ '^[0-9a-f]{64}$')
);

alter table public.bil_consent_receipts enable row level security;
alter table public.bil_sensitive_request_receipts enable row level security;

create policy bil_consent_receipts_own_read on public.bil_consent_receipts
for select to authenticated using (user_id = auth.uid());

create or replace function public.bil_record_consent(
  p_purpose text, p_policy_version text, p_granted boolean
) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if p_purpose not in ('health','camera','microphone','photos','notifications','devices','remote_ai')
     or length(trim(p_policy_version)) not between 1 and 64 then
    raise exception 'invalid_consent';
  end if;
  insert into bil_consent_receipts(user_id,purpose,policy_version,granted)
  values(auth.uid(),p_purpose,trim(p_policy_version),coalesce(p_granted,false))
  on conflict(user_id,purpose,policy_version) do update
    set granted=excluded.granted, recorded_at=now();
end $$;

create or replace function public.bil_claim_sensitive_request(
  p_action text, p_idempotency_key text, p_payload_digest text
) returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if p_action not in ('meal_image_analysis','account_export','account_deletion') then
    raise exception 'invalid_action';
  end if;
  perform bil_consume_rate_limit(p_action, case when p_action='meal_image_analysis' then 30 else 3 end, 3600);
  insert into bil_sensitive_request_receipts(user_id,action,idempotency_key,payload_digest)
  values(auth.uid(),p_action,p_idempotency_key,p_payload_digest)
  on conflict do nothing;
  return found;
end $$;

revoke all on public.bil_consent_receipts, public.bil_sensitive_request_receipts from anon, authenticated;
grant select on public.bil_consent_receipts to authenticated;
grant execute on function public.bil_record_consent(text,text,boolean),
  public.bil_claim_sensitive_request(text,text,text) to authenticated;

commit;
