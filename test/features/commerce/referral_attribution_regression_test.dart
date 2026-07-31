import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_entitlement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('referral package preserves locked commerce foundations', () {
    expect(FreePlan.createState().plan.name, 'free');
    expect(PaidPlanCatalog.entries, isNotEmpty);
    expect(LocalEntitlementRepository, isNotNull);
  });
}
