-- Transactional production-schema test for community-policy-v1.
-- Run only after 20260908032057_community_policy_v1_activation.sql,
-- 20260908032453_community_message_block_visibility_hardening.sql,
-- 20260908032558_community_block_pair_uuid_lock_fix.sql, and
-- 20260908132433_community_policy_client_status_rpc.sql, and
-- 20260908175000_community_policy_storage_upload_guard.sql, and
-- 20260908180500_community_policy_version_immutability.sql, and
-- 20260908181500_community_policy_ledger_postconditions.sql.
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

  if pg_catalog.to_regprocedure(
       'public.bil_current_community_policy_status()'
     ) is null then
    raise exception 'community_policy_v1_test_requires_status_rpc';
  end if;

  if pg_catalog.to_regprocedure(
       'public.bil_assert_community_publish_ready()'
     ) is null then
    raise exception 'community_policy_v1_test_requires_publish_ready_rpc';
  end if;

  if pg_catalog.to_regprocedure(
       'private.bil_guard_community_policy_version_integrity()'
     ) is null then
    raise exception 'community_policy_v1_test_requires_version_integrity_guard';
  end if;

  if pg_catalog.to_regprocedure(
       'private.bil_guard_community_policy_history_truncate()'
     ) is null then
    raise exception 'community_policy_v1_test_requires_history_truncate_guard';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_policy policy
    join pg_catalog.pg_class relation on relation.oid = policy.polrelid
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'storage'
      and relation.relname = 'objects'
      and policy.polname = 'community_post_image_policy_acceptance_guard'
      and not policy.polpermissive
      and policy.polcmd = 'a'
  ) then
    raise exception 'community_policy_v1_test_requires_storage_guard';
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

do $test_active_policy_identity_immutable$
declare
  v_statement text;
begin
  foreach v_statement in array array[
    'update public.bil_content_policies '
      'set version = ''community-policy-v1-mutated'' '
      'where version = ''community-policy-v1''',
    'update public.bil_content_policies '
      'set locale_code = ''ar'' '
      'where version = ''community-policy-v1''',
    'update public.bil_content_policies '
      'set document_url = '
      '''https://www.bilhealth.com/community-guidelines?changed=1'' '
      'where version = ''community-policy-v1''',
    'update public.bil_content_policies '
      'set effective_at = effective_at + interval ''1 second'' '
      'where version = ''community-policy-v1'''
  ] loop
    begin
      execute v_statement;
      raise exception 'test_expected_active_policy_identity_rejection';
    exception
      when sqlstate '55000' then
        if sqlerrm <> 'community_policy_version_immutable' then
          raise;
        end if;
    end;
  end loop;
end
$test_active_policy_identity_immutable$;

do $test_active_policy_delete_rejected$
begin
  begin
    delete from public.bil_content_policies
    where version = 'community-policy-v1';
    raise exception 'test_expected_active_policy_delete_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_history_immutable' then
        raise;
      end if;
  end;
end
$test_active_policy_delete_rejected$;

do $test_policy_truncate_rejected$
begin
  begin
    truncate table
      public.bil_content_policy_acceptances,
      public.bil_content_policies;
    raise exception 'test_expected_policy_truncate_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_history_immutable' then
        raise;
      end if;
  end;
end
$test_policy_truncate_rejected$;

-- Case 1: no effective active policy fails closed with a stable error.
savepoint test_no_active_policy_case;
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

do $test_publish_ready_no_policy$
begin
  begin
    perform public.bil_assert_community_publish_ready();
    raise exception 'test_expected_publish_ready_no_policy_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_unavailable' then
        raise;
      end if;
  end;
end
$test_publish_ready_no_policy$;

do $test_storage_upload_no_policy$
begin
  begin
    insert into storage.objects(bucket_id, name, owner_id)
    values (
      'community-post-images',
      '10000000-0000-4000-8000-000000000001/' ||
      '10000000-0000-4000-8000-000000000301/' ||
      '10000000-0000-4000-8000-000000000401.jpg',
      '10000000-0000-4000-8000-000000000001'
    );
    raise exception 'test_expected_storage_no_policy_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_unavailable' then
        raise;
      end if;
  end;
end
$test_storage_upload_no_policy$;

do $test_policy_status_unavailable$
declare
  v_status jsonb;
