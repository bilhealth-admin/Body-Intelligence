import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> usage(String plan, Object? totalRemaining) => {
  'plan': plan,
  'credits': <String, Object?>{'total_remaining': totalRemaining},
};

void main() {
  test('zero -> Boost -> consumed zero is reflected exactly', () {
    expect(aiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
    expect(aiCoachAccessFromUsageStatus(usage('free', 2500)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
  });

  test('AI subscription and trial require a positive total remaining', () {
    expect(aiCoachAccessFromUsageStatus(usage('ai_coach', 10000)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('ai_coach', 0)), isFalse);
    expect(aiCoachAccessFromUsageStatus(usage('trial', 1000)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage('trial', 0)), isFalse);
  });

  test(
    'ordinary Premium unlocks only when authoritative Boost total is positive',
    () {
      expect(aiCoachAccessFromUsageStatus(usage('premium', 2500)), isTrue);
      expect(aiCoachAccessFromUsageStatus(usage('premium', 0)), isFalse);
      expect(aiCoachAccessFromUsageStatus(usage('free', 0)), isFalse);
    },
  );

  test('total remaining is authoritative regardless of its source label', () {
    expect(aiCoachAccessFromUsageStatus(usage('future_plan', 1)), isTrue);
    expect(
      aiCoachAccessFromUsageStatus(<String, Object?>{
        'credits': <String, Object?>{'total_remaining': 1},
      }),
      isTrue,
    );
  });

  test('null, non-positive, and malformed credit snapshots fail closed', () {
    for (final value in <Object?>[
      null,
      const <String, Object?>{},
      usage('ai_coach', null),
      usage('ai_coach', '1000'),
      usage('ai_coach', 0),
      usage('ai_coach', -1),
      usage('ai_coach', double.nan),
      usage('ai_coach', double.infinity),
      <Object?, Object?>{1: 'not-a-string-key'},
      <Object?, Object?>{
        'plan': 'ai_coach',
        'credits': <Object?, Object?>{1: 1000},
      },
    ]) {
      expect(aiCoachAccessFromUsageStatus(value), isFalse, reason: '$value');
    }
  });

  test('AI subscription identity requires a verified live store boundary', () {
    final now = DateTime.utc(2026, 8, 30, 12);

    SubscriptionState state({
      CommercePlan plan = CommercePlan.premiumAiCoach,
      SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
      DateTime? currentPeriodEndsAt,
      DateTime? trialEndsAt,
      DateTime? gracePeriodEndsAt,
      EntitlementAuthority authority = EntitlementAuthority.verifiedServer,
    }) => SubscriptionState(
      plan: plan,
      entitlements: const {},
      authority: authority,
      lifecycle: lifecycle,
      currentPeriodEndsAt: currentPeriodEndsAt,
      trialEndsAt: trialEndsAt,
      gracePeriodEndsAt: gracePeriodEndsAt,
      isPurchasable: false,
      canRestorePurchases: false,
    );

    expect(
      hasVerifiedAiSubscription(
        state(currentPeriodEndsAt: now.add(const Duration(seconds: 1))),
        now: now,
      ),
      isTrue,
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          lifecycle: SubscriptionLifecycle.trial,
          trialEndsAt: now.add(const Duration(days: 7)),
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          lifecycle: SubscriptionLifecycle.gracePeriod,
          gracePeriodEndsAt: now.add(const Duration(hours: 1)),
        ),
        now: now,
      ),
      isTrue,
    );
    expect(
      hasVerifiedAiSubscription(state(currentPeriodEndsAt: now), now: now),
      isFalse,
      reason: 'the exact boundary instant is expired',
    );
    expect(
      hasVerifiedAiSubscription(state(), now: now),
      isFalse,
      reason: 'a missing boundary must fail closed',
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          plan: CommercePlan.premium,
          currentPeriodEndsAt: now.add(const Duration(days: 30)),
        ),
        now: now,
      ),
      isFalse,
    );
    expect(
      hasVerifiedAiSubscription(
        state(
          plan: CommercePlan.free,
          authority: EntitlementAuthority.localDefault,
          currentPeriodEndsAt: now.add(const Duration(days: 30)),
        ),
        now: now,
      ),
      isFalse,
    );
  });
}
