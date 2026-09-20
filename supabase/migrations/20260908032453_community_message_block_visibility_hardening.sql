-- Enforce bilateral Community blocks for private messages without depending
-- on the sender's RLS-visible slice of bil_blocks. The existing message RLS
-- policy remains unchanged; this trigger closes the proven visibility gap.
begin;

do $community_message_block_preflight$
begin
  if pg_catalog.to_regclass('public.bil_messages') is null
     or pg_catalog.to_regclass('public.bil_blocks') is null then
    raise exception 'community_message_block_schema_precondition_failed'
      using errcode = '55000';
  end if;
end
$community_message_block_preflight$;

-- Serialize block/unblock and message insertion for one unordered member
-- pair. A message that commits before a later block remains historical; once
-- the block transaction starts first, a concurrent message waits and is
-- rejected after the block becomes visible.
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
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_block_pair:' ||
      pg_catalog.least(v_blocker_id, v_blocked_id)::text || ':' ||
      pg_catalog.greatest(v_blocker_id, v_blocked_id)::text,
      0
    )
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

revoke all on function private.bil_lock_community_block_pair()
from public, anon, authenticated, service_role;

drop trigger if exists bil_00_blocks_relationship_lock
on public.bil_blocks;
create trigger bil_00_blocks_relationship_lock
before insert or delete
on public.bil_blocks
for each row execute function private.bil_lock_community_block_pair();

create or replace function private.bil_guard_unblocked_community_message()
returns trigger
language plpgsql
security definer
set search_path = ''
set row_security = 'off'
as $$
declare
  v_actor_id uuid := (select auth.uid());
begin
  if v_actor_id is null or new.sender_id <> v_actor_id then
    raise exception using
      errcode = '42501',
      message = 'community_message_sender_required';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'community_block_pair:' ||
      pg_catalog.least(new.sender_id, new.recipient_id)::text || ':' ||
      pg_catalog.greatest(new.sender_id, new.recipient_id)::text,
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

revoke all on function private.bil_guard_unblocked_community_message()
from public, anon, authenticated, service_role;

drop trigger if exists bil_00_messages_block_guard
on public.bil_messages;
create trigger bil_00_messages_block_guard
before insert
on public.bil_messages
for each row execute function private.bil_guard_unblocked_community_message();

do $community_message_block_postconditions$
begin
  if not exists (
    select 1
    from pg_catalog.pg_trigger trigger_row
    join pg_catalog.pg_class table_row
      on table_row.oid = trigger_row.tgrelid
    join pg_catalog.pg_namespace schema_row
      on schema_row.oid = table_row.relnamespace
    where schema_row.nspname = 'public'
      and table_row.relname = 'bil_messages'
      and trigger_row.tgname = 'bil_00_messages_block_guard'
      and not trigger_row.tgisinternal
  ) or not exists (
    select 1
    from pg_catalog.pg_trigger trigger_row
    join pg_catalog.pg_class table_row
      on table_row.oid = trigger_row.tgrelid
    join pg_catalog.pg_namespace schema_row
      on schema_row.oid = table_row.relnamespace
    where schema_row.nspname = 'public'
      and table_row.relname = 'bil_blocks'
      and trigger_row.tgname = 'bil_00_blocks_relationship_lock'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'community_message_block_postcondition_failed'
      using errcode = '55000',
            detail = 'Expected bilateral block triggers are missing.';
  end if;

  if pg_catalog.has_function_privilege(
       'anon', 'private.bil_guard_unblocked_community_message()', 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'authenticated',
       'private.bil_guard_unblocked_community_message()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role',
       'private.bil_guard_unblocked_community_message()',
       'EXECUTE'
     ) then
    raise exception 'community_message_block_postcondition_failed'
      using errcode = '55000',
            detail = 'The internal block guard is directly executable.';
  end if;
end
$community_message_block_postconditions$;

commit;
