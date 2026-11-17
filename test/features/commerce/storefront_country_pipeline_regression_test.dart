import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/commerce/domain/market_offer_policy.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase_storekit/src/sk2_pigeon.g.dart' as sk2;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '00000000-0000-4000-8000-000000000001';
const _b = '00000000-0000-4000-8000-000000000002';

AppStoreProduct2Details _product(String id) =>
    AppStoreProduct2Details.fromSK2Product(
      SK2Product(
        id: id,
        displayName: id,
        description: 'Synthetic catalog fixture',
        displayPrice: 'USD 9.99',
        price: 9.99,
        type: id == StoreCatalogConfiguration.aiBoost
            ? SK2ProductType.consumable
            : SK2ProductType.autoRenewable,
        priceLocale: SK2PriceLocale(currencyCode: 'USD', currencySymbol: r'$'),
        subscription: id == StoreCatalogConfiguration.aiBoost
            ? null
            : SK2SubscriptionInfo(
                subscriptionGroupID: 'synthetic-storefront-group',
                promotionalOffers: const [],
                subscriptionPeriod: SK2SubscriptionPeriod(
                  value: 1,
                  unit: id.endsWith('_annual')
                      ? SK2SubscriptionPeriodUnit.year
                      : SK2SubscriptionPeriodUnit.month,
                ),
              ),
      ),
    );
ProductDetailsResponse _allProducts() => ProductDetailsResponse(
  // Deliberately return every SKU, even when the request subset is smaller.
  // The real service must independently enforce the actual OS storefront.
  productDetails: StoreCatalogConfiguration.storefrontProductIds
      .map(_product)
      .toList(),
  notFoundIDs: const [],
);
Set<String> _ids(Iterable<BilStoreOfferMetadata> offers) =>
    MarketOfferPolicy.visibleOffers(offers).map((o) => o.productId).toSet();
const _ai = {
  StoreCatalogConfiguration.premiumAiCoachMonthly,
  StoreCatalogConfiguration.premiumAiCoachAnnual,
  StoreCatalogConfiguration.aiBoost,
};
const _premium = {
  StoreCatalogConfiguration.premiumMonthly,
  StoreCatalogConfiguration.premiumAnnual,
  StoreCatalogConfiguration.aiBoost,
};

class _Native extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  String country = 'JOR';
  int countryReads = 0, queries = 0, buys = 0;
  bool duplicateFirst = false;
  final queriedIds = <Set<String>>[];
  Future<String> Function(int)? readCountry;
  Future<ProductDetailsResponse> Function()? query;
  @override
  Future<String> countryCode() {
    countryReads++;
    return readCountry?.call(countryReads) ?? Future.value(country);
  }

  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    queries++;
    queriedIds.add(Set.of(ids));
    return query?.call() ?? Future.value(_allProducts());
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys++;
    if (duplicateFirst && buys == 1) {
      country = 'USA';
      throw PlatformException(code: 'storekit_duplicate_product_object');
    }
    return false; // No synthetic receipt, grant, or verification event.
  }
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Native native) : super(purchase: native, handlesBoost: false);
  @override
  bool get configured => true;
}

Future<void> _signIn(String id) =>
    Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-test-token',
        'token_type': 'bearer',
        'user': {
          'id': id,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );

Future<void> _roundTrip(WidgetTester tester) async {
  var previous = _a;
  final delivered = <String?>[];
  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    final id = state.session?.user.id;
    if (id != previous) {
      delivered.add(id);
      previous = id ?? '';
    }
  });
  // Auth persistence is ordinary asynchronous I/O, not a fake-clock task.
  // Run it in the real zone with a bounded deadline, then deliver the actual
  // owner stream in the widget zone before asserting its exact transitions.
  await tester.runAsync(() async {
    await _signIn(_b).timeout(const Duration(seconds: 5));
    await _signIn(_a).timeout(const Duration(seconds: 5));
  });
  await tester.pump();
  await tester.runAsync(() => sub.cancel());
  expect(delivered, [
    _b,
    _a,
  ], reason: 'Actual raw-owner visits must be delivered.');
}

