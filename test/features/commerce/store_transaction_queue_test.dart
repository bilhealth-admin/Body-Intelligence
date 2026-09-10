import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Real service, in-memory callback stream and HTTP client; no network/device.
class _NativeStore extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  final productResponse = Completer<ProductDetailsResponse>();
  final purchaseLaunch = Completer<bool>();
  bool failCompletion = false;
  int completionCalls = 0;
  int queries = 0;
  int launches = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    queries++;
    return productResponse.future;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completionCalls++;
    if (failCompletion) throw StateError('local acknowledgement failed');
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    updates.add([_receipt()]);
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) {
    launches++;
    return purchaseLaunch.future;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    launches++;
    return purchaseLaunch.future;
  }

  void finishPrices() => productResponse.complete(
    ProductDetailsResponse(
      productDetails: [
        AppStoreProduct2Details.fromSK2Product(
          SK2Product(
            id: StoreCatalogConfiguration.premiumMonthly,
            displayName: 'Premium',
            description: 'Fixture',
            displayPrice: '2.49',
            price: 2.49,
            type: SK2ProductType.autoRenewable,
            priceLocale: SK2PriceLocale(
              currencyCode: 'USD',
              currencySymbol: r'$',
            ),
            subscription: SK2SubscriptionInfo(
              subscriptionGroupID: 'fixture-premium',
              promotionalOffers: const [],
              subscriptionPeriod: const SK2SubscriptionPeriod(
                value: 1,
                unit: SK2SubscriptionPeriodUnit.month,
              ),
            ),
          ),
        ),
        ProductDetails(
          id: StoreCatalogConfiguration.aiBoost,
          title: 'Boost',
          description: 'Fixture',
          price: '2.49',
          rawPrice: 2.49,
          currencyCode: 'USD',
        ),
      ],
      notFoundIDs: const [],
    ),
  );
}

class _ConfiguredStore extends VerifiedStorePurchaseService {
  _ConfiguredStore(_NativeStore native) : super(purchase: native);
  @override
  bool get configured => true;
}

PurchaseDetails _receipt({
  PurchaseStatus status = PurchaseStatus.purchased,
  String productId = StoreCatalogConfiguration.aiBoost,
}) => PurchaseDetails(
  purchaseID: 'local-receipt',
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'fixture',
    serverVerificationData: 'fixture',
    source: 'app_store',
  ),
  transactionDate: '1',
  status: status,
)..pendingCompletePurchase = true;

