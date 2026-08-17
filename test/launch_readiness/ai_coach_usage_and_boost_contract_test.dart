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
    // Boost is available to every authenticated tier, including Free. The
    // credit RPC deliberately has no subscription/plan predicate.
    final creditStart = sql.indexOf(
      'create or replace function public.bil_credit_ai_boost_verified',
    );
    final reserveStart = sql.indexOf(
      'create or replace function public.bil_reserve_ai_usage',
    );
    final creditFunction = sql.substring(creditStart, reserveStart);
    expect(creditFunction, isNot(contains('bil_ai_coach_subscriptions')));
    expect(creditFunction, isNot(contains('bil_subscriptions')));
    expect(creditFunction, isNot(contains('bil_entitlements')));
    expect(
      creditFunction,
      contains("(p_owner_id,'vision',25),(p_owner_id,'text',125)"),
    );
    expect(
      creditFunction,
      contains("granted=public.bil_ai_paid_balances.granted+excluded.granted"),
    );
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

    // Reservations debit the weekly allowance first and only then paid Boost.
    expect(
      sql,
      contains(
        'v_week_debit:=least(p_units,greatest(v_limit-v_week_used-v_week_reserved,0))',
      ),
    );
    expect(sql, contains('v_paid_debit:=p_units-v_week_debit'));
  });

  test('Boost does not grant a subscription tier or Barcode access', () {
    final boost = File(
      'supabase/migrations/202608110004_bil_ai_coach_weekly_usage_and_boost.sql',
    ).readAsStringSync();
    final barcode = File(
      'supabase/migrations/202608110009_bil_premium_barcode_gateway.sql',
    ).readAsStringSync();

    expect(boost, isNot(contains("'plan:premium'")));
    expect(boost, isNot(contains("'plan:premium_ai_coach'")));
    expect(barcode, isNot(contains('bil_ai_paid_balances')));
    expect(barcode, isNot(contains('bil_ai_boost_purchases')));
    expect(
      barcode,
      contains("s.plan_id in ('pro','premium','premium_ai_coach')"),
    );
  });
}
