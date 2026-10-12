-- Prepared only. No Production execution is authorized in this phase.
-- Preserve the existing 32/35 RPCs, grant policy, receipts and store rights.
-- Serialize role withdrawal with financial operations already admitted by
-- the service-authenticated handler. Withdrawal committed before admission
-- denies the operation; withdrawal after admission waits for its transaction.
begin;
create or replace function bil_admin_private.require_administrator(p_actor_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.jwt()->>'role', '') <> 'service_role' or p_actor_id is null then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
  perform 1 from private.bil_ai_coach_admins a
    where a.user_id = p_actor_id and a.active for share;
  if not found then
    raise exception 'administrator_required' using errcode = '42501';
  end if;
end;
$$;
revoke all on function bil_admin_private.require_administrator(uuid)
  from public, anon, authenticated, service_role;
commit;