BilStoreOfferMetadata _aiOffer() => const BilStoreOfferMetadata(
  productId: StoreCatalogConfiguration.premiumAiCoachMonthly,
  kind: BilStoreProductKind.premiumAiCoachSubscription,
  localizedTitle: 'AI Coach',
  localizedPrice: 'USD 9.99',
  currencyCode: 'USD',
  priceMicros: 9990000,
  billingPeriodIso8601: 'P1M',
  storeCountryCode: 'JOR',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Native native;
  late _Store store;
  late VerifiedStoreCatalogAdapter adapter;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.unfinishedTransactions',
      sk2.InAppPurchase2API.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          channel,
          (_) async => <Object?>[<Object?>[]],
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, null),
    );
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://storefront-fixture.invalid',
      publishableKey: 'synthetic-test-publishable-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/rest/v1/bil_subscriptions') {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError(
          'Unexpected fixture network path: ${request.url.path}',
        );
      }),
    );
    await _signIn(_a);
    native = _Native();
    store = _Store(native);
    adapter = VerifiedStoreCatalogAdapter(store);
  });
  tearDown(() async {
    store.dispose();
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'real adapter stamps country and filters a mixed native catalog',
    () async {
      final offers = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      expect(_ids(offers), _ai);
      expect(offers.map((o) => o.storeCountryCode).toSet(), {'JO'});
      expect(native.queriedIds, [_ai]);
      expect(native.queries, 1);
      expect(native.countryReads, 3);
      expect(native.buys, 0);
    },
  );

  test(
    'warm adapter rereads country without a same-country product reload',
    () async {
      await adapter.loadOffers(StoreCatalogConfiguration.storefrontProductIds);
      final same = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      expect(_ids(same), _ai);
      expect(native.queries, 1);
      expect(native.countryReads, 4);
      native.country = 'EGY';
      final changed = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      expect(_ids(changed), _premium);
      expect(changed.map((o) => o.storeCountryCode).toSet(), {'EG'});
      expect(native.queries, 2);
      expect(native.countryReads, 7);
      expect(native.buys, 0);
    },
  );

  test(
    'held storefront can query only Boost even if native returns all SKUs',
    () async {
      native.country = 'CHN';
      final offers = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      expect(_ids(offers), {StoreCatalogConfiguration.aiBoost});
      expect(native.queriedIds, [
        {StoreCatalogConfiguration.aiBoost},
      ]);
      expect(native.buys, 0);
    },
  );

  testWidgets(
    'country timeout is bounded and keeps unknown fallback and Boost',
    (tester) async {
      try {
        final old = Completer<String>();
        native.readCountry = (call) => call == 1
            ? old.future
            : Future.error(StateError('Unavailable fixture storefront'));
        final pending = adapter.loadOffers(
          StoreCatalogConfiguration.storefrontProductIds,
        );
        await tester.pump(const Duration(seconds: 5));
        final offers = await pending;
        expect(_ids(offers), _premium);
        expect(offers.every((o) => o.storeCountryCode == null), isTrue);
        expect(native.countryReads, 3);
        expect(native.queries, 1);
        expect(native.buys, 0);
        old.complete('JOR');
        await tester.pump();
        expect(native.queries, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('A B A retires a country read; latest visit alone may load', (
    tester,
  ) async {
    try {
      final old = Completer<String>();
      native.readCountry = (call) =>
          call == 1 ? old.future : Future.value('JOR');
      final pending = adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      await tester.pump();
      await _roundTrip(tester);
      old.complete('JOR');
      expect(await pending, isEmpty);
      expect(native.queries, 0);
      final current = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      expect(_ids(current), _ai);
      expect(native.queries, 1);
      expect(native.countryReads, 4);
      await tester.pump();
      expect(native.queries, 1);
      expect(native.buys, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'A B A retires a delayed product query without publishing products',
    (tester) async {
      try {
        final old = Completer<ProductDetailsResponse>();
        native.query = () => old.future;
        final pending = store.initialize();
        await tester.pump();
        await _roundTrip(tester);
        old.complete(_allProducts());
        await pending;
        expect(store.products, isEmpty);
        expect(native.queries, 1);
        native.query = null;
        await store.initialize();
        expect(store.products.keys.toSet(), _ai);
        expect(native.queries, 2);
        expect(native.countryReads, 3);
        await tester.pump();
        expect(native.queries, 2);
        expect(native.buys, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('disposal retires a delayed country read without publication', (
    tester,
  ) async {
    try {
      final old = Completer<String>();
      native.readCountry = (_) => old.future;
      var notifications = 0;
      store.addListener(() => notifications++);
      final pending = adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      await tester.pump();
      store.dispose();
      final atDisposal = notifications;
      old.complete('JOR');
      expect(await pending, isEmpty);
      expect(notifications, atDisposal);
      expect(native.queries, 0);
      expect(native.buys, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test(
    'unknown storefront guard blocks an ambiguous catalog before native charge',
    () async {
      native.readCountry = (_) => Future.error(
        PlatformException(code: 'storekit2_failed_to_fetch_country_code'),
      );
      final offers = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      // Retain the established read-only UI fallback and valid Boost. The
      // protection belongs at checkout; it must not rewrite regional UI policy.
      expect(_ids(offers), _premium);
      expect(store.catalogStoreCountryCode, isNull);
      expect(
        store.products.keys.toSet(),
        StoreCatalogConfiguration.storefrontProductIds,
      );
      final selected = MarketOfferPolicy.visibleOffers(offers).firstWhere(
        (offer) => offer.productId == StoreCatalogConfiguration.premiumMonthly,
      );
      expect(selected.storeCountryCode, isNull);
      expect(native.buys, 0);
      await adapter.requestPurchase(selected);
      expect(
        native.buys,
        0,
        reason:
            'Ambiguous unknown country must not open a charge that verified Production market policy can reject afterward.',
      );
      expect(store.messageCode, 'store_catalog_changed');
      expect(store.entitlement, isNull);
    },
  );

  for (final family in [_premium, _ai]) {
    test(
      'unknown storefront guard retains a single native subscription family ${family.first}',
      () async {
        native.readCountry = (_) => Future.error(
          PlatformException(code: 'storekit2_failed_to_fetch_country_code'),
        );
        native.query = () async => ProductDetailsResponse(
          productDetails: family.map(_product).toList(),
          notFoundIDs: const [],
        );
        final offers = await adapter.loadOffers(
          StoreCatalogConfiguration.storefrontProductIds,
        );
        expect(_ids(offers), family);
        expect(store.catalogStoreCountryCode, isNull);
        final selected = MarketOfferPolicy.visibleOffers(offers).firstWhere(
          (offer) => offer.kind != BilStoreProductKind.aiBoostConsumable,
        );
        await adapter.requestPurchase(selected);
        expect(
          native.buys,
          1,
          reason:
              'An unambiguous native family keeps the established fallback; no synthetic grant or receipt is emitted.',
        );
        expect(store.entitlement, isNull);
      },
    );
  }

  test('unknown storefront guard preserves the known warm catalog pin', () async {
    final known = await adapter.loadOffers(
      StoreCatalogConfiguration.storefrontProductIds,
    );
    expect(_ids(known), _ai);
    expect(store.catalogStoreCountryCode, 'JO');
    native.readCountry = (_) => Future.error(
      PlatformException(code: 'storekit2_failed_to_fetch_country_code'),
    );
    final warm = await adapter.loadOffers(
      StoreCatalogConfiguration.storefrontProductIds,
    );
    expect(_ids(warm), _ai);
    final selected = MarketOfferPolicy.visibleOffers(warm).firstWhere(
      (offer) =>
          offer.productId == StoreCatalogConfiguration.premiumAiCoachMonthly,
    );
    // The adapter's failed warm country read currently erases offer metadata,
    // but the service still owns its previous exact catalog-country snapshot.
    expect(selected.storeCountryCode, isNull);
    expect(store.catalogStoreCountryCode, 'JO');
    await adapter.requestPurchase(selected);
    expect(
      native.buys,
      0,
      reason:
          'Missing offer metadata must not discard a known catalog-country pin at checkout.',
    );
    expect(store.messageCode, 'store_catalog_changed');
    expect(store.entitlement, isNull);
  });

  Future<void> prepareCheckout() async {
    final product = _product(StoreCatalogConfiguration.premiumAiCoachMonthly);
    store.products = {product.id: product};
    store.state = VerifiedStoreState.ready;
  }

  test(
    'checkout changed JOR to EGY stops before product lookup and buy',
    () async {
      await prepareCheckout();
      native.country = 'EGY';
      await adapter.requestPurchase(_aiOffer());
      expect(native.buys, 0);
      expect(native.queries, 0);
      expect(store.messageCode, 'store_catalog_changed');
    },
  );

  test(
    'checkout JO and JOR are one country and preserve exact selected SKU',
    () async {
      await prepareCheckout();
      native.country = 'JO';
      await adapter.requestPurchase(_aiOffer());
      expect(native.queries, 1);
      expect(native.countryReads, 2);
      expect(native.buys, 1);
    },
  );

  test('storefront changes during checkout lookup: zero buy', () async {
    await prepareCheckout();
    native.readCountry = (call) => Future.value(call == 1 ? 'JOR' : 'EGY');
    await adapter.requestPurchase(_aiOffer());
    expect(native.queries, 1);
    expect(native.countryReads, 2);
    expect(native.buys, 0);
    expect(store.messageCode, 'store_catalog_changed');
  });

  test(
    'duplicate recovery preserves the displayed country pin across same-family change',
    () async {
      await prepareCheckout();
      native.duplicateFirst = true;
      await adapter.requestPurchase(_aiOffer());
      expect(
        native.buys,
        1,
        reason: 'The original duplicate attempt is the only native call.',
      );
      expect(native.queries, 1);
      expect(native.countryReads, 3);
      expect(store.messageCode, 'store_catalog_changed');
    },
  );

  testWidgets('A B A during checkout country read never opens native buy', (
    tester,
  ) async {
    try {
      await prepareCheckout();
      final old = Completer<String>();
      native.readCountry = (_) => old.future;
      final pending = adapter.requestPurchase(_aiOffer());
      await tester.pump();
      await _roundTrip(tester);
      old.complete('JOR');
      await pending;
      expect(native.buys, 0);
      expect(native.queries, 0);
      expect(store.entitlement, isNull);
      await tester.pump();
      expect(native.buys, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
