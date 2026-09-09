import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260908181800_backend_function_lint_closure.sql';
  const sqlTestPath = 'supabase/tests/backend_function_lint_closure_test.sql';

  test('forward migration fixes push ambiguity without widening access', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(
      migration,
      contains(
        'on conflict on constraint bil_push_delivery_attempts_pkey do nothing',
      ),
    );
    expect(
      migration,
      contains(
        'public.bil_claim_push_deliveries(uuid, integer)\n'
        'to service_role;',
      ),
    );
    expect(
      migration,
      isNot(
        contains(
          RegExp(
            r'grant\s+execute[\s\S]*?bil_claim_push_deliveries[\s\S]*?'
            r'to\s+(?:anon|authenticated)',
            caseSensitive: false,
          ),
        ),
      ),
    );
  });

  test('public-code helper keeps behavior and removes shadow declaration', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('private.bil_social_public_code_payload_v2('));
    expect(migration, contains('security invoker'));
    expect(migration, contains("set search_path = ''"));
    expect(migration, contains('for v_attempt in 1..3 loop'));
    expect(migration, isNot(contains('v_attempt integer;')));
    expect(
      migration,
      contains(
        'private.bil_social_public_code_payload_v2(boolean)\n'
        'from public, anon, authenticated, service_role;',
      ),
    );
  });

  test('push runtime proof is transactional and lease-aware', () {
    final probe = File(sqlTestPath).readAsStringSync();

    expect(probe, contains('begin;'));
    expect(probe.trimRight(), endsWith('rollback;'));
    expect(probe, isNot(contains('commit;')));
    for (final marker in <String>[
      'test_push_claim_round_trip',
      'test_push_claim_lease_not_respected',
      'test_push_claim_attempt_state',
      'test_push_claim_acl',
    ]) {
      expect(probe, contains(marker));
    }
  });
}
