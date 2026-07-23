import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_entitlement_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Free plan, local repository, and provider defaults remain protected',
    () {
      final direct = FreePlan.createState();
      final repository = const LocalEntitlementRepository().current();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final providerState = container.read(subscriptionStateProvider);

      for (final state in [direct, repository, providerState]) {
        expect(state.plan, CommercePlan.free);
        expect(state.entitlements, containsAll(FreePlan.entitlements));
        expect(state.grants(CommerceEntitlement.cloudSync), isFalse);
      }
    },
  );

  test(
    'resolver uses catalog composition rather than duplicated plan switches',
    () {
      const resolver = EntitlementResolver();
      final now = DateTime.utc(2026, 7, 23);

      for (final plan in CommercePlan.values.where(
        (value) => value != CommercePlan.free,
      )) {
        final state = resolver.resolve(
          record: SubscriptionRecord(
            plan: plan,
            lifecycle: SubscriptionLifecycle.active,
            authorityVerified: true,
            provider: SubscriptionProvider.web,
            startedAt: now.subtract(const Duration(days: 1)),
            currentPeriodEndsAt: now.add(const Duration(days: 1)),
          ),
          now: now,
        );

        expect(
          state.entitlements,
          PaidPlanCatalog.composedEntitlementsFor(plan),
        );
      }
    },
  );

  test(
    'consumer authorization remains entitlement-based, not plan-name-based',
    () {
      const resolver = EntitlementResolver();
      final now = DateTime.utc(2026, 7, 23);
      final state = resolver.resolve(
        record: SubscriptionRecord(
          plan: CommercePlan.enterprise,
          lifecycle: SubscriptionLifecycle.revoked,
          authorityVerified: true,
          provider: SubscriptionProvider.google,
          startedAt: now.subtract(const Duration(days: 30)),
          currentPeriodEndsAt: now.add(const Duration(days: 30)),
        ),
        now: now,
      );

      expect(state.plan, CommercePlan.free);
      expect(
        state.grants(CommerceEntitlement.enterpriseAdministration),
        isFalse,
      );
    },
  );
}
