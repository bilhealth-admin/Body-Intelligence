import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260908032057_community_policy_v1_activation.sql';
  const blockMigrationPath =
      'supabase/migrations/20260908032453_community_message_block_visibility_hardening.sql';
  const blockLockFixMigrationPath =
      'supabase/migrations/20260908032558_community_block_pair_uuid_lock_fix.sql';
  const sqlTestPath = 'supabase/tests/community_policy_v1_test.sql';

  test('community policy migration is forward-only and acceptance-safe', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration, contains('commit;'));
    expect(
      migration,
      contains('bil_content_policies_single_active_uidx'),
    );
    expect(
      migration,
      contains('private.bil_assert_current_community_policy()'),
    );
    expect(migration, contains('community_policy_unavailable'));
    expect(migration, contains('community_policy_acceptance_required'));
    expect(migration, contains('acceptance.accepted_at >= v_policy_effective_at'));
    expect(migration, contains('bil_00_content_policy_acceptance_guard'));
    expect(migration, contains('new.accepted_at := pg_catalog.clock_timestamp()'));
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
      RegExp(r'\b(grant|alter\s+table\s+.+enable\s+row\s+level\s+security)\b',
              caseSensitive: false)
          .hasMatch(migration),
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
    ]) {
      expect(sqlTest, contains(marker));
    }
    expect(sqlTest, contains('community_relationship_blocked'));
    expect(sqlTest, contains('community-policy-v1-rollback-test'));
    expect(sqlTest.trimRight(), endsWith('rollback;'));
  });

  test('bilateral message block guard bypasses the proven RLS visibility gap', () {
    final migration = File(blockMigrationPath).readAsStringSync();
    final lockFix = File(blockLockFixMigrationPath).readAsStringSync();

    expect(migration, contains('private.bil_guard_unblocked_community_message()'));
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
  });

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
