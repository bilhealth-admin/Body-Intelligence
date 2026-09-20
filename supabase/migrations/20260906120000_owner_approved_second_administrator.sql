begin;

-- The owner explicitly approved a second operational administrator. Resolve
-- the account by its exact authenticated identity; never authorize by client
-- metadata or by an email string alone.
do $secondary_administrator$
declare
  v_owner_id uuid;
  v_secondary_id uuid;
  v_owner_count integer;
  v_secondary_count integer;
begin
  select count(*)::integer
    into v_owner_count
  from auth.users account
  where lower(account.email) = lower('kademcom@yahoo.com');

  select count(*)::integer
    into v_secondary_count
  from auth.users account
  where lower(account.email) = lower('bilhealth.app@gmail.com');

  if v_owner_count <> 1 or v_secondary_count <> 1 then
    raise exception 'secondary_administrator_preflight_failed'
      using detail =
        'Both the protected owner and the explicitly approved second administrator must exist exactly once.';
  end if;

  select account.id
    into v_owner_id
  from auth.users account
  where lower(account.email) = lower('kademcom@yahoo.com')
  limit 1;

  select account.id
    into v_secondary_id
  from auth.users account
  where lower(account.email) = lower('bilhealth.app@gmail.com')
  limit 1;

  -- This forward migration intentionally supersedes the earlier one-admin
  -- index. Existing authorization functions already check active membership,
  -- so both accounts receive the same server-backed admin surface.
  drop index if exists private.bil_ai_coach_single_active_admin_uidx;

  insert into private.bil_ai_coach_admins(
    user_id, active, granted_by, reason
  ) values (
    v_secondary_id,
    true,
    v_owner_id,
    'owner_approved_secondary_administrator'
  )
  on conflict (user_id) do update set
    active = true,
    granted_by = excluded.granted_by,
    reason = excluded.reason;

  -- The second admin can review community content from the normal moderator
  -- queue, while the database still rejects self-review of their own post.
  insert into public.bil_community_moderators(user_id)
  values (v_secondary_id)
  on conflict (user_id) do nothing;
end
$secondary_administrator$;

commit;
