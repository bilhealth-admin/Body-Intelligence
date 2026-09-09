begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $friendship_hardening_preflight$
declare
  v_columns text[];
  v_request_policy pg_catalog.pg_policies%rowtype;
  v_respond_policy pg_catalog.pg_policies%rowtype;
  v_request_rpc text;
begin
  if pg_catalog.to_regclass('public.bil_friendships') is null
     or not exists (
       select 1
       from pg_catalog.pg_class relation
       where relation.oid = 'public.bil_friendships'::regclass
         and relation.relrowsecurity
     ) then
    raise exception 'friendship_table_preflight_failed';
  end if;

  select pg_catalog.array_agg(attribute.attname order by attribute.attnum)
  into v_columns
  from pg_catalog.pg_attribute attribute
  where attribute.attrelid = 'public.bil_friendships'::regclass
    and attribute.attnum > 0
    and not attribute.attisdropped;

  if v_columns is distinct from array[
       'id', 'requester_id', 'addressee_id', 'status', 'created_at',
       'responded_at'
     ]::text[]
     or not exists (
       select 1
       from pg_catalog.pg_attribute attribute
       where attribute.attrelid = 'public.bil_friendships'::regclass
         and attribute.attname = 'id'
         and attribute.atttypid = 'uuid'::regtype
         and attribute.attnotnull
     )
     or not exists (
       select 1
       from pg_catalog.pg_attribute attribute
       where attribute.attrelid = 'public.bil_friendships'::regclass
         and attribute.attname in ('requester_id', 'addressee_id')
         and attribute.atttypid = 'uuid'::regtype
         and attribute.attnotnull
       group by attribute.attrelid
       having pg_catalog.count(*) = 2
     )
     or not exists (
       select 1
       from pg_catalog.pg_attribute attribute
       where attribute.attrelid = 'public.bil_friendships'::regclass
         and attribute.attname = 'status'
         and attribute.atttypid = 'text'::regtype
         and attribute.attnotnull
     )
     or not exists (
       select 1
       from pg_catalog.pg_attribute attribute
       where attribute.attrelid = 'public.bil_friendships'::regclass
         and attribute.attname = 'created_at'
         and attribute.atttypid = 'timestamp with time zone'::regtype
         and attribute.attnotnull
     )
     or not exists (
       select 1
       from pg_catalog.pg_attribute attribute
       where attribute.attrelid = 'public.bil_friendships'::regclass
         and attribute.attname = 'responded_at'
         and attribute.atttypid = 'timestamp with time zone'::regtype
         and not attribute.attnotnull
     ) then
    raise exception 'friendship_column_drift_preflight_failed';
  end if;

  select policy.* into v_request_policy
  from pg_catalog.pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'bil_friendships'
    and policy.policyname = 'bil_friendships_request';

  select policy.* into v_respond_policy
  from pg_catalog.pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'bil_friendships'
    and policy.policyname = 'bil_friendships_respond';

  if v_request_policy.policyname is null
     or v_request_policy.cmd <> 'INSERT'
     or v_request_policy.roles <> array['authenticated']::name[]
     or pg_catalog.strpos(
       pg_catalog.lower(v_request_policy.with_check), 'requester_id'
     ) = 0
     or pg_catalog.strpos(
       pg_catalog.lower(v_request_policy.with_check), 'auth.uid()'
     ) = 0
     or v_respond_policy.policyname is null
     or v_respond_policy.cmd <> 'UPDATE'
     or v_respond_policy.roles <> array['authenticated']::name[]
     or pg_catalog.strpos(
       pg_catalog.lower(v_respond_policy.qual), 'addressee_id'
     ) = 0
     or pg_catalog.strpos(
       pg_catalog.lower(v_respond_policy.with_check), 'addressee_id'
     ) = 0 then
    raise exception 'friendship_policy_drift_preflight_failed';
  end if;

  if pg_catalog.to_regprocedure('public.bil_request_friendship(uuid)') is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_request_friend_v2(uuid)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_require_premium_friendship()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_guard_community_member_access()'
     ) is null then
    raise exception 'friendship_function_drift_preflight_failed';
  end if;

  select pg_catalog.lower(pg_catalog.pg_get_functiondef(procedure.oid))
  into v_request_rpc
  from pg_catalog.pg_proc procedure
  where procedure.oid =
    'public.bil_request_friendship(uuid)'::regprocedure;

  if pg_catalog.strpos(v_request_rpc, 'bil_consume_rate_limit') = 0
     or pg_catalog.strpos(v_request_rpc, 'p_addressee_id = auth.uid()') = 0
     or pg_catalog.strpos(v_request_rpc, 'bil_blocks') = 0
     or pg_catalog.strpos(v_request_rpc, 'allow_friend_requests') = 0
     or pg_catalog.strpos(v_request_rpc, 'insert into bil_friendships') = 0 then
    raise exception 'friendship_request_rpc_body_drift_preflight_failed';
  end if;

  if not exists (
       select 1
       from pg_catalog.pg_trigger trigger_row
       where trigger_row.tgrelid = 'public.bil_friendships'::regclass
         and trigger_row.tgname = 'bil_00_friendships_member_access'
         and not trigger_row.tgisinternal
         and trigger_row.tgenabled = 'O'
     )
     or not exists (
       select 1
       from pg_catalog.pg_trigger trigger_row
       where trigger_row.tgrelid = 'public.bil_friendships'::regclass
         and trigger_row.tgname = 'bil_friendships_require_premium'
         and not trigger_row.tgisinternal
         and trigger_row.tgenabled = 'O'
     )
     or not exists (
       select 1
       from pg_catalog.pg_indexes index_row
       where index_row.schemaname = 'public'
         and index_row.tablename = 'bil_friendships'
         and index_row.indexname = 'bil_friendships_unordered_pair_idx'
     ) then
    raise exception 'friendship_trigger_or_index_drift_preflight_failed';
  end if;

  if exists (
    select 1
    from public.bil_friendships relationship
    where relationship.requester_id = relationship.addressee_id
       or relationship.status not in ('pending', 'accepted', 'declined')
       or relationship.id is null
       or relationship.created_at is null
       or (
         relationship.status = 'pending'
         and relationship.responded_at is not null
       )
       or (
         relationship.status in ('accepted', 'declined')
         and relationship.responded_at is null
       )
  ) then
    raise exception 'friendship_existing_row_preflight_failed';
  end if;
