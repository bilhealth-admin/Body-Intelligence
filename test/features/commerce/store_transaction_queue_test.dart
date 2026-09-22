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
  PurchaseDetails? restoreReceipt;
  List<PurchaseDetails>? restoreBatch;
  Duration? restoreCallbackDelay;
  Future<void> Function()? appleSync;
  bool failCompletion = false;
  int completionCalls = 0;
  int restoreCalls = 0;
  int appleSyncCalls = 0;
  final completionAttempted = Completer<void>();
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
    if (!completionAttempted.isCompleted) completionAttempted.complete();
    if (failCompletion) throw StateError('local acknowledgement failed');
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    final receipt = restoreReceipt ?? _receipt();
    final delay = restoreCallbackDelay;
    if (delay == null) {
      updates.add(restoreBatch ?? [receipt]);
      return;
    }
    unawaited(
      Future<void>.delayed(delay, () {
        if (!updates.isClosed) updates.add([receipt]);
      }),
    );
  }

  Future<void> syncAppleStore() async {
    appleSyncCalls++;
    await appleSync?.call();
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
  _ConfiguredStore(_NativeStore native)
    : super(purchase: native, appleStoreSync: native.syncAppleStore);
  @override
  bool get configured => true;
}

PurchaseDetails _receipt({
  PurchaseStatus status = PurchaseStatus.purchased,
  String productId = StoreCatalogConfiguration.aiBoost,
  String purchaseId = 'local-receipt',
}) => PurchaseDetails(
  purchaseID: purchaseId,
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

http.Response _verifiedSubscriptionResponse() => http.Response(
  '{"verified":true,"entitlement_active":true}',
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeStore native;
  late _ConfiguredStore store;
  late Completer<http.Response> verification;
  late Completer<void> verificationStarted;
  late int verificationCalls;
  late List<Map<String, Object?>> subscriptionRows;
  http.Response Function(http.Request)? verificationResponse;

  setUp(() async {
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    verification = Completer<http.Response>();
    verificationStarted = Completer<void>();
    verificationCalls = 0;
    verificationResponse = null;
    subscriptionRows = <Map<String, Object?>>[];
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
          return http.Response(
            jsonEncode(subscriptionRows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path == '/functions/v1/verify-store-purchase') {
          verificationCalls++;
          if (!verificationStarted.isCompleted) verificationStarted.complete();
          return verificationResponse?.call(request) ?? verification.future;
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
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
  });
  Future<void> ready() async {
    native.finishPrices();
    await store.initialize();
    expect(store.canStartPurchase, isTrue);
  }

  for (final product in [
    StoreCatalogConfiguration.premiumMonthly,
    StoreCatalogConfiguration.aiBoost,
  ]) {
    for (final status in [200, 400]) {
      test(
        'restore preserves ownership rejection for $product HTTP $status',
        () async {
          await ready();
          native.restoreReceipt = _receipt(
            productId: product,
            status: PurchaseStatus.restored,
          );
          final restore = store.restore();
          await verificationStarted.future;
          verification.complete(
            http.Response(
              '{"verified":false,"error":"purchase_owned_by_another_account"}',
              status,
              headers: {'content-type': 'application/json'},
            ),
          );
          await restore;
          expect(store.messageCode, 'purchase_owned_by_another_account');
          expect(store.state, VerifiedStoreState.failed);
          expect(store.canStartPurchase, isFalse);
          expect(store.entitlement, isNull);
          expect(native.completionCalls, 0);
          expect(verificationCalls, 1);
        },
      );
    }
  }

  test(
    'later inactive receipt cannot hide an earlier restore ownership rejection',
    () async {
      await ready();
      native.restoreBatch = [
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'other-owner',
        ),
        _receipt(
          productId: StoreCatalogConfiguration.premiumAnnual,
          purchaseId: 'expired-own',
        ),
      ];
      verificationResponse = (request) {
        final body = jsonDecode(request.body) as Map;
        final conflict = body['purchase_id'] == 'other-owner';
        return http.Response(
          conflict
              ? '{"verified":false,"error":"purchase_owned_by_another_account"}'
              : '{"verified":true,"entitlement_active":false}',
          conflict ? 400 : 200,
          headers: {'content-type': 'application/json'},
        );
      };
      await store.restore();
      expect(verificationCalls, 2);
      expect(native.completionCalls, 1);
      expect(store.messageCode, 'purchase_owned_by_another_account');
      expect(store.canStartPurchase, isFalse);
      expect(store.entitlement, isNull);
    },
  );

  Future<void> drain() async {
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> waitForStoreIdle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (store.busy) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Store purchase queue did not become idle.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
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
      await native.completionAttempted.future.timeout(
        const Duration(seconds: 2),
      );
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
    // No purchase was launched by this service in this test. A pending native
    // callback during startup is therefore a StoreKit reconciliation event,
    // not evidence that opening Plans launched a new checkout.
    expect(store.messageCode, 'reconciliation_pending');
  });
  test(
    'failed prices cannot overwrite a transaction that already verified',
    () async {
      final initialization = store.initialize();
      await drain();
      native.updates.add([_receipt()]);
      await verificationStarted.future;
      verification.complete(_verifiedResponse());
      await native.completionAttempted.future.timeout(
        const Duration(seconds: 2),
      );
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
      await native.completionAttempted.future.timeout(
        const Duration(seconds: 2),
      );
      expect(native.completionCalls, 1);
      await drain();
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
    'a startup StoreKit stream fault recovers after the catalog loads',
    () async {
      final initialization = store.initialize();
      await drain();

      native.updates.addError(StateError('startup stream unavailable'));
      await drain();
      expect(store.state, VerifiedStoreState.unavailable);

      native.finishPrices();
      await initialization;

      expect(store.state, VerifiedStoreState.ready);
      expect(store.messageCode, isNull);
      expect(store.canStartPurchase, isTrue);
      expect(native.launches, 0);
    },
  );
  test(
    'a startup historical StoreKit error does not lock the loaded catalog',
    () async {
      final initialization = store.initialize();
      await drain();

      native.updates.add([_receipt(status: PurchaseStatus.error)]);
      await drain();
      native.finishPrices();
      await initialization;

      expect(store.state, VerifiedStoreState.ready);
      expect(store.messageCode, isNull);
      expect(store.canStartPurchase, isTrue);
      expect(native.launches, 0);
    },
  );
  test(
    'a receipt verification failure cannot be overwritten by a startup fault',
    () async {
      final initialization = store.initialize();
      await drain();

      native.updates.addError(StateError('startup stream unavailable'));
      await drain();
      native.updates.add([_receipt(purchaseId: 'startup-failure-receipt')]);
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await waitForStoreIdle();
      native.finishPrices();
      await initialization;

      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'reconciliation_verification_failed');
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
  test('explicit iOS restore syncs before StoreKit restoration', () async {
    final sync = Completer<void>();
    native.appleSync = () => sync.future;
    await ready();

    final restoring = store.restore();
    await drain();
    expect(native.appleSyncCalls, 1);
    expect(native.restoreCalls, 0);

    sync.complete();
    await verificationStarted.future;
    expect(native.restoreCalls, 1);
    verification.complete(_verifiedResponse());
    await restoring;

    expect(native.appleSyncCalls, 1);
    expect(native.completionCalls, 1);
    expect(native.launches, 0);
  });
  test(
    'a failed explicit Apple sync never starts native restoration',
    () async {
      native.appleSync = () async {
        throw StateError('Apple sync unavailable');
      };
      await ready();

      await store.restore();

      expect(native.appleSyncCalls, 1);
      expect(native.restoreCalls, 0);
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'restore_failed');
      expect(native.launches, 0);
    },
  );
  test(
    'deduplicates a queued failed transaction but permits a new purchase id',
    () async {
      await ready();
      final replayed = _receipt(purchaseId: 'replayed-transaction');

      native.updates.add([replayed, replayed]);
      await verificationStarted.future;
      expect(verificationCalls, 1);

      // This is a second StoreKit stream delivery while the first verification
      // remains in flight. It must not become a second server request.
      native.updates.add([replayed]);
      await drain();
      expect(verificationCalls, 1);

      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await drain();
      expect(native.completionCalls, 0);

      // A distinct platform transaction is never covered by the replay key.
      native.updates.add([_receipt(purchaseId: 'new-transaction')]);
      await drain();
      expect(verificationCalls, 2);
    },
  );
  test(
    'a cooled-down replay cannot replace a newly pending checkout',
    () async {
      await ready();
      final oldReceipt = _receipt(purchaseId: 'old-replayed-transaction');
      native.updates.add([oldReceipt]);
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await drain();

      // A completed receipt verification failure correctly blocks a retry in
      // this Plans instance. Opening the route again is the real member path:
      // it starts ready, while the process-local replay cooldown remains.
      store.dispose();
      await native.updates.close();
      native = _NativeStore();
      store = _ConfiguredStore(native);
      native.finishPrices();
      await store.initialize();

      final launch = store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      await drain();
      expect(store.state, VerifiedStoreState.purchasePending);
      expect(store.messageCode, isNull);

      native.updates.add([oldReceipt]);
      await drain();

      expect(store.state, VerifiedStoreState.purchasePending);
      expect(store.messageCode, isNull);
      expect(native.launches, 1);
      native.purchaseLaunch.complete(false);
      await launch;
    },
  );
  test(
    'explicit Restore retries a failed transaction once despite cooldown',
    () async {
      native.restoreReceipt = _receipt(
        status: PurchaseStatus.restored,
        purchaseId: 'restore-retry-transaction',
      );
      await ready();

      final firstRestore = store.restore();
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await firstRestore;
      expect(verificationCalls, 1);
      expect(native.completionCalls, 0);

      await store.restore();

      expect(verificationCalls, 2);
      expect(native.appleSyncCalls, 2);
      expect(native.completionCalls, 0);
      expect(store.messageCode, 'restore_verification_failed');
    },
  );
  test(
    'failed replay cooldown is account scoped across Plans service instances',
    () async {
      await ready();
      final replayed = _receipt(purchaseId: 'account-scoped-transaction');
      native.updates.add([replayed]);
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await drain();
      expect(verificationCalls, 1);

      // Opening Plans creates a new service. The same member's unfinished
      // transaction stays fail-closed without consuming another rate-limit
      // slot.
      store.dispose();
      await native.updates.close();
      native = _NativeStore();
      store = _ConfiguredStore(native);
      native.finishPrices();
      await store.initialize();
      native.updates.add([replayed]);
      await drain();
      expect(verificationCalls, 1);
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'reconciliation_verification_failed');

      // The cooldown is not shared with another signed-in member, even when
      // StoreKit reports a transaction with the same id.
      store.dispose();
      await native.updates.close();
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'local-test-token-owner-b',
          'token_type': 'bearer',
          'user': {
            'id': '00000000-0000-4000-8000-000000000002',
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      native = _NativeStore();
      store = _ConfiguredStore(native);
      native.finishPrices();
      await store.initialize();
      native.updates.add([replayed]);
      await drain();

      expect(verificationCalls, 2);
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
  test('restore waits for a delayed restored Premium callback', () async {
    final now = DateTime.now().toUtc();
    subscriptionRows = [
      {
        'provider': 'apple',
        'plan_id': 'premium',
        'lifecycle': 'active',
        'verified_at': now.toIso8601String(),
        'started_at': now
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
        'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
        'grace_period_ends_at': null,
      },
    ];
    native.restoreReceipt = _receipt(
      status: PurchaseStatus.restored,
      productId: StoreCatalogConfiguration.premiumMonthly,
    );
    native.restoreCallbackDelay = const Duration(milliseconds: 10);
    await ready();

    final restoring = store.restore();
    await verificationStarted.future;
    verification.complete(_verifiedSubscriptionResponse());
    await restoring;

    expect(store.state, VerifiedStoreState.verified);
    expect(store.messageCode, 'subscription_verified');
    expect(native.completionCalls, 1);
    expect(native.launches, 0);
  });
  test(
    'a verified inactive subscription completes without restoring stale paid access',
    () async {
      final now = DateTime.now().toUtc();
      final inactiveVerifiedAt = now.add(const Duration(minutes: 1));
      // Simulate an App Store response that has already recorded an inactive
      // lifecycle while the subscription read still returns its old active row.
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      native.restoreReceipt = _receipt(
        status: PurchaseStatus.restored,
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: 'verified-inactive-subscription',
      );
      await ready();
      expect(store.entitlement?.grantsPaidAccess, isTrue);

      final restoring = store.restore();
      await verificationStarted.future;
      verification.complete(
        http.Response(
          jsonEncode({
            'verified': true,
            'entitlement_active': false,
            'verified_at': inactiveVerifiedAt.toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await restoring;

      expect(native.completionCalls, 1);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      expect(store.state, VerifiedStoreState.ready);
      expect(store.messageCode, 'no_restorable_purchases');
      expect(store.canStartPurchase, isTrue);
      expect(native.launches, 0);

      // The inactivity watermark blocks only the old replica row. A later
      // canonical active verification represents a real new subscription.
      final recoveredAt = inactiveVerifiedAt.add(const Duration(minutes: 1));
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': recoveredAt.toIso8601String(),
          'started_at': recoveredAt
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': recoveredAt
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      await store.refreshEntitlement();
      expect(store.entitlement?.grantsPaidAccess, isTrue);
    },
  );
  test(
    'a verified subscription missing entitlement state stays fail-closed',
    () async {
      native.restoreReceipt = _receipt(
        status: PurchaseStatus.restored,
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: 'missing-entitlement-state',
      );
      await ready();

      final restoring = store.restore();
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":true}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await restoring;

      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'restore_verification_failed');
      expect(store.canStartPurchase, isFalse);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'a newer canonical active row wins an inactive receipt response race',
    () async {
      final now = DateTime.now().toUtc();
      final inactiveVerifiedAt = now.add(const Duration(minutes: 1));
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      native.restoreReceipt = _receipt(
        status: PurchaseStatus.restored,
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: 'inactive-to-newer-active-race',
      );
      await ready();

      final restoring = store.restore();
      await verificationStarted.future;
      final newerActiveAt = inactiveVerifiedAt.add(const Duration(minutes: 1));
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': newerActiveAt.toIso8601String(),
          'started_at': newerActiveAt
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': newerActiveAt
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      verification.complete(
        http.Response(
          jsonEncode({
            'verified': true,
            'entitlement_active': false,
            'verified_at': inactiveVerifiedAt.toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await restoring;

      expect(native.completionCalls, 1);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'subscription_verified');
    },
  );
  test(
    'restore verification failure stays restore-specific and fail-closed',
    () async {
      native.restoreReceipt = _receipt(
        status: PurchaseStatus.restored,
        productId: StoreCatalogConfiguration.premiumMonthly,
      );
      await ready();

      final restoring = store.restore();
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await restoring;

      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'restore_verification_failed');
      expect(store.canStartPurchase, isFalse);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );

  test(
    'a transient empty entitlement read retains the verified member state',
    () async {
      final now = DateTime.now().toUtc();
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      await store.refreshEntitlement();
      expect(store.entitlement?.plan, CommercePlan.premium);
      expect(store.entitlement?.grantsPaidAccessAt(now), isTrue);

      subscriptionRows = <Map<String, Object?>>[];
      await store.refreshEntitlement();

      expect(store.entitlement?.plan, CommercePlan.premium);
      expect(store.entitlement?.grantsPaidAccessAt(now), isTrue);
    },
  );

  test(
    'a malformed active row does not erase a still-valid entitlement',
    () async {
      final now = DateTime.now().toUtc();
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': now.add(const Duration(hours: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      await store.refreshEntitlement();
      expect(store.entitlement?.grantsPaidAccessAt(now), isTrue);

      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'expires_at': null,
          'grace_period_ends_at': null,
        },
      ];
      await store.refreshEntitlement();

      expect(store.entitlement?.plan, CommercePlan.premium);
      expect(store.entitlement?.grantsPaidAccessAt(now), isTrue);
    },
  );
}
