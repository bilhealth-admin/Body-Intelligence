import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const pending = <String>[
    'supabase/migrations/20260904030000_community_post_human_moderation.sql',
    'supabase/migrations/20260904040000_push_delivery_idempotency.sql',
    'supabase/migrations/20260905010000_mobile_integrity_jit_grants.sql',
  ];

  test('pending backend migrations are transactional and SQL-special safe', () {
    for (final path in pending) {
      final source = File(path).readAsStringSync();
      expect(source.trimLeft(), contains('begin;'), reason: path);
      expect(source.trimRight().endsWith('commit;'), isTrue, reason: path);

      // COALESCE, GREATEST, LEAST, and NULLIF are PostgreSQL conditional
      // expressions rather than ordinary pg_catalog functions. Qualifying
      // them compiles as a missing-function error on the target database.
      expect(
        source,
        isNot(
          contains(
            RegExp(
              r'pg_catalog\.(?:coalesce|greatest|least|nullif)\s*\(',
              caseSensitive: false,
            ),
          ),
        ),
        reason: path,
      );
    }
  });
}