end
$friendship_hardening_preflight$;

-- Keep legacy clients compatible without retaining a table-wide INSERT grant.
-- A client may name only the two relationship parties; PostgreSQL supplies the
-- opaque id, pending state, and server timestamps. The reviewed RPC continues
-- to work through its SECURITY DEFINER owner privileges.
revoke insert on table public.bil_friendships from public, anon, authenticated;
revoke insert (
  id, requester_id, addressee_id, status, created_at, responded_at
) on public.bil_friendships from public, anon, authenticated;
grant insert (requester_id, addressee_id)
on public.bil_friendships to authenticated;

-- Existing mobile clients send status + responded_at together. Preserve that
-- payload shape, but make responded_at server-authoritative in the trigger
-- below and deny all identity/party/timestamp column updates.
revoke update on table public.bil_friendships from public, anon, authenticated;
revoke update (
  id, requester_id, addressee_id, status, created_at, responded_at
) on public.bil_friendships from public, anon, authenticated;
grant update (status, responded_at)
on public.bil_friendships to authenticated;

drop policy if exists bil_friendships_request on public.bil_friendships;
create policy bil_friendships_request
on public.bil_friendships
for insert
to authenticated
with check (
  requester_id = (select auth.uid())
  and status = 'pending'
  and responded_at is null
);

drop policy if exists bil_friendships_respond on public.bil_friendships;
create policy bil_friendships_respond
on public.bil_friendships
for update
to authenticated
using (
  addressee_id = (select auth.uid())
  and status = 'pending'
)
with check (
  addressee_id = (select auth.uid())
  and status in ('accepted', 'declined')
  and responded_at is not null
);

