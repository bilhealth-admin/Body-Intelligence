import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Real service with only controlled callback timing. Every
// store callback and HTTP response is in memory; no native/cloud API is called.
class NativeFixture extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  final queried = Completer<void>();
  final catalog = Completer<ProductDetailsResponse>();
  int queries = 0, finishes = 0, finished = 0, launches = 0;
  Future<void> Function()? finish;
  bool failFinish = false;
  String storeCountry = 'EGY';
  int countryReads = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> countryCode() async {
    countryReads++;
    return storeCountry;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    queries++;
    if (!queried.isCompleted) queried.complete();
    return catalog.future;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
    await finish?.call();
    if (failFinish) throw StateError('Synthetic native finish failure');
    finished++;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    launches++;
    return false;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    launches++;
    return false;
  }

  void settleCatalog() => catalog.complete(
    ProductDetailsResponse(
      productDetails: [
        AppStoreProduct2Details.fromSK2Product(
          SK2Product(
            id: StoreCatalogConfiguration.premiumMonthly,
            displayName: 'Premium Monthly',
            description: 'Synthetic fixture',
            displayPrice: '99.99',
            price: 99.99,
            type: SK2ProductType.autoRenewable,
            priceLocale: SK2PriceLocale(
              currencyCode: 'ZAR',
              currencySymbol: 'R',
            ),
            subscription: SK2SubscriptionInfo(
              subscriptionGroupID: 'synthetic-group',
              promotionalOffers: const [],
              subscriptionPeriod: const SK2SubscriptionPeriod(
                value: 1,
                unit: SK2SubscriptionPeriodUnit.month,
              ),
            ),
          ),
        ),
        AppStoreProduct2Details.fromSK2Product(
          SK2Product(
            id: StoreCatalogConfiguration.premiumAnnual,
            displayName: 'Premium Annual',
            description: 'Synthetic fixture',
            displayPrice: '599.99',
            price: 599.99,
            type: SK2ProductType.autoRenewable,
            priceLocale: SK2PriceLocale(
              currencyCode: 'ZAR',
              currencySymbol: 'R',
            ),
            subscription: SK2SubscriptionInfo(
              subscriptionGroupID: 'synthetic-group',
              promotionalOffers: const [],
              subscriptionPeriod: const SK2SubscriptionPeriod(
                value: 1,
                unit: SK2SubscriptionPeriodUnit.year,
              ),
            ),
          ),
        ),
      ],
      notFoundIDs: const [],
    ),
  );
}

class ConfiguredSubscription extends VerifiedStorePurchaseService {
  ConfiguredSubscription(NativeFixture native)
    : super(purchase: native, handlesBoost: false);
  @override
  bool get configured => true;
}

