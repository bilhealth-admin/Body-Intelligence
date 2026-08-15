begin;

-- The original cloud table predates the ledger sync contract. CREATE TABLE IF
-- NOT EXISTS in the ledger migration intentionally preserved it, so reconcile
-- the additive columns without deleting or rewriting existing user records.
alter table public.bil_cloud_records
  add column if not exists revision_device_id text,
  add column if not exists updated_at timestamptz,
  add column if not exists change_sequence bigint;

update public.bil_cloud_records
set revision_device_id = coalesce(revision_device_id, device_id),
    updated_at = coalesce(updated_at, client_updated_at),
    change_sequence = coalesce(
      change_sequence,
      nextval('public.bil_cloud_change_sequence')
    )
where revision_device_id is null
   or updated_at is null
   or change_sequence is null;

alter table public.bil_cloud_records
  alter column revision_device_id set not null,
  alter column updated_at set not null,
  alter column change_sequence
    set default nextval('public.bil_cloud_change_sequence'),
  alter column change_sequence set not null;

create index if not exists bil_cloud_records_change_pull_idx
  on public.bil_cloud_records (owner_id, change_sequence);

create or replace function public.bil_register_push_token(
  p_token text,
  p_platform text,
  p_timezone text,
  p_sensitive_preview_allowed boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if length(p_token) < 20 or p_platform not in ('fcm','apns') then
    raise exception 'invalid push token';
  end if;
  insert into public.bil_push_device_tokens(
    user_id, token_ciphertext, token_fingerprint, platform, timezone,
    sensitive_preview_allowed
  ) values (
    auth.uid(), p_token,
    encode(extensions.digest(p_token, 'sha256'), 'hex'),
    p_platform, p_timezone, false
  )
  on conflict(token_fingerprint) do update
    set user_id = auth.uid(), enabled = true, timezone = excluded.timezone,
        last_seen_at = now(), sensitive_preview_allowed = false;
end
$$;

revoke all on function public.bil_register_push_token(text,text,text,boolean)
  from public, anon;
grant execute on function public.bil_register_push_token(text,text,text,boolean)
  to authenticated;

commit;
