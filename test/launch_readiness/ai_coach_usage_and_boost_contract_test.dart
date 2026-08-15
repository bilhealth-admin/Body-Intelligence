import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach quota and verified Boost remain separated and fail closed', () {
    final sql = File(
      'supabase/migrations/202608110004_bil_ai_coach_weekly_usage_and_boost.sql',
    ).readAsStringSync();
    final store = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();

    expect(sql, contains("('ai_coach','vision',25,'requests')"));
    expect(sql, contains("('ai_coach','text',125,'requests')"));
    expect(sql, contains("('ai_coach','voice',15,'minutes')"));
    expect(sql, contains('public.bil_ai_coach_subscriptions'));
    expect(sql, isNot(contains("s.plan_id='pro'")));
    expect(sql, contains('used + reserved <= granted'));
    expect(sql, contains("state='refunded'"));
    expect(sql, contains("now()+interval '15 minutes'"));
    expect(sql, contains("auth.role()<>'service_role'"));
    expect(sql, contains('bil_reserve_ai_usage(uuid,text,text,numeric)'));
    expect(
      sql,
      contains(
        'bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)',
      ),
    );
    expect(sql, contains("product_id='bil_ai_boost'"));
    expect(
      sql,
      isNot(
        contains(
          'bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text)\n  to authenticated',
        ),
      ),
    );
    // The only execute grant for credit must be the service role.
    expect(sql, contains('to service_role;'));

    expect(store, contains("body.action === 'verify_ai_boost'"));
    expect(store, contains("productId !== 'bil_ai_boost'"));
    expect(store, contains('verifyGoogleConsumable'));
    expect(store, contains('verifyApple(verification)'));
    expect(store, contains("admin.rpc('bil_credit_ai_boost_verified'"));
    expect(store, contains('consumeGoogleConsumable'));
    expect(store, isNot(contains('BIL_GEMINI_API_KEY')));
  });
}
