-- PostgreSQL implements LEAST/GREATEST as conditional expressions rather than
-- pg_catalog functions, so schema-qualifying them fails for UUID arguments.
-- Replace only the two freshly added trigger bodies with an explicit stable
-- UUID-text ordering; all trigger bindings and ACLs remain unchanged.
begin;

create or replace function private.bil_lock_community_block_pair()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_blocker_id uuid := case when tg_op = 'DELETE'
    then old.blocker_id else new.blocker_id end;
  v_blocked_id uuid := case when tg_op = 'DELETE'
    then old.blocked_id else new.blocked_id end;
  v_left_id uuid;
  v_right_id uuid;
begin
  if v_blocker_id::text < v_blocked_id::text then
    v_left_id := v_blocker_id;
    v_right_id := v_blocked_id;
  else
    v_left_id := v_blocked_id;
    v_right_id := v_blocker_id;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_block_pair:' || v_left_id::text || ':' || v_right_id::text,
      0
    )
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function private.bil_guard_unblocked_community_message()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = 'off'
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_left_id uuid;
  v_right_id uuid;
begin
  if v_actor_id is null or new.sender_id <> v_actor_id then
    raise exception using
      errcode = '42501',
      message = 'community_message_sender_required';
  end if;

  if new.sender_id::text < new.recipient_id::text then
    v_left_id := new.sender_id;
    v_right_id := new.recipient_id;
  else
    v_left_id := new.recipient_id;
    v_right_id := new.sender_id;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_block_pair:' || v_left_id::text || ':' || v_right_id::text,
      0
    )
  );

  if exists (
    select 1
    from public.bil_blocks block_row
    where (block_row.blocker_id = new.sender_id
           and block_row.blocked_id = new.recipient_id)
       or (block_row.blocker_id = new.recipient_id
           and block_row.blocked_id = new.sender_id)
  ) then
    raise exception using
      errcode = '42501',
      message = 'community_relationship_blocked';
  end if;

  return new;
end;
$$;

do $community_block_pair_uuid_lock_fix_postcondition$
begin
  if pg_catalog.pg_get_functiondef(
       'private.bil_lock_community_block_pair()'::regprocedure
     ) ilike '%pg_catalog.least%'
     or pg_catalog.pg_get_functiondef(
       'private.bil_guard_unblocked_community_message()'::regprocedure
     ) ilike '%pg_catalog.least%' then
    raise exception 'community_block_pair_uuid_lock_fix_failed'
      using errcode = '55000';
  end if;
end
$community_block_pair_uuid_lock_fix_postcondition$;

commit;
