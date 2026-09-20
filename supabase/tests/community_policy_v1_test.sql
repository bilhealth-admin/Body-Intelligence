-- Transactional production-schema test for community-policy-v1.
-- Run only after 20260908032057_community_policy_v1_activation.sql,
-- 20260908032453_community_message_block_visibility_hardening.sql, and
-- 20260908032558_community_block_pair_uuid_lock_fix.sql.
-- All synthetic auth, policy, relationship, and content rows are rolled back.
begin;

set local lock_timeout = '5s';
set local statement_timeout = '30s';

do $test_preflight$
begin
  if not exists (
    select 1
    from public.bil_content_policies policy
    where policy.version = 'community-policy-v1'
      and policy.active
  ) then
    raise exception 'community_policy_v1_test_requires_migration';
  end if;

  if exists (
    select 1
    from auth.users account
    where account.id in (
      '10000000-0000-4000-8000-000000000001'::uuid,
      '10000000-0000-4000-8000-000000000002'::uuid,
      '10000000-0000-4000-8000-000000000003'::uuid
    )
  ) then
    raise exception 'community_policy_v1_test_fixture_collision';
  end if;
end
$test_preflight$;

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '10000000-0000-4000-8000-000000000001', 'authenticated',
    'authenticated', 'policy-actor@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '10000000-0000-4000-8000-000000000002', 'authenticated',
    'authenticated', 'policy-partner@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  ),
  (
    '10000000-0000-4000-8000-000000000003', 'authenticated',
    'authenticated', 'policy-moderator@bil-test.invalid', '',
    pg_catalog.clock_timestamp(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    pg_catalog.clock_timestamp(), pg_catalog.clock_timestamp()
  );

insert into public.bil_community_moderators(user_id)
values ('10000000-0000-4000-8000-000000000003');

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

-- Case 1: no effective active policy fails closed with a stable error.
update public.bil_content_policies
set active = false
where version = 'community-policy-v1';

set local role authenticated;
do $test_no_active_policy$
begin
  begin
    insert into public.bil_community_posts(id, author_id, body, visibility)
    values (
      '10000000-0000-4000-8000-000000000101',
      '10000000-0000-4000-8000-000000000001',
      'Safe policy test post',
      'community'
    );
    raise exception 'test_expected_community_policy_unavailable';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_unavailable' then
        raise;
      end if;
  end;
end
$test_no_active_policy$;
reset role;

update public.bil_content_policies
set active = true
where version = 'community-policy-v1';

-- Case 2: an effective policy without an exact receipt blocks publishing.
set local role authenticated;
do $test_active_policy_unaccepted$
begin
  begin
    insert into public.bil_community_posts(id, author_id, body, visibility)
    values (
      '10000000-0000-4000-8000-000000000102',
      '10000000-0000-4000-8000-000000000001',
      'Safe unaccepted policy test post',
      'community'
    );
    raise exception 'test_expected_community_policy_acceptance_required';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_active_policy_unaccepted$;
reset role;

-- Create an inactive future-version fixture, then prove it cannot be
-- pre-accepted while v1 is current.
insert into public.bil_content_policies(
  version, locale_code, document_url, effective_at, active
) values (
  'community-policy-v2-test', 'en',
  'https://www.bilhealth.com/community-guidelines',
  pg_catalog.clock_timestamp() - interval '1 second', false
);

set local role authenticated;
do $test_inactive_preaccept_rejected$
begin
  begin
    insert into public.bil_content_policy_acceptances(user_id, policy_version)
    values (
      '10000000-0000-4000-8000-000000000001',
      'community-policy-v2-test'
    );
    raise exception 'test_expected_inactive_preaccept_rejected';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_inactive_preaccept_rejected$;

-- Case 3: a real user insert creates a server-timestamped receipt and
-- the same user can publish under that exact version.
insert into public.bil_content_policy_acceptances(
  user_id, policy_version
) values (
  '10000000-0000-4000-8000-000000000001',
  'community-policy-v1'
);

do $test_receipt_timestamp$
begin
  if not exists (
    select 1
    from public.bil_content_policy_acceptances acceptance
    join public.bil_content_policies policy
      on policy.version = acceptance.policy_version
    where acceptance.user_id =
          '10000000-0000-4000-8000-000000000001'
      and acceptance.policy_version = 'community-policy-v1'
      and acceptance.accepted_at >= policy.effective_at
  ) then
    raise exception 'test_acceptance_timestamp_not_server_authoritative';
  end if;
end
$test_receipt_timestamp$;

insert into public.bil_community_posts(id, author_id, body, visibility)
values (
  '10000000-0000-4000-8000-000000000103',
  '10000000-0000-4000-8000-000000000001',
  'Safe accepted policy test post',
  'community'
);
reset role;

-- Case 4: activating a new version invalidates the v1 receipt until the real
-- user explicitly accepts the newly active version.
update public.bil_content_policies
set active = false
where version = 'community-policy-v1';
update public.bil_content_policies
set active = true
where version = 'community-policy-v2-test';

set local role authenticated;
do $test_new_version_requires_new_acceptance$
begin
  begin
    insert into public.bil_community_posts(id, author_id, body, visibility)
    values (
      '10000000-0000-4000-8000-000000000104',
      '10000000-0000-4000-8000-000000000001',
      'Safe new policy version test post',
      'community'
    );
    raise exception 'test_expected_new_version_acceptance_required';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_new_version_requires_new_acceptance$;

insert into public.bil_content_policy_acceptances(user_id, policy_version)
values (
  '10000000-0000-4000-8000-000000000001',
  'community-policy-v2-test'
);
reset role;

-- Case 5: suspension remains authoritative even with a valid current receipt.
insert into private.bil_community_member_access(
  user_id, suspended, reason, suspended_by
) values (
  '10000000-0000-4000-8000-000000000001', true,
  'Synthetic policy test suspension',
  '10000000-0000-4000-8000-000000000003'
);

set local role authenticated;
do $test_suspended_user$
begin
  begin
    insert into public.bil_community_posts(id, author_id, body, visibility)
    values (
      '10000000-0000-4000-8000-000000000105',
      '10000000-0000-4000-8000-000000000001',
      'Safe suspended user test post',
      'community'
    );
    raise exception 'test_expected_community_access_suspended';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_access_suspended' then
        raise;
      end if;
  end;
end
$test_suspended_user$;
reset role;

delete from private.bil_community_member_access
where user_id = '10000000-0000-4000-8000-000000000001';

-- Case 6: a block remains authoritative for a direct message even when the
-- two synthetic users are otherwise accepted friends and policy is accepted.
-- The friendship guard requires Premium for the requester. This synthetic
-- entitlement exists only inside this BEGIN/ROLLBACK test transaction; it is
-- never a production grant and cannot survive the final ROLLBACK (or an error).
insert into public.bil_entitlements(
  owner_id,
  entitlement_id,
  product_id,
  provider,
  active,
  starts_at,
  expires_at,
  source_transaction_id
) values (
  '10000000-0000-4000-8000-000000000001',
  'plan:premium',
  'bil.policy.test.premium',
  'google',
  true,
  pg_catalog.clock_timestamp() - interval '1 minute',
  pg_catalog.clock_timestamp() + interval '5 minutes',
  'community-policy-v1-rollback-test'
);

insert into public.bil_friendships(
  requester_id, addressee_id, status, responded_at
) values (
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  'accepted', pg_catalog.clock_timestamp()
);
insert into public.bil_blocks(blocker_id, blocked_id)
values (
  '10000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001'
);

set local role authenticated;
do $test_blocked_relationship$
begin
  begin
    insert into public.bil_messages(id, sender_id, recipient_id, body)
    values (
      '10000000-0000-4000-8000-000000000201',
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002',
      'Safe blocked relationship test message'
    );
    raise exception 'test_expected_blocked_relationship_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_relationship_blocked' then
        raise;
      end if;
  end;

  if exists (
    select 1 from public.bil_messages message
    where message.id = '10000000-0000-4000-8000-000000000201'
  ) then
    raise exception 'test_blocked_relationship_message_persisted';
  end if;
end
$test_blocked_relationship$;

-- Case 7 / direct publish without acceptance: deleting the current receipt is
-- a database-owner-only test fixture cleanup that immediately restores the
-- publication guard; no client DELETE grant is assumed or added.
reset role;
delete from public.bil_content_policy_acceptances
where user_id = '10000000-0000-4000-8000-000000000001'
  and policy_version = 'community-policy-v2-test';

set local role authenticated;
do $test_direct_publish_without_acceptance$
begin
  begin
    insert into public.bil_community_posts(id, author_id, body, visibility)
    values (
      '10000000-0000-4000-8000-000000000106',
      '10000000-0000-4000-8000-000000000001',
      'Safe direct publish rejection test post',
      'community'
    );
    raise exception 'test_expected_direct_publish_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_direct_publish_without_acceptance$;
reset role;

rollback;
