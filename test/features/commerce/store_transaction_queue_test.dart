import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/commerce/services/store_verification_request_policy.dart';

import 'package:body_intelligence_log/features/commerce/domain/entitlement_resolver.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_record.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:flutter/material.dart';

import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/services/store_subscription_blocker_recovery.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/providers/app_purchase_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/verified_purchase_handoff.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase_storekit/src/sk2_pigeon.g.dart' as sk2;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'store_native_purchase_completion_test.dart' as billing;
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
  Future<void> Function()? finish;
  int completionCalls = 0;
  final completionChanges = ChangeNotifier();
  int restoreCalls = 0;
  Object? restoreError;
  Future<void> Function()? restoreAction;
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
    completionChanges.notifyListeners();
    if (!completionAttempted.isCompleted) completionAttempted.complete();
    if (failCompletion) throw StateError('local acknowledgement failed');
    await finish?.call();
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    final action = restoreAction;
    if (action != null) return action();
    final error = restoreError;
    if (error != null) throw error;
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

// Deterministic held native query; no production hook.
class _IosHeldFreshQueryNative extends _NativeStore {
  final freshQueryReached = Completer<void>();
  final releaseFreshQuery = Completer<ProductDetailsResponse>();
  final events = <String>[];
  void Function()? beforeLaunch;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    if (queries == 0) return super.queryProductDetails(ids);
    queries++;
    events.add('fresh-query-held');
    if (!freshQueryReached.isCompleted) freshQueryReached.complete();
    return releaseFreshQuery.future;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    beforeLaunch?.call();
    events.add('native-launch');
    return super.buyNonConsumable(purchaseParam: purchaseParam);
  }
}

class _NeverDescribe {
  @override
  String toString() => throw StateError('Native details must not be formatted');
}

class _ConfiguredStore extends VerifiedStorePurchaseService {
  _ConfiguredStore(
    _NativeStore native, {
    super.pendingTimeout,
    super.subscriptionInventoryReader,
    super.freshRecoveryEntitlementReader,
  }) : super(purchase: native, appleStoreSync: native.syncAppleStore);
  @override
  bool get configured => true;
}

PurchaseDetails _receipt({
  PurchaseStatus status = PurchaseStatus.purchased,
  String productId = StoreCatalogConfiguration.aiBoost,
  String purchaseId = 'local-receipt',
  String verificationData = 'fixture',
}) => PurchaseDetails(
  purchaseID: purchaseId,
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'fixture',
    serverVerificationData: verificationData,
    source: 'app_store',
  ),
  transactionDate: '1',
  status: status,
)..pendingCompletePurchase = true;

