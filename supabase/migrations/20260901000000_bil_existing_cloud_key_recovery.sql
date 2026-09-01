-- Recover existing cloud payload key from Vault without creating or mutating state.
-- Startup can use this RPC only when the latest cloud_sync consent is granted.
begin;

create or replace function public.bil_get_existing_cloud_key()
returns text
language plpgsql
security definer
set search_path = public, vault, extensions, pg_temp
as $$
declare
  v_owner uuid := auth.uid();
  v_latest_consent boolean;
  v_secret_id uuid;
  v_secret text;
begin
  if v_owner is null then
    raise exception 'authentication_required';
  end if;

  select consent.granted
    into v_latest_consent
    from (
      select granted
      from public.bil_consent_receipts
      where user_id = v_owner
        and purpose = 'cloud_sync'
      order by recorded_at desc
      limit 1
    ) as consent;

  if v_latest_consent is distinct from true then
    return null;
  end if;

  select vault_secret_id
    into v_secret_id
    from public.bil_cloud_key_refs
   where owner_id = v_owner;

  if v_secret_id is null then
    return null;
  end if;

  select decrypted_secret
    into v_secret
    from vault.decrypted_secrets
   where id = v_secret_id;

  return v_secret;
end;
$$;

revoke all on function public.bil_get_existing_cloud_key() from public, anon;
grant execute on function public.bil_get_existing_cloud_key() to authenticated;

commit;
