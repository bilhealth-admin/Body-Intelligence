import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/server_entitlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 23, 12);

  SubscriptionState paid({DateTime? periodEnd}) => SubscriptionState(
    plan: CommercePlan.premiumAiCoach,
    entitlements: const {CommerceEntitlement.adFree},
    authority: EntitlementAuthority.verifiedServer,
    lifecycle: SubscriptionLifecycle.active,
    currentPeriodEndsAt: periodEnd ?? now.add(const Duration(days: 7)),
    isPurchasable: false,
    canRestorePurchases: false,
  );

  test('transient fallback is owner scoped and short lived', () {
    final cache = VerifiedEntitlementSessionCache();
    cache.remember(ownerId: 'owner-a', state: paid(), now: now);

    expect(
      cache.fallbackFor(ownerId: 'owner-a', now: now)?.plan,
      CommercePlan.premiumAiCoach,
    );
    expect(cache.fallbackFor(ownerId: 'owner-b', now: now), isNull);
    expect(
      cache.fallbackFor(
        ownerId: 'owner-a',
        now: now.add(const Duration(minutes: 5, seconds: 1)),
      ),
      isNull,
    );
  });

  test('continuity never outlives the verified billing boundary', () {
    final cache = VerifiedEntitlementSessionCache();
    cache.remember(
      ownerId: 'owner-a',
      state: paid(periodEnd: now.add(const Duration(seconds: 30))),
      now: now,
    );

    expect(
      cache.fallbackFor(
        ownerId: 'owner-a',
        now: now.add(const Duration(seconds: 31)),
      ),
      isNull,
    );
  });

  test('a verified free response clears prior paid continuity', () {
    final cache = VerifiedEntitlementSessionCache();
    cache.remember(ownerId: 'owner-a', state: paid(), now: now);
    cache.remember(
      ownerId: 'owner-a',
      state: SubscriptionState(
        plan: CommercePlan.free,
        entitlements: const {CommerceEntitlement.localTracking},
        authority: EntitlementAuthority.verifiedServer,
        lifecycle: SubscriptionLifecycle.inactive,
        isPurchasable: false,
        canRestorePurchases: false,
      ),
      now: now.add(const Duration(seconds: 1)),
    );

    expect(cache.fallbackFor(ownerId: 'owner-a', now: now), isNull);
  });
}
