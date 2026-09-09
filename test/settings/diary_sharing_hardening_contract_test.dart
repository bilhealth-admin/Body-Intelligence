import 'dart:io';

import 'package:body_intelligence_log/features/settings/reference_preferences_pages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String runtimeProbe;
  late String page;

  setUpAll(() {
    migration = File(
      'supabase/migrations/'
      '20260908182300_harden_shared_diary_read_access.sql',
    ).readAsStringSync().toLowerCase();
    runtimeProbe = File(
      'supabase/tests/shared_diary_read_hardening_test.sql',
    ).readAsStringSync().toLowerCase();
    page = File(
      'lib/features/settings/reference_preferences_pages.dart',
    ).readAsStringSync();
  });

  test('locked diary attempts use one bounded caller-wide rate bucket', () {
    expect(migration, contains("'shared_diary_locked_read', 30, 3600"));
    expect(
      migration,
      contains(
        "perform public.bil_consume_rate_limit(\n"
        "      'shared_diary_locked_read',",
      ),
    );
    expect(migration, contains("if v_supplied_key <> '' then"));
    expect(migration, contains('before looking up any target'));
    expect(migration, contains("v_supplied_key ~ '^[0-9a-f]{64}\$'"));
    expect(migration, contains('if not v_allowed then'));
    expect(migration, contains('return null;'));
  });

  test('reader is volatile, fixed-path, and authenticated-only', () {
    final readerStart = migration.indexOf(
      'create or replace function public.bil_read_shared_diary(',
    );
    expect(readerStart, greaterThanOrEqualTo(0));
    final reader = migration.substring(readerStart);
    expect(reader, contains('volatile'));
    expect(reader, contains("set search_path = ''"));
    expect(
      reader,
      contains(
        'revoke all on function '
        'public.bil_read_shared_diary(uuid, date, text)',
      ),
    );
    expect(reader, contains('from public, anon, authenticated, service_role'));
    expect(
      reader,
      contains(
        'grant execute on function '
        'public.bil_read_shared_diary(uuid, date, text)\n'
        'to authenticated',
      ),
    );
  });

  test(
    'rollback probe covers compatibility, block, exhaustion, and cleanup',
    () {
      expect(runtimeProbe, contains('test_wrong_diary_key_was_accepted'));
      expect(
        runtimeProbe,
        contains('test_correct_legacy_digest_did_not_read_snapshot'),
      );
      expect(runtimeProbe, contains('test_blocked_shared_diary_was_visible'));
      expect(runtimeProbe, contains('test_expected_shared_diary_rate_limit'));
      expect(
        runtimeProbe,
        contains('test_shared_diary_bucket_is_not_caller_wide_and_bounded'),
      );
      expect(runtimeProbe.trimRight(), endsWith('rollback;'));
    },
  );

  test('official client no longer creates six-character locked keys', () {
    expect(page, contains('diarySharingAccessKeyLengthIsValid(key)'));
    expect(page, contains('Key must contain 16 to 128 characters'));
    expect(page, isNot(contains('key.length < 6')));

    expect(diarySharingAccessKeyLengthIsValid('short1'), isFalse);
    expect(
      diarySharingAccessKeyLengthIsValid('correct-hardened-diary-key'),
      isTrue,
    );
    expect(
      diarySharingAccessKeyLengthIsValid(List.filled(16, 'ض').join()),
      isTrue,
    );
    expect(
      diarySharingAccessKeyLengthIsValid(List.filled(129, 'x').join()),
      isFalse,
    );
  });
}
