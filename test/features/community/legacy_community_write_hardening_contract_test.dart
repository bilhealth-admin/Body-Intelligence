import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/'
      '20260908235044_harden_legacy_community_writes_and_reports.sql';

  late String source;
  late String normalized;

  setUpAll(() {
    source = File(migrationPath).readAsStringSync();
    normalized = source.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  });

  test(
    'migration is transactional, bounded, and preserves protected domains',
    () {
      expect(source.trimLeft().startsWith('--'), isTrue);
      expect(normalized, contains("begin; set local lock_timeout = '5s';"));
      expect(normalized, contains("set local statement_timeout = '30s';"));
      expect(source.trimRight().endsWith('commit;'), isTrue);

      for (final forbidden in <RegExp>[
        RegExp(r'\b(?:drop|truncate)\s+table\b', caseSensitive: false),
        RegExp(r'\balter\s+table\s+public\.bil_social_', caseSensitive: false),
        RegExp(
          r'\b(?:insert|update|delete)\s+(?:into\s+|from\s+)?public\.'
          r'bil_content_polic',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(?:insert|update|delete)\s+(?:into\s+|from\s+)?public\.'
          r'bil_entitlement',
          caseSensitive: false,
        ),
        RegExp(
          r'\b(?:grant|revoke)\b[^;]*\b(?:rls|policy)\b',
          caseSensitive: false,
        ),
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden.pattern);
      }

      expect(normalized, isNot(contains('disable row level security')));
      expect(normalized, isNot(contains('enable row level security')));
      expect(normalized, isNot(contains('create policy')));
      expect(normalized, isNot(contains('drop policy')));
    },
  );

  test(
    'fails closed on reviewed schema, RLS, policy, guard, and duplicate drift',
    () {
      for (final invariant in <String>[
        'legacy_community_write_precondition_failed',
        'legacy_community_rls_precondition_failed',
        'legacy_community_column_drift_precondition_failed',
        'legacy_community_function_precondition_failed',
        'legacy_community_function_definition_precondition_failed',
        'legacy_community_post_guard_precondition_failed',
        'legacy_community_post_guard_definition_precondition_failed',
        'legacy_community_media_constraint_precondition_failed',
        'legacy_community_policy_precondition_failed',
        'legacy_community_select_acl_precondition_failed',
        'legacy_community_report_duplicate_precondition_failed',
        'legacy_community_hardening_name_precondition_failed',
      ]) {
        expect(source, contains(invariant));
      }

      expect(normalized, contains("having pg_catalog.count(*) > 1"));
      expect(normalized, contains("report.status in ('open', 'reviewing')"));
      expect(
        normalized,
        contains(
          'create trigger bil_01_posts_moderation_guard before insert or '
          'update on public.bil_community_posts for each row execute function '
          'public.bil_guard_community_post_moderation();',
        ),
      );
      expect(
        normalized,
        contains('community_post_update_requires_human_review'),
      );
    },
  );

  test('legacy clients retain only the reviewed column-level writes', () {
    expect(
      normalized,
      contains(
        'grant insert ( id, author_id, body, media_url, visibility, '
        'media_object_path, media_mime_type, media_bytes, media_width, '
        'media_height, moderation_status ) on table '
        'public.bil_community_posts to authenticated;',
      ),
    );
    expect(
      normalized,
      contains(
        'grant update ( deleted_at, media_url, media_object_path, '
        'media_mime_type, media_bytes, media_width, media_height ) on table '
        'public.bil_community_posts to authenticated;',
      ),
    );
    expect(
      normalized,
      contains(
        'grant insert (sender_id, recipient_id, body) on table '
        'public.bil_messages to authenticated;',
      ),
    );
    expect(
      normalized,
      contains(
        'grant insert (reporter_id, target_kind, target_id, reason) on table '
        'public.bil_community_reports to authenticated;',
      ),
    );

    for (final table in <String>[
      'bil_community_posts',
      'bil_messages',
      'bil_community_reports',
    ]) {
      expect(
        normalized,
        contains(
          'revoke insert, update, delete on table public.$table '
          'from public, anon, authenticated;',
        ),
      );
    }
  });

  test(
    'report guard is invoker-safe, non-enumerating, serialized and bounded',
    () {
      expect(
        normalized,
        contains(
          'create function public.bil_guard_community_report_write() '
          'returns trigger language plpgsql security invoker set search_path =',
        ),
      );
      expect(normalized, contains("set search_path = ''"));
      expect(
        normalized,
        contains("new.reporter_id is distinct from v_actor_id"),
      );
      expect(normalized, contains("new.status <> 'open'"));
      expect(
        normalized,
        contains('pg_catalog.char_length(new.reason) not between 3 and 500'),
      );

      for (final target in <String>[
        "when 'profile'",
        "when 'post'",
        "when 'message'",
        "when 'food'",
      ]) {
        expect(normalized, contains(target));
      }
      expect(source, contains('community_report_target_unavailable'));
      expect(normalized, contains('pg_catalog.pg_advisory_xact_lock'));
      expect(normalized, contains("return null;"));
      expect(normalized, contains("interval '1 hour'"));
      expect(normalized, contains('if v_recent_count >= 20 then'));
      expect(source, contains('community_report_rate_limit_exceeded'));
      expect(
        normalized,
        contains(
          'revoke all on function public.bil_guard_community_report_write() '
          'from public, anon, authenticated, service_role;',
        ),
      );
    },
  );

  test(
    'postconditions reject broad residual privileges and missing objects',
    () {
      for (final invariant in <String>[
        'legacy_community_table_acl_postcondition_failed',
        'legacy_community_column_acl_postcondition_failed',
        'legacy_community_residual_acl_postcondition_failed',
        'legacy_community_report_guard_postcondition_failed',
        'legacy_community_post_guard_postcondition_failed',
        'legacy_community_schema_postcondition_failed',
      ]) {
        expect(source, contains(invariant));
      }

      expect(normalized, contains("privilege.grantee = 0"));
      expect(
        normalized,
        contains("privilege.privilege_type in ('insert', 'update', 'delete')"),
      );
      expect(normalized, contains('and not procedure.prosecdef'));
      expect(normalized, contains("and procedure.provolatile = 'v'"));
      expect(normalized, contains('and index_row.indisunique'));
      expect(normalized, contains('and index_row.indpred is not null'));
    },
  );
}
