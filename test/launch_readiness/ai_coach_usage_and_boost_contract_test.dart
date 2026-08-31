import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Coach uses one cost-normalized token balance and fails closed', () {
    final baseSql = File(
      'supabase/migrations/20260821080542_ai_coach_unified_weekly_tokens.sql',
    ).readAsStringSync();
    final policySql = File(
      'supabase/migrations/20260821102504_commerce_country_policy_and_ai_allowances.sql',
    ).readAsStringSync();
    final allowanceSql = File(
      'supabase/migrations/20260821123043_ai_coach_monthly_allowance_status_and_fallback.sql',
    ).readAsStringSync();
    final backfillSql = File(
      'supabase/migrations/20260821123129_ai_coach_monthly_usage_backfill.sql',
    ).readAsStringSync();
    final trialSql = File(
      'supabase/migrations/20260821124334_ai_trial_universal_1000_tokens.sql',
    ).readAsStringSync();
    final trialPeriodSql = File(
      'supabase/migrations/20260821124632_ai_trial_fixed_period_metering.sql',
    ).readAsStringSync();
    final store = File(
      'supabase/functions/verify-store-purchase/store_backend.ts',
    ).readAsStringSync();

    expect(policySql, contains("when plan_id = 'ai_coach' then 2500"));
    expect(policySql, contains("when plan_id = 'ai_coach' then 10000"));
    expect(policySql, contains('public.bil_ai_credit_monthly_usage'));
    expect(allowanceSql, contains('v_included_debit := least('));
    expect(allowanceSql, contains('v_month_limit - v_month_used'));
    expect(allowanceSql, contains("'monthly_limit',v_month_limit"));
    expect(allowanceSql, contains("'included_remaining',v_included_remaining"));
    expect(backfillSql, contains('sum(used)::bigint'));
    expect(trialSql, contains("values ('trial', 1000, 1000)"));
    expect(trialSql, contains("s.lifecycle = 'trial'"));
    expect(trialSql, contains('bil_resolve_ai_allowance_plan'));
    expect(trialPeriodSql, contains("if v_plan = 'trial'"));
    expect(trialPeriodSql, contains('coalesce(s.started_at, s.verified_at)'));
    expect(trialPeriodSql, contains("then (v_week + 7)::date"));
    expect(baseSql, contains('public.bil_ai_credit_weekly_usage'));
    expect(baseSql, contains('public.bil_ai_credit_balances'));
    expect(baseSql, contains("'unit','BIL AI Token'"));
    expect(baseSql, contains('ceil(p_cost_usd * 10000)::bigint'));
    expect(baseSql, contains("when 'text' then 100"));
    expect(baseSql, contains("when 'vision' then 100"));
    expect(baseSql, contains('ceil(p_units * 500)::bigint + 50'));
    expect(baseSql, contains('public.bil_ai_coach_subscriptions'));
    expect(baseSql, isNot(contains("s.plan_id='pro'")));
    expect(baseSql, contains('used + reserved <= granted'));
    expect(baseSql, contains("state = 'refunded'"));
    expect(baseSql, contains("now() + interval '15 minutes'"));
    expect(baseSql, contains("auth.jwt()->>'role'"));
    expect(baseSql, contains('bil_reserve_ai_usage(uuid,text,text,numeric)'));
    expect(
      baseSql,
      contains(
        'bil_settle_ai_usage(uuid,text,text,boolean,text,text,integer,integer,integer,numeric)',
      ),
    );
    expect(policySql, contains("p_product_id <> 'bil_ai_boost'"));
    // Boost is available to every authenticated tier, including Free. The
    // credit RPC deliberately has no subscription/plan predicate.
    final creditStart = policySql.indexOf(
      'create or replace function public.bil_credit_ai_boost_verified',
    );
    final grantStart = policySql.indexOf(
      '\nrevoke all on function',
      creditStart,
    );
    final creditFunction = policySql.substring(creditStart, grantStart);
    expect(creditFunction, isNot(contains('bil_ai_coach_subscriptions')));
    expect(creditFunction, isNot(contains('bil_subscriptions')));
    expect(creditFunction, isNot(contains('bil_entitlements')));
    expect(creditFunction, contains('v_boost_tokens constant bigint := 2500'));
    expect(
      creditFunction,
      contains(
        'granted = public.bil_ai_credit_balances.granted + excluded.granted',
      ),
    );
    expect(
      policySql,
      isNot(
        contains(
          'bil_credit_ai_boost_verified(uuid,text,text,text,timestamptz,text)\n  to authenticated',
        ),
      ),
    );
    // The only execute grant for credit must be the service role.
    expect(policySql, contains('to service_role;'));

    expect(
      store,
      matches(RegExp(r'''body\.action\s*===\s*["']verify_ai_boost["']''')),
    );
    expect(
      store,
      matches(RegExp(r'''productId\s*!==\s*["']bil_ai_boost["']''')),
    );
    expect(store, contains('verifyGoogleConsumable'));
    expect(store, contains('verifyApple(verification)'));
    expect(
      store,
      matches(
        RegExp(r'''admin\.rpc\(\s*["']bil_credit_ai_boost_verified["']'''),
      ),
    );
    expect(store, contains('consumeGoogleConsumable'));
    expect(store, isNot(contains('BIL_GEMINI_API_KEY')));

    // Reservations debit the shared weekly tokens first and only then Boost.
    expect(baseSql, contains('v_week_debit := least('));
    expect(
      baseSql,
      contains('v_paid_debit := v_credit_reserve - v_week_debit'),
    );
    expect(
      baseSql,
      contains("'text',v_shared,'vision',v_shared,'voice',v_shared"),
    );
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
