import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260927064211_audit_block_and_ai_period_hardening.sql',
  ).readAsStringSync();

  test('community policies use a bilateral private block predicate', () {
    expect(migration, contains('private.bil_is_blocked_with'));
    expect(migration, contains('security definer'));
    expect(migration, contains('b.blocker_id = auth.uid()'));
    expect(migration, contains('b.blocked_id = auth.uid()'));
    expect(migration, contains('not private.bil_is_blocked_with(author_id)'));
    expect(migration, contains('not private.bil_is_blocked_with(user_id)'));
    expect(
      migration,
      isNot(contains('grant select on public.bil_blocks to authenticated')),
    );
  });

  test('AI settlement keeps its reservation period and one lock order', () {
    final periodMigration = File(
      'supabase/migrations/'
      '20260927082755_ai_monthly_event_period_reconciliation.sql',
    ).readAsStringSync();
    expect(periodMigration, contains('new.created_at'));
    expect(periodMigration, contains('private.bil_current_ai_month_start'));
    expect(
      periodMigration,
      contains('drop trigger if exists bil_ai_credit_monthly_usage_sync'),
    );
    expect(
      periodMigration,
      contains('create trigger bil_ai_credit_monthly_event_sync'),
    );
    expect(
      periodMigration,
      isNot(contains('date_trunc(\'month\', new.week_start)')),
    );
    expect(migration, contains("hashtextextended('bil.ai.'"));
    expect(migration, contains('bil_reserve_ai_usage_unserialized'));
    expect(migration, contains('bil_settle_ai_usage_unserialized'));
  });

  test('AI event periods are immutable and status cleanup shares the lock', () {
    final sql = File(
      'supabase/migrations/'
      '20260927141000_ai_event_period_and_status_lock.sql',
    ).readAsStringSync();
    expect(sql, contains('credit_plan_id'));
    expect(sql, contains('credit_period_start'));
    expect(sql, contains('before insert or update of created_at'));
    expect(sql, contains('on public.bil_ai_usage_events'));
    expect(sql, contains('ai_usage_event_period_immutable'));
    expect(sql, contains("hashtextextended('bil.ai.'"));
    expect(sql, contains('bil_get_ai_usage_status_unserialized'));
  });

  test('scheduled store persistence is fenced by the source revision', () {
    final sql = File(
      'supabase/migrations/'
      '20260927140000_store_reconciliation_revision_guard.sql',
    ).readAsStringSync();
    expect(sql, contains('p_expected_revision'));
    expect(sql, contains('v_current.revision is distinct from'));
    expect(sql, contains("'superseded',true"));
    expect(sql, contains("hashtextextended('bil-store-owner:'"));
  });

  test('meal vision timeout covers bounded provider body consumption', () {
    final source = File(
      'supabase/functions/analyze-meal/index.ts',
    ).readAsStringSync();
    expect(source, contains('readProviderResponseBody(upstream)'));
    expect(source, contains('provider_response_too_large'));
    expect(source, contains('clearTimeout(timer)'));
    expect(source, isNot(contains('await upstream.text()')));
  });
}
