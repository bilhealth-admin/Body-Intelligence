import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260815225624_bil_canonical_consumer_tiers.sql',
    ).readAsStringSync();
  });

  test('migrates historical tiers without granting legacy Plus AI access', () {
    expect(sql, contains("when 'pro' then 'premium'"));
    expect(sql, contains("when 'plus' then 'legacy_plus'"));
    expect(sql, isNot(contains("when 'plus' then 'premium_ai_coach'")));
    expect(
      sql,
      contains("plan_id in ('premium', 'premium_ai_coach', 'legacy_plus')"),
    );
    expect(
      sql,
      contains("not enabled or plan_id in ('premium', 'premium_ai_coach')"),
    );
  });

  test('AI Coach quota mirror is driven only by verified subscription rows', () {
    expect(sql, contains('after insert or update or delete'));
    expect(sql, contains("if new.plan_id = 'premium_ai_coach' then"));
    expect(sql, contains('insert into public.bil_ai_coach_subscriptions'));
    expect(sql, contains('delete from public.bil_ai_coach_subscriptions'));
    expect(sql, contains('where owner_id = new.owner_id'));
    expect(
      sql,
      contains(
        'revoke all on function public.bil_sync_ai_coach_store_subscription()',
      ),
    );
    expect(sql, contains("if tg_op = 'DELETE' then"));
    expect(sql, contains('where owner_id = old.owner_id'));
  });

  test('switching plans deactivates stale plan entitlements', () {
    expect(sql, contains("entitlement_id like 'plan:%'"));
    expect(sql, contains("entitlement_id <> 'plan:' || new.plan_id"));
    expect(sql, contains('and active = true'));
  });

  test('canonical subscriptions retain the authoritative Meal Vision quota', () {
    expect(sql, contains('bil_vision_quota_config_plan_id_check'));
    expect(
      sql,
      contains("('free', 'premium', 'premium_ai_coach', 'legacy_plus')"),
    );
    expect(sql, contains('create or replace function public.bil_reserve_vision_request'));
    expect(sql, contains('create or replace function public.bil_get_vision_usage'));
    expect(
      sql,
      contains("s.plan_id in ('premium', 'premium_ai_coach', 'legacy_plus')"),
    );
    expect(sql, isNot(contains("s.plan_id in ('pro','plus')")));
  });
}
