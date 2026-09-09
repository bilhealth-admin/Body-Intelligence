-- Transactional authenticated-role proof for 20260908182400. Every account,
-- entitlement, profile, relationship, push/audit side effect, and rate-limit
-- bucket created below is removed by the final ROLLBACK.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_preflight$
begin
  if pg_catalog.to_regprocedure(
       'public.bil_enforce_friendship_write_contract()'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_request_friendship(uuid)'
     ) is null
     or pg_catalog.to_regprocedure(
       'public.bil_social_request_friend_v2(uuid)'
     ) is null then
    raise exception 'friendship_write_hardening_test_requires_migration';
  end if;

  if exists (
    select 1
    from auth.users account
    where account.id in (
      '14000000-0000-4000-8000-000000000001'::uuid,
      '14000000-0000-4000-8000-000000000002'::uuid,
      '14000000-0000-4000-8000-000000000003'::uuid
    )
  ) then
    raise exception 'friendship_write_hardening_fixture_collision';
  end if;
end
$test_preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '14000000-0000-4000-8000-000000000001', 'authenticated',
    'authenticated', 'friendship-actor@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '14000000-0000-4000-8000-000000000002', 'authenticated',
    'authenticated', 'friendship-recipient@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '14000000-0000-4000-8000-000000000003', 'authenticated',
    'authenticated', 'friendship-rpc-target@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  );

insert into public.bil_public_profiles (
  user_id, display_name, profile_visibility, discoverable,
  allow_friend_requests
) values
  (
    '14000000-0000-4000-8000-000000000001',
    'Friendship Actor', 'public', true, true
  ),
  (
    '14000000-0000-4000-8000-000000000002',
    'Friendship Recipient', 'public', true, true
  ),
  (
    '14000000-0000-4000-8000-000000000003',
    'Friendship RPC Target', 'public', true, true
  );

-- The existing Premium product rule remains authoritative. These receipts are
-- synthetic, transaction-local test prerequisites, never production grants.
insert into public.bil_entitlements (
  owner_id, entitlement_id, product_id, provider, active, starts_at,
  expires_at, source_transaction_id
) values
  (
    '14000000-0000-4000-8000-000000000001', 'plan:premium',
    'bil.friendship.hardening.actor', 'google', true,
    pg_catalog.clock_timestamp() - interval '1 minute',
    pg_catalog.clock_timestamp() + interval '5 minutes',
    'friendship-hardening-actor-rollback'
  ),
  (
    '14000000-0000-4000-8000-000000000002', 'plan:premium',
    'bil.friendship.hardening.recipient', 'google', true,
    pg_catalog.clock_timestamp() - interval '1 minute',
    pg_catalog.clock_timestamp() + interval '5 minutes',
    'friendship-hardening-recipient-rollback'
  );

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '14000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

set local role authenticated;

do $test_direct_accepted_insert_denied$
begin
  begin
    insert into public.bil_friendships(
      requester_id, addressee_id, status, responded_at
    ) values (
      '14000000-0000-4000-8000-000000000001',
      '14000000-0000-4000-8000-000000000002',
      'accepted', pg_catalog.clock_timestamp()
    );
    raise exception 'test_expected_direct_accepted_insert_denial';
  exception
    when sqlstate '42501' then null;
  end;

  if exists (
    select 1
    from public.bil_friendships relationship
    where relationship.requester_id =
        '14000000-0000-4000-8000-000000000001'::uuid
      and relationship.addressee_id =
        '14000000-0000-4000-8000-000000000002'::uuid
  ) then
    raise exception 'test_direct_accepted_insert_created_a_row';
  end if;
end
$test_direct_accepted_insert_denied$;

do $test_legacy_pending_insert_remains_compatible$
declare
  v_relationship public.bil_friendships%rowtype;
begin
  insert into public.bil_friendships(requester_id, addressee_id)
  values (
    '14000000-0000-4000-8000-000000000001',
    '14000000-0000-4000-8000-000000000002'
  )
  returning * into v_relationship;

  if v_relationship.status <> 'pending'
     or v_relationship.responded_at is not null
     or v_relationship.id is null
     or v_relationship.created_at is null then
    raise exception 'test_legacy_pending_insert_not_server_authoritative';
  end if;
end
$test_legacy_pending_insert_remains_compatible$;

do $test_requester_cannot_accept$
declare
  v_rows integer;
begin
  update public.bil_friendships
  set status = 'accepted',
      responded_at = timestamp with time zone '2001-01-01 00:00:00+00'
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000002';
  get diagnostics v_rows = row_count;

  if v_rows <> 0 then
    raise exception 'test_requester_self_accepted_relationship';
  end if;
end
$test_requester_cannot_accept$;