create or replace function public.bil_enforce_friendship_write_contract()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- SECURITY DEFINER RPCs and server maintenance remain responsible for their
  -- own reviewed contracts. This guard closes direct PostgREST writes made as
  -- the two client roles without obstructing rollback fixtures or operations.
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    if new.requester_id is distinct from auth.uid()
       or new.addressee_id is null
       or new.addressee_id = auth.uid()
       or new.status <> 'pending'
       or new.responded_at is not null then
      raise exception 'invalid_friendship_request' using errcode = '42501';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
     or new.requester_id is distinct from old.requester_id
     or new.addressee_id is distinct from old.addressee_id
     or new.created_at is distinct from old.created_at then
    raise exception 'friendship_identity_fields_immutable'
      using errcode = '42501';
  end if;

  if auth.uid() is distinct from old.addressee_id
     or old.status <> 'pending'
     or new.status not in ('accepted', 'declined') then
    raise exception 'invalid_friendship_transition' using errcode = '42501';
  end if;

  -- Ignore the client clock while accepting its historical payload field.
  new.responded_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

revoke all on function public.bil_enforce_friendship_write_contract()
from public, anon, authenticated, service_role;

drop trigger if exists bil_000_friendships_write_contract
on public.bil_friendships;
create trigger bil_000_friendships_write_contract
before insert or update on public.bil_friendships
for each row execute function public.bil_enforce_friendship_write_contract();

do $friendship_hardening_postconditions$
declare
  v_insert_policy text;
  v_update_using text;
  v_update_check text;
begin
  if pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_friendships', 'INSERT'
     )
     or not pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'requester_id', 'INSERT'
     )
     or not pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'addressee_id', 'INSERT'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'status', 'INSERT'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'id', 'INSERT'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'created_at', 'INSERT'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'responded_at', 'INSERT'
     ) then
    raise exception 'friendship_insert_acl_postcondition_failed';
  end if;

  if pg_catalog.has_table_privilege(
       'authenticated', 'public.bil_friendships', 'UPDATE'
     )
     or not pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'status', 'UPDATE'
     )
     or not pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'responded_at', 'UPDATE'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'id', 'UPDATE'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'requester_id', 'UPDATE'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'addressee_id', 'UPDATE'
     )
     or pg_catalog.has_column_privilege(
       'authenticated', 'public.bil_friendships', 'created_at', 'UPDATE'
     ) then
    raise exception 'friendship_update_acl_postcondition_failed';
  end if;

  select policy.with_check
  into v_insert_policy
  from pg_catalog.pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'bil_friendships'
    and policy.policyname = 'bil_friendships_request';

  if v_insert_policy is null
     or pg_catalog.strpos(
       pg_catalog.lower(v_insert_policy), 'status = ''pending'''
     ) = 0
     or pg_catalog.strpos(
       pg_catalog.lower(v_insert_policy), 'responded_at is null'
     ) = 0 then
    raise exception 'friendship_insert_policy_postcondition_failed';
  end if;

  select policy.qual, policy.with_check
  into v_update_using, v_update_check
  from pg_catalog.pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'bil_friendships'
    and policy.policyname = 'bil_friendships_respond';

  if v_update_using is null
     or v_update_check is null
     or pg_catalog.strpos(
       pg_catalog.lower(v_update_using), 'status = ''pending'''
     ) = 0
     or pg_catalog.strpos(
       pg_catalog.lower(v_update_check), 'accepted'
     ) = 0
     or pg_catalog.strpos(
       pg_catalog.lower(v_update_check), 'declined'
     ) = 0
     or pg_catalog.strpos(
       pg_catalog.lower(v_update_check), 'responded_at is not null'
     ) = 0 then
    raise exception 'friendship_update_policy_postcondition_failed';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.bil_friendships'::regclass
      and trigger_row.tgname = 'bil_000_friendships_write_contract'
      and not trigger_row.tgisinternal
      and trigger_row.tgenabled = 'O'
  ) then
    raise exception 'friendship_write_trigger_postcondition_failed';
  end if;

  if not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_request_friendship(uuid)',
       'EXECUTE'
     )
     or not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_social_request_friend_v2(uuid)',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon', 'public.bil_request_friendship(uuid)', 'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon', 'public.bil_social_request_friend_v2(uuid)', 'EXECUTE'
     ) then
    raise exception 'friendship_rpc_acl_postcondition_failed';
  end if;
end
$friendship_hardening_postconditions$;

commit;
