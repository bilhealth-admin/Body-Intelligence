import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_nutrition_glass.dart';
import 'package:body_intelligence_log/features/commerce/presentation/premium_label_badge.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'group gold action requires current verified denial, not stale data',
    (tester) async {
      var lookup = Future<SubscriptionState>.value(_state(CommercePlan.free));
      final container = ProviderContainer(
        overrides: [
          verifiedSubscriptionStateProvider.overrideWith((_) => lookup),
          // Exercise retained AsyncValue from Riverpod's real refresh, rather
          // than constructing internal copyWithPrevious test objects.
          verifiedSubscriptionAccessProvider.overrideWith(
            (ref) => ref.watch(verifiedSubscriptionStateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: PremiumNutritionFieldsGroup(child: SizedBox(height: 80)),
            ),
          ),
          GoRoute(
            path: '/plans',
            builder: (_, _) => const Scaffold(body: Text('plans destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PremiumLabelBadge), findsOneWidget);
      final pending = Completer<SubscriptionState>();
      lookup = pending.future;
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      final refreshing = container.read(verifiedSubscriptionStateProvider);
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.hasValue, isTrue);
      expect(find.byType(PremiumLabelBadge), findsNothing);
      final observed = container
          .read(verifiedSubscriptionStateProvider.future)
          .then<Object?>((_) => null, onError: (Object error) => error);
      pending.completeError(StateError('offline'));
      expect(await observed, isA<StateError>());
      await tester.pumpAndSettle();
      final failed = container.read(verifiedSubscriptionStateProvider);
      expect(failed.hasError, isTrue);
      expect(failed.hasValue, isTrue);
      expect(find.byType(PremiumLabelBadge), findsNothing);
      lookup = Future.value(_state(CommercePlan.free));
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumLabelBadge), findsOneWidget);
      await tester.tap(find.byType(PremiumLabelBadge));
      await tester.pumpAndSettle();
      expect(find.text('plans destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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

  for (final plan in [CommercePlan.premium, CommercePlan.premiumAiCoach]) {
    testWidgets('only server-verified ${plan.id} removes the glass', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(_state(plan)));
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
  }

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
    'subscription error stays protected with retry and no false Premium offer',
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
      expect(
        find.bySemanticsLabel('Subscription check unavailable'),
        findsOneWidget,
      );
    },
  );

  testWidgets('local Free fallback requires retry, never a paid upsell', (
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
    entitlements:
        const {CommercePlan.premium, CommercePlan.premiumAiCoach}.contains(plan)
        ? const {CommerceEntitlement.advancedIntelligence}
        : const <CommerceEntitlement>{},
    authority: EntitlementAuthority.verifiedServer,
    currentPeriodEndsAt: DateTime.utc(2099),
    isPurchasable: true,
    canRestorePurchases: true,
  );
}