http.Response _verifiedResponse() => http.Response(
  '{"verified":true}',
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeStore native;
  late _ConfiguredStore store;
  late Completer<http.Response> verification;
  late Completer<void> verificationStarted;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    verification = Completer<http.Response>();
    verificationStarted = Completer<void>();
    await Supabase.initialize(
      url: 'https://billing-fixture.invalid',
      publishableKey: 'fixture-publishable-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/rest/v1/bil_subscriptions') {
          return http.Response('[]', 200);
        }
        if (request.url.path == '/functions/v1/verify-store-purchase') {
          if (!verificationStarted.isCompleted) verificationStarted.complete();
          return verification.future;
        }
        throw StateError(
          'Unexpected test-only HTTP request: ${request.url.path}',
        );
      }),
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'local-test-token',
        'token_type': 'bearer',
        'user': {
          'id': '00000000-0000-4000-8000-000000000001',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    native = _NativeStore();
    store = _ConfiguredStore(native);
  });
  tearDown(() async {
    store.dispose();
    if (!verification.isCompleted) {
      verification.complete(http.Response('{"verified":false}', 200));
    }
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  Future<void> ready() async {
    native.finishPrices();
    await store.initialize();
    expect(store.canStartPurchase, isTrue);
  }

  Future<void> drain() async {
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'a callback locks purchase immediately before asynchronous verification',
    () async {
      await ready();
      native.updates.add([_receipt()]);
      expect(store.busy, isTrue);
      expect(store.canStartPurchase, isFalse);
      await store.initialize();
      expect(native.queries, 1);
      await verificationStarted.future;
      verification.complete(_verifiedResponse());
      await drain();
      expect(store.state, VerifiedStoreState.verified);
      expect(store.busy, isFalse);
      expect(native.completionCalls, 1);
    },
  );
  test('slow prices cannot overwrite a pending native transaction', () async {
    final initialization = store.initialize();
    await drain();
    native.updates.add([_receipt(status: PurchaseStatus.pending)]);
    await drain();
    native.productResponse.complete(
      ProductDetailsResponse(productDetails: [], notFoundIDs: []),
    );
    await initialization;
    expect(store.state, VerifiedStoreState.purchasePending);
    expect(store.messageCode, 'purchase_pending');
  });
  test(
    'failed prices cannot overwrite a transaction that already verified',
    () async {
      final initialization = store.initialize();
      await drain();
      native.updates.add([_receipt()]);
      await verificationStarted.future;
      verification.complete(_verifiedResponse());
      await drain();
      expect(store.state, VerifiedStoreState.verified);
      native.productResponse.completeError(StateError('catalog unavailable'));
      await initialization;
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'ai_boost_verified');
    },
  );
  for (final throws in [false, true]) {
    test(
      'late Boost launch failure (throws=$throws) cannot replace a verified receipt',
      () async {
        await ready();
        final launch = store.purchaseBoost();
        expect(native.launches, 1);
        await store.purchaseBoost();
        expect(native.launches, 1);
        native.updates.add([_receipt()]);
        await verificationStarted.future;
        verification.complete(_verifiedResponse());
        await drain();
        expect(store.state, VerifiedStoreState.verified);
        if (throws) {
          native.purchaseLaunch.completeError(StateError('late native reply'));
        } else {
          native.purchaseLaunch.complete(false);
        }
        await launch;
        expect(store.state, VerifiedStoreState.verified);
        expect(store.messageCode, 'ai_boost_verified');
      },
    );
    test(
      'late plan launch failure (throws=$throws) cannot unlock a pending native transaction',
      () async {
        await ready();
        final launch = store.purchasePlan(
          CommercePlan.premium,
          term: SubscriptionTerm.oneMonth,
        );
        expect(native.launches, 1);
        native.updates.add([
          _receipt(
            status: PurchaseStatus.pending,
            productId: StoreCatalogConfiguration.premiumMonthly,
          ),
        ]);
        await drain();
        if (throws) {
          native.purchaseLaunch.completeError(StateError('late native reply'));
        } else {
          native.purchaseLaunch.complete(false);
        }
        await launch;
        expect(store.state, VerifiedStoreState.purchasePending);
        expect(store.canStartPurchase, isFalse);
        expect(store.messageCode, 'purchase_pending');
        native.updates.add([
          _receipt(
            status: PurchaseStatus.canceled,
            productId: StoreCatalogConfiguration.premiumMonthly,
          ),
        ]);
        await drain();
        expect(store.state, VerifiedStoreState.ready);
        expect(store.messageCode, isNull);
      },
    );
  }
  test(
    'acknowledgement failure after verification cannot enable a second purchase',
    () async {
      await ready();
      native.failCompletion = true;
      native.updates.add([_receipt()]);
      await verificationStarted.future;
      verification.complete(_verifiedResponse());
      await drain();
      expect(native.completionCalls, 1);
      expect(store.messageCode, 'verification_failed');
      expect(store.canStartPurchase, isFalse);
    },
  );
  test(
    'a native stream error leaves pending state without enabling recharge',
    () async {
      await ready();
      native.updates.add([_receipt(status: PurchaseStatus.pending)]);
      await drain();
      expect(store.busy, isTrue);
      native.updates.addError(StateError('native stream unavailable'));
      await drain();
      expect(store.busy, isFalse);
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'store_stream_failed');
      expect(store.canStartPurchase, isFalse);
    },
  );
  test(
    'a stream error cannot replace the outcome of an in-flight receipt',
    () async {
      await ready();
      native.updates.add([_receipt()]);
      await verificationStarted.future;
      native.updates.addError(StateError('native stream unavailable'));
      expect(store.busy, isTrue);
      verification.complete(_verifiedResponse());
      await drain();
      expect(store.state, VerifiedStoreState.verified);
      expect(store.busy, isFalse);
    },
  );
  test(
    'restore waits for receipt verification before publishing its result',
    () async {
      await ready();
      var finished = false;
      final restoring = store.restore().then((_) => finished = true);
      await verificationStarted.future;
      await drain();
      expect(finished, isFalse);
      expect(store.busy, isTrue);
      verification.complete(_verifiedResponse());
      await restoring;
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'ai_boost_verified');
      expect(store.busy, isFalse);
    },
  );
}