begin
  select public.bil_current_community_policy_status() into v_status;

  if v_status->>'status' <> 'unavailable'
     or v_status->>'accepted' <> 'false'
     or v_status->>'version' is not null
     or v_status->>'document_url' is not null
     or v_status->>'server_now' is null then
    raise exception 'test_policy_status_unavailable';
  end if;
end
$test_policy_status_unavailable$;
reset role;
rollback to savepoint test_no_active_policy_case;
release savepoint test_no_active_policy_case;

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

do $test_publish_ready_unaccepted$
begin
  begin
    perform public.bil_assert_community_publish_ready();
    raise exception 'test_expected_publish_ready_unaccepted_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_publish_ready_unaccepted$;

do $test_storage_upload_unaccepted$
begin
  begin
    insert into storage.objects(bucket_id, name, owner_id)
    values (
      'community-post-images',
      '10000000-0000-4000-8000-000000000001/' ||
      '10000000-0000-4000-8000-000000000302/' ||
      '10000000-0000-4000-8000-000000000402.jpg',
      '10000000-0000-4000-8000-000000000001'
    );
    raise exception 'test_expected_storage_unaccepted_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_storage_upload_unaccepted$;

do $test_policy_status_acceptance_required$
declare
  v_status jsonb;
begin
  select public.bil_current_community_policy_status() into v_status;

  if v_status->>'status' <> 'acceptance_required'
     or v_status->>'version' <> 'community-policy-v1'
     or v_status->>'document_url' <>
          'https://www.bilhealth.com/community-guidelines'
     or v_status->>'accepted' <> 'false'
     or (v_status->>'server_now')::timestamptz > pg_catalog.clock_timestamp() then
    raise exception 'test_policy_status_acceptance_required';
  end if;
end
$test_policy_status_acceptance_required$;
reset role;

