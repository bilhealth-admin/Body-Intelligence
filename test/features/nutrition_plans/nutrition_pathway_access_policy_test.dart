import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/nutrition_plans/domain/nutrition_pathway_access_policy.dart';
import 'package:body_intelligence_log/features/nutrition_plans/presentation/nutrition_pathway_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 16);

void main() {
  test(
    'lookup accepts canonical IDs only and never normalizes unknown input',
    () {
      expect(nutritionPathwayForExactId('carb-cycling')?.id, 'carb-cycling');
      expect(nutritionPathwayForExactId(' carb-cycling'), isNull);
      expect(nutritionPathwayForExactId('CARB-CYCLING'), isNull);
      expect(nutritionPathwayForExactId('unknown'), isNull);
    },
  );

  test('free access is unconditional but Premium is server-grant based', () {
    final freePathway = nutritionPathwayForExactId('carb-cycling')!;
    final premiumPathway = nutritionPathwayForExactId('high-protein')!;

    expect(nutritionPathwayAccessGranted(freePathway, null), isTrue);
    expect(
      nutritionPathwayAccessGranted(
        premiumPathway,
        _state(
          authority: EntitlementAuthority.localDefault,
          entitlements: const {CommerceEntitlement.premiumPrograms},
        ),
      ),
      isFalse,
    );
    expect(
      nutritionPathwayAccessGranted(
        premiumPathway,
        _state(authority: EntitlementAuthority.verifiedServer),
      ),
      isFalse,
    );
    expect(
      nutritionPathwayAccessGranted(
        premiumPathway,
        _state(
          authority: EntitlementAuthority.verifiedServer,
          entitlements: const {CommerceEntitlement.premiumPrograms},
        ),
      ),
      isTrue,
    );
  });

  testWidgets('free deep link opens without consulting commerce', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NutritionPathwayAccessGate(
          pathwayId: 'carb-cycling',
          child: Scaffold(body: Text('free editor')),
        ),
      ),
    );

    expect(find.text('free editor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-glass-veil')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'paid deep link stays locked without a verified period boundary',
    (tester) async {
      await tester.pumpWidget(
        _premiumApp(
          state: _state(
            authority: EntitlementAuthority.verifiedServer,
            entitlements: const {CommerceEntitlement.premiumPrograms},
            hasPeriodBoundary: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('premium-route-protected-content')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Premium deep link keeps preview under glass for Free', (
    tester,
  ) async {
    await tester.pumpWidget(
      _premiumApp(
        state: _state(authority: EntitlementAuthority.verifiedServer),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('premium editor preview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-glass-veil')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-route-protected-content')),
      findsOneWidget,
    );
  });

  testWidgets('verified premiumPrograms removes deep-link glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      _premiumApp(
        state: _state(
          authority: EntitlementAuthority.verifiedServer,
          entitlements: const {CommerceEntitlement.premiumPrograms},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('premium editor preview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-glass-veil')),
      findsNothing,
    );
  });
}

Widget _premiumApp({required SubscriptionState state}) => ProviderScope(
  overrides: [
    verifiedEntitlementClockProvider.overrideWithValue(() => _now),
    verifiedSubscriptionStateProvider.overrideWith((_) async => state),
    storefrontTargetPlanProvider.overrideWith(
      (_) async => CommercePlan.premium,
    ),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: NutritionPathwayAccessGate(
      pathwayId: 'high-protein',
      child: Scaffold(body: Text('premium editor preview')),
    ),
  ),
);

SubscriptionState _state({
  required EntitlementAuthority authority,
  Set<CommerceEntitlement> entitlements = const <CommerceEntitlement>{},
  bool hasPeriodBoundary = true,
}) => SubscriptionState(
  plan:
      authority == EntitlementAuthority.verifiedServer &&
          entitlements.contains(CommerceEntitlement.premiumPrograms)
      ? CommercePlan.premium
      : CommercePlan.free,
  entitlements: entitlements,
  authority: authority,
  lifecycle: SubscriptionLifecycle.active,
  currentPeriodEndsAt: hasPeriodBoundary
      ? _now.add(const Duration(days: 1))
      : null,
  isPurchasable: false,
  canRestorePurchases: false,
);
