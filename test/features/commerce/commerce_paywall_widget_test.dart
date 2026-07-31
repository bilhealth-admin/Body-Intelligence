import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/presentation/commerce_paywall.dart';
import 'package:body_intelligence_log/features/commerce/presentation/paywall_plan_view_model.dart';
import 'package:body_intelligence_log/features/commerce/presentation/paywall_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders deterministic plan cards and emits selection', (
    tester,
  ) async {
    String? selected;
    final state = PaywallState(
      plans: [
        PaywallPlanViewModel(
          plan: CommercePlan.plus,
          title: 'Plus',
          subtitle: 'Everyday intelligence',
          priceLabel: r'$4.99',
          billingPeriodLabel: 'per month',
          highlights: const ['Advanced insights'],
          isCurrent: false,
          isRecommended: true,
          isEligible: true,
        ),
      ],
      isRestoring: false,
      isPurchasing: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CommercePaywall(
          state: state,
          onPlanSelected: (value) => selected = value,
          onContinue: () {},
          onRestore: () {},
        ),
      ),
    );

    expect(find.text('Plus'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    await tester.tap(find.text('Plus'));
    expect(selected, 'plus');
  });

  testWidgets('disables continue when no plan is selected', (tester) async {
    final state = PaywallState(
      plans: const [],
      isRestoring: false,
      isPurchasing: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommercePaywall(
          state: state,
          onPlanSelected: (_) {},
          onContinue: () {},
          onRestore: () {},
        ),
      ),
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(button.onPressed, isNull);
  });
}
