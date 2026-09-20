begin;

alter table public.bil_store_notification_inbox
  add column if not exists error_code text
    check (error_code is null or (length(error_code) between 1 and 80
      and error_code ~ '^[a-z0-9_]+$'));

create or replace function public.bil_finish_store_notification(
  p_provider text, p_notification_id text, p_claim_token uuid,
  p_status text, p_error_code text
) returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  if p_claim_token is null or p_status is null
     or p_status not in ('processed','rejected','error')
     or (p_status = 'error' and (p_error_code is null or
       p_error_code !~ '^[a-z0-9_]{1,80}$'))
     or (p_status <> 'error' and p_error_code is not null) then
    raise exception 'invalid_store_notification_completion';
  end if;
  update public.bil_store_notification_inbox set
    status=p_status,
    error_code=case when p_status='error' then p_error_code else null end,
    processed_at=case when p_status='error' then null else clock_timestamp() end,
    lease_expires_at=null
  where provider=p_provider and notification_id=p_notification_id
    and claim_token=p_claim_token and status='received'
    and lease_expires_at>clock_timestamp();
  return found;
end
$$;

create or replace function public.bil_finish_store_notification(
  p_provider text, p_notification_id text, p_claim_token uuid, p_status text
) returns boolean
language sql security definer set search_path = public
as $$
  select public.bil_finish_store_notification(
    p_provider,p_notification_id,p_claim_token,p_status,null
  )
$$;

revoke all on function public.bil_finish_store_notification(
  text,text,uuid,text,text
) from public,anon,authenticated;
grant execute on function public.bil_finish_store_notification(
  text,text,uuid,text,text
) to service_role;

commit;
