import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FreePlan', () {
    test('grants the complete offline-first foundation', () {
      final state = FreePlan.createState();

      expect(state.plan, CommercePlan.free);
      expect(state.authority, EntitlementAuthority.localDefault);
      expect(state.isPurchasable, isFalse);
      expect(state.canRestorePurchases, isFalse);
      expect(
        state.entitlements,
        containsAll(<CommerceEntitlement>{
          CommerceEntitlement.localTracking,
          CommerceEntitlement.nutritionFoundation,
          CommerceEntitlement.explainableNutrition,
          CommerceEntitlement.localAnalytics,
          CommerceEntitlement.dataExport,
          CommerceEntitlement.cloudSync,
        }),
      );
    });

    test('does not grant future paid or organization capabilities', () {
      final state = FreePlan.createState();

      expect(state.grants(CommerceEntitlement.advancedIntelligence), isFalse);
      expect(state.grants(CommerceEntitlement.cloudSync), isTrue);
      expect(state.grants(CommerceEntitlement.coachWorkspace), isFalse);
      expect(state.grants(CommerceEntitlement.clinicWorkspace), isFalse);
      expect(
        state.grants(CommerceEntitlement.enterpriseAdministration),
        isFalse,
      );
    });

    test('returns an immutable entitlement snapshot', () {
      final state = FreePlan.createState();

      expect(
        () => state.entitlements.add(CommerceEntitlement.cloudSync),
        throwsUnsupportedError,
      );
    });
  });
}
