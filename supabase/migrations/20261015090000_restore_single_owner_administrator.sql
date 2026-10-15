-- Store reviewers are not administrators. Restore the documented single
-- owner/admin boundary after the older secondary-admin migration.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $restore_single_owner_admin$
declare
  v_owner_id uuid;
  v_owner_count integer;
begin
  select pg_catalog.count(*)::integer
    into v_owner_count
  from auth.users account
  where pg_catalog.lower(account.email) = 'kademcom@yahoo.com';

  if v_owner_count <> 1 then
    raise exception 'single_owner_administrator_preflight_failed'
      using detail = 'The designated owner account must exist exactly once.';
  end if;

  select account.id
    into v_owner_id
  from auth.users account
  where pg_catalog.lower(account.email) = 'kademcom@yahoo.com'
  limit 1;

  -- Preserve history, but remove active administration from every other
  -- account. This also reverses the prior reviewer/secondary-admin overlap.
  update private.bil_ai_coach_admins administrator
  set active = false
  where administrator.active
    and administrator.user_id <> v_owner_id;

  insert into private.bil_ai_coach_admins(
    user_id, active, granted_by, reason
  ) values (
    v_owner_id, true, v_owner_id, 'designated_operational_owner'
  )
  on conflict (user_id) do update set
    active = true,
    granted_by = excluded.granted_by,
    reason = excluded.reason;

  if (select pg_catalog.count(*)
      from private.bil_ai_coach_admins administrator
      where administrator.active) <> 1 then
    raise exception 'single_owner_administrator_preflight_failed';
  end if;
end
$restore_single_owner_admin$;

create unique index if not exists bil_ai_coach_single_active_admin_uidx
  on private.bil_ai_coach_admins ((active))
  where active;

commit;