-- Create an inactive future-version fixture, then prove it cannot be
-- pre-accepted while v1 is current.
insert into public.bil_content_policies(
  version, locale_code, document_url, effective_at, active
) values (
  'community-policy-draft-test', 'en',
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
      'community-policy-draft-test'
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

reset role;
do $test_inactive_policy_delete_rejected$
begin
  begin
    delete from public.bil_content_policies
    where version = 'community-policy-draft-test';
    raise exception 'test_expected_inactive_policy_delete_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_history_immutable' then
        raise;
      end if;
  end;
end
$test_inactive_policy_delete_rejected$;
set local role authenticated;

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

do $test_policy_status_accepted$
declare
  v_status jsonb;
begin
  select public.bil_current_community_policy_status() into v_status;

  if v_status->>'status' <> 'accepted'
     or v_status->>'version' <> 'community-policy-v1'
     or v_status->>'accepted' <> 'true'
     or (v_status->>'accepted_at')::timestamptz <
          '2026-09-08T00:00:00Z'::timestamptz
     or v_status->>'server_now' is null then
    raise exception 'test_policy_status_accepted';
  end if;
end
$test_policy_status_accepted$;

do $test_publish_ready_accepted$
declare
  v_policy_version text;
begin
  select public.bil_assert_community_publish_ready() into v_policy_version;

  if v_policy_version <> 'community-policy-v1' then
    raise exception 'test_publish_ready_accepted';
  end if;
end
$test_publish_ready_accepted$;

do $test_storage_upload_accepted$
declare
  v_inserted bigint;
begin
  insert into storage.objects(bucket_id, name, owner_id)
  values (
    'community-post-images',
    '10000000-0000-4000-8000-000000000001/' ||
    '10000000-0000-4000-8000-000000000303/' ||
    '10000000-0000-4000-8000-000000000403.jpg',
    '10000000-0000-4000-8000-000000000001'
  );
  get diagnostics v_inserted = row_count;

  if v_inserted <> 1 then
    raise exception 'test_storage_upload_accepted';
  end if;
end
$test_storage_upload_accepted$;

do $test_storage_upload_wrong_owner$
begin
  begin
    insert into storage.objects(bucket_id, name, owner_id)
    values (
      'community-post-images',
      '10000000-0000-4000-8000-000000000001/' ||
      '10000000-0000-4000-8000-000000000306/' ||
      '10000000-0000-4000-8000-000000000406.jpg',
      '10000000-0000-4000-8000-000000000002'
    );
    raise exception 'test_expected_storage_wrong_owner_rejection';
  exception
    when sqlstate '42501' then null;
  end;
end
$test_storage_upload_wrong_owner$;

do $test_storage_upload_invalid_path$
begin
  begin
    insert into storage.objects(bucket_id, name, owner_id)
    values (
      'community-post-images',
      '10000000-0000-4000-8000-000000000001/not-a-post/not-an-image.gif',
      '10000000-0000-4000-8000-000000000001'
    );
    raise exception 'test_expected_storage_invalid_path_rejection';
  exception
    when sqlstate '42501' then null;
  end;
end
$test_storage_upload_invalid_path$;

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

do $test_inactive_policy_identity_immutable$
begin
  begin
    update public.bil_content_policies
    set effective_at = effective_at + interval '1 second'
    where version = 'community-policy-v1';
    raise exception 'test_expected_inactive_policy_identity_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_version_immutable' then
        raise;
      end if;
  end;
end
$test_inactive_policy_identity_immutable$;

do $test_policy_reactivation_forbidden$
begin
  begin
    update public.bil_content_policies
    set active = true
    where version = 'community-policy-v1';
    raise exception 'test_expected_policy_reactivation_rejection';
  exception
    when sqlstate '55000' then
      if sqlerrm <> 'community_policy_reactivation_forbidden' then
        raise;
      end if;
  end;
end
$test_policy_reactivation_forbidden$;

insert into public.bil_content_policies(
  version, locale_code, document_url, effective_at, active
) values (
  'community-policy-v2-test', 'en',
  'https://www.bilhealth.com/community-guidelines',
  pg_catalog.clock_timestamp() - interval '1 second', true
);

do $test_versioned_policy_rotation$
begin
  if (select pg_catalog.count(*)
      from public.bil_content_policies policy
      where policy.active) <> 1 then
    raise exception 'test_versioned_policy_rotation';
  end if;
end
$test_versioned_policy_rotation$;

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

do $test_policy_status_new_version_requires_acceptance$
declare
  v_status jsonb;
begin
  select public.bil_current_community_policy_status() into v_status;

  if v_status->>'status' <> 'acceptance_required'
     or v_status->>'version' <> 'community-policy-v2-test'
     or v_status->>'accepted' <> 'false' then
    raise exception 'test_policy_status_new_version_requires_acceptance';
  end if;
end
$test_policy_status_new_version_requires_acceptance$;

do $test_storage_upload_new_version$
begin
  begin
    insert into storage.objects(bucket_id, name, owner_id)
    values (
      'community-post-images',
      '10000000-0000-4000-8000-000000000001/' ||
      '10000000-0000-4000-8000-000000000304/' ||
      '10000000-0000-4000-8000-000000000404.jpg',
      '10000000-0000-4000-8000-000000000001'
    );
    raise exception 'test_expected_storage_new_version_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_policy_acceptance_required' then
        raise;
      end if;
  end;
end
$test_storage_upload_new_version$;

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
do $test_publish_ready_suspended_user$
begin
  begin
    perform public.bil_assert_community_publish_ready();
    raise exception 'test_expected_publish_ready_suspended_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_access_suspended' then
        raise;
      end if;
  end;
end
$test_publish_ready_suspended_user$;

do $test_storage_upload_suspended$
begin
  begin
    insert into storage.objects(bucket_id, name, owner_id)
    values (
      'community-post-images',
      '10000000-0000-4000-8000-000000000001/' ||
      '10000000-0000-4000-8000-000000000305/' ||
      '10000000-0000-4000-8000-000000000405.jpg',
      '10000000-0000-4000-8000-000000000001'
    );
    raise exception 'test_expected_storage_suspended_rejection';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'community_access_suspended'
         and position('row-level security policy' in sqlerrm) = 0 then
        raise;
      end if;
  end;
end
$test_storage_upload_suspended$;

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

-- The RPC is deliberately an authenticated-only read interface. Check the
-- actual ACL as well as the migration's catalog postcondition.
do $test_policy_status_rpc_acl$
begin
  if not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_current_community_policy_status()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon',
       'public.bil_current_community_policy_status()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role',
       'public.bil_current_community_policy_status()',
       'EXECUTE'
     ) then
    raise exception 'test_policy_status_rpc_acl';
  end if;
end
$test_policy_status_rpc_acl$;

do $test_publish_ready_rpc_acl$
begin
  if not pg_catalog.has_function_privilege(
       'authenticated',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'anon',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     )
     or pg_catalog.has_function_privilege(
       'service_role',
       'public.bil_assert_community_publish_ready()',
       'EXECUTE'
     ) then
    raise exception 'test_publish_ready_rpc_acl';
  end if;
end
$test_publish_ready_rpc_acl$;

rollback;
