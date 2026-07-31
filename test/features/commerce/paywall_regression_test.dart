import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/paywall_plan_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation remains keyed by stable commerce plan identifiers', () {
    final model = PaywallPlanViewModel(
      plan: CommercePlan.elite,
      title: 'Elite',
      subtitle: 'Description',
      priceLabel: r'$19.99',
      billingPeriodLabel: 'per month',
      highlights: const [],
      isCurrent: false,
      isRecommended: false,
      isEligible: true,
    );
    expect(model.plan.id, 'elite');
    expect(model.canSelect, isTrue);
  });

  test('UI model cannot imply access for current or ineligible plans', () {
    final model = PaywallPlanViewModel(
      plan: CommercePlan.pro,
      title: 'Pro',
      subtitle: 'Description',
      priceLabel: r'$9.99',
      billingPeriodLabel: 'per month',
      highlights: const [],
      isCurrent: true,
      isRecommended: true,
      isEligible: true,
    );
    expect(model.canSelect, isFalse);
  });
}
