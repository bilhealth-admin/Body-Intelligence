import 'dart:async';

import 'package:body_intelligence_log/shared/widgets/bil_compact_activity_indicator.dart';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _now = DateTime.utc(2026, 11, 6);

SubscriptionState _verified(CommercePlan plan) =>
    const EntitlementResolver().resolve(
      record: SubscriptionRecord(
        plan: plan,
        lifecycle: SubscriptionLifecycle.active,
        authorityVerified: true,
        // Server-issued review grants have no purchased store provider.
        provider: null,
        startedAt: _now.subtract(const Duration(days: 1)),
        currentPeriodEndsAt: _now.add(const Duration(days: 1)),
      ),
      now: _now,
    );

ProviderContainer _container(Future<SubscriptionState> Function() load) =>
    ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        verifiedEntitlementOwnerIdProvider.overrideWithValue('fixture-owner'),
        verifiedEntitlementClockProvider.overrideWithValue(() => _now),
        verifiedEntitlementLoaderProvider.overrideWithValue(load),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  _Catalog catalog, {
  String? focus,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: BilStorePlansPage(
          catalog: catalog,
          connectToDeviceStore: false,
          productIds: catalog.offers.map((offer) => offer.productId).toSet(),
          initialFocus: focus,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _disposeFixture(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Dispose inside the widget test's fake clock, before its timer invariants.
  // addTearDown remains an idempotent safety net if an assertion fails early.
  container.dispose();
  await tester.pump();
}

void main() {
  testWidgets('ready store cannot label unresolved account Free or sell again', (
    tester,
  ) async {
    final authority = Completer<SubscriptionState>();
    final container = _container(() => authority.future);
    final catalog = _Catalog(const [_aiAnnual]);
    addTearDown(container.dispose);
    await _pump(tester, container, catalog);
    expect(find.text('Checking subscription'), findsNothing);
    expect(find.byType(BilCompactActivityIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.text('Current plan'), findsNothing);
    expect(find.byKey(const Key('store-current-plan-status')), findsNothing);
    expect(find.byKey(const Key('store-purchase-cta')), findsNothing);
    // Even a queued callback from an older rendered offer must recheck access.
    tester
        .widget<BilDynamicStoreOffers>(find.byType(BilDynamicStoreOffers))
        .onPurchaseRequested(_aiAnnual);
    await tester.pump();
    expect(catalog.requested, isEmpty);

    authority.complete(_verified(CommercePlan.premiumAiCoach));
    await tester.pumpAndSettle();
    expect(find.text('Current plan: Premium AI Coach'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.byKey(const Key('store-purchase-cta')), findsNothing);
    expect(
      find.byKey(const Key('store-current-plan-continue')),
      findsOneWidget,
    );
    expect(catalog.requested, isEmpty);
    await _disposeFixture(tester, container);
  });

  testWidgets(
    'server-issued paid access continues into the app without purchase',
    (tester) async {
      final container = _container(
        () async => _verified(CommercePlan.premiumAiCoach),
      );
      final catalog = _Catalog(const [_aiAnnual]);
      final router = GoRouter(
        initialLocation: '/plans',
        routes: [
          GoRoute(
            path: '/plans',
            builder: (_, _) => BilStorePlansPage(
              catalog: catalog,
              connectToDeviceStore: false,
              productIds: const {'ai.annual'},
            ),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const Scaffold(body: Text('Dashboard fixture')),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        router.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('store-current-plan-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard fixture'), findsOneWidget);
      expect(catalog.requested, isEmpty);
      await _disposeFixture(tester, container);
    },
  );

  testWidgets(
    'current grant stays usable when Play has no purchasable catalog',
    (tester) async {
      final container = _container(
        () async => _verified(CommercePlan.premiumAiCoach),
      );
      final catalog = _Catalog(const []);
      addTearDown(container.dispose);
      await _pump(tester, container, catalog);
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);
      expect(
        find.byKey(const Key('store-current-plan-continue')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('store-purchase-cta')), findsNothing);
      expect(catalog.requested, isEmpty);
      await _disposeFixture(tester, container);
    },
  );

  for (final fails in [false, true]) {
    testWidgets('unverified access is retryable, never Free; error=$fails', (
      tester,
    ) async {
      var retried = false;
      final container = _container(() async {
        if (retried) return _verified(CommercePlan.free);
        if (fails) throw StateError('synthetic authority outage');
        return FreePlan.createState();
      });
      final catalog = _Catalog(const [_aiAnnual]);
      addTearDown(container.dispose);
      await _pump(tester, container, catalog);
      await tester.pumpAndSettle();
      expect(find.text('Subscription check unavailable'), findsOneWidget);
      expect(find.text('Current plan'), findsNothing);
      expect(find.byKey(const Key('store-purchase-cta')), findsNothing);
      expect(catalog.requested, isEmpty);
      retried = true;
      await tester.tap(find.byKey(const Key('store-account-access-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('store-account-access-status')),
        findsNothing,
      );
      expect(find.text('Current plan'), findsOneWidget);
      final checkout = find.byKey(const Key('store-purchase-cta'));
      expect(tester.widget<InkWell>(checkout).onTap, isNotNull);
      await tester.tap(checkout);
      await tester.pumpAndSettle();
      expect(catalog.requested, [_aiAnnual]);
      await _disposeFixture(tester, container);
    });
  }

  testWidgets('a completed offline reread preserves the visible CTA without selling', (tester) async {
    var state = _verified(CommercePlan.free);
    final container = _container(() async => state);
    final catalog = _Catalog(const [_aiAnnual]);
    final cta = find.byKey(const Key('store-purchase-cta'));
    try {
      await _pump(tester, container, catalog);
      await tester.pumpAndSettle();
      final before = tester.element(cta);
      state = FreePlan.createState();
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pumpAndSettle();
      expect(tester.element(cta), same(before));
      await tester.tap(cta);
      await tester.pump();
      expect(catalog.requested, isEmpty);
      expect(find.text('Subscription check unavailable'), findsOneWidget);
      state = _verified(CommercePlan.free);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(catalog.requested, [_aiAnnual]);
    } finally {
      await _disposeFixture(tester, container);
    }
  });

  testWidgets('a held reread leaves an active member header untouched', (tester) async {
    final held = Completer<SubscriptionState>();
    var reads = 0;
    final paid = _verified(CommercePlan.premiumAiCoach);
    final container = _container(() => ++reads == 1 ? Future.value(paid) : held.future);
    final catalog = _Catalog(const [_aiAnnual]);
    try {
      await _pump(tester, container, catalog);
      await tester.pumpAndSettle();
      final header = find.byKey(const Key('store-current-plan-continue'));
      final before = tester.element(header);
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(tester.element(header), same(before));
      expect(find.byKey(const Key('store-slow-access-retry')), findsNothing);
      expect(find.text('Subscription check unavailable'), findsNothing);
      expect(find.byKey(const Key('store-purchase-cta')), findsNothing);
      expect(catalog.requested, isEmpty);
    } finally {
      if (!held.isCompleted) held.complete(paid);
      await _disposeFixture(tester, container);
    }
  });

  testWidgets('a stalled background read offers one explicit recheck without selling', (tester) async {
    final held = Completer<SubscriptionState>();
    final recovery = Completer<SubscriptionState>();
    var reads = 0;
    final container = _container(() {
      reads++;
      return switch (reads) {
        1 => Future.value(_verified(CommercePlan.free)),
        2 => held.future,
        _ => recovery.future,
      };
    });
    final catalog = _Catalog(const [_aiAnnual]);
    final cta = find.byKey(const Key('store-purchase-cta'));
    final retry = find.byKey(const Key('store-slow-access-retry'));
    try {
      await _pump(tester, container, catalog);
      await tester.pumpAndSettle();
      container.invalidate(verifiedSubscriptionStateProvider);
      await tester.pump();
      await tester.pump(const Duration(seconds: 29));
      expect(retry, findsNothing);
      expect(reads, 2);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(retry, findsOneWidget);
      expect(cta, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(reads, 3);
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(retry, findsNothing);
      expect(find.text('Subscription check unavailable'), findsOneWidget);
      expect(reads, 3);
      expect(catalog.requested, isEmpty);
      recovery.complete(_verified(CommercePlan.premiumAiCoach));
      await tester.pumpAndSettle();
      held.complete(_verified(CommercePlan.free));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store-current-plan-continue')), findsOneWidget);
      expect(cta, findsNothing);
      expect(catalog.requested, isEmpty);
    } finally {
      if (!held.isCompleted) held.complete(FreePlan.createState());
      if (!recovery.isCompleted) recovery.complete(FreePlan.createState());
      await _disposeFixture(tester, container);
    }
  });

  testWidgets('queued Free checkout cannot purchase an already verified tier', (
    tester,
  ) async {
    var plan = CommercePlan.free;
    final container = _container(() async => _verified(plan));
    final catalog = _Catalog(const [_aiAnnual]);
    addTearDown(container.dispose);
    await _pump(tester, container, catalog);
    await tester.pumpAndSettle();
    final queued = tester
        .widget<BilDynamicStoreOffers>(find.byType(BilDynamicStoreOffers))
        .onPurchaseRequested;
    plan = CommercePlan.premiumAiCoach;
    container.invalidate(verifiedSubscriptionStateProvider);
    await tester.pumpAndSettle();
    queued(_aiAnnual);
    await tester.pumpAndSettle();
    expect(catalog.requested, isEmpty);
    expect(find.byKey(const Key('store-purchase-cta')), findsNothing);
    await _disposeFixture(tester, container);
  });

  for (final plan in [CommercePlan.premium, CommercePlan.premiumAiCoach]) {
    testWidgets('different-tier store changes remain available for $plan', (
      tester,
    ) async {
      final container = _container(() async => _verified(plan));
      final offer = plan == CommercePlan.premium ? _aiAnnual : _premiumMonthly;
      final catalog = _Catalog([offer]);
      addTearDown(container.dispose);
      await _pump(tester, container, catalog);
      await tester.pumpAndSettle();
      final checkout = find.byKey(const Key('store-purchase-cta'));
      expect(tester.widget<InkWell>(checkout).onTap, isNotNull);
      await tester.tap(checkout);
      await tester.pumpAndSettle();
      expect(catalog.requested, [offer]);
      await _disposeFixture(tester, container);
    });
  }

  for (final verified in [false, true]) {
    testWidgets(
      'Boost checkout stays independent of membership; known=$verified',
      (tester) async {
        final container = _container(
          () async => verified
              ? _verified(CommercePlan.premiumAiCoach)
              : FreePlan.createState(),
        );
        final catalog = _Catalog(const [_aiAnnual, _boost]);
        addTearDown(container.dispose);
        await _pump(tester, container, catalog, focus: 'boost');
        await tester.pumpAndSettle();
        final checkout = find.byKey(const Key('store-purchase-cta'));
        expect(tester.widget<InkWell>(checkout).onTap, isNotNull);
        await tester.tap(checkout);
        await tester.pumpAndSettle();
        expect(catalog.requested, [_boost]);
        await _disposeFixture(tester, container);
      },
    );
  }
}

const _aiAnnual = BilStoreOfferMetadata(
  productId: 'ai.annual',
  kind: BilStoreProductKind.premiumAiCoachSubscription,
  localizedTitle: 'Annual',
  localizedPrice: '£54.99',
  currencyCode: 'GBP',
  priceMicros: 54990000,
  billingPeriodIso8601: 'P1Y',
);

const _premiumMonthly = BilStoreOfferMetadata(
  productId: 'premium.monthly',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Monthly',
  localizedPrice: '£4.99',
  currencyCode: 'GBP',
  priceMicros: 4990000,
  billingPeriodIso8601: 'P1M',
);

const _boost = BilStoreOfferMetadata(
  productId: 'ai.boost',
  kind: BilStoreProductKind.aiBoostConsumable,
  localizedTitle: 'AI Boost',
  localizedPrice: '£2.49',
  currencyCode: 'GBP',
  priceMicros: 2490000,
);

final class _Catalog implements BilStoreCatalogGateway {
  _Catalog(this.offers);

  final List<BilStoreOfferMetadata> offers;
  final List<BilStoreOfferMetadata> requested = [];

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => offers;

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    requested.add(offer);
  }

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> restorePurchases() async {}
}
