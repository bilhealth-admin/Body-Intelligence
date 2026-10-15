-- Supersede the historical store-reviewer Moderator bootstrap only. Personal
-- operational administrators/moderators keep their existing memberships.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';

-- Follow the authority-before-roster order used by the server role manager.
lock table private.bil_ai_coach_admins in share mode;
select pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('community_moderator_roster', 0));
lock table public.bil_community_moderators in share row exclusive mode;

do $remove_legacy_reviewer_moderator$
declare
  v_reviewer_id uuid;
begin
  if (select pg_catalog.count(*) from auth.users
      where pg_catalog.lower(email) = 'play-review@bilhealth.com') <> 1 then
    raise exception 'store_reviewer_moderator_identity_preflight_failed';
  end if;

  select id into strict v_reviewer_id from auth.users
    where pg_catalog.lower(email) = 'play-review@bilhealth.com';

  if exists (select 1 from private.bil_ai_coach_admins
      where user_id = v_reviewer_id and active) then
    raise exception 'store_reviewer_moderator_protected_identity';
  end if;

  if exists (select 1 from public.bil_community_moderators
      where user_id = v_reviewer_id) then
    -- Match the existing roster safeguard: do not remove the last moderator.
    if not exists (select 1 from public.bil_community_moderators
        where user_id <> v_reviewer_id) then
      raise exception 'community_moderation_preflight_failed';
    end if;
    delete from public.bil_community_moderators
      where user_id = v_reviewer_id;
  end if;
end
$remove_legacy_reviewer_moderator$;

commit;
