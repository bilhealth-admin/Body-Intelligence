import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaidPlanCatalog', () {
    test('contains every paid plan exactly once', () {
      final paidPlans = CommercePlan.values
          .where((plan) => plan != CommercePlan.free)
          .toSet();

      expect(PaidPlanCatalog.entries.keys, paidPlans);
      expect(PaidPlanCatalog.entries.length, paidPlans.length);
    });

    test('orders entries by unique stable rank', () {
      final entries = PaidPlanCatalog.orderedEntries;
      final ranks = entries.map((entry) => entry.rank).toList();

      expect(ranks.toSet().length, ranks.length);
      expect(ranks, orderedEquals(<int>[10, 20, 30, 40, 50, 60, 80, 90]));
    });

    test('composes individual tiers without duplicate entitlement logic', () {
      final premium = PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.premium,
      );
      final premiumAiCoach = PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.premiumAiCoach,
      );
      final elite = PaidPlanCatalog.composedEntitlementsFor(CommercePlan.elite);

      expect(premium, contains(CommerceEntitlement.cloudSync));
      expect(premium, contains(CommerceEntitlement.advancedIntelligence));
      expect(premiumAiCoach, containsAll(premium));
      expect(elite, containsAll(premium));
    });

    test('composes professional and enterprise capabilities explicitly', () {
      final coach = PaidPlanCatalog.composedEntitlementsFor(CommercePlan.coach);
      final clinic = PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.clinic,
      );
      final enterprise = PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.enterprise,
      );

      expect(coach, contains(CommerceEntitlement.coachWorkspace));
      expect(clinic, contains(CommerceEntitlement.clinicWorkspace));
      expect(
        enterprise,
        containsAll(<CommerceEntitlement>{
          CommerceEntitlement.coachWorkspace,
          CommerceEntitlement.clinicWorkspace,
          CommerceEntitlement.enterpriseAdministration,
        }),
      );
    });

    test('returns immutable composed entitlement sets', () {
      final entitlements = PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.premium,
      );

      expect(
        () => entitlements.add(CommerceEntitlement.enterpriseAdministration),
        throwsUnsupportedError,
      );
    });
  });
}
