import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AI trial allowance is scoped to both AI products and never Premium',
    () {
      final sql = File(
        'supabase/migrations/'
        '20260830175811_restrict_ai_trials_to_ai_coach_products.sql',
      ).readAsStringSync();

      expect(sql, contains('BOTH_AI_PRODUCTS_NO_PREMIUM_TRIAL'));
      expect(sql, contains("s.plan_id = 'premium_ai_coach'"));
      expect(sql, contains("'bil_premium_ai_coach'"));
      expect(sql, contains("'bil_premium_ai_coach_annual'"));
      expect(sql, isNot(contains("'bil_premium'")));
      expect(sql, isNot(contains("'bil_premium_annual'")));

      final resolverStart = sql.indexOf(
        'create or replace function public.bil_resolve_ai_allowance_plan',
      );
      final resolverEnd = sql.indexOf(
        'revoke all on function public.bil_resolve_ai_allowance_plan',
      );
      final resolver = sql.substring(resolverStart, resolverEnd);
      expect(resolver, contains("and s.lifecycle = 'trial'"));
      expect(resolver, contains("s.lifecycle in ('active', 'grace_period')"));
      expect(resolver, contains('s.expires_at is not null'));
      expect(
        resolver,
        isNot(contains('s.expires_at is null or s.expires_at > now()')),
      );
      expect(
        resolver,
        isNot(contains("s.lifecycle in ('trial', 'active', 'grace_period')")),
      );
    },
  );

  test(
    'every trial anchor and seven-day window uses the fail-closed helper',
    () {
      final sql = File(
        'supabase/migrations/'
        '20260830175811_restrict_ai_trials_to_ai_coach_products.sql',
      ).readAsStringSync();

      final anchorStart = sql.indexOf(
        'create or replace function public.bil_resolve_ai_trial_anchor',
      );
      final anchorEnd = sql.indexOf(
        'revoke all on function public.bil_resolve_ai_trial_anchor',
      );
      final anchor = sql.substring(anchorStart, anchorEnd);
      expect(anchor, contains("s.plan_id = 'premium_ai_coach'"));
      expect(anchor, contains("s.lifecycle = 'trial'"));
      expect(anchor, contains('s.expires_at is not null'));
      expect(anchor, contains('s.expires_at > now()'));
      expect(
        anchor,
        contains('coalesce(s.started_at, s.verified_at) <= now()'),
      );

      expect(
        RegExp(
          r'select public\.bil_resolve_ai_trial_anchor\(',
        ).allMatches(sql).length,
        2,
      );
      expect(
        sql,
        contains('public.bil_reserve_ai_usage(uuid,text,text,numeric)'),
      );
      expect(sql, contains('public.bil_get_ai_usage_status()'));
      expect(sql, contains('public.bil_sync_ai_monthly_usage()'));
      expect(sql, contains("if position(v_old in v_definition) = 0 then"));
      expect(sql, contains("raise exception 'trial anchor hardening failed"));
    },
  );

  test(
    'the 1,000-token config remains reachable only through trial resolver',
    () {
      final allowanceSql = File(
        'supabase/migrations/20260821124334_ai_trial_universal_1000_tokens.sql',
      ).readAsStringSync();
      final hardeningSql = File(
        'supabase/migrations/'
        '20260830175811_restrict_ai_trials_to_ai_coach_products.sql',
      ).readAsStringSync();

      expect(allowanceSql, contains("values ('trial', 1000, 1000)"));
      expect(
        hardeningSql,
        contains(
          'create or replace function public.bil_resolve_ai_allowance_plan',
        ),
      );
      expect(
        hardeningSql,
        contains('select public.bil_resolve_ai_trial_anchor(v_owner)'),
      );
      expect(
        hardeningSql,
        contains('select public.bil_resolve_ai_trial_anchor(new.owner_id)'),
      );
    },
  );

  test(
    'historical market migration is immutable and lifecycle sync is forward-only',
    () {
      final historical = File(
        'supabase/migrations/'
        '20260828220000_final_store_market_policy_alignment.sql',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final historicalDigest = sha256
          .convert(utf8.encode(historical))
          .toString();
      expect(
        historicalDigest,
        '35d2996cbe9c193dfa4b278aad10b5f141b739c1c3a3866592f6a8c498856801',
        reason:
            'Applied migrations must never be rewritten; use a later migration.',
      );
      expect(
        historical,
        isNot(contains('bil_sync_ai_coach_store_subscription')),
      );

      const forwardPath =
          'supabase/migrations/'
          '20260830120109_canonical_store_lifecycle_mirror_forward_20260830110000.sql';
      expect(
        forwardPath.compareTo(
          'supabase/migrations/20260830053817_account_deletion_storage_cleanup_20260830093000.sql',
        ),
        greaterThan(0),
      );
      final forward = File(forwardPath).readAsStringSync();
      expect(
        forward,
        contains(
          'create or replace function '
          'public.bil_sync_ai_coach_store_subscription()',
        ),
      );
      expect(forward, contains("new.plan_id = 'premium_ai_coach'"));
      expect(
        forward,
        contains(
          'drop trigger if exists '
          'bil_sync_ai_coach_store_subscription_trigger',
        ),
      );
      expect(
        forward,
        contains('create trigger bil_sync_ai_coach_store_subscription_trigger'),
      );
      expect(
        forward,
        contains(
          "new.lifecycle not in ('trial', 'active', 'grace_period', 'cancelled')",
        ),
      );
      expect(forward, contains("'bil_premium_ai_coach'"));
      expect(forward, contains("'bil_premium_ai_coach_annual'"));
      expect(forward, contains('when v_boundary is null then \'expired\''));
      expect(forward, contains('when v_boundary <= now() then \'expired\''));
      expect(forward, contains("where plan_id = 'premium_ai_coach'"));
      expect(forward, contains('from public.bil_ai_coach_subscriptions a'));
      expect(
        forward,
        contains('where a.owner_id = bil_subscriptions.owner_id'),
      );
      expect(
        forward,
        contains('delete from public.bil_ai_coach_subscriptions a'),
      );
      expect(forward, contains('and not exists ('));
      expect(
        forward,
        contains(
          "s.lifecycle in ('trial', 'active', 'grace_period', 'cancelled')",
        ),
      );
      expect(
        forward,
        contains('then s.grace_period_ends_at else s.expires_at end) > now()'),
      );
    },
  );
}