do $test_identity_columns_are_not_client_writable$
begin
  begin
    update public.bil_friendships
    set id = pg_catalog.gen_random_uuid()
    where requester_id = '14000000-0000-4000-8000-000000000001'
      and addressee_id = '14000000-0000-4000-8000-000000000002';
    raise exception 'test_expected_friendship_identity_update_denial';
  exception
    when sqlstate '42501' then null;
  end;

  begin
    update public.bil_friendships
    set requester_id = '14000000-0000-4000-8000-000000000003'
    where requester_id = '14000000-0000-4000-8000-000000000001'
      and addressee_id = '14000000-0000-4000-8000-000000000002';
    raise exception 'test_expected_friendship_requester_update_denial';
  exception
    when sqlstate '42501' then null;
  end;

  begin
    update public.bil_friendships
    set addressee_id = '14000000-0000-4000-8000-000000000003'
    where requester_id = '14000000-0000-4000-8000-000000000001'
      and addressee_id = '14000000-0000-4000-8000-000000000002';
    raise exception 'test_expected_friendship_addressee_update_denial';
  exception
    when sqlstate '42501' then null;
  end;

  begin
    update public.bil_friendships
    set created_at = timestamp with time zone '2001-01-01 00:00:00+00'
    where requester_id = '14000000-0000-4000-8000-000000000001'
      and addressee_id = '14000000-0000-4000-8000-000000000002';
    raise exception 'test_expected_friendship_created_at_update_denial';
  exception
    when sqlstate '42501' then null;
  end;
end
$test_identity_columns_are_not_client_writable$;

reset role;

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '14000000-0000-4000-8000-000000000002',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);

set local role authenticated;
do $test_recipient_transition_and_server_timestamp$
declare
  v_before timestamptz := pg_catalog.clock_timestamp();
  v_original_id uuid;
  v_original_created_at timestamptz;
  v_result public.bil_friendships%rowtype;
begin
  select relationship.id, relationship.created_at
  into v_original_id, v_original_created_at
  from public.bil_friendships relationship
  where relationship.requester_id =
      '14000000-0000-4000-8000-000000000001'::uuid
    and relationship.addressee_id =
      '14000000-0000-4000-8000-000000000002'::uuid;

  update public.bil_friendships
  set status = 'accepted',
      responded_at = timestamp with time zone '2001-01-01 00:00:00+00'
  where id = v_original_id
  returning * into v_result;

  if v_result.status <> 'accepted'
     or v_result.responded_at < v_before
     or v_result.responded_at =
        timestamp with time zone '2001-01-01 00:00:00+00'
     or v_result.id is distinct from v_original_id
     or v_result.requester_id is distinct from
        '14000000-0000-4000-8000-000000000001'::uuid
     or v_result.addressee_id is distinct from
        '14000000-0000-4000-8000-000000000002'::uuid
     or v_result.created_at is distinct from v_original_created_at then
    raise exception 'test_recipient_transition_contract_failed';
  end if;
end
$test_recipient_transition_and_server_timestamp$;

do $test_terminal_status_cannot_transition_again$
declare
  v_rows integer;
begin
  update public.bil_friendships
  set status = 'declined', responded_at = pg_catalog.clock_timestamp()
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000002';
  get diagnostics v_rows = row_count;

  if v_rows <> 0 then
    raise exception 'test_terminal_friendship_status_changed_again';
  end if;
end
$test_terminal_status_cannot_transition_again$;
reset role;

-- The current Flutter RPC path remains functional after direct-table ACL
-- reduction, and it can create only a pending relationship.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '14000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

set local role authenticated;
do $test_social_request_rpc_remains_pending$
declare
  v_status text;
  v_relationship public.bil_friendships%rowtype;
begin
  select public.bil_social_request_friend_v2(
    '14000000-0000-4000-8000-000000000003'
  ) into v_status;

  select * into v_relationship
  from public.bil_friendships relationship
  where relationship.requester_id =
      '14000000-0000-4000-8000-000000000001'::uuid
    and relationship.addressee_id =
      '14000000-0000-4000-8000-000000000003'::uuid;

  if v_status <> 'pending'
     or not found
     or v_relationship.status <> 'pending'
     or v_relationship.responded_at is not null then
    raise exception 'test_social_request_rpc_did_not_create_pending_row';
  end if;
end
$test_social_request_rpc_remains_pending$;
reset role;

-- A third party cannot delete another pair's relationship.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '14000000-0000-4000-8000-000000000003',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
do $test_non_party_cannot_delete$
declare
  v_rows integer;
begin
  delete from public.bil_friendships
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000002';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'test_non_party_deleted_friendship';
  end if;
end
$test_non_party_cannot_delete$;

-- Declining is terminal: a declined row cannot later be promoted to accepted.
do $test_declined_cannot_become_accepted$
declare
  v_rows integer;
begin
  update public.bil_friendships
  set status = 'declined',
      responded_at = timestamp with time zone '2001-01-01 00:00:00+00'
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000003';
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'test_recipient_could_not_decline_pending_request';
  end if;

  update public.bil_friendships
  set status = 'accepted', responded_at = pg_catalog.clock_timestamp()
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000003';
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'test_declined_relationship_became_accepted';
  end if;
end
$test_declined_cannot_become_accepted$;
reset role;

-- The addressee may remove the accepted A/B relationship.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '14000000-0000-4000-8000-000000000002',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
do $test_addressee_can_delete$
declare
  v_rows integer;
begin
  delete from public.bil_friendships
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000002';
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'test_addressee_could_not_delete_friendship';
  end if;
end
$test_addressee_can_delete$;
reset role;

-- The requester may remove the terminal A/C relationship.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '14000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"14000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
do $test_requester_can_delete$
declare
  v_rows integer;
begin
  delete from public.bil_friendships
  where requester_id = '14000000-0000-4000-8000-000000000001'
    and addressee_id = '14000000-0000-4000-8000-000000000003';
  get diagnostics v_rows = row_count;
  if v_rows <> 1 then
    raise exception 'test_requester_could_not_delete_friendship';
  end if;
end
$test_requester_can_delete$;
reset role;

rollback;
