import 'package:body_intelligence_log/features/commerce/services/store_native_purchase_completion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

/// Windows widget-test isolates have no registered mobile purchase plugin.
/// This public platform-interface subclass supplies only the initial slot;
/// tested Android calls still use the real SDK with the controlled client below.
class _IsolatedPurchasePlatform extends InAppPurchasePlatform {}

InAppPurchasePlatform existingOrIsolatedPurchasePlatform() {
  try {
    return InAppPurchasePlatform.instance;
  } on Error {
    // The public getter's only operation reads its late static backing field.
    // Do not register StoreKit/Play native channels just to initialize it.
    final isolated = _IsolatedPurchasePlatform();
    InAppPurchasePlatform.instance = isolated;
    return isolated;
  }
}

class NativeBillingClient extends Fake implements BillingClient {
  BillingResponse response = BillingResponse.serviceUnavailable;
  Future<BillingResultWrapper> Function()? acknowledge;
  int acknowledgements = 0, queries = 0;
  PurchasesResultWrapper purchases = const PurchasesResultWrapper(
    responseCode: BillingResponse.ok,
    billingResult: BillingResultWrapper(responseCode: BillingResponse.ok),
    purchasesList: [],
  );
  @override
  Future<PurchasesResultWrapper> queryPurchases(ProductType productType) async {
    expect(productType, isIn([ProductType.inapp, ProductType.subs]));
    queries++;
    if (productType == ProductType.inapp) {
      return const PurchasesResultWrapper(
        responseCode: BillingResponse.ok,
        billingResult: BillingResultWrapper(responseCode: BillingResponse.ok),
        purchasesList: [],
      );
    }
    return purchases;
  }

  @override
  Future<BillingResultWrapper> startConnection({
    required OnBillingServiceDisconnected onBillingServiceDisconnected,
    BillingChoiceMode billingChoiceMode = BillingChoiceMode.playBillingOnly,
    // The installed SDK does not export the concrete pending-params type.
    // Object? is a valid wider override at this controlled client boundary.
    Object? pendingPurchasesParams,
  }) async => const BillingResultWrapper(responseCode: BillingResponse.ok);
  @override
  Future<void> endConnection() async {}
  @override
  Future<bool> isReady() async => true;
  @override
  Future<BillingResultWrapper> acknowledgePurchase(String token) async {
    acknowledgements++;
    if (acknowledge != null) return acknowledge!();
    return BillingResultWrapper(responseCode: response);
  }
}

InAppPurchaseAndroidPlatform realAndroidPlatform(NativeBillingClient api) =>
    InAppPurchaseAndroidPlatform(
      manager: BillingClientManager(
        billingClientFactory: (listener, alternative) => api,
      ),
    );

GooglePlayPurchaseDetails googleSubscription({
  bool acknowledged = false,
  String token = 'fixture-not-a-real-token',
  String product = 'bil_premium',
  String packageName = 'com.bilhealth.bodyintelligencelog',
  PurchaseStateWrapper state = PurchaseStateWrapper.purchased,
}) => GooglePlayPurchaseDetails.fromPurchase(
  PurchaseWrapper(
    orderId: 'fixture-order',
    packageName: packageName,
    purchaseTime: 1,
    signature: 'fixture-only',
    products: [product],
    purchaseToken: token,
    isAutoRenewing: true,
    originalJson: '',
    developerPayload: '',
    isAcknowledged: acknowledged,
    purchaseState: state,
  ),
).single;

class _VoidStore extends Fake implements InAppPurchase {
  _VoidStore(this.addition);
  final InAppPurchaseAndroidPlatformAddition addition;
  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      addition as T;
  int completions = 0;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completions++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeBillingClient api;
  late InAppPurchaseAndroidPlatform platform;
  late InAppPurchasePlatform previous;
  late _VoidStore store;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    previous = existingOrIsolatedPurchasePlatform();
    api = NativeBillingClient();
    platform = realAndroidPlatform(api);
    InAppPurchasePlatform.instance = platform;
    store = _VoidStore(
      InAppPurchaseAndroidPlatformAddition(platform.billingClientManager),
    );
  });
  tearDown(() async {
    platform.billingClientManager.dispose();
    InAppPurchasePlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
  });
  for (final response in [
    BillingResponse.serviceUnavailable,
    BillingResponse.error,
    BillingResponse.developerError,
  ]) {
    test(
      'actual Android SDK non-OK ${response.name} remains retryable',
      () async {
        api.response = response;
        final purchase = googleSubscription();
        await expectLater(
          completeVerifiedNativePurchase(store, purchase),
          throwsA(isA<StateError>()),
        );
        expect(api.acknowledgements, 1);
        expect(
          store.completions,
          0,
          reason: 'the generic void wrapper must not discard BillingResult',
        );
        api.response = BillingResponse.ok;
        await completeVerifiedNativePurchase(store, purchase);
        expect(api.acknowledgements, 2);
      },
    );
  }
  test(
    'actual SDK fresh acknowledged subscription settles a stale callback after non-OK retry',
    () async {
      api.response = BillingResponse.developerError;
      api.purchases = PurchasesResultWrapper(
        responseCode: BillingResponse.ok,
        billingResult: const BillingResultWrapper(
          responseCode: BillingResponse.ok,
        ),
        purchasesList: [
          googleSubscription(acknowledged: true).billingClientPurchase,
        ],
      );
      await completeVerifiedNativePurchase(store, googleSubscription());
      expect(api.acknowledgements, 1);
      expect(
        api.queries,
        2,
        reason: 'the public SDK queries both product types',
      );
      expect(store.completions, 0);
    },
  );
  for (final mismatch in [
    'token',
    'product',
    'package',
    'unacknowledged',
    'pending',
    'query-error',
  ]) {
    test(
      'fresh Android $mismatch cannot retire the verified finish retry',
      () async {
        api.response = BillingResponse.developerError;
        final row = googleSubscription(
          acknowledged: mismatch != 'unacknowledged',
          token: mismatch == 'token'
              ? 'foreign-token'
              : 'fixture-not-a-real-token',
          product: mismatch == 'product' ? 'foreign-product' : 'bil_premium',
          packageName: mismatch == 'package'
              ? 'foreign.package'
              : 'com.bilhealth.bodyintelligencelog',
          state: mismatch == 'pending'
              ? PurchaseStateWrapper.pending
              : PurchaseStateWrapper.purchased,
        );
        api.purchases = PurchasesResultWrapper(
          responseCode: mismatch == 'query-error'
              ? BillingResponse.error
              : BillingResponse.ok,
          billingResult: BillingResultWrapper(
            responseCode: mismatch == 'query-error'
                ? BillingResponse.error
                : BillingResponse.ok,
          ),
          purchasesList: [row.billingClientPurchase],
        );
        await expectLater(
          completeVerifiedNativePurchase(store, googleSubscription()),
          throwsA(isA<StateError>()),
        );
        expect(
          api.queries,
          2,
          reason: 'the public SDK queries both product types',
        );
        expect(store.completions, 0);
      },
    );
  }

  test(
    'already acknowledged Android receipt needs no second native call',
    () async {
      await completeVerifiedNativePurchase(
        store,
        googleSubscription(acknowledged: true),
      );
      expect(api.acknowledgements, 0);
    },
  );
  test('Apple keeps its native finish contract', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await completeVerifiedNativePurchase(store, googleSubscription());
    expect(store.completions, 1);
    expect(api.acknowledgements, 0);
  });
}
