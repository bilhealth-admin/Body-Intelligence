import 'dart:async';
import 'dart:io';

import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan route is fail-closed when owner store IDs are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: BilStorePlansPage(connectToDeviceStore: false)),
    );
    await tester.pump();

    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Premium AI Coach'), findsNothing);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Price unavailable on this device'), findsNWidgets(2));
    expect(find.textContaining('Loading price'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan route respects dark interface and 200% text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const BilStorePlansPage(connectToDeviceStore: false),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNot(Colors.white));
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('legacy glass paywall is not imported by the production plan route', () {
    final routeSource = File(
      'lib/features/commerce/presentation/bil_store_plans_page.dart',
    ).readAsStringSync();
    expect(routeSource, isNot(contains('glass_store_offer.dart')));
    expect(routeSource, contains('BilDynamicStoreOffers'));
  });

  testWidgets('unavailable price is tappable and reloads the store catalog', (
    tester,
  ) async {
    final catalog = _SequencedCatalog([
      const [],
      const [_monthlyOffer],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BilStorePlansPage(
          catalog: catalog,
          productIds: const {'premium.monthly'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(catalog.loadCalls, 1);
    final retry = find.byKey(
      const ValueKey('store-price-retry-premiumSubscription'),
    );
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(catalog.loadCalls, 2);
    expect(find.text('EGP 129.99'), findsWidgets);
    expect(retry, findsNothing);
  });

  testWidgets('empty catalog reloads after returning to the foreground', (
    tester,
  ) async {
    final catalog = _SequencedCatalog([
      const [],
      const [_monthlyOffer],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BilStorePlansPage(
          catalog: catalog,
          productIds: const {'premium.monthly'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(catalog.loadCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(catalog.loadCalls, 2);
    expect(find.text('EGP 129.99'), findsWidgets);
  });

  testWidgets('malformed catalog remains reloadable after app resume', (
    tester,
  ) async {
    const malformed = BilStoreOfferMetadata(
      productId: 'premium.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: '',
      currencyCode: 'EGP',
      priceMicros: 129990000,
      billingPeriodIso8601: 'P1M',
    );
    final catalog = _SequencedCatalog([
      const [malformed],
      const [_monthlyOffer],
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: BilStorePlansPage(
          catalog: catalog,
          productIds: const {'premium.monthly'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Price unavailable on this device'), findsNWidgets(2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(catalog.loadCalls, 2);
    expect(find.text('EGP 129.99'), findsWidgets);
  });

  testWidgets('resume does not duplicate an in-flight store query', (
    tester,
  ) async {
    final catalog = _DeferredCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: BilStorePlansPage(
          catalog: catalog,
          productIds: const {'premium.monthly'},
        ),
      ),
    );
    await tester.pump();
    expect(catalog.loadCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(catalog.loadCalls, 1);
    catalog.complete(const [_monthlyOffer]);
    await tester.pumpAndSettle();
    expect(find.text('EGP 129.99'), findsWidgets);
  });

  testWidgets('Continue dispatches exactly one selected store offer', (
    tester,
  ) async {
    final catalog = _DeferredPurchaseCatalog();
    await tester.pumpWidget(
      MaterialApp(
        home: BilStorePlansPage(
          catalog: catalog,
          productIds: const {'premium.monthly'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.byKey(const ValueKey('store-purchase-cta'));
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await tester.pump();

    expect(catalog.requested, <BilStoreOfferMetadata>[_monthlyOffer]);
    expect(find.text('Opening secure purchase…'), findsOneWidget);
    expect(tester.widget<InkWell>(cta).onTap, isNull);

    catalog.completePurchase();
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(cta).onTap, isNotNull);
  });

  testWidgets(
    'a cancelled native sheet clears feedback and permits a lower term',
    (tester) async {
      final store = _CancellationReadyStore();
      final catalog = _RecordingCatalog(const [_monthlyOffer, _annualOffer]);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BilStorePlansPage(
            store: store,
            catalog: catalog,
            productIds: const {'premium.monthly', 'premium.annual'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      store.reportCancelled();
      await tester.pump();

      final cta = find.byKey(const ValueKey('store-purchase-cta'));
      expect(find.byKey(const ValueKey('store-purchase-status')), findsNothing);
      expect(tester.widget<InkWell>(cta).onTap, isNotNull);

      final monthly = find.byKey(const ValueKey('store-offer-premium.monthly'));
      await tester.ensureVisible(monthly);
      await tester.tap(monthly);
      await tester.pump();
      await tester.tap(cta);
      await tester.pump();

      expect(catalog.requested, <BilStoreOfferMetadata>[_monthlyOffer]);
    },
  );
}

const _monthlyOffer = BilStoreOfferMetadata(
  productId: 'premium.monthly',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Monthly',
  localizedPrice: 'EGP 129.99',
  currencyCode: 'EGP',
  priceMicros: 129990000,
  billingPeriodIso8601: 'P1M',
);

const _annualOffer = BilStoreOfferMetadata(
  productId: 'premium.annual',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Annual',
  localizedPrice: 'EGP 999.99',
  currencyCode: 'EGP',
  priceMicros: 999990000,
  billingPeriodIso8601: 'P1Y',
);

final class _SequencedCatalog implements BilStoreCatalogGateway {
  _SequencedCatalog(this.responses);

  final List<List<BilStoreOfferMetadata>> responses;
  int loadCalls = 0;

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> productIds) async {
    final index = loadCalls < responses.length
        ? loadCalls
        : responses.length - 1;
    loadCalls += 1;
    return responses[index];
  }

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {}

  @override
  Future<void> restorePurchases() async {}
}

final class _DeferredCatalog implements BilStoreCatalogGateway {
  final Completer<List<BilStoreOfferMetadata>> _result = Completer();
  int loadCalls = 0;

  void complete(List<BilStoreOfferMetadata> offers) => _result.complete(offers);

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> productIds) {
    loadCalls += 1;
    return _result.future;
  }

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {}

  @override
  Future<void> restorePurchases() async {}
}

final class _DeferredPurchaseCatalog implements BilStoreCatalogGateway {
  final Completer<void> _purchase = Completer<void>();
  final List<BilStoreOfferMetadata> requested = [];

  void completePurchase() => _purchase.complete();

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => const [_monthlyOffer];

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) {
    requested.add(offer);
    return _purchase.future;
  }

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> restorePurchases() async {}
}

final class _CancellationReadyStore extends VerifiedStorePurchaseService {
  @override
  bool get canStartPurchase => true;

  @override
  bool get busy => false;

  void reportCancelled() {
    state = VerifiedStoreState.cancelled;
    messageCode = 'purchase_cancelled';
    notifyListeners();
  }
}

final class _RecordingCatalog implements BilStoreCatalogGateway {
  _RecordingCatalog(this.offers);

  final List<BilStoreOfferMetadata> offers;
  final List<BilStoreOfferMetadata> requested = [];

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => offers;

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    requested.add(offer);
  }

  @override
  Future<void> restorePurchases() async {}
}
