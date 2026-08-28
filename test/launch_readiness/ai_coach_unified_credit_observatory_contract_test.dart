import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260821075318_ai_coach_unified_credit_observatory.sql',
  ).readAsStringSync();

  test('BIL AI Token is one privacy-safe cost-normalized unit', () {
    expect(migration, contains('v_credits_per_usd constant numeric := 10000'));
    expect(migration, contains("'usd_per_token',0.0001"));
    expect(
      migration,
      contains('ceil(coalesce(cost_usd,0) * v_credits_per_usd)'),
    );
    expect(
      migration,
      contains("'rounding','ceil_per_successful_provider_request'"),
    );
  });

  test('observatory is owner-scoped and exposes all planning periods', () {
    expect(migration, contains('security invoker'));
    expect(migration, contains('v_owner uuid := auth.uid()'));
    expect(migration, contains('where owner_id = v_owner'));
    expect(migration, contains('array array[7,30,365]'));
    expect(migration, contains("when 7 then 'weekly'"));
    expect(migration, contains("when 30 then 'monthly'"));
    expect(migration, contains("else 'annual'"));
    expect(migration, isNot(contains('prompt_text')));
    expect(migration, isNot(contains('reply_text')));
    expect(migration, isNot(contains('audio_data')));
  });
}
