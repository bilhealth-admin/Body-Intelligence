-- Correct the mistaken classification of a personal operational account as a
-- store reviewer. Restore only its previously owner-approved administrator
-- membership; retain the original grant provenance, moderators and purchases.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

lock table private.bil_ai_coach_admins in share row exclusive mode;

do $restore_approved_secondary_admin$
declare
  v_owner_id uuid;
  v_secondary_id uuid;
  v_index_id oid;
begin
  if (select pg_catalog.count(*) from auth.users
      where pg_catalog.lower(email) = 'kademcom@yahoo.com') <> 1
    or (select pg_catalog.count(*) from auth.users
        where pg_catalog.lower(email) = 'bilhealth.app@gmail.com') <> 1 then
    raise exception 'approved_secondary_admin_identity_preflight_failed';
  end if;

  select id into strict v_owner_id from auth.users
    where pg_catalog.lower(email) = 'kademcom@yahoo.com';
  select id into strict v_secondary_id from auth.users
    where pg_catalog.lower(email) = 'bilhealth.app@gmail.com';

  if v_owner_id = v_secondary_id
    or not exists (select 1 from private.bil_ai_coach_admins
      where user_id = v_owner_id and active)
    or not exists (select 1 from private.bil_ai_coach_admins
      where user_id = v_secondary_id and granted_by = v_owner_id
        and reason = 'owner_approved_secondary_administrator')
    or exists (select 1 from private.bil_ai_coach_admins
      where active and user_id not in (v_owner_id, v_secondary_id)) then
    raise exception 'approved_secondary_admin_provenance_preflight_failed';
  end if;

  -- Drop only the restrictive index introduced by the mistaken restore.
  -- An unexpected object with this name must stop the transaction.
  v_index_id := pg_catalog.to_regclass(
    'private.bil_ai_coach_single_active_admin_uidx');
  if v_index_id is not null then
    if not exists (select 1 from pg_catalog.pg_index
      where indexrelid = v_index_id
        and indrelid = 'private.bil_ai_coach_admins'::pg_catalog.regclass
        and indisunique and indisvalid and indnkeyatts = 1 and indnatts = 1
        and pg_catalog.pg_get_indexdef(indexrelid, 1, true) = 'active'
        and pg_catalog.pg_get_expr(indpred, indrelid) = 'active') then
      raise exception 'approved_secondary_admin_index_preflight_failed';
    end if;
    drop index private.bil_ai_coach_single_active_admin_uidx;
  end if;

  update private.bil_ai_coach_admins
    set active = true
    where user_id = v_secondary_id and not active;
end
$restore_approved_secondary_admin$;

commit;
