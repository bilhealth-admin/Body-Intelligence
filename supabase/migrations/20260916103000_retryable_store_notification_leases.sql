begin;

do $migration$
declare
  v_oid oid := to_regprocedure('public.bil_claim_store_notification(text,text,text,text)');
  v_body text;
begin
  if v_oid is null then raise exception 'required_notification_claim_missing'; end if;
  select lower(regexp_replace(prosrc,'\s+','','g')) into v_body from pg_proc where oid=v_oid;
  if v_body <> 'begininsertintopublic.bil_store_notification_inbox(provider,notification_id,payload_digest,environment)values(p_provider,p_notification_id,p_payload_digest,p_environment)onconflict(provider,notification_id)donothing;returnfound;end;'
     and v_body <> 'selectpublic.bil_claim_store_notification(p_provider,p_notification_id,p_payload_digest,p_environment,gen_random_uuid())' then
    raise exception 'unexpected_notification_claim_definition';
  end if;
end
$migration$;

alter table public.bil_store_notification_inbox
  add column if not exists claim_token uuid,
  add column if not exists claimed_at timestamptz,
  add column if not exists lease_expires_at timestamptz,
  add column if not exists attempt_count integer not null default 0
    check (attempt_count >= 0);

-- A false result means a terminal duplicate ONLY. An active worker must cause
-- a retryable error, never an acknowledgement which could lose a notification.
create or replace function public.bil_claim_store_notification(
  p_provider text, p_notification_id text, p_payload_digest text,
  p_environment text, p_claim_token uuid
) returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.bil_store_notification_inbox%rowtype;
  v_inserted boolean;
  v_now timestamptz := clock_timestamp();
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_provider is null or p_provider not in ('apple','google')
     or p_notification_id is null or length(trim(p_notification_id)) not between 1 and 256
     or p_notification_id <> trim(p_notification_id)
     or p_payload_digest is null or p_payload_digest !~ '^[0-9a-f]{64}$'
     or (p_environment is not null and p_environment not in ('sandbox','production'))
     or p_claim_token is null then
    raise exception 'invalid_store_notification_claim';
  end if;
  insert into public.bil_store_notification_inbox(
    provider,notification_id,payload_digest,environment
  ) values (p_provider,p_notification_id,p_payload_digest,p_environment)
  on conflict (provider,notification_id) do nothing;
  v_inserted := found;
  select * into v_row from public.bil_store_notification_inbox
    where provider=p_provider and notification_id=p_notification_id for update;
  if v_row.payload_digest <> p_payload_digest
     or (v_row.environment is not null and
         v_row.environment is distinct from p_environment) then
    raise exception 'notification_payload_conflict';
  end if;
  if v_row.status in ('processed','rejected') then return false; end if;
  if not v_inserted and v_row.status='received'
     and coalesce(v_row.lease_expires_at,v_row.received_at+interval '5 minutes') > v_now then
    raise exception 'notification_claim_in_progress';
  end if;
  if not v_inserted and v_row.claim_token=p_claim_token then
    raise exception 'notification_claim_token_reused';
  end if;
  update public.bil_store_notification_inbox set
    status='received', claim_token=p_claim_token, claimed_at=v_now,
    lease_expires_at=v_now+interval '5 minutes', processed_at=null,
    environment=coalesce(environment,p_environment), attempt_count=attempt_count+1
  where provider=p_provider and notification_id=p_notification_id;
  return true;
end
$$;

-- Retain the legacy RPC signature during rollout. Legacy callers can still
-- mark status using their existing service-role path; only the new token-aware
-- finish RPC below provides stale-worker fencing. Deploy that backend next.
create or replace function public.bil_claim_store_notification(
  p_provider text, p_notification_id text, p_payload_digest text,
  p_environment text default null
) returns boolean
language sql security definer set search_path = public
as $$
  select public.bil_claim_store_notification(
    p_provider,p_notification_id,p_payload_digest,p_environment,gen_random_uuid()
  )
$$;

create or replace function public.bil_finish_store_notification(
  p_provider text, p_notification_id text, p_claim_token uuid, p_status text
) returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_claim_token is null or p_status is null
     or p_status not in ('processed','rejected','error') then
    raise exception 'invalid_store_notification_completion';
  end if;
  update public.bil_store_notification_inbox set
    status=p_status,
    processed_at=case when p_status='error' then null else clock_timestamp() end,
    lease_expires_at=null
  where provider=p_provider and notification_id=p_notification_id
    and claim_token=p_claim_token and status='received'
    and lease_expires_at>clock_timestamp();
  return found;
end
$$;

revoke all on function public.bil_claim_store_notification(text,text,text,text),
  public.bil_claim_store_notification(text,text,text,text,uuid),
  public.bil_finish_store_notification(text,text,uuid,text)
  from public,anon,authenticated;
grant execute on function public.bil_claim_store_notification(text,text,text,text),
  public.bil_claim_store_notification(text,text,text,text,uuid),
  public.bil_finish_store_notification(text,text,uuid,text) to service_role;

commit;
