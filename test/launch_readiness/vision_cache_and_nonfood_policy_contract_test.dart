import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vision cache and rolling non-food courtesy remain server authoritative', () {
    final migration = File(
      'supabase/migrations/202608110006_bil_ai_vision_cache_and_nonfood_policy.sql',
    ).readAsStringSync();
    final quotaMigration = File(
      'supabase/migrations/202608110004_bil_ai_coach_weekly_usage_and_boost.sql',
    ).readAsStringSync();
    final throttleMigration = File(
      'supabase/migrations/202608110008_bil_ai_vision_nonfood_throttle.sql',
    ).readAsStringSync();
    final edge = File(
      'supabase/functions/analyze-meal/index.ts',
    ).readAsStringSync();

    expect(migration, contains("result_kind='food'"));
    expect(migration, contains("state='succeeded'"));
    expect(migration, contains("'cache_hit',true"));
    expect(migration, contains("now()-interval '24 hours'"));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains("auth.role()<>'service_role'"));
    expect(quotaMigration, contains('v_event.weekly_debit'));
    expect(quotaMigration, contains('v_event.paid_debit'));
    expect(migration, isNot(contains('bil_ai_boost_299')));

    expect(edge, contains('bil_decide_unknown_nonfood_settlement'));
    expect(edge, contains('bil_mark_ai_vision_food'));
    expect(edge, contains('settle(!courtesyRefund'));
    expect(edge, contains('charged: !courtesyRefund'));
    expect(edge, contains('charged: false'));
    expect(throttleMigration, contains("v_count>=3"));
    expect(throttleMigration, contains("v_count>=6"));
    expect(throttleMigration, contains("v_count>=10"));
    expect(throttleMigration, contains('retry_after_seconds'));
    expect(edge, contains('bil_check_vision_nonfood_throttle'));
    expect(edge, contains('vision_nonfood_throttled'));
  });
}
