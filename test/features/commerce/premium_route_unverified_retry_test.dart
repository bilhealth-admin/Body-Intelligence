import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Premium AI Coach grants every paid shared route without Plans', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final paid = SubscriptionState(
      plan: CommercePlan.premiumAiCoach,
      entitlements: PaidPlanCatalog.composedEntitlementsFor(
        CommercePlan.premiumAiCoach,
      ),
      authority: EntitlementAuthority.verifiedServer,
      startedAt: now.subtract(const Duration(minutes: 1)),
      currentPeriodEndsAt: now.add(const Duration(minutes: 5)),
      isPurchasable: false,
      canRestorePurchases: false,
    );
    for (final feature in const [
      PremiumGateFeature.premium,
      PremiumGateFeature.decisionMemory,
      PremiumGateFeature.personalPlan,
      PremiumGateFeature.experiments,
      PremiumGateFeature.bodyMeasurements,
      PremiumGateFeature.nutritionPrograms,
      PremiumGateFeature.weeklyReport,
      PremiumGateFeature.nutritionAnalytics,
      PremiumGateFeature.workoutLibrary,
      PremiumGateFeature.recipeLibrary,
      PremiumGateFeature.recipeImport,
      PremiumGateFeature.mealPlanner,
      PremiumGateFeature.contentPacks,
      PremiumGateFeature.fasting,
      PremiumGateFeature.sleep,
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('paid-${feature.name}'),
          overrides: [
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(paid),
            ),
            storefrontTargetPlanProvider.overrideWith(
              (_) async => CommercePlan.premiumAiCoach,
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
                feature: feature,
                child: const Text(
                  'Reviewer paid feature',
                  key: ValueKey('reviewer-paid-feature-content'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('reviewer-paid-feature-content')),
        findsOneWidget,
        reason: feature.name,
      );
      expect(
        find.byKey(const ValueKey('premium-route-glass-blur')),
        findsNothing,
        reason: feature.name,
      );
      expect(
        find.byKey(const ValueKey('premium-route-access-unavailable')),
        findsNothing,
        reason: feature.name,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final kind in ['unverified', 'verified-free', 'verified-premium']) {
    testWidgets('shared Premium gate distinguishes $kind without leakage', (
      tester,
    ) async {
      var protectedTaps = 0;
      final subscription = switch (kind) {
        'verified-free' => SubscriptionState(
          plan: CommercePlan.free,
          entitlements: FreePlan.entitlements,
          authority: EntitlementAuthority.verifiedServer,
          isPurchasable: false,
          canRestorePurchases: false,
        ),
        'verified-premium' => SubscriptionState(
          plan: CommercePlan.premiumAiCoach,
          entitlements: const {},
          authority: EntitlementAuthority.verifiedServer,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
          currentPeriodEndsAt: DateTime.now().toUtc().add(
            const Duration(minutes: 5),
          ),
          isPurchasable: false,
          canRestorePurchases: false,
        ),
        _ => FreePlan.createState(),
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            verifiedSubscriptionStateProvider.overrideWithValue(
              AsyncData(subscription),
            ),
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
                feature: PremiumGateFeature.weeklyReport,
                child: Center(
                  child: FilledButton(
                    key: const Key('reviewer-protected-action'),
                    onPressed: () => protectedTaps++,
                    child: const Text('Protected report'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-access-unavailable')),
        kind == 'unverified' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('premium-route-glass-blur')),
        kind == 'verified-free' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('premium-route-access-retry')),
        kind == 'unverified' ? findsOneWidget : findsNothing,
      );
      if (kind == 'unverified') {
        expect(find.text('BIL PREMIUM'), findsNothing);
      }
      if (kind == 'verified-premium') {
        await tester.tap(find.byKey(const Key('reviewer-protected-action')));
        expect(protectedTaps, 1);
      } else {
        expect(protectedTaps, 0);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  test('5000 server-owned AI credits allow Coach, zero does not', () {
    Object usage(num total) => {
      'plan': 'ai_coach',
      'credits': {
        'paid_remaining': 2500,
        'included_remaining': 2500,
        'total_remaining': total,
      },
    };
    expect(aiCoachAccessFromUsageStatus(usage(5000)), isTrue);
    expect(aiCoachAccessFromUsageStatus(usage(0)), isFalse);
  });
}
