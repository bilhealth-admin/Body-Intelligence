import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/paywall_controller.dart';
import 'package:body_intelligence_log/features/commerce/presentation/paywall_plan_view_model.dart';
import 'package:body_intelligence_log/features/commerce/presentation/paywall_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaywallPlanViewModel plan(
    CommercePlan value, {
    bool eligible = true,
    bool current = false,
  }) => PaywallPlanViewModel(
    plan: value,
    title: value.name,
    subtitle: 'Plan description',
    priceLabel: r'$9.99',
    billingPeriodLabel: 'per month',
    highlights: const ['Feature'],
    isCurrent: current,
    isRecommended: value == CommercePlan.pro,
    isEligible: eligible,
    ineligibilityReason: eligible ? null : 'Unavailable in this country',
  );

  test('selects only eligible non-current plans', () {
    final controller = PaywallController(
      initialState: PaywallState(
        plans: [
          plan(CommercePlan.free, current: true),
          plan(CommercePlan.plus),
          plan(CommercePlan.pro, eligible: false),
        ],
        isRestoring: false,
        isPurchasing: false,
      ),
    );

    expect(controller.select('free'), isNull);
    expect(controller.select('pro'), isNull);
    expect(controller.select('plus')?.plan, CommercePlan.plus);
    expect(controller.state.selectedPlanId, 'plus');
  });

  test('purchase and restore states cannot overlap', () {
    final controller = PaywallController(
      initialState: PaywallState(
        plans: [plan(CommercePlan.plus)],
        isRestoring: false,
        isPurchasing: false,
      ),
    );

    controller.select('plus');
    controller.beginPurchase();
    expect(controller.state.isPurchasing, isTrue);
    controller.beginRestore();
    expect(controller.state.isRestoring, isFalse);
    controller.complete(message: 'Done');
    controller.beginRestore();
    expect(controller.state.isRestoring, isTrue);
  });
}
