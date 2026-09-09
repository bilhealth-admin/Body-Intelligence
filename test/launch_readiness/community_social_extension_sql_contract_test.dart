import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/'
      '20260908181700_community_social_saves_and_public_codes.sql';
  const sqlTestPath =
      'supabase/tests/community_social_saves_public_codes_v2_test.sql';
  const authorsMigrationPath =
      'supabase/migrations/'
      '20260908181900_community_social_post_authors_v2.sql';
  const authorsVolatilityMigrationPath =
      'supabase/migrations/'
      '20260908182000_community_social_post_authors_volatility.sql';
  const socialIntegrityMigrationPath =
      'supabase/migrations/'
      '20260908182100_community_social_handle_backfill_and_reply_visibility.sql';

  test('Social v2 extension is additive, transactional, and RPC-only', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(migration, contains('create table public.bil_social_post_saves_v2'));
    expect(
      migration,
      contains('create table public.bil_social_public_codes_v2'),
    );
    expect(
      migration,
      isNot(
        contains(
          RegExp(
            r'\b(?:drop|truncate)\s+table\s+public\.bil_social_',
            caseSensitive: false,
          ),
        ),
      ),
    );
    expect(
      migration,
      isNot(
        contains(
          RegExp(
            r'\b(?:insert\s+into|update|delete\s+from)\s+'
            r'public\.bil_content_policy_acceptances\b',
            caseSensitive: false,
          ),
        ),
      ),
      reason: 'A migration must never fabricate or rewrite user acceptance.',
    );

    for (final table in <String>[
      'bil_social_post_saves_v2',
      'bil_social_public_codes_v2',
    ]) {
      expect(
        migration,
        contains('alter table public.$table enable row level security;'),
      );
    }
    expect(
      migration,
      contains('from public, anon, authenticated, service_role;'),
    );
    expect(migration, contains('to authenticated;'));
    expect(migration, contains('privilege.grantee = 0'));
    expect(migration, contains("set search_path = ''"));
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

  test('post-author batch is caller-scoped and least-privilege', () {
    final migration = File(authorsMigrationPath).readAsStringSync();
    final volatility = File(authorsVolatilityMigrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(
      migration,
      contains('function public.bil_social_post_authors_v2(p_user_ids uuid[])'),
    );
    expect(migration, contains('v_actor uuid := auth.uid();'));
    expect(migration, contains('public.bil_can_use_community()'));
    expect(migration, contains('cardinality(p_user_ids), 0) > 100'));
    expect(migration, contains('public.bil_social_profile_visible_v2'));
    expect(migration, contains("set search_path = ''"));
    expect(
      migration,
      contains('from public, anon, authenticated, service_role;'),
    );
    expect(migration, contains('to authenticated;'));
    expect(migration, isNot(contains('email')));
    expect(migration, isNot(contains('phone')));
    expect(volatility, contains('alter function'));
    expect(volatility, contains('uuid[]) volatile;'));
  });

  test('handles are guaranteed and replies fail closed with hidden roots', () {
    final migration = File(socialIntegrityMigrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(
      migration,
      contains('private.bil_social_create_handle_for_profile_v2()'),
    );
    expect(migration, contains('after insert on public.bil_public_profiles'));
    expect(migration, contains("'member_' || pg_catalog.left("));
    expect(migration, contains('on conflict (user_id) do nothing'));
    expect(migration, contains('where social_handle.user_id is null'));
    expect(migration, contains('root.id = comment.parent_id'));
    expect(migration, contains('root.deleted_at is null'));
    expect(migration, contains('root.removed_at is null'));
    expect(migration, contains('root.parent_id is null'));
    expect(
      migration,
      isNot(
        contains(
          RegExp(
            r'(?:insert\s+into|update|delete\s+from)\s+'
            r'public\.bil_content_policy_acceptances\b',
            caseSensitive: false,
          ),
        ),
      ),
    );
  });

  test('BIL public codes are opaque, rotatable, and enumeration-safe', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains(r"check (code ~ '^[a-f0-9]{32}$')"));
    expect(migration, contains("'bil://community/member/' || v_code"));
    expect(migration, contains('bil_social_rotate_public_code_v2'));
    expect(migration, contains("'community_public_code_rotate_v2'"));
    expect(migration, contains("'community_public_code_resolve_v2'"));
    expect(migration, contains('pg_catalog.octet_length(p_code) <> 32'));
    expect(migration, contains('if not found then\n    return null;'));
    expect(migration, contains("v_relationship := 'self';"));
    expect(migration, contains("then 'pending'\n        else 'incoming'"));
    expect(migration, isNot(contains("'email'")));
    expect(migration, isNot(contains("'phone'")));
  });

  test(
    'transactional SQL probe covers saves, rotation, privacy, and suspension',
    () {
      final probe = File(sqlTestPath).readAsStringSync();

      expect(probe, contains('begin;'));
      expect(probe.trimRight(), endsWith('rollback;'));
      expect(probe, isNot(contains('commit;')));
      for (final marker in <String>[
        'test_save_round_trip',
        'test_actor_public_code_round_trip',
        'test_social_rotated_code_still_resolves',
        'test_target_code_resolution',
        'test_private_code_hidden',
        'test_blocked_code_hidden',
        'test_suspended_actor_fails_closed',
        'test_rpc_only_tables',
        'test_post_authors_batch',
        'test_deleted_root_hides_replies',
        'test_social_deleted_root_exposes_reply',
        'test_expected_orphan_reply_like_rejection',
        'test_expected_orphan_reply_report_rejection',
      ]) {
        expect(probe, contains(marker));
      }
    },
  );
}
