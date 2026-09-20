import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/20260831192412_admin_notification_controls.sql';

void main() {
  test('admin notices are own-row durable and minimally exposed', () {
    final sql = File(_migrationPath).readAsStringSync();

    expect(sql, startsWith('begin;'));
    expect(sql.trimRight(), endsWith('commit;'));
    expect(
      sql,
      contains('create table if not exists public.bil_admin_notices'),
    );
    expect(
      sql,
      contains(
        'alter table public.bil_admin_notices enable row level security',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.bil_admin_notices to authenticated',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant update on table public.bil_admin_notices to authenticated',
        ),
      ),
    );
    expect(sql, contains('owner_id = (select auth.uid())'));
    expect(sql, contains('public.bil_dismiss_admin_notice'));
    expect(sql, contains('set seen_at = now()'));
    expect(
      sql,
      contains(
        'grant execute on function public.bil_dismiss_admin_notice(uuid, uuid)\n  to authenticated;',
      ),
    );
  });

  test('mutation is service-only, audited, idempotent, and admin checked', () {
    final sql = File(_migrationPath).readAsStringSync();
    final mutation = _function(
      sql,
      'bil_enqueue_admin_notification',
      'revoke all on function public.bil_resolve_admin_notification_target',
    );

    expect(sql, contains('private.bil_admin_notification_audit'));
    expect(sql, contains('idempotency_key text not null unique'));
    expect(mutation, contains("auth.jwt()->>'role'"));
    expect(mutation, contains("<> 'service_role'"));
    expect(mutation, contains('private.bil_ai_coach_admins'));
    expect(mutation, contains('on conflict (idempotency_key) do nothing'));
    expect(mutation, contains('idempotency_key_request_mismatch'));
    expect(
      sql,
      contains(
        'public.bil_enqueue_admin_notification(uuid, text, text, uuid, text, text)\n  from public, anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'public.bil_enqueue_admin_notification(uuid, text, text, uuid, text, text)\n  to service_role;',
      ),
    );
  });

  test('notification operation cannot mutate commercial or usage state', () {
    final sql = File(_migrationPath).readAsStringSync();
    final mutation = _function(
      sql,
      'bil_enqueue_admin_notification',
      'revoke all on function public.bil_resolve_admin_notification_target',
    );

    expect(mutation, contains('insert into public.bil_admin_notices'));
    expect(mutation, contains('insert into public.bil_push_outbox'));
    for (final forbidden in <String>[
      'update public.bil_ai_credit_monthly_usage',
      'update public.bil_ai_credit_weekly_usage',
      'update public.bil_ai_weekly_usage',
      'update public.bil_subscriptions',
      'update public.bil_entitlements',
      'update public.bil_ai_credit_balances',
      'insert into public.bil_ai_coach_reset_notices',
    ]) {
      expect(mutation, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('email lookup is exact, normalized, service-only, and UUID-private', () {
    final sql = File(_migrationPath).readAsStringSync();
    final resolver = _function(
      sql,
      'bil_resolve_admin_notification_target',
      'bil_admin_notification_locale',
    );

    expect(resolver, contains('lower(trim(u.email)) = v_email'));
    expect(resolver, contains('from auth.users u'));
    expect(resolver, contains('v_match_count > 1'));
    expect(resolver, contains('ambiguous_target_email'));
    expect(resolver, contains("<> 'service_role'"));
    expect(resolver, contains('private.bil_ai_coach_admins'));
  });

  test(
    'canned copy covers every production locale and custom is mandatory',
    () {
      final sql = File(_migrationPath).readAsStringSync();
      const locales = <String>[
        'ar',
        'fr',
        'es',
        'tr',
        'de',
        'it',
        'pt-br',
        'pt-pt',
        'ur',
        'fa',
        'hi',
        'id',
        'ms',
        'ja',
        'ko',
        'zh-hans',
        'zh-hant',
        'ru',
        'bn',
        'vi',
        'th',
        'pl',
        'nl',
        'uk',
      ];
      for (final locale in locales) {
        expect(
          RegExp("when '$locale' then").allMatches(sql).length,
          greaterThanOrEqualTo(2),
          reason: locale,
        );
      }
      expect(sql, contains("v_kind = 'custom'"));
      expect(sql, contains('char_length(v_custom_body) not between 1 and 180'));
      expect(sql, contains("v_custom_body ~ '[[:cntrl:]]'"));
      expect(sql, contains('unexpected_custom_notification'));
    },
  );

  test('only safe canned copy bypasses private lock-screen preview', () {
    for (final path in <String>[
      'supabase/functions/community-push-dispatch/index.ts',
      'supabase/functions/community_push_dispatch.ts',
    ]) {
      final source = File(path).readAsStringSync();
      final safeSetStart = source.indexOf('const safeVisibleCopyKeys');
      final safeSetEnd = source.indexOf(']);', safeSetStart);
      final safeSet = source.substring(safeSetStart, safeSetEnd);
      expect(
        safeSet,
        contains('admin_notification_compensation_v1'),
        reason: path,
      );
      expect(safeSet, contains('admin_notification_gift_v1'), reason: path);
      expect(
        safeSet,
        isNot(contains('admin_notification_custom_v1')),
        reason: path,
      );
      expect(source, contains('token.sensitive_preview_allowed'), reason: path);
      expect(source, contains('You have a new private update.'), reason: path);
    }
  });
}

String _function(String sql, String startName, String endName) {
  final nameIndex = sql.indexOf(startName);
  final start = sql.lastIndexOf('create or replace function', nameIndex);
  final end = sql.indexOf(endName, nameIndex + startName.length);
  return sql.substring(start, end);
}
