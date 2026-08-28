import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_route_glass_gate.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGate(
    WidgetTester tester, {
    required CommercePlan storefrontPlan,
    Locale locale = const Locale('en'),
    bool creditAccess = false,
    CommercePlan subscriptionPlan = CommercePlan.free,
    PremiumGateFeature feature = PremiumGateFeature.aiCoach,
    Widget? child,
  }) async {
    final subscriptionState = subscriptionPlan == CommercePlan.free
        ? FreePlan.createState()
        : SubscriptionState(
            plan: subscriptionPlan,
            entitlements: const {},
            authority: EntitlementAuthority.verifiedServer,
            isPurchasable: true,
            canRestorePurchases: true,
          );
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey('gate-${storefrontPlan.name}-${feature.name}'),
        overrides: [
          verifiedSubscriptionStateProvider.overrideWith(
            (_) async => subscriptionState,
          ),
          storefrontTargetPlanProvider.overrideWith(
            (_) async => storefrontPlan,
          ),
          aiCoachCreditAccessProvider.overrideWith((_) async => creditAccess),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumRouteGlassGate(
            feature: feature,
            child:
                child ??
                const ColoredBox(
                  key: ValueKey('unlocked-ai-coach'),
                  color: Colors.white,
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('profitable storefront lock offers only AI Boost', (
    tester,
  ) async {
    await pumpGate(tester, storefrontPlan: CommercePlan.premiumAiCoach);

    expect(find.text('Get AI Boost'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.textContaining('non-expiring'), findsWidgets);
  });

  testWidgets('token storefront shows the same Boost-only lock', (
    tester,
  ) async {
    await pumpGate(tester, storefrontPlan: CommercePlan.premium);

    expect(find.text('Get AI Boost'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Ready · speak any language'), findsOneWidget);
  });

  testWidgets('glass names the subscription family returned by the store', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.weeklyReport,
    );
    expect(find.text('BIL PREMIUM AI COACH'), findsOneWidget);

    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.weeklyReport,
    );
    expect(find.text('BIL PREMIUM'), findsOneWidget);
    expect(find.text('BIL PREMIUM AI COACH'), findsNothing);
  });

  testWidgets('Arabic AI gate has no English fallback', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      locale: const Locale('ar'),
    );

    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Get AI Boost'), findsNothing);
    expect(
      find.text(RuntimeCopy.resolve('Get AI Boost', 'ar')!),
      findsOneWidget,
    );
  });

  testWidgets('regular Premium does not unlock AI Coach', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      subscriptionPlan: CommercePlan.premium,
    );

    expect(find.text('Get AI Boost'), findsOneWidget);
  });

  testWidgets('Free previews community behind glass', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.community,
      child: const ColoredBox(
        key: ValueKey('community-preview-content'),
        color: Color(0xFFE9FAFF),
      ),
    );

    expect(
      find.byKey(const ValueKey('community-preview-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-route-glass-blur')),
      findsOneWidget,
    );
    expect(find.text('Friends and requests'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
  });

  testWidgets('Premium AI Coach inherits and opens community', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      subscriptionPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.community,
      child: const ColoredBox(
        key: ValueKey('community-preview-content'),
        color: Color(0xFFE9FAFF),
      ),
    );

    expect(
      find.byKey(const ValueKey('community-preview-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('premium-route-glass-blur')),
      findsNothing,
    );
  });

  testWidgets('Premium AI Coach subscription unlocks AI Coach', (tester) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      subscriptionPlan: CommercePlan.premiumAiCoach,
    );

    expect(find.byKey(const ValueKey('unlocked-ai-coach')), findsOneWidget);
    expect(find.text('Get AI Boost'), findsNothing);
  });

  testWidgets('server AI grant opens coach in profitable storefront', (
    tester,
  ) async {
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      creditAccess: true,
    );

    expect(find.byKey(const ValueKey('unlocked-ai-coach')), findsOneWidget);
    expect(find.text('Get AI Boost'), findsNothing);
  });

  testWidgets('locked route stays built and painted but cannot be used', (
    tester,
  ) async {
    var protectedTaps = 0;
    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premium,
      feature: PremiumGateFeature.weeklyReport,
      child: Scaffold(
        body: Center(
          child: FilledButton(
            key: const ValueKey('protected-action'),
            onPressed: () => protectedTaps += 1,
            child: const Text('PROTECTED DASHBOARD ACTION'),
          ),
        ),
      ),
    );

    expect(find.text('PROTECTED DASHBOARD ACTION'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('premium-route-glass-blur')),
      findsOneWidget,
    );
    expect(find.byType(Opacity), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('protected-action')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(protectedTaps, 0);
  });

  testWidgets('premium route glass visual proof', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpGate(
      tester,
      storefrontPlan: CommercePlan.premiumAiCoach,
      feature: PremiumGateFeature.weeklyReport,
      child: const _PremiumGlassFixture(),
    );

    await expectLater(
      find.byType(PremiumRouteGlassGate),
      matchesGoldenFile('goldens/premium_route_glass_gate.png'),
    );
  });
}

class _PremiumGlassFixture extends StatelessWidget {
  const _PremiumGlassFixture();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly report')),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9FAFF), Color(0xFFF8E9FF), Color(0xFFFFF4D6)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'YOUR ORIGINAL REPORT',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          for (final item in const [
            ('Calories', '1,840 kcal', Color(0xFF18A9D5)),
            ('Protein', '126 g', Color(0xFF8A5CE6)),
            ('Progress', '+ 4.8%', Color(0xFFE8A31A)),
          ])
            Card(
              color: item.$3,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
