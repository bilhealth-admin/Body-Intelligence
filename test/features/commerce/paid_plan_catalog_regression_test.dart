import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_entitlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paid catalog metadata does not activate paid runtime access', () {
    final localState = const LocalEntitlementRepository().current();
    final proCatalog = PaidPlanCatalog.composedEntitlementsFor(
      CommercePlan.pro,
    );

    expect(proCatalog, contains(CommerceEntitlement.advancedIntelligence));
    expect(localState.plan, CommercePlan.free);
    expect(localState.authority, EntitlementAuthority.localDefault);
    expect(
      localState.grants(CommerceEntitlement.advancedIntelligence),
      isFalse,
    );
  });

  test('all paid plans retain the complete Free foundation', () {
    for (final plan in CommercePlan.values.where(
      (plan) => plan != CommercePlan.free,
    )) {
      expect(
        PaidPlanCatalog.composedEntitlementsFor(plan),
        containsAll(FreePlan.entitlements),
        reason: '${plan.id} must not regress Free-plan capabilities',
      );
    }
  });

  test('catalog entries are immutable', () {
    final entry = PaidPlanCatalog.entryFor(CommercePlan.enterprise);

    expect(
      () => entry.parentPlans.add(CommercePlan.free),
      throwsUnsupportedError,
    );
    expect(
      () => entry.addedEntitlements.add(CommerceEntitlement.cloudSync),
      throwsUnsupportedError,
    );
  });
}
