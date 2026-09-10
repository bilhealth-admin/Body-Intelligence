import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/20260908141133_harden_public_default_table_privileges.sql';
  const sqlProbePath = 'supabase/tests/default_privileges_hardening_test.sql';

  test('default-privileges hardening is forward-only and owner-scoped', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('begin;'));
    expect(migration.trimRight(), endsWith('commit;'));
    expect(
      migration,
      contains('alter default privileges for role postgres in schema public'),
    );
    expect(
      migration,
      contains(
        'revoke truncate, trigger, references, maintain on tables\n'
        '  from anon, authenticated;',
      ),
    );
    expect(migration, contains('default_acl_hardening_preflight'));
    expect(migration, contains('default_acl_hardening_postconditions'));
    expect(migration, contains('v_global_dangerous_count <> 0'));
    expect(migration, contains('v_public_dangerous_count <> 8'));
    expect(migration, contains('v_client_dangerous_count <> 0'));
    expect(migration, contains('v_service_role_dangerous_count <> 4'));
    expect(migration, contains("default_acl.defaclobjtype = 'r'"));
    expect(migration, contains('privilege.grantee = 0'));
    expect(migration, contains("in ('anon', 'authenticated')"));
    expect(
      migration,
      isNot(
        contains(
          "coalesce(pg_catalog.pg_get_userbyid(privilege.grantee), 'PUBLIC')",
        ),
      ),
      reason: 'PUBLIC has ACL grantee OID 0, not a NULL role lookup.',
    );
  });

  test('default-privileges migration cannot mutate current data or RLS', () {
    final migration = File(migrationPath).readAsStringSync();

    final forbiddenMutation = RegExp(
      r'^\s*(?:insert\s+into|update\s+\S+\s+set|delete\s+from|'
      r'truncate\s+table|create\s+table|drop\s+table|alter\s+table|'
      r'create\s+policy|alter\s+policy|drop\s+policy)\b',
      caseSensitive: false,
      multiLine: true,
    );
    expect(
      forbiddenMutation.hasMatch(migration),
      isFalse,
      reason:
          'The forward migration may change only postgres/public relation defaults.',
    );
    expect(migration, isNot(contains('supabase_admin')));
    expect(
      RegExp(
        r'\brevoke\b[^;]*\bfrom\b[^;]*\bservice_role\b',
        caseSensitive: false,
      ).hasMatch(migration),
      isFalse,
      reason: 'The repair must not revoke or rewrite service_role defaults.',
    );
    expect(
      RegExp(
        r'^\s*grant\b[^;]*\bto\b[^;]*\b(?:anon|authenticated)\b',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(migration),
      isFalse,
      reason: 'The repair must remove only the four dangerous default grants.',
    );
  });

  test(
    'transactional probe creates one synthetic table and always rolls back',
    () {
      final probe = File(sqlProbePath).readAsStringSync();

      expect(probe, contains('begin;'));
      expect(probe.trimRight(), endsWith('rollback;'));
      expect(probe, isNot(contains('commit;')));
      expect(probe, contains("if current_user <> 'postgres' then"));
      expect(
        probe,
        contains('public.bil_default_acl_hardening_probe_20260908141133'),
      );
      expect(
        probe,
        contains('create table public.bil_default_acl_hardening_probe_'),
      );
      for (final marker in <String>[
        "'anon'::name",
        "'authenticated'::name",
        "'TRUNCATE'::text",
        "'TRIGGER'::text",
        "'REFERENCES'::text",
        "'MAINTAIN'::text",
        'pg_catalog.has_table_privilege',
        'default_acl_hardening_probe_failed',
      ]) {
        expect(probe, contains(marker));
      }
    },
  );
}
