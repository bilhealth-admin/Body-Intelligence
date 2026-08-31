import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260831193304_sync_display_locale_preferences.sql';

void main() {
  test('migration accepts exactly the reviewed 25 canonical locale tags', () {
    final sql = File(_migrationPath).readAsStringSync();
    const tags = <String>[
      'ar',
      'en',
      'fr',
      'es',
      'tr',
      'de',
      'it',
      'pt-BR',
      'pt-PT',
      'ur',
      'fa',
      'hi',
      'id',
      'ms',
      'ja',
      'ko',
      'zh-Hans',
      'zh-Hant',
      'ru',
      'bn',
      'vi',
      'th',
      'pl',
      'nl',
      'uk',
    ];

    expect(sql, startsWith('begin;'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(sql, contains('bil_public_profiles_locale_code_check'));
    expect(sql, contains('bil_user_locale_preferences_locale_code_check'));
    for (final tag in tags) {
      expect(
        RegExp("'$tag'", caseSensitive: true).allMatches(sql).length,
        greaterThanOrEqualTo(2),
        reason: tag,
      );
    }
  });

  test('locale preference is protected by own-row RLS and minimal grants', () {
    final sql = File(_migrationPath).readAsStringSync();
    final tableSection = sql.substring(
      sql.indexOf('create table public.bil_user_locale_preferences'),
      sql.indexOf(
        'create or replace function private.bil_touch_user_locale_preference',
      ),
    );

    expect(
      tableSection,
      contains(
        'alter table public.bil_user_locale_preferences enable row level security',
      ),
    );
    expect(
      RegExp(
        r'owner_id = \(select auth\.uid\(\)\)',
      ).allMatches(tableSection).length,
      greaterThanOrEqualTo(4),
    );
    expect(
      tableSection,
      contains(
        'revoke all on table public.bil_user_locale_preferences\n  from public, anon, authenticated',
      ),
    );
    expect(
      tableSection,
      contains(
        'grant select, insert, update on table public.bil_user_locale_preferences\n  to authenticated',
      ),
    );
    expect(tableSection, isNot(contains('grant delete')));
    expect(tableSection, isNot(contains('raw_user_meta_data')));
    expect(tableSection, isNot(contains('raw_app_meta_data')));
  });

  test('server canned-copy locale prefers the explicit display preference', () {
    final sql = File(_migrationPath).readAsStringSync();
    final helper = sql.substring(
      sql.indexOf(
        'create or replace function private.bil_admin_notification_locale',
      ),
      sql.indexOf(
        'revoke all on function private.bil_admin_notification_locale',
      ),
    );

    final preference = helper.indexOf('lp.locale_code');
    final appMetadata = helper.indexOf("u.raw_app_meta_data->>'locale'");
    final publicProfile = helper.indexOf('coalesce(p.locale_code');
    final userMetadata = helper.indexOf("u.raw_user_meta_data->>'locale'");
    expect(preference, greaterThanOrEqualTo(0));
    expect(appMetadata, greaterThan(preference));
    expect(publicProfile, greaterThan(appMetadata));
    expect(userMetadata, greaterThan(publicProfile));
    expect(
      helper,
      contains(
        'left join public.bil_user_locale_preferences lp on lp.owner_id = u.id',
      ),
    );
    expect(helper, contains("'en'"));
  });

  test('app upsert derives owner from current authenticated session', () {
    final source = File(
      'lib/app/services/display_locale_sync_service.dart',
    ).readAsStringSync();

    expect(source, contains("from('bil_user_locale_preferences').upsert"));
    expect(source, contains("'owner_id': user.id"));
    expect(source, contains("'locale_code': canonical"));
    expect(source, contains('_client.auth.currentUser'));
    expect(source, contains('_client.auth.currentSession'));
    expect(source, isNot(contains('rawUserMetaData')));
    expect(source, isNot(contains('updateUser(')));
  });
}
