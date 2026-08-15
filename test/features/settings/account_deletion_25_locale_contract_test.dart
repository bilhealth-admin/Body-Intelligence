import 'dart:io';

import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion has direct copy for every extended locale', () {
    final source = File(
      'lib/features/settings/account_deletion_page.dart',
    ).readAsStringSync();
    final englishStart = source.indexOf("    'en': {");
    final englishEnd = source.indexOf("\n    'ar': {", englishStart);
    expect(englishStart, greaterThanOrEqualTo(0));
    expect(englishEnd, greaterThan(englishStart));
    final values = RegExp(r":\s*'((?:\\.|[^'])*)'", multiLine: true)
        .allMatches(source.substring(englishStart, englishEnd))
        .map((match) => match.group(1)!)
        .toSet();
    expect(values, hasLength(15));
    expect(RuntimeCopy.supported, hasLength(25));
    const directStatusKeys = {
      'Status',
      'Request reference',
      'Pending',
      'Processing',
    };
    for (final value in values.where(
      (value) => !directStatusKeys.contains(value),
    )) {
      for (final locale in ExtendedRuntimeCopy.supported) {
        final translated = ExtendedRuntimeCopy.values[value]?[locale]?.trim();
        expect(translated, isNotNull, reason: 'missing $locale/$value');
        expect(translated, isNotEmpty, reason: 'blank $locale/$value');
        if (value != 'Close') {
          expect(translated, isNot(value), reason: 'fallback $locale/$value');
        }
      }
    }
    for (final locale in ExtendedRuntimeCopy.supported) {
      expect(
        source,
        contains("'$locale': {"),
        reason: 'missing direct status copy for $locale',
      );
    }
  });

  test('all five authored locales preserve the complete surface key set', () {
    final source = File(
      'lib/features/settings/account_deletion_page.dart',
    ).readAsStringSync();
    const locales = ['en', 'ar', 'fr', 'es', 'tr'];
    Set<String>? expected;
    for (var index = 0; index < locales.length; index++) {
      final locale = locales[index];
      final start = source.indexOf("    '$locale': {");
      final end = index + 1 < locales.length
          ? source.indexOf("\n    '${locales[index + 1]}': {", start)
          : source.indexOf('\n    },\n  };', start);
      expect(start, greaterThanOrEqualTo(0), reason: 'missing $locale map');
      expect(end, greaterThan(start), reason: 'unterminated $locale map');
      final keys = RegExp(r"^\s*'([^']+)':", multiLine: true)
          .allMatches(source.substring(start, end))
          .map((match) => match.group(1)!)
          .where((key) => key != locale)
          .toSet();
      expected ??= keys;
      expect(keys, expected, reason: 'surface drift in $locale');
      expect(keys, hasLength(15), reason: 'incomplete $locale surface');
    }
  });

  test('unconfigured cloud is checked before Supabase client access', () {
    final source = File(
      'lib/features/settings/account_deletion_page.dart',
    ).readAsStringSync();
    final guard = source.indexOf('!supabase.isInitialized');
    final client = source.indexOf('final client = supabase.client;');
    expect(guard, greaterThanOrEqualTo(0));
    expect(client, greaterThan(guard));
  });

  test('deletion receipt is idempotent and the submitting page cannot pop', () {
    final page = File(
      'lib/features/settings/account_deletion_page.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/202608140001_bil_account_deletion_idempotency.sql',
    ).readAsStringSync();
    expect(page, contains('canPop: !_submitting'));
    expect(page, contains("response['request_id']"));
    expect(page, contains("status != 'pending' && status != 'processing'"));
    expect(migration, contains('bil_account_deletion_one_active_per_user'));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(
      migration,
      contains(
        'lock table public.bil_account_deletion_requests in share row exclusive mode',
      ),
    );
    expect(
      migration,
      contains("case status when 'processing' then 0 else 1 end"),
    );
    expect(migration, contains("returns jsonb"));
    expect(migration, contains("'request_id', v_request.id"));
  });
}