class _Inventory implements StoreSubscriptionInventoryReader {
  int reads = 0;
  Future<NativeStoreSubscriptionInventory> Function()? onRead;
  @override
  Future<NativeStoreSubscriptionInventory> read() async {
    reads++;
    return onRead == null
        ? const NativeStoreSubscriptionInventory(
            currentEntitlementCount: 0,
            unfinishedCount: 0,
          )
        : await onRead!();
  }
}

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
    native.completionChanges.dispose();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
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

  Future<void> waitForStoreCondition(bool Function() condition) async {
    final reached = Completer<void>();
    void changed() {
      if (!reached.isCompleted && condition()) reached.complete();
    }

    store.addListener(changed);
    native.completionChanges.addListener(changed);
    try {
      changed();
      await reached.future.timeout(const Duration(seconds: 2));
    } finally {
      store.removeListener(changed);
      native.completionChanges.removeListener(changed);
    }
  }

  Future<void> waitForVerificationFailure() async {
    for (var i = 0; i < 100; i++) {
      if (store.state == VerifiedStoreState.failed) return;
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(store.state, VerifiedStoreState.failed);
  }

  Future<void> restoreInactiveWithFailedFinish() async {
    await ready();
    native.failCompletion = true;
    native.restoreReceipt = _receipt(
      status: PurchaseStatus.restored,
      productId: StoreCatalogConfiguration.premiumMonthly,
      purchaseId: 'inactive-finish-recovery',
    );
    final restoring = store.restore();
    await verificationStarted.future;
    verification.complete(
      http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await restoring;
    await waitForStoreCondition(
      () =>
          store.hasPendingVerifiedFinish &&
          store.messageCode == 'store_finish_pending',
    );
    expect(store.state, VerifiedStoreState.ready);
    expect(store.canStartPurchase, isFalse);
    expect(store.entitlement?.grantsPaidAccess, isNot(true));
  }

  test(
    'restore support sync code is fixed and clears at next operation',
    () async {
      await ready();
      native.appleSync = () async => throw PlatformException(
        code: 'storekit2_failed_to_sync_to_app_store',
        message: 'DO_NOT_RENDER_JWS_OR_ACCOUNT',
        details: 'private callback URL and credentials must stay private',
      );
      await store.restore();
      expect(store.messageCode, 'restore_failed');
      expect(store.restoreSupportCode, 'BIL-RS-SYNC-01');
      expect(native.appleSyncCalls, 1);
      expect(native.restoreCalls, 0);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      native.appleSync = null;
      await store.initialize();
      expect(store.restoreSupportCode, isNull);
      expect(native.appleSyncCalls, 1);
      expect(native.launches, 0);
    },
  );

  for (final entry in {
    'storekit2_restore_failed': 'BIL-RS-ENUM-02',
    'DO_NOT_RENDER_SECRET_CODE': 'BIL-RS-ENUM-98',
  }.entries) {
    test(
      'restore support safely categorizes native enum ${entry.value}',
      () async {
        await ready();
        native.restoreError = PlatformException(
          code: entry.key,
          message: 'DO_NOT_RENDER_JWS_OR_ACCOUNT',
          details: _NeverDescribe(),
        );
        await store.restore();
        expect(store.messageCode, 'restore_failed');
        expect(store.restoreSupportCode, entry.value);
        expect(native.appleSyncCalls, 1);
        expect(native.restoreCalls, 1);
        expect(verificationCalls, 0);
        expect(native.completionCalls, 0);
        expect(native.launches, 0);
        store.dispose();
        expect(store.restoreSupportCode, isNull);
      },
    );
  }

  test(
    'restore support unexpected native failure is a fixed category',
    () async {
      await ready();
      native.appleSync = () async => throw _NeverDescribe();
      await store.restore();
      expect(store.restoreSupportCode, 'BIL-RS-SYNC-99');
      expect(store.messageCode, 'restore_failed');
      expect(native.restoreCalls, 0);
      expect(verificationCalls, 0);
    },
  );

  test(
    'restore support native callback error does not verify or finish',
    () async {
      await ready();
      native.restoreBatch = [_receipt(status: PurchaseStatus.error)];
      await store.restore();
      expect(store.messageCode, 'restore_failed');
      expect(store.restoreSupportCode, 'BIL-RS-CALLBACK-03');
      expect(native.appleSyncCalls, 1);
      expect(native.restoreCalls, 1);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );

  test(
    'restore support retired A B A attempt cannot publish a late error',
    () async {
      await ready();
      final sync = Completer<void>();
      native.appleSync = () => sync.future;
      final restoring = store.restore();
      await drain();
      final owners = <String>[];
      var previousOwner = '00000000-0000-4000-8000-000000000001';
      final delivered = Completer<void>();
      final listener = Supabase.instance.client.auth.onAuthStateChange.listen((
        event,
      ) {
        final id = event.session?.user.id;
        if (id == null || id == previousOwner) return;
        previousOwner = id;
        owners.add(id);
        if (owners.length == 2 && !delivered.isCompleted) delivered.complete();
      });
      try {
        for (final id in [
          '00000000-0000-4000-8000-000000000002',
          '00000000-0000-4000-8000-000000000001',
        ]) {
          await Supabase.instance.client.auth.setInitialSession(
            jsonEncode({
              'access_token': 'synthetic-restoration-test',
              'token_type': 'bearer',
              'user': {
                'id': id,
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
          );
        }
        await delivered.future.timeout(const Duration(seconds: 2));
        expect(owners, [
          '00000000-0000-4000-8000-000000000002',
          '00000000-0000-4000-8000-000000000001',
        ]);
        sync.completeError(PlatformException(code: 'storekit2_restore_failed'));
        await restoring;
        expect(store.restoreSupportCode, isNull);
        expect(store.messageCode, 'authentication_required');
        expect(native.appleSyncCalls, 1);
        expect(native.restoreCalls, 0);
        expect(verificationCalls, 0);
        expect(native.launches, 0);
      } finally {
        await listener.cancel();
        if (!sync.isCompleted) sync.complete();
        await restoring;
      }
    },
  );

  test(
    'restore support late native error cannot replace fresh verified benefit',
    () async {
      await ready();
      verificationResponse = (_) => _verifiedResponse();
      native.restoreAction = () async {
        native.updates.add([_receipt(status: PurchaseStatus.restored)]);
        await waitForStoreCondition(
          () => store.state == VerifiedStoreState.verified,
        );
        throw PlatformException(
          code: 'storekit2_restore_failed',
          details: _NeverDescribe(),
        );
      };
      await store.restore();
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'ai_boost_verified');
      expect(store.verifiedBenefitRevision, 1);
      expect(store.restoreSupportCode, isNull);
      expect(verificationCalls, 1);
      expect(native.appleSyncCalls, 1);
      expect(native.restoreCalls, 1);
      expect(native.launches, 0);
    },
  );

  test(
    'restore support late native error cannot replace current receipt denial',
    () async {
      await ready();
      verificationResponse = (_) => http.Response('{"verified":false}', 200);
      native.restoreAction = () async {
        native.updates.add([_receipt(status: PurchaseStatus.restored)]);
        await waitForStoreCondition(
          () => store.messageCode == 'restore_verification_failed',
        );
        throw PlatformException(
          code: 'storekit2_restore_failed',
          details: _NeverDescribe(),
        );
      };
      await store.restore();
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'restore_verification_failed');
      expect(store.restoreSupportCode, isNull);
      expect(store.verifiedBenefitRevision, 0);
      expect(verificationCalls, 1);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );

  test(
    'restore support old membership revision is not a new Restore proof',
    () async {
      await ready();
      store.state = VerifiedStoreState.verified;
      store.verifiedBenefitRevision = 7;
      store.benefitOwnerId = Supabase.instance.client.auth.currentUser!.id;
      native.restoreError = PlatformException(code: 'storekit2_restore_failed');
      await store.restore();
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'restore_failed');
      expect(store.restoreSupportCode, 'BIL-RS-ENUM-02');
      expect(store.verifiedBenefitRevision, 7);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
    },
  );

  test(
    'restore support late native error cannot replace current ownership rejection',
    () async {
      await ready();
      verificationResponse = (_) => http.Response(
        '{"error":"purchase_owned_by_another_account"}',
        409,
        headers: {'content-type': 'application/json'},
      );
      native.restoreAction = () async {
        native.updates.add([_receipt(status: PurchaseStatus.restored)]);
        await waitForStoreCondition(
          () => store.messageCode == 'purchase_owned_by_another_account',
        );
        throw PlatformException(
          code: 'storekit2_restore_failed',
          details: _NeverDescribe(),
        );
      };
      await store.restore();
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'purchase_owned_by_another_account');
      expect(store.restoreSupportCode, isNull);
      expect(store.verifiedBenefitRevision, 0);
      expect(verificationCalls, 1);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );

  test(
    'inactive finish retry releases checkout only after acknowledgement',
    () async {
      await restoreInactiveWithFailedFinish();
      native.failCompletion = false;
      var notifications = 0;
      void changed() => notifications++;
      store.addListener(changed);
      try {
        await store.continueVerification();
        expect(store.hasPendingVerifiedFinish, isFalse);
        expect(store.state, VerifiedStoreState.ready);
        expect(store.messageCode, 'no_restorable_purchases');
        expect(store.canStartPurchase, isTrue);
        expect(notifications, greaterThan(0));
        expect(store.entitlement?.grantsPaidAccess, isNot(true));
        expect(verificationCalls, 1);
        expect(native.completionCalls, 2);
        expect(native.launches, 0);
        // Reopening the page cannot inherit the retired blocking marker.
        await store.initialize();
        expect(store.canStartPurchase, isTrue);
        native.restoreBatch = const [];
        native.purchaseLaunch.complete(true);
        await store.purchasePlan(
          CommercePlan.premium,
          term: SubscriptionTerm.oneMonth,
        );
        expect(native.launches, 1);
        expect(store.entitlement?.grantsPaidAccess, isNot(true));
      } finally {
        store.removeListener(changed);
      }
    },
  );

  test(
    'inactive finish retry failure remains blocked without re-verification',
    () async {
      await restoreInactiveWithFailedFinish();
      await store.continueVerification();
      expect(store.hasPendingVerifiedFinish, isTrue);
      expect(store.messageCode, 'store_finish_pending');
      expect(store.canStartPurchase, isFalse);
      expect(verificationCalls, 1);
      expect(native.launches, 0);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
    },
  );

  test(
    'inactive finish retry cannot replace a newer receipt rejection',
    () async {
      await restoreInactiveWithFailedFinish();
      final entered = Completer<void>();
      final held = Completer<void>();
      native.failCompletion = false;
      native.finish = () {
        if (!entered.isCompleted) entered.complete();
        return held.future;
      };
      final retry = store.continueVerification();
      String? newerFailure;
      try {
        await entered.future.timeout(const Duration(seconds: 2));
        verificationResponse = (_) => http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        );
        native.updates.add([
          _receipt(
            productId: StoreCatalogConfiguration.premiumAnnual,
            purchaseId: 'newer-rejected-while-inactive-finish-retries',
          ),
        ]);
        await waitForVerificationFailure();
        newerFailure = store.messageCode;
        expect(newerFailure, 'reconciliation_verification_failed');
      } finally {
        held.complete();
        await retry;
      }
      expect(store.hasPendingVerifiedFinish, isFalse);
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, newerFailure);
      expect(store.canStartPurchase, isFalse);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      expect(verificationCalls, 2);
      expect(native.launches, 0);
    },
  );

  test(
    'subscription callback timeout stays unresolved and cannot open a second charge',
    () async {
      store.dispose();
      store = _ConfiguredStore(
        native,
        pendingTimeout: const Duration(milliseconds: 1),
      );
      await ready();
      native.purchaseLaunch.complete(true);
      await store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'purchase_status_unknown');
      expect(store.canStartPurchase, isFalse);
      await store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      expect(native.launches, 1);
      expect(native.completionCalls, 0);
      expect(
        store.userOperationInProgress,
        isFalse,
        reason:
            'Waiting for a late native confirmation is not opening another sheet',
      );
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
        },
      ];
      await store.refreshEntitlement();
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      expect(store.messageCode, 'purchase_status_unknown');
      expect(store.canStartPurchase, isFalse);
      expect(native.launches, 1);
      verificationResponse = (_) => _verifiedSubscriptionResponse();
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'late-after-modal-confirmation',
        ),
      ]);
      await waitForStoreCondition(
        () => store.state == VerifiedStoreState.verified,
      );
      expect(store.messageCode, 'subscription_verified');
      expect(store.lastDeliveryIsUserPurchase, isTrue);
      expect(native.launches, 1);
    },
  );

  test(
    'explicit recovery retries retained receipt normally without restore, inventory or checkout',
    () async {
      store.dispose();
      final inventory = _Inventory();
      var freshReads = 0;
      store = _ConfiguredStore(
        native,
        subscriptionInventoryReader: inventory,
        freshRecoveryEntitlementReader: () async {
          freshReads++;
          return FreePlan.createState();
        },
      );
      await ready();
      verificationResponse = (_) => http.Response(
        '{"verified":false}',
        503,
        headers: {'content-type': 'application/json'},
      );
      final receipt = _receipt(
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: 'explicit-recovery-exact-receipt',
      );
      native.updates.add([receipt]);
      await waitForVerificationFailure();
      expect(store.canRecoverSubscriptionBlocker, isTrue);
      expect(store.canStartPurchase, isFalse);
      verificationResponse = (_) => http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
      await store.recoverSubscriptionBlocker();
      expect(verificationCalls, 2);
      expect(native.completionCalls, 1);
      expect(native.restoreCalls, 0);
      expect(native.appleSyncCalls, 0);
      expect(native.launches, 0);
      expect(inventory.reads, 0);
      expect(freshReads, 0);
      expect(store.canStartPurchase, isTrue);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      // A stale UI phase after the now-settled known subscription needs two
      // successful empty inventories and a new canonical verified Free read.
      store.state = VerifiedStoreState.failed;
      store.messageCode = 'reconciliation_verification_failed';
      expect(store.canRecoverSubscriptionBlocker, isTrue);
      await store.recoverSubscriptionBlocker();
      expect(inventory.reads, 1);
      expect(freshReads, 1);
      expect(
        store.canStartPurchase,
        isFalse,
        reason: 'An unverified Free fallback is never empty-history proof',
      );
      expect(store.messageCode, 'reconciliation_verification_failed');
    },
  );

  test(
    'explicit stale UI recovery needs complete proof and never launches a purchase',
    () async {
      store.dispose();
      final inventory = _Inventory();
      var freshReads = 0;
      store = _ConfiguredStore(
        native,
        subscriptionInventoryReader: inventory,
        freshRecoveryEntitlementReader: () async {
          freshReads++;
          return SubscriptionState(
            plan: CommercePlan.free,
            entitlements: FreePlan.entitlements,
            authority: EntitlementAuthority.verifiedServer,
            verifiedAt: DateTime.now().toUtc(),
            isPurchasable: false,
            canRestorePurchases: true,
          );
        },
      );
      await ready();
      verificationResponse = (_) => http.Response(
        '{"verified":false}',
        503,
        headers: {'content-type': 'application/json'},
      );
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'strict-ui-recovery-known-failed',
        ),
      ]);
      await waitForVerificationFailure();
      verificationResponse = (_) => http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
      await store.recoverSubscriptionBlocker();
      expect(store.canStartPurchase, isTrue);
      store.state = VerifiedStoreState.failed;
      store.messageCode = 'reconciliation_verification_failed';
      final revision = store.verifiedBenefitRevision;
      final finishes = native.completionCalls;
      await store.recoverSubscriptionBlocker();
      expect(inventory.reads, 2);
      expect(freshReads, 1);
      expect(store.canStartPurchase, isTrue);
      expect(store.state, VerifiedStoreState.ready);
      expect(store.verifiedBenefitRevision, revision);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      expect(verificationCalls, 2);
      expect(native.completionCalls, finishes);
      expect(native.launches, 0);
      expect(native.restoreCalls, 0);
      expect(native.appleSyncCalls, 0);
    },
  );

  test(
    'receipt rejection survives app initialization without a second checkout',
    () async {
      await ready();
      native.purchaseLaunch.complete(true);
      await store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      native.updates.add([
        _receipt(productId: StoreCatalogConfiguration.premiumMonthly),
      ]);
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await waitForVerificationFailure();
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'verification_failed');
      await store.initialize();
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'verification_failed');
      expect(store.canStartPurchase, isFalse);
      await store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      expect(native.launches, 1);
      expect(native.completionCalls, 0);
    },
  );
  test(
    'Android non-OK acknowledgement keeps committed benefit and retries same receipt',
    () async {
      await ready();
      final now = DateTime.now().toUtc();
      subscriptionRows = [
        {
          'provider': 'google',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
        },
      ];
      verificationResponse = (_) => _verifiedSubscriptionResponse();
      final previousPlatform = billing.existingOrIsolatedPurchasePlatform();
      final nativeResult = Completer<BillingResultWrapper>();
      final ackStarted = Completer<void>();
      final api = billing.NativeBillingClient()
        ..acknowledge = () {
          if (!ackStarted.isCompleted) ackStarted.complete();
          return nativeResult.future;
        };
      final platform = billing.realAndroidPlatform(api);
      InAppPurchasePlatform.instance = platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        platform.billingClientManager.dispose();
        InAppPurchasePlatform.instance = previousPlatform;
      });
      native.updates.add([billing.googleSubscription()]);
      await ackStarted.future;
      expect(store.state, VerifiedStoreState.verified);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      expect(store.verifiedBenefitRevision, 1);
      expect(verificationCalls, 1);
      nativeResult.complete(
        BillingResultWrapper(responseCode: BillingResponse.serviceUnavailable),
      );
      await drain();
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'store_finish_pending');
      expect(store.hasPendingVerifiedFinish, isTrue);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      api.acknowledge = null;
      api.response = BillingResponse.ok;
      await store.continueVerification();
      expect(store.hasPendingVerifiedFinish, isFalse);
      expect(api.acknowledgements, 2);
      expect(verificationCalls, 1, reason: 'finish retry must not recredit');
      expect(native.launches, 0);
      expect(store.verifiedBenefitRevision, 1);
    },
  );

  test(
    'durable active subscription is published before slow native finish',
    () async {
      await ready();
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
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      final finish = Completer<void>();
      native.finish = () => finish.future;
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'slow-finish-current',
        ),
      ]);
      await verificationStarted.future;
      verification.complete(_verifiedSubscriptionResponse());
      await native.completionAttempted.future;
      await drain();
      final stateBeforeFinish = store.state;
      final paidBeforeFinish = store.entitlement?.grantsPaidAccess;
      finish.complete();
      await drain();
      expect(paidBeforeFinish, isTrue);
      expect(stateBeforeFinish, VerifiedStoreState.verified);
      expect(native.completionCalls, 1);
    },
  );

  test(
    'verified native finish cannot block a distinct receipt in the same batch',
    () async {
      await ready();
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
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      verificationResponse = (_) => _verifiedSubscriptionResponse();
      final finish = Completer<void>();
      native.finish = () => finish.future;
      var verifiedBeforeFinish = 0;
      try {
        native.updates.add([
          _receipt(
            productId: StoreCatalogConfiguration.premiumMonthly,
            purchaseId: 'held-verified-acknowledgement',
          ),
          _receipt(
            productId: StoreCatalogConfiguration.premiumMonthly,
            purchaseId: 'next-distinct-transaction',
          ),
        ]);
        await native.completionAttempted.future.timeout(
          const Duration(seconds: 2),
        );
        final deadline = DateTime.now().add(const Duration(milliseconds: 500));
        while (verificationCalls < 2 && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        native.updates.add([
          _receipt(
            productId: StoreCatalogConfiguration.premiumMonthly,
            purchaseId: 'held-verified-acknowledgement',
          ),
          _receipt(
            productId: StoreCatalogConfiguration.premiumMonthly,
            purchaseId: 'next-distinct-transaction',
          ),
        ]);
        await drain();
        verifiedBeforeFinish = verificationCalls;
      } finally {
        finish.complete();
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (store.busy && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(store.busy, isFalse);
      }
      expect(
        verifiedBeforeFinish,
        2,
        reason:
            'Server verification stays serialized, but a verified native acknowledgement must not hold the next distinct receipt.',
      );
      expect(native.completionCalls, 2);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      expect(native.launches, 0);
    },
  );

  test(
    'older native finish failure preserves newer success and remains retryable',
    () async {
      await ready();
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
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      verificationResponse = (_) => _verifiedSubscriptionResponse();
      final oldFinish = Completer<void>();
      native.finish = () =>
          native.completionCalls == 1 ? oldFinish.future : Future<void>.value();
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'old-native-failure',
        ),
        _receipt(
          productId: StoreCatalogConfiguration.premiumAnnual,
          purchaseId: 'new-native-success',
        ),
      ]);
      await waitForStoreCondition(
        () =>
            native.completionCalls == 2 &&
            store.lastVerifiedProductId ==
                StoreCatalogConfiguration.premiumAnnual,
      );
      expect(verificationCalls, 2);
      expect(
        store.lastVerifiedProductId,
        StoreCatalogConfiguration.premiumAnnual,
      );
      oldFinish.completeError(StateError('fixture delayed native failure'));
      await waitForStoreCondition(() => store.hasPendingVerifiedFinish);
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'subscription_verified');
      expect(store.hasPendingVerifiedFinish, isTrue);
      await store.continueVerification();
      expect(store.hasPendingVerifiedFinish, isFalse);
      expect(
        verificationCalls,
        2,
        reason:
            'Retry acknowledges the verified receipt without another server credit.',
      );
      expect(native.completionCalls, 3);
      expect(
        store.lastVerifiedProductId,
        StoreCatalogConfiguration.premiumAnnual,
      );
    },
  );

  test(
    'simultaneous verified finish retries share one native acknowledgement',
    () async {
      await ready();
      final now = DateTime.now().toUtc();
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now.toIso8601String(),
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      native.failCompletion = true;
      native.restoreReceipt = _receipt(
        productId: StoreCatalogConfiguration.premiumMonthly,
      );
      final restoring = store.restore();
      await verificationStarted.future;
      verification.complete(_verifiedSubscriptionResponse());
      await restoring;
      expect(store.hasPendingVerifiedFinish, isTrue);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      final held = Completer<void>();
      native.failCompletion = false;
      native.finish = () => held.future;
      final first = store.continueVerification();
      final second = store.continueVerification();
      try {
        await drain();
        expect(
          native.completionCalls,
          2,
          reason: 'one failed attempt plus one shared retry',
        );
        expect(verificationCalls, 1);
        expect(native.launches, 0);
        expect(store.entitlement?.grantsPaidAccess, isTrue);
      } finally {
        held.complete();
        await Future.wait([first, second]);
      }
      expect(store.hasPendingVerifiedFinish, isFalse);
    },
  );

  test(
    'commerce race regression: retired retry does not acknowledge another queued receipt',
    () async {
      await ready();
      final now = DateTime.now().toUtc();
      subscriptionRows = [
        {
          'provider': 'apple',
          'plan_id': 'premium',
          'lifecycle': 'active',
          'verified_at': now.toIso8601String(),
          'started_at': now.toIso8601String(),
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      verificationResponse = (_) => _verifiedSubscriptionResponse();
      native.failCompletion = true;
      final receipts = [
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'retired-retry-first',
        ),
        _receipt(
          productId: StoreCatalogConfiguration.premiumAnnual,
          purchaseId: 'retired-retry-second',
        ),
      ];
      // Await each actual pending acknowledgement, rather than assuming a
      // fixed number of event-loop turns finishes asynchronous verification.
      for (var index = 0; index < receipts.length; index++) {
        final pending = Completer<void>();
        void changed() {
          if (!pending.isCompleted &&
              native.completionCalls == index + 1 &&
              store.lastVerifiedProductId == receipts[index].productID &&
              store.messageCode == 'store_finish_pending' &&
              store.hasPendingVerifiedFinish) {
            pending.complete();
          }
        }

        store.addListener(changed);
        try {
          native.updates.add([receipts[index]]);
          await pending.future.timeout(const Duration(seconds: 2));
        } finally {
          store.removeListener(changed);
        }
      }
      expect(verificationCalls, 2);
      expect(native.completionCalls, 2);
      expect(store.hasPendingVerifiedFinish, isTrue);

      final entered = Completer<void>();
      final held = Completer<void>();
      native.failCompletion = false;
      native.finish = () {
        if (!entered.isCompleted) entered.complete();
        return held.future;
      };
      final retry = store.continueVerification();
      await entered.future.timeout(const Duration(seconds: 2));
      expect(native.completionCalls, 3);
      store.dispose();
      held.completeError(StateError('fixture failure after retired visit'));
      await retry;
      expect(
        native.completionCalls,
        3,
        reason:
            'A failed old retry must stop before the next native call after disposal.',
      );
      expect(verificationCalls, 2);
      expect(native.launches, 0);
    },
  );

  Future<void> waitForStoreIdle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (store.busy) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Store purchase queue did not become idle.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  for (final product in [
    StoreCatalogConfiguration.premiumMonthly,
    StoreCatalogConfiguration.aiBoost,
  ]) {
    test(
      'passive ownership rejection stays quiet and blocked for $product',
      () async {
        await ready();
        native.updates.add([
          _receipt(
            productId: product,
            status: PurchaseStatus.restored,
            purchaseId: 'passive-other-owner',
          ),
        ]);
        await verificationStarted.future;
        verification.complete(
          http.Response(
            '{"verified":false,"error":"purchase_owned_by_another_account"}',
            409,
            headers: {'content-type': 'application/json'},
          ),
        );
        await waitForStoreIdle();
        expect(store.state, VerifiedStoreState.failed);
        expect(store.messageCode, 'reconciliation_verification_failed');
        expect(store.ownershipConflictProductId, product);
        expect(store.canStartPurchase, isFalse);
        expect(store.canRecoverSubscriptionBlocker, isFalse);
        expect(store.entitlement, isNull);
        expect(store.verifiedBenefitRevision, 0);
        expect(native.restoreCalls, 0);
        expect(native.completionCalls, 0);
        await store.purchaseBoost();
        await store.purchasePlan(
          CommercePlan.premium,
          term: SubscriptionTerm.oneMonth,
        );
        expect(native.launches, 0);
        expect(verificationCalls, 1);
      },
    );
  }

  test(
    'explicit Boost ownership rejection survives a late native launch reply',
    () async {
      await ready();
      final launch = store.purchaseBoost();
      expect(native.launches, 1);
      native.updates.add([_receipt(purchaseId: 'explicit-buy-other-owner')]);
      await verificationStarted.future;
      verification.complete(
        http.Response(
          '{"verified":false,"error":"purchase_owned_by_another_account"}',
          409,
          headers: {'content-type': 'application/json'},
        ),
      );
      await waitForStoreIdle();
      native.purchaseLaunch.complete(false);
      await launch;
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'purchase_owned_by_another_account');
      expect(
        store.ownershipConflictProductId,
        StoreCatalogConfiguration.aiBoost,
      );
      expect(store.canStartPurchase, isFalse);
      expect(store.entitlement, isNull);
      expect(store.verifiedBenefitRevision, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 1);
      expect(verificationCalls, 1);
    },
  );

  test(
    'a passive conflict cannot replace an earlier explicit Restore SKU witness',
    () async {
      await ready();
      verificationResponse = (_) => http.Response(
        '{"verified":false,"error":"purchase_owned_by_another_account"}',
        409,
        headers: {'content-type': 'application/json'},
      );
      native.restoreReceipt = _receipt(
        productId: StoreCatalogConfiguration.premiumMonthly,
        status: PurchaseStatus.restored,
        purchaseId: 'explicit-restore-other-owner',
      );
      await store.restore();
      expect(store.messageCode, 'purchase_owned_by_another_account');
      expect(
        store.ownershipConflictProductId,
        StoreCatalogConfiguration.premiumMonthly,
      );
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.aiBoost,
          status: PurchaseStatus.restored,
          purchaseId: 'later-passive-different-sku',
        ),
      ]);
      await waitForStoreIdle();
      expect(store.messageCode, 'purchase_owned_by_another_account');
      expect(
        store.ownershipConflictProductId,
        StoreCatalogConfiguration.premiumMonthly,
      );
      expect(store.canStartPurchase, isFalse);
      expect(store.canRecoverSubscriptionBlocker, isFalse);
      expect(store.entitlement, isNull);
      expect(store.verifiedBenefitRevision, 0);
      expect(native.restoreCalls, 1);
      expect(native.launches, 0);
      expect(native.completionCalls, 0);
      expect(verificationCalls, 2);
    },
  );

  testWidgets(
    'real passive ownership replay stays quiet in paid Plans and after reopening',
    (tester) async {
      try {
        final now = DateTime.now().toUtc();
        final owner = Supabase.instance.client.auth.currentUser!.id;
        final paid = const EntitlementResolver().resolve(
          record: SubscriptionRecord(
            plan: CommercePlan.premium,
            lifecycle: SubscriptionLifecycle.active,
            provider: SubscriptionProvider.apple,
            authorityVerified: true,
            startedAt: now.subtract(const Duration(days: 1)),
            currentPeriodEndsAt: now.add(const Duration(days: 1)),
            verifiedAt: now,
          ),
          now: now,
        );
        subscriptionRows = [
          {
            'provider': 'apple',
            'plan_id': 'premium',
            'lifecycle': 'active',
            'verified_at': now.toIso8601String(),
            'started_at': now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
            'grace_period_ends_at': null,
          },
        ];
        await tester.runAsync(() async {
          await ready();
          await store.refreshEntitlement();
        });
        final priorEntitlement = store.entitlement;
        expect(priorEntitlement?.grantsPaidAccess, isTrue);
        final conflict = PurchaseOwnershipConflictStore();
        final container = ProviderContainer(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (ref) => Stream.value(owner),
            ),
            verifiedEntitlementClockProvider.overrideWithValue(() => now),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () async => paid,
            ),
            purchaseOwnershipConflictStoreProvider.overrideWithValue(conflict),
          ],
        );
        addTearDown(container.dispose);
        Future<void> openPlans() async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: BilStorePlansPage(
                  store: store,
                  connectToDeviceStore: false,
                  productIds: const {StoreCatalogConfiguration.premiumMonthly},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        void expectQuietPaidPlans() {
          final offers = tester.widget<BilDynamicStoreOffers>(
            find.byType(BilDynamicStoreOffers),
          );
          expect(find.text('Current plan: Premium'), findsOneWidget);
          expect(
            find.byKey(const Key('store-current-plan-continue')),
            findsOneWidget,
          );
          expect(offers.purchaseStatusMessage, isNull);
          expect(offers.purchaseStatusIsError, isFalse);
          expect(offers.blockedPurchaseKinds, isEmpty);
          expect(
            find.text(
              BilStoreCopy.text('en', 'purchase_owned_by_another_account'),
            ),
            findsNothing,
          );
          expect(conflict.blockedKinds, isEmpty);
        }

        try {
          await openPlans();
          expectQuietPaidPlans();
          await tester.runAsync(() async {
            native.updates.add([
              _receipt(
                productId: StoreCatalogConfiguration.premiumMonthly,
                status: PurchaseStatus.restored,
                purchaseId: 'paid-member-passive-other-owner',
              ),
            ]);
            await verificationStarted.future;
            verification.complete(
              http.Response(
                '{"verified":false,"error":"purchase_owned_by_another_account"}',
                409,
                headers: {'content-type': 'application/json'},
              ),
            );
            await waitForStoreIdle();
          });
          await tester.pumpAndSettle();
          expect(store.state, VerifiedStoreState.failed);
          expect(store.messageCode, 'reconciliation_verification_failed');
          expect(
            store.ownershipConflictProductId,
            StoreCatalogConfiguration.premiumMonthly,
          );
          expect(store.entitlement, same(priorEntitlement));
          expect(store.entitlement?.grantsPaidAccess, isTrue);
          expect(store.verifiedBenefitRevision, 0);
          expect(store.canStartPurchase, isFalse);
          expectQuietPaidPlans();
          await tester.pumpWidget(const SizedBox.shrink());
          await openPlans();
          expectQuietPaidPlans();
          expect(native.restoreCalls, 0);
          expect(native.launches, 0);
          expect(native.completionCalls, 0);
          expect(verificationCalls, 1);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await tester.pump();
        }
      } finally {
        // Widget invariants run before the file's package:test tearDown.
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

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

  // A fixed count of microtask drains is insufficient under parallel CI.
  // Poll the observable native handoff with a strict deadline instead.
  Future<void> waitForNativeLaunch() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (native.launches == 0) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Native purchase launch was never requested.');
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
  test(
    'real catalog launch may still await native completion after its exact receipt verified',
    () async {
      await ready();
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
          'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
          'grace_period_ends_at': null,
        },
      ];
      var returned = false;
      final launch = VerifiedStoreCatalogAdapter(store)
          .requestPurchase(
            const BilStoreOfferMetadata(
              productId: StoreCatalogConfiguration.premiumMonthly,
              kind: BilStoreProductKind.premiumSubscription,
              localizedTitle: 'Premium',
              localizedPrice: '2.49',
              currencyCode: 'USD',
              priceMicros: 2490000,
              billingPeriodIso8601: 'P1M',
            ),
          )
          .then((_) => returned = true);
      await waitForNativeLaunch();
      expect(store.state, VerifiedStoreState.purchasePending);
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'verified-before-native-launch-completion',
        ),
      ]);
      await verificationStarted.future;
      // This diagnostic asserts the authenticated v2 delivery identity, not
      // only the legacy verified/active flags used by other receipt fixtures.
      verification.complete(
        http.Response(
          jsonEncode({
            'verified': true,
            'entitlement_active': true,
            'delivery': {
              'version': 2,
              'owner_id': Supabase.instance.client.auth.currentUser!.id,
              'product_id': StoreCatalogConfiguration.premiumMonthly,
              'store': 'app_store',
              'environment': 'sandbox',
              'event_key': List.filled(64, 'd').join(),
              'kind': 'subscription',
              'verified_at': now.toIso8601String(),
              'active': true,
              'finish_pending': false,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await native.completionAttempted.future;
      await drain();

      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'subscription_verified');
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      expect(store.lastDeliveryIsUserPurchase, isTrue);
      expect(
        store.lastDelivery?.productId,
        StoreCatalogConfiguration.premiumMonthly,
      );
      expect(
        store.lastDelivery?.ownerId,
        Supabase.instance.client.auth.currentUser!.id,
      );
      expect(store.lastDelivery?.eventKey, List.filled(64, 'd').join());
      expect(store.busy, isFalse);
      expect(
        returned,
        isFalse,
        reason:
            'The page request Future is a separate native lifecycle, not receipt authority',
      );

      native.purchaseLaunch.complete(true);
      await launch;
      expect(returned, isTrue);
      expect(store.state, VerifiedStoreState.verified);
      expect(native.launches, 1);
      expect(verificationCalls, 1);
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
        await native.completionAttempted.future.timeout(
          const Duration(seconds: 2),
        );
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
        await waitForNativeLaunch();
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
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'store_finish_pending');
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
      expect(store.messageCode, 'reconciliation_verification_failed');
      expect(store.userOperationInProgress, isFalse);
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

  // These two cases intentionally differ only in how the
  // identical expired receipt became verified+finished before the held query.
  // No drain()/microtask count/physical StoreKit calls are used for ordering.
  for (final seededByPreflight in [false, true]) {
    test('IOS_REPLAY_COUNTEREXAMPLE settled expired receipt from '
        '${seededByPreflight ? "unfinished-preflight" : "observer-control"} '
        'does not retire one held-quote checkout', () async {
      store.dispose();
      await native.updates.close();
      native.completionChanges.dispose();
      final held = _IosHeldFreshQueryNative();
      native = held;
      store = _ConfiguredStore(native);
      await ready();
      final stableQuote = await native.productResponse.future;
      final owner = Supabase.instance.client.auth.currentUser!.id;
      var finished = false;
      var nativeFinishInFlight = false;
      var finishedCount = 0;
      final verifiedNativeFinish = Completer<void>();
      native.finish = () async {
        nativeFinishInFlight = true;
        held.events.add('finish-${++finishedCount}-started');
        finished = true;
        nativeFinishInFlight = false;
        held.events.add('finish-$finishedCount-ended');
        if (!verifiedNativeFinish.isCompleted) verifiedNativeFinish.complete();
      };
      verificationResponse = (_) {
        held.events.add('expired-verification-$verificationCalls');
        return http.Response(
          '{"verified":true,"entitlement_active":false}',
          200,
          headers: {'content-type': 'application/json'},
        );
      };
      const unfinishedChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.unfinishedTransactions',
        sk2.InAppPurchase2API.pigeonChannelCodec,
      );
      var nativeInventoryReads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(unfinishedChannel, (_) async {
            nativeInventoryReads++;
            return <Object?>[
              <Object?>[
                if (seededByPreflight && !finished)
                  sk2.SK2TransactionMessage(
                    id: 123,
                    originalId: 123,
                    productId: StoreCatalogConfiguration.premiumMonthly,
                    purchaseDate: 1,
                    receiptData: 'signed-expired-identical-fixture',
                    status: sk2.SK2PurchaseStatusMessage.purchased,
                  ),
              ],
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(unfinishedChannel, null),
      );
      // Exactly the same source/product/purchaseID/status/JWS as the direct
      // unfinished preflight. A changed payload/status is not needed to make
      // this counterexample; the control detects false dedup assumptions.
      final old = SK2PurchaseDetails(
        productID: StoreCatalogConfiguration.premiumMonthly,
        purchaseID: '123',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'signed-expired-identical-fixture',
          source: 'app_store',
        ),
        transactionDate: '1',
        status: PurchaseStatus.purchased,
        appAccountToken: null,
      );
      if (!seededByPreflight) {
        native.updates.add([old]);
        await verifiedNativeFinish.future.timeout(const Duration(seconds: 2));
        // This observed public idle gate proves the ordinary receipt queue
        // and native acknowledgement settled, rather than guessing drains.
        await waitForStoreCondition(() => store.canStartPurchase);
        expect(verificationCalls, 1);
        expect(native.completionCalls, 1);
      }
      held.beforeLaunch = () {
        expect(Supabase.instance.client.auth.currentUser!.id, owner);
        expect(finished, isTrue);
        expect(nativeFinishInFlight, isFalse);
        expect(store.hasPendingVerifiedFinish, isFalse);
        expect(store.entitlement?.grantsPaidAccess, isNot(true));
      };
      native.purchaseLaunch.complete(false); // No simulated payment outcome.
      final checkout = store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      await held.freshQueryReached.future.timeout(const Duration(seconds: 2));
      await verifiedNativeFinish.future.timeout(const Duration(seconds: 2));
      expect(finished, isTrue);
      expect(verificationCalls, 1);
      expect(native.completionCalls, 1);
      expect(native.launches, 0);
      held.events.add('identical-observer-replay-enqueued');
      native.updates.add([
        old,
      ]); // synchronous enqueue; known order before quote.
      held.events.add('stable-quote-released');
      held.releaseFreshQuery.complete(stableQuote);
      await checkout.timeout(const Duration(seconds: 3));
      await waitForStoreCondition(() => !store.busy);
      // Regression: direct unfinished preflight previously omitted settled
      // replay reservation. An identical observer then retired this held
      // query's user intent. Both receipt paths must now launch exactly once.
      expect(
        held.events.indexOf('identical-observer-replay-enqueued'),
        lessThan(held.events.indexOf('stable-quote-released')),
      );
      expect(nativeInventoryReads, greaterThanOrEqualTo(1));
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      expect(native.restoreCalls, 0);
      expect(
        native.launches,
        1,
        reason:
            'Same owner, same quote, already verified inactive+finished '
            'historical receipt must not silently consume the user intent. '
            'Observed order: ${held.events}; verifications=$verificationCalls; '
            'completions=${native.completionCalls}; state=${store.state}; '
            'code=${store.messageCode}',
      );
      if (!seededByPreflight) {
        expect(
          verificationCalls,
          1,
          reason:
              'Ordinary settled fingerprint dedup must precede generation increment.',
        );
        expect(native.completionCalls, 1);
      }
    });
  }

  // Supporting guard matrix. Same real service, same held-query
  // native hook as IOS_REPLAY_COUNTEREXAMPLE; never run against device/network.
  Future<
    ({
      _IosHeldFreshQueryNative held,
      ProductDetailsResponse quote,
      Future<void> checkout,
      String owner,
    })
  >
  beginHeldQueryAfterVerifiedInactivePreflight() async {
    store.dispose();
    await native.updates.close();
    native.completionChanges.dispose();
    final held = _IosHeldFreshQueryNative();
    native = held;
    store = _ConfiguredStore(native);
    await ready();
    final quote = await native.productResponse.future;
    final owner = Supabase.instance.client.auth.currentUser!.id;
    var finished = false;
    final finishObserved = Completer<void>();
    native.finish = () async {
      finished = true;
      held.events.add('verified-inactive-native-finish');
      if (!finishObserved.isCompleted) finishObserved.complete();
    };
    verificationResponse = (_) => http.Response(
      '{"verified":true,"entitlement_active":false}',
      200,
      headers: {'content-type': 'application/json'},
    );
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.unfinishedTransactions',
      sk2.InAppPurchase2API.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          channel,
          (_) async => <Object?>[
            <Object?>[
              if (!finished)
                sk2.SK2TransactionMessage(
                  id: 123,
                  originalId: 123,
                  productId: StoreCatalogConfiguration.premiumMonthly,
                  purchaseDate: 1,
                  receiptData: 'signed-expired-negative-guard-fixture',
                  status: sk2.SK2PurchaseStatusMessage.purchased,
                ),
            ],
          ],
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, null),
    );
    native.purchaseLaunch.complete(false);
    final checkout = store.purchasePlan(
      CommercePlan.premium,
      term: SubscriptionTerm.oneMonth,
    );
    await held.freshQueryReached.future.timeout(const Duration(seconds: 2));
    await finishObserved.future.timeout(const Duration(seconds: 2));
    expect(finished, isTrue);
    expect(verificationCalls, 1);
    expect(native.completionCalls, 1);
    expect(native.launches, 0);
    return (held: held, quote: quote, checkout: checkout, owner: owner);
  }

  for (final guard in [
    'fresh-active',
    'fresh-pending',
    'verification-failed',
    'owner-ABA',
    'quote-change',
  ]) {
    test(
      'IOS_REPLAY_FENCES $guard still aborts the held original intent',
      () async {
        final gate = await beginHeldQueryAfterVerifiedInactivePreflight();
        final originalVisit = store.captureCatalogVisit();
        var releasedQuote = gate.quote;
        if (guard == 'fresh-active') {
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
          verificationResponse = (_) => http.Response(
            '{"verified":true,"entitlement_active":true}',
            200,
            headers: {'content-type': 'application/json'},
          );
          native.updates.add([
            _receipt(
              productId: StoreCatalogConfiguration.premiumMonthly,
              purchaseId: '124-new-active-not-an-old-replay',
              verificationData: 'signed-new-active-guard-fixture',
            ),
          ]);
          await waitForStoreCondition(
            () => store.entitlement?.grantsPaidAccess == true,
          );
        } else if (guard == 'fresh-pending') {
          native.updates.add([
            _receipt(
              productId: StoreCatalogConfiguration.premiumMonthly,
              purchaseId: '124-new-pending-not-an-old-replay',
              status: PurchaseStatus.pending,
            ),
          ]);
          await waitForStoreCondition(
            () =>
                store.state == VerifiedStoreState.purchasePending &&
                store.messageCode == 'reconciliation_pending',
          );
          expect(
            verificationCalls,
            1,
          ); // Pending must never be verified/finished.
          expect(native.completionCalls, 1);
        } else if (guard == 'verification-failed') {
          verificationResponse = (_) => http.Response(
            '{"verified":false}',
            200,
            headers: {'content-type': 'application/json'},
          );
          native.updates.add([
            _receipt(
              productId: StoreCatalogConfiguration.premiumMonthly,
              purchaseId: '124-unverified-not-an-old-settled-replay',
              verificationData: 'unverified-guard-fixture',
            ),
          ]);
          await waitForStoreCondition(
            () => store.state == VerifiedStoreState.failed,
          );
          expect(store.messageCode, 'reconciliation_verification_failed');
          expect(
            native.completionCalls,
            1,
          ); // Unverified receipt never finishes.
        } else if (guard == 'owner-ABA') {
          final owners = <String>[];
          var previous = gate.owner;
          final delivered = Completer<void>();
          final listener = Supabase.instance.client.auth.onAuthStateChange
              .listen((event) {
                final id = event.session?.user.id;
                if (id == null || id == previous) return;
                previous = id;
                owners.add(id);
                if (owners.length == 2 && !delivered.isCompleted) {
                  delivered.complete();
                }
              });
          try {
            for (final owner in [
              '00000000-0000-4000-8000-000000000002',
              gate.owner,
            ]) {
              await Supabase.instance.client.auth.setInitialSession(
                jsonEncode({
                  'access_token': 'synthetic-external-guard-test',
                  'token_type': 'bearer',
                  'user': {
                    'id': owner,
                    'app_metadata': {},
                    'user_metadata': {},
                    'aud': 'authenticated',
                    'created_at': '2026-01-01T00:00:00Z',
                  },
                }),
              );
            }
            await delivered.future.timeout(const Duration(seconds: 2));
            expect(owners, [
              '00000000-0000-4000-8000-000000000002',
              gate.owner,
            ]);
            expect(Supabase.instance.client.auth.currentUser!.id, gate.owner);
            expect(
              store.isCurrentCatalogVisit(originalVisit),
              isFalse,
              reason:
                  'Returning to the same UID must not revive the old visit.',
            );
          } finally {
            await listener.cancel();
          }
        } else if (guard == 'quote-change') {
          final changed = AppStoreProduct2Details.fromSK2Product(
            SK2Product(
              id: StoreCatalogConfiguration.premiumMonthly,
              displayName: 'Premium',
              description: 'Fixture',
              displayPrice: '3.49',
              price: 3.49,
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
          );
          releasedQuote = ProductDetailsResponse(
            productDetails: [changed],
            notFoundIDs: const [],
          );
        }
        gate.held.events.add('guard-$guard-established-before-quote-release');
        gate.held.releaseFreshQuery.complete(releasedQuote);
        await gate.checkout.timeout(const Duration(seconds: 3));
        if (guard != 'fresh-pending') {
          await waitForStoreCondition(() => !store.busy);
        }
        expect(
          native.launches,
          0,
          reason:
              'Do not ignore a real $guard invalidation to fix old replay. '
              'Order: ${gate.held.events}',
        );
        expect(native.restoreCalls, 0);
        if (guard == 'fresh-active') {
          expect(store.entitlement?.grantsPaidAccess, isTrue);
          expect(store.state, VerifiedStoreState.verified);
          expect(store.messageCode, 'subscription_verified');
        } else {
          expect(store.entitlement?.grantsPaidAccess, isNot(true));
        }
        if (guard == 'fresh-pending') {
          expect(store.state, VerifiedStoreState.purchasePending);
          expect(store.canStartPurchase, isFalse);
        }
        if (guard == 'verification-failed') {
          expect(store.canStartPurchase, isFalse);
          expect(native.completionCalls, 1);
        }
        if (guard == 'owner-ABA') {
          expect(store.messageCode, 'authentication_required');
          expect(store.isCurrentCatalogVisit(originalVisit), isFalse);
        }
        if (guard == 'quote-change') {
          expect(store.messageCode, 'store_catalog_changed');
          expect(verificationCalls, 1);
        }
      },
    );
  }

  // Direct preflight must not mark an unresolved or retired
  // native acknowledgement as settled merely to suppress observer generation.
  for (final ownerRetiresDuringFinish in [false, true]) {
    test('IOS_PREFLIGHT_FINISH_GUARD '
        '${ownerRetiresDuringFinish ? "ownerABA-during-finish" : "finish-failure"} '
        'does not publish settled replay or launch checkout', () async {
      await ready();
      final owner = Supabase.instance.client.auth.currentUser!.id;
      const signed = 'signed-expired-finish-guard-fixture';
      final replayKey = storeReceiptReplayKey(
        ownerId: owner,
        source: 'app_store',
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: '123',
        status: PurchaseStatus.purchased.name,
        verificationData: signed,
      );
      var finished = false;
      final finishPermit = Completer<void>();
      if (ownerRetiresDuringFinish) {
        native.finish = () async {
          await finishPermit.future;
          finished = true;
        };
      } else {
        native.failCompletion = true;
      }
      verificationResponse = (_) => http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.unfinishedTransactions',
        sk2.InAppPurchase2API.pigeonChannelCodec,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            channel,
            (_) async => <Object?>[
              <Object?>[
                if (!finished)
                  sk2.SK2TransactionMessage(
                    id: 123,
                    originalId: 123,
                    productId: StoreCatalogConfiguration.premiumMonthly,
                    purchaseDate: 1,
                    receiptData: signed,
                    status: sk2.SK2PurchaseStatusMessage.purchased,
                  ),
              ],
            ],
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(channel, null),
      );
      native.purchaseLaunch.complete(false);
      final checkout = store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      await native.completionAttempted.future.timeout(
        const Duration(seconds: 2),
      );
      if (ownerRetiresDuringFinish) {
        final delivered = Completer<void>();
        final owners = <String>[];
        var previous = owner;
        final listener = Supabase.instance.client.auth.onAuthStateChange.listen(
          (event) {
            final id = event.session?.user.id;
            if (id == null || id == previous) return;
            previous = id;
            owners.add(id);
            if (owners.length == 2 && !delivered.isCompleted) {
              delivered.complete();
            }
          },
        );
        try {
          for (final id in ['00000000-0000-4000-8000-000000000002', owner]) {
            await Supabase.instance.client.auth.setInitialSession(
              jsonEncode({
                'access_token': 'synthetic-external-preflight-finish-guard',
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
          }
          await delivered.future.timeout(const Duration(seconds: 2));
          expect(owners, ['00000000-0000-4000-8000-000000000002', owner]);
        } finally {
          await listener.cancel();
          if (!finishPermit.isCompleted) finishPermit.complete();
        }
      }
      await checkout.timeout(const Duration(seconds: 6));
      expect(native.launches, 0);
      expect(native.restoreCalls, 0);
      expect(
        native.queries,
        1,
        reason:
            'No fresh checkout price request before unresolved finish/retired visit.',
      );
      expect(verificationCalls, 1);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      expect(
        StoreVerificationRequestPolicy.shared.isSettledReplay(replayKey),
        isFalse,
        reason:
            'Verified inactive alone is insufficient: native finish must '
            'be acknowledged while its original owner visit remains current.',
      );
      if (ownerRetiresDuringFinish) {
        expect(store.messageCode, 'authentication_required');
        expect(Supabase.instance.client.auth.currentUser!.id, owner);
      } else {
        expect(store.hasPendingVerifiedFinish, isTrue);
        expect(store.messageCode, 'store_finish_pending');
        expect(store.canStartPurchase, isFalse);
      }
    });
  }

  test('expired unfinished preflight waits for verified native finish', () async {
    await ready();
    final finish = Completer<void>();
    var finished = false;
    var reads = 0;
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.unfinishedTransactions',
      sk2.InAppPurchase2API.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, (_) async {
          reads++;
          return <Object?>[
            <Object?>[
              if (!finished)
                sk2.SK2TransactionMessage(
                  id: 123,
                  originalId: 123,
                  productId: StoreCatalogConfiguration.premiumMonthly,
                  purchaseDate: 1,
                  receiptData: 'signed-expired-fixture',
                  status: sk2.SK2PurchaseStatusMessage.purchased,
                ),
            ],
          ];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, null),
    );
    verificationResponse = (_) => http.Response(
      '{"verified":true,"entitlement_active":false}',
      200,
      headers: {'content-type': 'application/json'},
    );
    native.finish = () async {
      await finish.future;
      finished = true;
    };
    native.purchaseLaunch.complete(false);
    final checkout = store.purchasePlan(
      CommercePlan.premium,
      term: SubscriptionTerm.oneMonth,
    );
    await native.completionAttempted.future;
    await drain();
    final readsDuringFinish = reads;
    final launchesDuringFinish = native.launches;
    await store.purchasePlan(
      CommercePlan.premium,
      term: SubscriptionTerm.oneMonth,
    );
    finish.complete();
    await checkout;
    expect(
      readsDuringFinish,
      1,
      reason:
          'unfinished state cannot be re-read before verified finish settles',
    );
    expect(launchesDuringFinish, 0);
    expect(native.launches, 1);
    expect(native.completionCalls, 1);
    expect(verificationCalls, 1);
    expect(store.entitlement?.grantsPaidAccess ?? false, isFalse);
    expect(store.messageCode, 'purchase_not_started');
  });

  test(
    'expired renewal backlog finishes every verified receipt before checkout',
    () async {
      await ready();
      const backlogSize = 12;
      var finished = 0;
      var reads = 0;
      const channel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.in_app_purchase_storekit.InAppPurchase2API.unfinishedTransactions',
        sk2.InAppPurchase2API.pigeonChannelCodec,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, (_) async {
            reads++;
            return <Object?>[
              <Object?>[
                for (var index = finished; index < backlogSize; index++)
                  sk2.SK2TransactionMessage(
                    id: 1000 + index,
                    originalId: 1000,
                    productId: StoreCatalogConfiguration.premiumMonthly,
                    purchaseDate: 1.0 + index,
                    receiptData: 'signed-expired-renewal-$index',
                    status: sk2.SK2PurchaseStatusMessage.purchased,
                  ),
              ],
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(channel, null),
      );
      verificationResponse = (_) => http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
      native.finish = () async {
        expect(
          reads,
          1,
          reason: 'Do not re-read unfinished receipts mid-finish',
        );
        expect(
          native.launches,
          0,
          reason: 'No checkout before backlog settlement',
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));
        finished++;
      };
      native.purchaseLaunch.complete(false);
      await store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      expect(finished, backlogSize);
      expect(native.completionCalls, backlogSize);
      expect(verificationCalls, backlogSize);
      expect(reads, 2);
      expect(native.launches, 1);
      expect(store.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(store.messageCode, 'purchase_not_started');
    },
  );

  test(
    'stalled explicit restore ends waiting without duplicate native sync',
    () async {
      store.dispose();
      store = _ConfiguredStore(
        native,
        pendingTimeout: const Duration(milliseconds: 5),
      );
      await ready();
      final sync = Completer<void>();
      native.appleSync = () => sync.future;
      native.restoreBatch = [];
      var returned = false;
      final restoring = store.restore().then((_) => returned = true);
      await Future.any<void>([
        restoring,
        Future<void>.delayed(const Duration(milliseconds: 80)),
      ]);
      final returnedBeforeNative = returned;
      final busyBeforeNative = store.busy;
      final codeBeforeNative = store.messageCode;
      final mayPurchaseBeforeNative = store.canStartPurchase;
      await store.initialize();
      expect(
        store.messageCode,
        'purchase_status_unknown',
        reason: 're-entering Plans must retain an actionable unresolved result',
      );
      // A retry observes the same App Store operation; it must not open another
      // authentication sheet while the first native operation is unresolved.
      final retry = store.restore();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      final syncCallsBeforeNative = native.appleSyncCalls;
      sync.complete();
      await restoring;
      await retry;
      expect(returnedBeforeNative, isTrue);
      expect(busyBeforeNative, isFalse);
      expect(codeBeforeNative, 'purchase_status_unknown');
      expect(mayPurchaseBeforeNative, isFalse);
      expect(syncCallsBeforeNative, 1);
      expect(native.restoreCalls, 1);
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
    'real catalog adapter does not claim an empty history from silent iOS restore',
    () async {
      native.restoreBatch = const [];
      await ready();

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(native.appleSyncCalls, 1);
      expect(native.restoreCalls, 1);
      expect(store.messageCode, 'restore_unconfirmed');
      expect(store.state, VerifiedStoreState.ready);
      expect(store.busy, isFalse);
      expect(store.canStartPurchase, isTrue);
      expect(store.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(store.verifiedBenefitRevision, 0);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'real catalog adapter maps wrapped Apple authentication cancellation neutrally',
    () async {
      native.appleSync = () async {
        throw PlatformException(
          code: 'storekit2_failed_to_sync_to_app_store',
          message: 'Storekit has failed to sync to the app store.',
          details: 'userCancelled',
        );
      };
      await ready();

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(native.restoreCalls, 0);
      expect(store.messageCode, 'restore_cancelled');
      expect(store.restoreSupportCode, isNull);
      expect(store.state, VerifiedStoreState.ready);
      expect(store.busy, isFalse);
      expect(store.canStartPurchase, isTrue);
      expect(store.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(store.verifiedBenefitRevision, 0);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'empty iOS restore retains existing paid access but cannot clear another receipt ownership rejection',
    () async {
      await ready();
      native.restoreBatch = const [];
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
      expect(store.entitlement?.grantsPaidAccess, isTrue);

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(store.messageCode, 'restore_unconfirmed');
      expect(store.state, VerifiedStoreState.verified);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      store.state = VerifiedStoreState.failed;
      store.messageCode = 'purchase_owned_by_another_account';

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(store.messageCode, 'purchase_owned_by_another_account');
      expect(store.state, VerifiedStoreState.failed);
      expect(store.canStartPurchase, isFalse);
      expect(store.entitlement?.grantsPaidAccess, isTrue);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'explicit restore stream cancellation is not an empty checked history',
    () async {
      native.restoreReceipt = _receipt(status: PurchaseStatus.canceled);
      await ready();

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(store.messageCode, 'restore_cancelled');
      expect(store.restoreSupportCode, isNull);
      expect(store.state, VerifiedStoreState.ready);
      expect(store.busy, isFalse);
      expect(store.canStartPurchase, isTrue);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'native restore cancellation after sync leaves a retryable neutral result',
    () async {
      native.restoreError = PlatformException(code: 'payment_cancelled');
      await ready();

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(native.appleSyncCalls, 1);
      expect(native.restoreCalls, 1);
      expect(store.messageCode, 'restore_cancelled');
      expect(store.canStartPurchase, isTrue);
      expect(verificationCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'a pending restored callback remains unresolved instead of claiming no purchases',
    () async {
      native.restoreReceipt = _receipt(status: PurchaseStatus.pending);
      await ready();

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'purchase_status_unknown');
      expect(store.canStartPurchase, isFalse);
      expect(store.busy, isFalse);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'cancelled or unconfirmed restore cannot remove unresolved receipt blockers',
    () async {
      await ready();
      for (final cancelled in [true, false]) {
        for (final code in [
          'verification_failed',
          'restore_verification_failed',
          'reconciliation_verification_failed',
          'purchase_status_unknown',
          'purchase_owned_by_another_account',
          'store_finish_pending',
        ]) {
          store.state = code == 'store_finish_pending'
              ? VerifiedStoreState.ready
              : VerifiedStoreState.failed;
          store.messageCode = code;
          native.appleSync = cancelled
              ? () async => throw PlatformException(code: 'user_cancelled')
              : null;
          native.restoreBatch = const [];

          await VerifiedStoreCatalogAdapter(store).restorePurchases();

          expect(store.messageCode, code, reason: '$code cancelled=$cancelled');
          expect(store.canStartPurchase, isFalse);
          expect(store.busy, isFalse);
          expect(store.entitlement?.grantsPaidAccess ?? false, isFalse);
        }
      }
      expect(store.verifiedBenefitRevision, 0);
      expect(verificationCalls, 0);
      expect(native.completionCalls, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'unrecognized Apple sync error is not disguised as user cancellation',
    () async {
      native.appleSync = () async {
        throw PlatformException(
          code: 'storekit2_failed_to_sync_to_app_store',
          details: 'Network unavailable; cancellation status is unknown',
        );
      };
      await ready();

      await VerifiedStoreCatalogAdapter(store).restorePurchases();

      expect(store.messageCode, 'restore_failed');
      expect(store.state, VerifiedStoreState.failed);
      expect(store.canStartPurchase, isFalse);
      expect(native.restoreCalls, 0);
      expect(verificationCalls, 0);
    },
  );
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
    'settled exact passive receipts verify once; a changed signed payload rechecks',
    () async {
      await ready();
      verificationResponse = (_) => http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
      final receipt = _receipt(
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: 'settled-passive',
      );
      native.updates.add([receipt]);
      await waitForStoreCondition(
        () => !store.busy && native.completionCalls == 1,
      );
      expect(verificationCalls, 1);
      native.updates.add([receipt]);
      await drain();
      expect(verificationCalls, 1);
      expect(native.completionCalls, 1);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'settled-passive',
          verificationData: 'fixture-new-signed-revocation',
        ),
      ]);
      await waitForStoreCondition(
        () => !store.busy && native.completionCalls == 2,
      );
      expect(verificationCalls, 2);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
    },
  );

  test(
    'acknowledgement failure replays only native finish, then becomes settled',
    () async {
      await ready();
      native.failCompletion = true;
      verificationResponse = (_) => http.Response(
        '{"verified":true,"entitlement_active":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
      final receipt = _receipt(
        productId: StoreCatalogConfiguration.premiumMonthly,
        purchaseId: 'ack-only-passive',
      );
      native.updates.add([receipt]);
      await waitForStoreCondition(
        () => !store.busy && store.hasPendingVerifiedFinish,
      );
      expect(verificationCalls, 1);
      native.updates.add([receipt]);
      await waitForStoreCondition(() => native.completionCalls >= 2);
      expect(verificationCalls, 1);
      expect(store.hasPendingVerifiedFinish, isTrue);
      native.failCompletion = false;
      await store.continueVerification();
      expect(store.hasPendingVerifiedFinish, isFalse);
      final completed = native.completionCalls;
      native.updates.add([receipt]);
      await drain();
      expect(verificationCalls, 1);
      expect(native.completionCalls, completed);
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
    },
  );

  test(
    '429 pauses distinct passive receipts and explicit Restore before native billing',
    () async {
      await ready();
      verificationResponse = (_) => http.Response(
        '{"error":"rate_limited","verified":false,"entitlement_active":false,"retry_after_seconds":3600}',
        429,
        headers: {'content-type': 'application/json'},
      );
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'quota-first',
        ),
      ]);
      await waitForStoreCondition(
        () => !store.busy && store.state == VerifiedStoreState.failed,
      );
      expect(verificationCalls, 1);
      expect(store.verificationBackedOff, isTrue);
      expect(store.userOperationInProgress, isFalse);
      expect(store.canStartPurchase, isFalse);
      native.updates.add([
        _receipt(
          productId: StoreCatalogConfiguration.premiumMonthly,
          purchaseId: 'quota-distinct',
        ),
      ]);
      await drain();
      expect(verificationCalls, 1);
      await store.restore();
      expect(verificationCalls, 1);
      expect(native.restoreCalls, 0);
      expect(native.appleSyncCalls, 0);
      expect(store.messageCode, 'restore_verification_failed');
      expect(store.entitlement?.grantsPaidAccess, isNot(true));
      expect(native.launches, 0);
    },
  );

  test(
    'deduplicates a queued failed transaction but permits a new purchase id',
    () async {
      await ready();
      final replayed = _receipt(purchaseId: 'replayed-transaction');

      native.updates.add([replayed, replayed]);
      await verificationStarted.future.timeout(const Duration(seconds: 2));
      expect(verificationCalls, 1);

      // This is a second StoreKit stream delivery while the first verification
      // remains in flight. It must not become a second server request.
      native.updates.add([replayed]);
      expect(verificationCalls, 1);

      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      // A response completer releases the mock HTTP response, not the real
      // service's async verification/queue. Observe its terminal receipt state.
      await waitForStoreCondition(
        () => store.state == VerifiedStoreState.failed && !store.busy,
      );
      expect(verificationCalls, 1);
      expect(native.completionCalls, 0);

      // A distinct platform transaction is never covered by the replay key.
      verification = Completer<http.Response>();
      verificationStarted = Completer<void>();
      native.updates.add([_receipt(purchaseId: 'new-transaction')]);
      await verificationStarted.future.timeout(const Duration(seconds: 2));
      expect(verificationCalls, 2);
      expect(store.busy, isTrue);
      expect(native.completionCalls, 0);
      verification.complete(
        http.Response(
          '{"verified":false}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await waitForStoreCondition(
        () => store.state == VerifiedStoreState.failed && !store.busy,
      );
      expect(verificationCalls, 2);
      expect(native.completionCalls, 0);
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
      await waitForNativeLaunch();
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
      await waitForStoreIdle();
      expect(verificationCalls, 1);
      expect(store.state, VerifiedStoreState.failed);
      expect(store.messageCode, 'reconciliation_verification_failed');

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
      await waitForStoreIdle();
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
      await waitForStoreIdle();

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

      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue(
            '00000000-0000-4000-8000-000000000001',
          ),
          appSubscriptionPurchaseFactoryProvider.overrideWithValue(() => store),
        ],
      );
      addTearDown(container.dispose);
      container.listen(appSubscriptionPurchaseProvider, (_, _) {});
      container.listen(verifiedPurchaseHandoffProvider, (_, _) {});
      final nativeFinish = Completer<void>();
      native.finish = () => nativeFinish.future;

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
      await native.completionAttempted.future;
      await drain();
      expect(nativeFinish.isCompleted, isFalse);
      expect(
        container.read(verifiedPurchaseHandoffProvider)?.plan,
        CommercePlan.free,
        reason:
            'authoritative revocation must reach readers before native finish',
      );
      expect(native.completionCalls, 1);
      nativeFinish.complete();
      await restoring;
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

  for (final status in <int>[409, 429, 500, 503]) {
    test(
      'verification HTTP $status stays fail closed and unacknowledged',
      () async {
        await ready();
        native.updates.add([_receipt(purchaseId: 'fault-$status')]);
        await verificationStarted.future;
        verification.complete(
          http.Response(
            '{"verified":false,"error":"injected_http_$status"}',
            status,
            headers: {'content-type': 'application/json'},
          ),
        );
        await waitForStoreIdle();
        expect(store.state, VerifiedStoreState.failed);
        expect(store.entitlement, isNull);
        expect(native.completionCalls, 0);
        expect(verificationCalls, 1);
      },
    );
  }

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
