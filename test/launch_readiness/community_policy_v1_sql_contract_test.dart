import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260908032057_community_policy_v1_activation.sql';
  const blockMigrationPath =
      'supabase/migrations/20260908032453_community_message_block_visibility_hardening.sql';
  const blockLockFixMigrationPath =
      'supabase/migrations/20260908032558_community_block_pair_uuid_lock_fix.sql';
  const statusMigrationPath =
      'supabase/migrations/20260908132433_community_policy_client_status_rpc.sql';
  const storageGuardMigrationPath =
      'supabase/migrations/20260908175000_community_policy_storage_upload_guard.sql';
  const versionIntegrityMigrationPath =
      'supabase/migrations/20260908180500_community_policy_version_immutability.sql';
  const ledgerPostconditionsMigrationPath =
      'supabase/migrations/20260908181500_community_policy_ledger_postconditions.sql';
  const sqlTestPath = 'supabase/tests/community_policy_v1_test.sql';

  test('community policy migration is forward-only and acceptance-safe', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration, contains('commit;'));
    expect(migration, contains('bil_content_policies_single_active_uidx'));
    expect(
      migration,
      contains('private.bil_assert_current_community_policy()'),
    );
    expect(migration, contains('community_policy_unavailable'));
    expect(migration, contains('community_policy_acceptance_required'));
    expect(
      migration,
      contains('acceptance.accepted_at >= v_policy_effective_at'),
    );
    expect(migration, contains('bil_00_content_policy_acceptance_guard'));
    expect(
      migration,
      contains('new.accepted_at := pg_catalog.clock_timestamp()'),
    );
    expect(migration, contains('bil_01_social_comments_policy_guard'));
    expect(migration, contains("'community-policy-v1'"));
    expect(
      migration,
      contains("'https://www.bilhealth.com/community-guidelines'"),
    );
    expect(migration, contains("'2026-09-08T00:00:00Z'::timestamptz"));

    final acceptanceMutation = RegExp(
      r'^\s*(insert\s+into|update|delete\s+from)\s+'
      r'public\.bil_content_policy_acceptances\b',
      caseSensitive: false,
      multiLine: true,
    );
    expect(
      acceptanceMutation.hasMatch(migration),
      isFalse,
      reason: 'The activation migration must never fabricate user acceptance.',
    );
    expect(
      RegExp(
        r'\b(grant|alter\s+table\s+.+enable\s+row\s+level\s+security)\b',
        caseSensitive: false,
      ).hasMatch(migration),
      isFalse,
      reason: 'Existing grants and RLS state must remain unchanged.',
    );
  });

  test('transaction SQL test names every required behavior case', () {
    final sqlTest = File(sqlTestPath).readAsStringSync();

    for (final marker in <String>[
      r'$test_no_active_policy$',
      r'$test_active_policy_unaccepted$',
      r'$test_receipt_timestamp$',
      r'$test_new_version_requires_new_acceptance$',
      r'$test_suspended_user$',
      r'$test_blocked_relationship$',
      r'$test_direct_publish_without_acceptance$',
      r'$test_policy_status_unavailable$',
      r'$test_policy_status_acceptance_required$',
      r'$test_policy_status_accepted$',
      r'$test_policy_status_new_version_requires_acceptance$',
      r'$test_policy_status_rpc_acl$',
      r'$test_publish_ready_no_policy$',
      r'$test_publish_ready_unaccepted$',
      r'$test_publish_ready_accepted$',
      r'$test_publish_ready_suspended_user$',
      r'$test_publish_ready_rpc_acl$',
      r'$test_storage_upload_no_policy$',
      r'$test_storage_upload_unaccepted$',
      r'$test_storage_upload_accepted$',
      r'$test_storage_upload_wrong_owner$',
      r'$test_storage_upload_invalid_path$',
      r'$test_storage_upload_new_version$',
      r'$test_storage_upload_suspended$',
      r'$test_active_policy_identity_immutable$',
      r'$test_inactive_policy_identity_immutable$',
      r'$test_policy_reactivation_forbidden$',
      r'$test_active_policy_delete_rejected$',
      r'$test_inactive_policy_delete_rejected$',
      r'$test_policy_truncate_rejected$',
      r'$test_versioned_policy_rotation$',
    ]) {
      expect(sqlTest, contains(marker));
    }
    expect(sqlTest, contains('community_relationship_blocked'));
    expect(sqlTest, contains('community-policy-v1-rollback-test'));
    expect(sqlTest.trimRight(), endsWith('rollback;'));
  });

  test('Community image upload has a restrictive policy acceptance guard', () {
    final migration = File(storageGuardMigrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(
      migration,
      contains('create policy community_post_image_policy_acceptance_guard'),
    );
    expect(migration, contains('on storage.objects'));
    expect(migration, contains('as restrictive'));
    expect(migration, contains('for insert'));
    expect(migration, contains('to authenticated'));
    expect(migration, contains("bucket_id = 'community-post-images'"));
    expect(
      migration,
      contains('public.bil_assert_community_publish_ready() is not null'),
    );
    expect(migration, contains('else true'));
    expect(migration, contains("policy.polpermissive"));
    expect(migration, contains("v_permissive is not false"));
    expect(
      RegExp(
        r'^\s*(?:insert\s+into|update|delete\s+from)\s+'
        r'(?:public\.bil_content_policy|storage\.objects)\b',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(migration),
      isFalse,
      reason: 'The guard migration must not mutate policy receipts or objects.',
    );
    expect(
      RegExp(
        r'\bgrant\b|alter\s+table\s+.+\s+(?:enable|disable)\s+'
        r'row\s+level\s+security',
        caseSensitive: false,
      ).hasMatch(migration),
      isFalse,
      reason: 'Existing grants and table RLS state must remain unchanged.',
    );
  });

  test(
    'accepted policy identity is immutable and rotation stays versioned',
    () {
      final migration = File(versionIntegrityMigrationPath).readAsStringSync();

      expect(migration, contains('begin;'));
      expect(migration.trimRight(), endsWith('commit;'));
      expect(
        migration,
        contains('private.bil_guard_community_policy_version_integrity()'),
      );
      expect(migration, contains('before update or delete'));
      expect(migration, contains('new.version is distinct from old.version'));
      expect(
        migration,
        contains('new.locale_code is distinct from old.locale_code'),
      );
      expect(
        migration,
        contains('new.document_url is distinct from old.document_url'),
      );
      expect(
        migration,
        contains('new.effective_at is distinct from old.effective_at'),
      );
      expect(migration, contains('community_policy_version_immutable'));
      expect(migration, contains('community_policy_history_immutable'));
      expect(migration, contains('community_policy_reactivation_forbidden'));
      expect(migration, contains('not old.active and new.active'));
      expect(migration, contains('bil_00_content_policy_version_integrity'));
      expect(
        RegExp(
          r'^\s*(?:insert\s+into|update|delete\s+from)\s+'
          r'public\.bil_content_policy(?:_acceptances|ies)\b',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(migration),
        isFalse,
        reason:
            'The integrity migration must not alter policy or receipt data.',
      );
      expect(
        RegExp(
          r'\bgrant\b|alter\s+table\s+.+\s+(?:enable|disable)\s+'
          r'row\s+level\s+security',
          caseSensitive: false,
        ).hasMatch(migration),
        isFalse,
        reason: 'Existing grants and table RLS state must remain unchanged.',
      );
    },
  );

  test(
    'policy ledger pins the canonical row and rejects privileged truncation',
    () {
      final migration = File(
        ledgerPostconditionsMigrationPath,
      ).readAsStringSync();

      expect(migration, contains('begin;'));
      expect(migration.trimRight(), endsWith('commit;'));
      expect(migration, contains("v_active_count <> 1"));
      expect(migration, contains("policy.version = 'community-policy-v1'"));
      expect(migration, contains("policy.locale_code = 'en'"));
      expect(
        migration,
        contains("'https://www.bilhealth.com/community-guidelines'"),
      );
      expect(migration, contains("'2026-09-08T00:00:00Z'::timestamptz"));
      expect(
        migration,
        contains('public.bil_content_policies_single_active_uidx'),
      );
      expect(
        migration,
        contains('private.bil_guard_community_policy_history_truncate()'),
      );
      expect(migration, contains('before truncate'));
      expect(migration, contains('for each statement'));
      expect(migration, contains('community_policy_history_immutable'));
      expect(migration, contains('security definer'));
      expect(migration, contains("set search_path = ''"));
      expect(migration, contains('bil_00_content_policy_history_truncate'));
      expect(
        RegExp(
          r'^\s*(?:insert\s+into|update|delete\s+from|truncate)\s+'
          r'public\.bil_content_policy(?:_acceptances|ies)\b',
          caseSensitive: false,
          multiLine: true,
        ).hasMatch(migration),
        isFalse,
        reason: 'The ledger guard migration must not mutate policy data.',
      );
      expect(
        RegExp(
          r'\bgrant\b|alter\s+table\s+.+\s+(?:enable|disable)\s+'
          r'row\s+level\s+security',
          caseSensitive: false,
        ).hasMatch(migration),
        isFalse,
        reason: 'Existing grants and table RLS state must remain unchanged.',
      );
    },
  );

  test('policy-status RPC is server-timed, invoker-scoped, and fail-closed', () {
    final migration = File(statusMigrationPath).readAsStringSync();
    final statusFunction = RegExp(
      r'create function public\.bil_current_community_policy_status\(\)[\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(migration)?.group(0);

    expect(statusFunction, isNotNull);
    final statusDefinition = statusFunction!;
    expect(migration, contains('begin;'));
    expect(migration, contains('commit;'));
    expect(migration, contains('public.bil_current_community_policy_status()'));
    expect(statusDefinition, contains('security invoker'));
    expect(statusDefinition, contains("set search_path = ''"));
    expect(statusDefinition, contains('pg_catalog.statement_timestamp()'));
    expect(
      migration,
      contains('pg_catalog.count(*) over () as effective_policy_count'),
    );
    expect(
      migration,
      contains('coalesce(policy.effective_policy_count, 0) <> 1'),
    );
    expect(
      migration,
      contains(
        "case when policy.effective_policy_count = 1 then policy.version end",
      ),
    );
    expect(
      migration,
      contains(
        'policy.effective_policy_count = 1\n      and acceptance.accepted_at is not null',
      ),
    );
    expect(migration, contains("'unauthenticated'"));
    expect(migration, contains("'unavailable'"));
    expect(migration, contains("'acceptance_required'"));
    expect(migration, contains("'accepted'"));
    expect(migration, contains("'server_now'"));
    expect(migration, contains("'accepted_at'"));
    expect(
      migration,
      contains('from public, anon, authenticated, service_role'),
    );
    expect(migration, contains('to authenticated;'));
    expect(migration, contains("'service_role'"));
    expect(migration, contains("v_volatility <> 's'"));
    expect(statusDefinition, isNot(contains('security definer')));
    expect(
      RegExp(
        r'^\s*(?:insert\s+into|update|delete\s+from)\s+'
        r'public\.bil_content_policy(?:_acceptances|ies)\b',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(migration),
      isFalse,
      reason: 'A status RPC must never create or alter a user receipt.',
    );
    expect(
      RegExp(
        r'\b(?:create|alter|drop)\s+policy\b|'
        r'alter\s+table\s+.+\s+(?:enable|disable)\s+row\s+level\s+security',
        caseSensitive: false,
      ).hasMatch(migration),
      isFalse,
      reason: 'The RPC must preserve existing table RLS definitions.',
    );
  });

  test('publish-ready RPC is a strict self-only definer assertion', () {
    final migration = File(statusMigrationPath).readAsStringSync();
    final publishReadyFunction = RegExp(
      r'create function public\.bil_assert_community_publish_ready\(\)[\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(migration)?.group(0);

    expect(publishReadyFunction, isNotNull);
    final publishReadyDefinition = publishReadyFunction!;
    expect(publishReadyDefinition, contains('returns text'));
    expect(publishReadyDefinition, contains('language plpgsql'));
    expect(publishReadyDefinition, contains('volatile'));
    expect(publishReadyDefinition, contains('security definer'));
    expect(publishReadyDefinition, contains("set search_path = ''"));
    expect(publishReadyDefinition, contains('(select auth.uid())'));
    expect(
      publishReadyDefinition,
      contains('community_authentication_required'),
    );
    expect(publishReadyDefinition, contains('public.bil_can_use_community()'));
    expect(publishReadyDefinition, contains('community_access_suspended'));
    expect(
      publishReadyDefinition,
      contains('private.bil_assert_current_community_policy()'),
    );
    expect(
      publishReadyDefinition,
      isNot(contains('insert into')),
      reason:
          'The assertion is read-only and must never publish on behalf of a caller.',
    );
    expect(
      publishReadyDefinition,
      isNot(contains('user_id')),
      reason: 'The RPC must not accept or target a caller-supplied identity.',
    );
    expect(migration, contains('community_publish_ready_postconditions'));
    expect(migration, contains("v_volatility <> 'v'"));
    expect(
      migration,
      contains(
        'revoke all on function public.bil_assert_community_publish_ready()',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.bil_assert_community_publish_ready()\nto authenticated;',
      ),
    );
  });

  test(
    'bilateral message block guard bypasses the proven RLS visibility gap',
    () {
      final migration = File(blockMigrationPath).readAsStringSync();
      final lockFix = File(blockLockFixMigrationPath).readAsStringSync();

      expect(
        migration,
        contains('private.bil_guard_unblocked_community_message()'),
      );
      expect(migration, contains('bil_00_messages_block_guard'));
      expect(migration, contains('bil_00_blocks_relationship_lock'));
      expect(migration, contains("set row_security = 'off'"));
      expect(migration, contains('community_relationship_blocked'));
      expect(lockFix, contains('v_blocker_id::text < v_blocked_id::text'));
      expect(lockFix, contains('new.sender_id::text < new.recipient_id::text'));
      expect(lockFix, isNot(contains('pg_catalog.least(')));
      expect(
        RegExp(
          r'\b(?:grant|create\s+policy|alter\s+policy|drop\s+policy)\b',
          caseSensitive: false,
        ).hasMatch(migration),
        isFalse,
        reason: 'The repair must not widen grants or replace existing RLS.',
      );
    },
  );

  test('canonical website policy exposes the real version and URL content', () {
    final site = File('public_site/app.js').readAsStringSync();

    expect(site, contains("version: 'community-policy-v1'"));
    expect(site, contains("effective: '8 September 2026'"));
    expect(site, contains("updated: '8 September 2026'"));
    expect(site, contains('posts, comments, replies, likes'));
    expect(site, contains('friend and follow requests'));
    expect(site, contains('private messages'));
    expect(site, contains('Keep contact inside BIL'));
    expect(site, contains('Human moderation and enforcement'));
    expect(site, contains('Privacy and health information'));
    expect(site, contains("effective: '8 سبتمبر 2026'"));
  });
}
