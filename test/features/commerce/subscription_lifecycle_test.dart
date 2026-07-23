import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = EntitlementResolver();
  final now = DateTime.utc(2026, 7, 23, 12);

  SubscriptionRecord record(
    SubscriptionLifecycle lifecycle, {
    DateTime? periodEnd,
    DateTime? trialEnd,
    DateTime? graceEnd,
    bool verified = true,
  }) => SubscriptionRecord(
    plan: CommercePlan.pro,
    lifecycle: lifecycle,
    authorityVerified: verified,
    provider: SubscriptionProvider.apple,
    startedAt: now.subtract(const Duration(days: 10)),
    currentPeriodEndsAt: periodEnd,
    trialEndsAt: trialEnd,
    gracePeriodEndsAt: graceEnd,
  );

  test('trial grants paid access through the inclusive trial boundary', () {
    final state = resolver.resolve(
      record: record(SubscriptionLifecycle.trial, trialEnd: now),
      now: now,
    );

    expect(state.plan, CommercePlan.pro);
    expect(state.grants(CommerceEntitlement.advancedIntelligence), isTrue);
  });

  test(
    'active and cancelled retain access only through current period end',
    () {
      for (final lifecycle in <SubscriptionLifecycle>[
        SubscriptionLifecycle.active,
        SubscriptionLifecycle.cancelled,
      ]) {
        final entitled = resolver.resolve(
          record: record(
            lifecycle,
            periodEnd: now.add(const Duration(days: 1)),
          ),
          now: now,
        );
        final ended = resolver.resolve(
          record: record(
            lifecycle,
            periodEnd: now.subtract(const Duration(seconds: 1)),
          ),
          now: now,
        );

        expect(entitled.plan, CommercePlan.pro);
        expect(ended.plan, CommercePlan.free);
      }
    },
  );

  test('grace period grants access only through grace end', () {
    final state = resolver.resolve(
      record: record(
        SubscriptionLifecycle.gracePeriod,
        periodEnd: now.subtract(const Duration(days: 1)),
        graceEnd: now.add(const Duration(hours: 1)),
      ),
      now: now,
    );

    expect(state.plan, CommercePlan.pro);
  });

  test('terminal and paused states deterministically fall back to Free', () {
    for (final lifecycle in <SubscriptionLifecycle>[
      SubscriptionLifecycle.inactive,
      SubscriptionLifecycle.paused,
      SubscriptionLifecycle.expired,
      SubscriptionLifecycle.refunded,
      SubscriptionLifecycle.revoked,
    ]) {
      final state = resolver.resolve(
        record: record(lifecycle, periodEnd: now.add(const Duration(days: 30))),
        now: now,
      );

      expect(state.plan, CommercePlan.free, reason: '$lifecycle');
      expect(state.grants(CommerceEntitlement.advancedIntelligence), isFalse);
    }
  });

  test('unverified paid records can never grant paid access', () {
    final state = resolver.resolve(
      record: record(
        SubscriptionLifecycle.active,
        periodEnd: now.add(const Duration(days: 30)),
        verified: false,
      ),
      now: now,
    );

    expect(state.plan, CommercePlan.free);
    expect(state.grants(CommerceEntitlement.advancedIntelligence), isFalse);
    expect(state.canRestorePurchases, isFalse);
    expect(state.isPurchasable, isFalse);
  });
}
