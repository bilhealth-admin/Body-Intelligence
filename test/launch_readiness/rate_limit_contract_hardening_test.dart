import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260908181600_harden_rate_limit_contract.sql';
  const sqlTestPath = 'supabase/tests/rate_limit_contract_hardening_test.sql';

  test('rate-limit hardening preserves every reviewed caller tuple', () {
    final migration = File(migrationPath).readAsStringSync();
    const reviewedTuples = <(String, int, int)>[
      ('account_deletion', 3, 3600),
      ('account_deletion', 3, 86400),
      ('account_export', 3, 3600),
      ('ai_boost_purchase_verification', 20, 3600),
      ('app_attest_issue', 60, 3600),
      ('admin_ai_coach_global_reset', 3, 3600),
      ('admin_ai_coach_individual_reset', 20, 3600),
      ('admin_community_member_list', 120, 3600),
      ('admin_community_member_reinstate', 30, 3600),
      ('admin_community_member_suspend', 30, 3600),
      ('admin_community_moderator_add', 30, 3600),
      ('admin_community_moderator_list', 120, 3600),
      ('admin_community_moderator_remove', 30, 3600),
      ('admin_notification_all', 10, 3600),
      ('admin_notification_individual', 50, 3600),
      ('community_comment_report_v2', 20, 3600),
      ('community_comment_v2', 60, 3600),
      ('community_handle_claim_v2', 10, 3600),
      ('community_handle_search_v2', 60, 60),
      ('community_like_v2', 120, 60),
      ('community_post_save_v2', 120, 60),
      ('community_public_code_resolve_v2', 60, 60),
      ('community_public_code_rotate_v2', 5, 86400),
      ('follow', 40, 3600),
      ('food_search_hour', 60, 3600),
      ('food_search_minute', 10, 60),
      ('friend_request', 20, 3600),
      ('meal_image_analysis', 30, 3600),
      ('message', 60, 3600),
      ('play_integrity_issue', 60, 3600),
      ('post', 12, 3600),
      ('store_purchase_verification', 20, 3600),
    ];

    for (final (action, limit, window) in reviewedTuples) {
      expect(
        migration,
        contains("('$action', $limit, $window)"),
        reason: '$action/$limit/$window',
      );
    }
  });

  test('rate-limit RPC rejects arbitrary keys without widening its ACL', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(
      migration,
      contains('create or replace function public.bil_consume_rate_limit('),
    );
    expect(migration, contains("set search_path = ''"));
    expect(migration, contains('pg_catalog.octet_length(p_action)'));
    expect(migration, contains('invalid_rate_limit_contract'));
    expect(migration, contains('to authenticated, service_role;'));
    expect(migration, contains('privilege.grantee = 0'));
    expect(migration, isNot(contains('alter table')));
    expect(migration, isNot(contains('delete from')));
    expect(
      migration,
      isNot(
        contains(
          RegExp(
            r'pg_catalog\.(?:coalesce|greatest|least|nullif)\s*\(',
            caseSensitive: false,
          ),
        ),
      ),
    );
  });

  test('runtime probe is transactional and checks storage amplification', () {
    final probe = File(sqlTestPath).readAsStringSync();

    expect(probe, contains('begin;'));
    expect(probe.trimRight(), endsWith('rollback;'));
    expect(probe, isNot(contains('commit;')));
    for (final marker in <String>[
      'test_rejects_arbitrary_bucket_keys',
      'test_expected_oversized_action_rejection',
      'test_expected_limit_mismatch_rejection',
      'test_canonical_tuple_and_limit',
      'test_bucket_write_is_bounded',
      'test_rate_limit_rpc_acl',
    ]) {
      expect(probe, contains(marker));
    }
  });
}