PurchaseDetails oldInactive({
  bool boost = false,
  PurchaseStatus status = PurchaseStatus.restored,
}) => PurchaseDetails(
  purchaseID: 'synthetic-expired-transaction',
  productID: boost
      ? StoreCatalogConfiguration.aiBoost
      : StoreCatalogConfiguration.premiumMonthly,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'synthetic-receipt',
    serverVerificationData: 'synthetic-receipt',
    source: 'app_store',
  ),
  transactionDate: '1',
  status: status,
)..pendingCompletePurchase = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeFixture native;
  late ConfiguredSubscription service;
  late Completer<void> verificationStarted;
  late Completer<http.Response> verification;
  var verificationCalls = 0;
  setUp(() async {
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    verificationStarted = Completer<void>();
    verification = Completer<http.Response>();
    verificationCalls = 0;
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
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/functions/v1/verify-store-purchase') {
          verificationCalls++;
          if (!verificationStarted.isCompleted) verificationStarted.complete();
          return verification.future;
        }
        throw StateError('Unexpected mock-only HTTP path');
      }),
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-local-token',
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
    native = NativeFixture();
    service = ConfiguredSubscription(native);
  });
  tearDown(() async {
    service.dispose();
    if (!verification.isCompleted) {
      verification.complete(http.Response('{"verified":false}', 200));
    }
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
  });
  Future<void> idle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (service.busy || native.finished == 0) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Synthetic inactive receipt did not settle');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  void inactiveVerified() => verification.complete(
    http.Response(
      '{"verified":true,"entitlement_active":false}',
      200,
      headers: {'content-type': 'application/json'},
    ),
  );

  test(
    'verified inactive legacy receipt finished BEFORE catalog leaves valid Premium checkout actionable',
    () async {
      final init = service.initialize();
      await native.queried.future;
      native.updates.add([oldInactive()]);
      await verificationStarted.future;
      inactiveVerified();
      await idle();
      expect(service.state, VerifiedStoreState.unavailable);
      expect(service.products, isEmpty);
      native.settleCatalog();
      await init;
      expect(service.products.length, 2);
      expect(service.busy, isFalse);
      expect(service.hasPendingVerifiedFinish, isFalse);
      expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(native.launches, 0);
      expect(
        service.canStartPurchase,
        isTrue,
        reason:
            'An authenticated inactive historical receipt grants no paid access, but must not permanently disable a fresh valid catalog after it settles.',
      );
    },
  );
  test(
    'CONTROL: identical inactive legacy receipt AFTER catalog leaves Premium actionable without a paid grant',
    () async {
      native.settleCatalog();
      await service.initialize();
      expect(service.canStartPurchase, isTrue);
      native.updates.add([oldInactive()]);
      await verificationStarted.future;
      inactiveVerified();
      await idle();
      expect(service.state, VerifiedStoreState.ready);
      expect(service.messageCode, 'no_restorable_purchases');
      expect(service.canStartPurchase, isTrue);
      expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(native.launches, 0);
    },
  );
  test(
    'LANE CONTROL: Boost callback before catalog never enters subscription verification or changes readiness',
    () async {
      final init = service.initialize();
      await native.queried.future;
      native.updates.add([oldInactive(boost: true)]);
      await Future<void>.delayed(Duration.zero);
      native.settleCatalog();
      await init;
      expect(verificationCalls, 0);
      expect(service.state, VerifiedStoreState.ready);
      expect(service.canStartPurchase, isTrue);
      expect(native.finishes, 0);
      expect(native.launches, 0);
    },
  );

  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Synthetic store condition did not settle');
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  test(
    'catalog arriving during inactive native finish stays blocked until that finish succeeds',
    () async {
      final finish = Completer<void>();
      native.finish = () => finish.future;
      final init = service.initialize();
      await native.queried.future;
      native.updates.add([oldInactive()]);
      await verificationStarted.future;
      inactiveVerified();
      await until(() => native.finishes == 1 && !service.busy);
      native.settleCatalog();
      await init;
      expect(service.products.length, 2);
      expect(service.canStartPurchase, isFalse);
      expect(native.finished, 0);
      expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      finish.complete();
      await until(() => native.finished == 1 && service.canStartPurchase);
      expect(service.state, VerifiedStoreState.ready);
      expect(service.messageCode, 'no_restorable_purchases');
      expect(native.launches, 0);
    },
  );
  test('pending native callback before catalog remains fail closed', () async {
    final init = service.initialize();
    await native.queried.future;
    native.updates.add([oldInactive(status: PurchaseStatus.pending)]);
    await Future<void>.delayed(Duration.zero);
    native.settleCatalog();
    await init;
    expect(service.state, VerifiedStoreState.purchasePending);
    expect(service.canStartPurchase, isFalse);
    expect(verificationCalls, 0);
    expect(native.finishes, 0);
    expect(native.launches, 0);
  });
  for (final ownershipConflict in [false, true]) {
    test(
      '${ownershipConflict ? 'ownership rejection' : 'verification failure'} before catalog remains fail closed',
      () async {
        final init = service.initialize();
        await native.queried.future;
        native.updates.add([oldInactive()]);
        await verificationStarted.future;
        verification.complete(
          http.Response(
            ownershipConflict
                ? '{"verified":false,"error":"purchase_owned_by_another_account"}'
                : '{"verified":false}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        await until(() => !service.busy);
        native.settleCatalog();
        await init;
        expect(service.products.length, 2);
        expect(service.state, VerifiedStoreState.failed);
        expect(
          service.messageCode,
          ownershipConflict
              ? 'purchase_owned_by_another_account'
              : 'reconciliation_verification_failed',
        );
        expect(service.canStartPurchase, isFalse);
        expect(native.finishes, 0);
        expect(native.launches, 0);
        expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      },
    );
  }
  test(
    'failed inactive native finish keeps acknowledgement blocker after catalog',
    () async {
      native.failFinish = true;
      final init = service.initialize();
      await native.queried.future;
      native.updates.add([oldInactive()]);
      await verificationStarted.future;
      inactiveVerified();
      await until(() => !service.busy && service.hasPendingVerifiedFinish);
      native.settleCatalog();
      await init;
      expect(service.products.length, 2);
      expect(service.hasPendingVerifiedFinish, isTrue);
      expect(service.messageCode, 'store_finish_pending');
      expect(service.canStartPurchase, isFalse);
      expect(native.finished, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'newer pending callback cannot be overwritten by an older inactive finish',
    () async {
      final finish = Completer<void>();
      native.finish = () => finish.future;
      final init = service.initialize();
      await native.queried.future;
      native.updates.add([oldInactive()]);
      await verificationStarted.future;
      inactiveVerified();
      await until(() => native.finishes == 1 && !service.busy);
      native.updates.add([oldInactive(status: PurchaseStatus.pending)]);
      await until(() => service.state == VerifiedStoreState.purchasePending);
      native.settleCatalog();
      await init;
      finish.complete();
      await until(() => native.finished == 1);
      expect(service.state, VerifiedStoreState.purchasePending);
      expect(service.canStartPurchase, isFalse);
      expect(native.launches, 0);
    },
  );
  test(
    'startup stream error cannot reset a newer pending receipt when catalog arrives',
    () async {
      final init = service.initialize();
      await native.queried.future;
      native.updates.addError(StateError('Synthetic startup stream error'));
      await until(() => service.state == VerifiedStoreState.unavailable);
      expect(service.messageCode, isNull);
      native.updates.add([oldInactive(status: PurchaseStatus.pending)]);
      await until(() => service.state == VerifiedStoreState.purchasePending);
      native.settleCatalog();
      await init;
      expect(service.state, VerifiedStoreState.purchasePending);
      expect(service.messageCode, 'reconciliation_pending');
      expect(service.products.length, 2);
      expect(native.countryReads, 2);
      expect(service.canStartPurchase, isFalse);
      expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(verificationCalls, 0);
      expect(native.finishes, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'country change clears unsafe prices without replacing a newer pending receipt',
    () async {
      final init = service.initialize();
      await native.queried.future;
      expect(native.countryReads, 1);
      native.updates.add([oldInactive(status: PurchaseStatus.pending)]);
      await until(() => service.state == VerifiedStoreState.purchasePending);
      native.storeCountry = 'JOR';
      native.settleCatalog();
      await init;
      expect(native.countryReads, 2);
      expect(service.products, isEmpty);
      expect(service.state, VerifiedStoreState.purchasePending);
      expect(service.messageCode, 'reconciliation_pending');
      expect(service.canStartPurchase, isFalse);
      expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(verificationCalls, 0);
      expect(native.finishes, 0);
      expect(native.launches, 0);
    },
  );
  test(
    'retired owner receives no readiness publication from old inactive acknowledgement',
    () async {
      final finish = Completer<void>();
      native.finish = () => finish.future;
      final init = service.initialize();
      await native.queried.future;
      native.updates.add([oldInactive()]);
      await verificationStarted.future;
      inactiveVerified();
      await until(() => native.finishes == 1 && !service.busy);
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'synthetic-second-token',
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
      await Future<void>.delayed(Duration.zero);
      native.settleCatalog();
      await init;
      final beforeState = service.state,
          beforeMessage = service.messageCode,
          beforeRevision = service.verifiedBenefitRevision;
      finish.complete();
      await until(() => native.finished == 1);
      expect(service.state, beforeState);
      expect(service.messageCode, beforeMessage);
      expect(service.verifiedBenefitRevision, beforeRevision);
      expect(service.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(native.launches, 0);
    },
  );
}
