import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_nutrition_glass.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('verified Free hides nutrition semantics and routes to plans', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_state(CommercePlan.free)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premium-nutrition-glass')), findsOneWidget);
    expect(find.bySemanticsLabel('private macro values'), findsNothing);

    await tester.tap(find.byKey(const Key('premium-nutrition-glass')));
    await tester.pumpAndSettle();
    expect(find.text('plans destination'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('only server-verified Premium removes the glass', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_state(CommercePlan.premium)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('premium-nutrition-glass')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'private macro values',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('subscription loading never flashes an upgrade action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_appWithSubscription(const AsyncLoading()));
    await tester.pump();

    expect(find.byKey(const Key('premium-nutrition-checking')), findsOneWidget);
    expect(find.byKey(const Key('premium-nutrition-glass')), findsNothing);
    expect(find.text('Premium'), findsNothing);
    expect(find.bySemanticsLabel('private macro values'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'subscription error stays protected and offers retry, not upsell',
    (tester) async {
      await tester.pumpWidget(
        _appWithSubscription(
          AsyncError<SubscriptionState>(
            StateError('verification unavailable'),
            StackTrace.empty,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('premium-nutrition-entitlement-retry')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('premium-nutrition-glass')), findsNothing);
      expect(find.text('Premium'), findsNothing);
    },
  );

  testWidgets('unverified local default never impersonates verified Free', (
    tester,
  ) async {
    final localDefault = SubscriptionState(
      plan: CommercePlan.free,
      entitlements: const <CommerceEntitlement>{},
      authority: EntitlementAuthority.localDefault,
      isPurchasable: false,
      canRestorePurchases: false,
    );
    await tester.pumpWidget(_app(localDefault));
    await tester.pump();

    expect(
      find.byKey(const Key('premium-nutrition-entitlement-retry')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('premium-nutrition-glass')), findsNothing);
    expect(find.text('Premium'), findsNothing);
  });
}

Widget _app(SubscriptionState state) => _appWithSubscription(AsyncData(state));

Widget _appWithSubscription(AsyncValue<SubscriptionState> subscription) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: PremiumNutritionGlass(
            child: Semantics(
              label: 'private macro values',
              child: Text('Protein 24 g'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/plans',
        builder: (_, _) => const Scaffold(body: Text('plans destination')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      verifiedSubscriptionStateProvider.overrideWithValue(subscription),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

SubscriptionState _state(CommercePlan plan) {
  return SubscriptionState(
    plan: plan,
    entitlements: plan == CommercePlan.premium
        ? const {CommerceEntitlement.advancedIntelligence}
        : const <CommerceEntitlement>{},
    authority: EntitlementAuthority.verifiedServer,
    isPurchasable: true,
    canRestorePurchases: true,
  );
}
