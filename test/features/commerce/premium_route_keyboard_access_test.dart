import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ['free', 'unavailable', 'paid']) {
    testWidgets('Premium keyboard boundary is enforced for $mode', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 4);
      final node = FocusNode();
      addTearDown(node.dispose);
      var presses = 0;
      final paid = SubscriptionState(
        plan: CommercePlan.premium,
        entitlements: PaidPlanCatalog.composedEntitlementsFor(
          CommercePlan.premium,
        ),
        authority: EntitlementAuthority.verifiedServer,
        startedAt: now.subtract(const Duration(days: 1)),
        currentPeriodEndsAt: now.add(const Duration(days: 30)),
        isPurchasable: true,
        canRestorePurchases: true,
      );
      final AsyncValue<SubscriptionState> state = mode == 'unavailable'
          ? AsyncError(StateError('synthetic lookup failure'), StackTrace.empty)
          : AsyncData(mode == 'paid' ? paid : FreePlan.createState());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedSubscriptionStateProvider.overrideWithValue(state),
            verifiedEntitlementClockProvider.overrideWithValue(() => now),
            storefrontTargetPlanProvider.overrideWith(
              (_) async => CommercePlan.premium,
            ),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: PremiumRouteGlassGate(
                feature: PremiumGateFeature.nutritionAnalytics,
                child: Center(
                  child: FilledButton(
                    key: const Key('protected-premium-action'),
                    focusNode: node,
                    onPressed: () => presses++,
                    child: const Text('Protected Premium action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, mode == 'paid' ? 1 : 0);
      expect(node.canRequestFocus, mode == 'paid');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
