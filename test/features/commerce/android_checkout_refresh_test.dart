import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

GooglePlayProductDetails _product({
  String token = 'old-token',
  int micros = 7990000,
  String currency = 'USD',
  String basePlan = 'monthly',
  String period = 'P1M',
  bool trial = false,
}) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    productId: 'bil_premium_ai_coach',
    name: 'AI Coach',
    title: 'AI Coach',
    description: 'Test-only subscription',
    productType: ProductType.subs,
    subscriptionOfferDetails: [
      SubscriptionOfferDetailsWrapper(
        basePlanId: basePlan,
        offerId: trial ? 'trial-7-day' : null,
        offerTags: trial ? ['new-customer'] : [],
        offerIdToken: token,
        pricingPhases: [
          if (trial)
            const PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P7D',
              formattedPrice: 'Free',
              priceAmountMicros: 0,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
          PricingPhaseWrapper(
            billingCycleCount: 0,
            billingPeriod: period,
            formattedPrice: '$currency ${micros / 1000000}',
            priceAmountMicros: micros,
            priceCurrencyCode: currency,
            recurrenceMode: RecurrenceMode.infiniteRecurring,
          ),
        ],
      ),
    ],
  ),
).single;

class _Play extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  late Future<ProductDetailsResponse> Function(Set<String>) query;
  int queries = 0;
  int launches = 0;
  PurchaseParam? lastPurchase;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    queries++;
    return query(ids);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    launches++;
    lastPurchase = purchaseParam;
    return true;
  }
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Play play) : super(purchase: play);
  @override
  bool get configured => true;
}

class _OwnedPurchase extends Fake implements GooglePlayPurchaseDetails {
  @override
  String get productID => 'bil_premium_ai_coach';
}

Future<void> _signIn(String id) =>
    Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Play play;
  late _Store store;
  late GooglePlayProductDetails displayed;
  ProductDetailsResponse response(List<ProductDetails> values) =>
      ProductDetailsResponse(productDetails: values, notFoundIDs: []);
  Future<void> buy() => store.purchasePlan(
    CommercePlan.premiumAiCoach,
    term: SubscriptionTerm.oneMonth,
  );

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://checkout-fixture.invalid',
      publishableKey: 'test-publishable-key',
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
        throw StateError('Unexpected network path: ${request.url.path}');
      }),
    );
    await _signIn('00000000-0000-4000-8000-000000000001');
    displayed = _product();
    play = _Play()..query = (_) async => response([displayed]);
    store = _Store(play)
      ..products = {displayed.id: displayed}
      ..state = VerifiedStoreState.ready;
  });
  tearDown(() async {
    store.dispose();
    await play.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('opening the catalog does not initiate checkout', () async {
    await store.initialize();
    expect(play.queries, 1);
    expect(play.launches, 0);
    expect(store.canStartPurchase, isTrue);
  });

  test(
    'uses fresh Play ProductDetails and rotated token for identical terms',
    () async {
      final fresh = _product(token: 'fresh-token');
      play.query = (ids) async {
        expect(ids, {displayed.id});
        return response([fresh]);
      };
      await buy();
      expect(play.queries, 1);
      expect(play.launches, 1);
      expect(play.lastPurchase!.productDetails, same(fresh));
      expect(
        (play.lastPurchase as GooglePlayPurchaseParam).offerToken,
        'fresh-token',
      );
    },
  );

  test('missing selected product stops before opening Play billing', () async {
    play.query = (_) async => response([]);
    await buy();
    expect(play.launches, 0);
    expect(store.products, isEmpty);
    expect(store.messageCode, 'store_catalog_changed');
    expect(store.busy, isFalse);
  });

  testWidgets('unanswered Play lookup times out without launching a purchase', (
    tester,
  ) async {
    try {
      final pending = Completer<ProductDetailsResponse>();
      play.query = (_) => pending.future;
      final attempt = buy();
      await tester.pump(const Duration(seconds: 11));
      await attempt;
      expect(play.launches, 0);
      expect(store.busy, isFalse);
      expect(store.messageCode, 'store_catalog_refresh_failed');
      // A late native response must not restart the abandoned checkout.
      pending.complete(response([displayed]));
      await tester.pump();
      expect(play.launches, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final changed in ['price', 'currency', 'basePlan', 'period', 'trial']) {
    test(
      '$changed changes require displaying the new offer before checkout',
      () async {
        if (changed == 'trial') {
          displayed = _product(trial: true);
          store.products = {displayed.id: displayed};
        }
        final fresh = switch (changed) {
          'price' => _product(micros: 8990000),
          'currency' => _product(currency: 'EUR'),
          'basePlan' => _product(basePlan: 'new-monthly'),
          'period' => _product(period: 'P1Y'),
          _ => _product(),
        };
        play.query = (_) async => response([fresh]);
        await buy();
        expect(play.launches, 0);
        expect(store.messageCode, 'store_catalog_changed');
        expect(store.busy, isFalse);
      },
    );
  }

  test(
    'failed refresh is retryable but never falls back to stale details',
    () async {
      play.query = (_) async => throw StateError('offline');
      await buy();
      expect(play.launches, 0);
      expect(store.messageCode, 'store_catalog_refresh_failed');
      expect(store.canStartPurchase, isTrue);
      play.query = (_) async => response([_product(token: 'recovered')]);
      await buy();
      expect(play.launches, 1);
    },
  );

  test(
    'duplicate taps during preflight produce one query and one purchase',
    () async {
      final pending = Completer<ProductDetailsResponse>();
      play.query = (_) => pending.future;
      final first = buy();
      await buy();
      expect(play.queries, 1);
      expect(play.launches, 0);
      pending.complete(response([_product(token: 'fresh')]));
      await first;
      expect(play.launches, 1);
    },
  );

  test(
    'switching BIL account while querying prevents checkout for the old owner',
    () async {
      final pending = Completer<ProductDetailsResponse>();
      play.query = (_) => pending.future;
      final first = buy();
      await _signIn('00000000-0000-4000-8000-000000000002');
      pending.complete(response([displayed]));
      await first;
      expect(play.launches, 0);
      expect(store.messageCode, 'authentication_required');
      expect(store.busy, isFalse);
    },
  );

  test(
    'same subscription is never supplied as a replacement of itself',
    () async {
      await store.purchasePlan(
        CommercePlan.premiumAiCoach,
        term: SubscriptionTerm.oneMonth,
        replacesGooglePurchase: _OwnedPurchase(),
      );
      expect(
        (play.lastPurchase as GooglePlayPurchaseParam).changeSubscriptionParam,
        isNull,
      );
    },
  );

  test(
    'adapter retains the selected subscription token and rejects an outdated screen',
    () async {
      final adapter = VerifiedStoreCatalogAdapter(store);
      final offers = await adapter.loadOffers({displayed.id});
      expect(offers.single.purchaseOfferToken, displayed.offerToken);
      store.products = {displayed.id: _product(token: 'another-selection')};
      await adapter.requestPurchase(offers.single);
      expect(play.launches, 0);
      expect(store.messageCode, 'store_catalog_changed');
    },
  );
}
