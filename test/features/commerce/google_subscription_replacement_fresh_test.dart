import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/services/android_store_purchase_readiness.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_native_purchase_completion_test.dart' as billing;

const _owner = '00000000-0000-4000-8000-000000000081';
const _monthly = StoreCatalogConfiguration.premiumAiCoachMonthly;
const _annual = StoreCatalogConfiguration.premiumAiCoachAnnual;

GooglePlayProductDetails _details(String id, String period) =>
    GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        productId: id,
        name: id,
        title: id,
        description: 'Synthetic subscription',
        productType: ProductType.subs,
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: period == 'P1M' ? 'monthly' : 'yearly',
            offerId: null,
            offerTags: const [],
            offerIdToken: 'offer-$id',
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: period,
                formattedPrice: 'JOD4.250',
                priceAmountMicros: 4250000,
                priceCurrencyCode: 'JOD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      ),
    ).single;

class _Play extends Fake implements InAppPurchase {
  _Play(this.addition);
  final InAppPurchaseAndroidPlatformAddition addition;
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  PurchaseParam? last;
  int launches = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> countryCode() async => 'JOR';
  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      addition as T;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [_details(_monthly, 'P1M'), _details(_annual, 'P1Y')],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    last = purchaseParam;
    launches++;
    return true;
  }
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Play play)
    : super(
        purchase: play,
        androidReadiness: AndroidStorePurchaseReadiness(
          probe: (_, _) async {},
          recover: (_) async => false,
          release: (_) async {},
        ),
      );
  @override
  bool get configured => true;
}

class _Harness {
  late billing.NativeBillingClient api;
  late InAppPurchaseAndroidPlatform platform;
  late InAppPurchasePlatform previous;
  late _Play play;
  late _Store store;
  final now = DateTime.now().toUtc();
  List<Map<String, Object?>> rows = [];
  bool mirrorFails = false;
  int verifies = 0, reads = 0;
  Future<void> Function()? holdMirror;

  GooglePlayPurchaseDetails receipt({
    String product = _monthly,
    String token = 'synthetic-old-monthly',
    bool acknowledged = true,
    PurchaseStateWrapper state = PurchaseStateWrapper.purchased,
  }) => billing.googleSubscription(
    product: product,
    token: token,
    acknowledged: acknowledged,
    state: state,
    packageName: StoreCatalogConfiguration.packageName,
  );

  void inventory(List<GooglePlayPurchaseDetails> details) {
    api.purchases = PurchasesResultWrapper(
      responseCode: BillingResponse.ok,
      billingResult: const BillingResultWrapper(
        responseCode: BillingResponse.ok,
      ),
      purchasesList: details.map((p) => p.billingClientPurchase).toList(),
    );
  }

  Map<String, Object?> row({
    bool active = false,
    String product = _monthly,
    String token = 'synthetic-old-monthly',
  }) => {
    'owner_id': _owner,
    'provider': 'google',
    'product_id': product,
    'plan_id': 'premium_ai_coach',
    'lifecycle': active ? 'active' : 'expired',
    'latest_transaction_id': token,
    'original_transaction_id': token,
    'started_at': now.subtract(const Duration(days: 1)).toIso8601String(),
    'expires_at': now
        .add(Duration(minutes: active ? 30 : -1))
        .toIso8601String(),
    'verified_at': now.subtract(const Duration(seconds: 1)).toIso8601String(),
    'auto_renews': active,
    'revision': active ? 10 : 9,
  };

  static Future<_Harness> open({bool active = false}) async {
    final h = _Harness();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
    await Supabase.initialize(
      url: 'https://replacement-proof-test.invalid',
      publishableKey: 'synthetic-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/bil_subscriptions')) {
          h.reads++;
          await h.holdMirror?.call();
          if (h.mirrorFails) throw StateError('Synthetic canonical failure');
          return http.Response(
            jsonEncode(h.rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/verify-store-purchase')) {
          h.verifies++;
          return http.Response(
            jsonEncode({
              'verified': true,
              'entitlement_active': active,
              'verified_at': h.now.toIso8601String(),
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected synthetic endpoint');
      }),
    );
    await h.signIn(_owner);
    h.previous = billing.existingOrIsolatedPurchasePlatform();
    h.api = billing.NativeBillingClient()..response = BillingResponse.ok;
    h.platform = billing.realAndroidPlatform(h.api);
    InAppPurchasePlatform.instance = h.platform;
    h.play = _Play(
      InAppPurchaseAndroidPlatformAddition(h.platform.billingClientManager),
    );
    h.store = _Store(h.play);
    h.rows = [h.row(active: active)];
    h.inventory([h.receipt()]);
    await h.store.initialize();
    expect(
      h.verifies,
      1,
      reason: 'The real initializer observed and settled the old receipt.',
    );
    expect(h.store.canStartPurchase, isTrue);
    return h;
  }

  Future<void> signIn(String owner) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-token',
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

  Future<void> buy({GooglePlayPurchaseDetails? explicitOld}) =>
      store.purchasePlan(
        CommercePlan.premiumAiCoach,
        term: SubscriptionTerm.oneYear,
        replacesGooglePurchase: explicitOld,
      );
  Future<void> close() async {
    store.dispose();
    await play.updates.close();
    platform.billingClientManager.dispose();
    InAppPurchasePlatform.instance = previous;
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'expired monthly pointer never becomes the annual replacement after fresh empty inventory',
    () async {
      final h = await _Harness.open();
      try {
        h.inventory([]);
        await h.buy();
        expect(h.play.launches, 1);
        final param = h.play.last! as GooglePlayPurchaseParam;
        expect(param.changeSubscriptionParam, isNull);
        expect(
          h.verifies,
          1,
          reason: 'Checkout proof does not verify another receipt.',
        );
      } finally {
        await h.close();
      }
    },
  );
  test(
    'replacement uses the fresh exact owned token, never the cached token',
    () async {
      final h = await _Harness.open(active: true);
      try {
        h.rows = [h.row(active: true, token: 'synthetic-fresh-monthly')];
        h.inventory([h.receipt(token: 'synthetic-fresh-monthly')]);
        await h.buy();
        expect(h.play.launches, 1);
        final param = h.play.last! as GooglePlayPurchaseParam;
        expect(
          param
              .changeSubscriptionParam!
              .oldPurchaseDetails
              .billingClientPurchase
              .purchaseToken,
          'synthetic-fresh-monthly',
        );
      } finally {
        await h.close();
      }
    },
  );
  for (final failure in [
    'empty-native-active-row',
    'mismatch',
    'unacknowledged',
    'pending',
    'multiple',
    'network',
    'already-target',
    'explicit-old-bypass',
  ]) {
    test('$failure cannot open a second financial intent', () async {
      final h = await _Harness.open(active: true);
      try {
        h.rows = [h.row(active: true)];
        h.inventory([h.receipt()]);
        if (failure == 'empty-native-active-row') h.inventory([]);
        if (failure == 'mismatch') {
          h.rows.single['latest_transaction_id'] = 'different';
        }
        if (failure == 'unacknowledged') {
          h.inventory([h.receipt(acknowledged: false)]);
        }
        if (failure == 'pending') {
          h.inventory([h.receipt(state: PurchaseStateWrapper.pending)]);
        }
        if (failure == 'multiple') {
          h.inventory([h.receipt(), h.receipt(token: 'other')]);
        }
        if (failure == 'network') h.mirrorFails = true;
        if (failure == 'already-target') {
          h.rows = [h.row(active: true, product: _annual)];
          h.inventory([h.receipt(product: _annual)]);
        }
        await h.buy(
          explicitOld: failure == 'explicit-old-bypass'
              ? h.receipt(token: 'forged-explicit-pointer')
              : null,
        );
        expect(h.play.launches, 0);
        expect(h.verifies, 1);
        expect(h.store.verifiedBenefitRevision, 1);
      } finally {
        await h.close();
      }
    });
  }
  test(
    'owner A to B to A retires the old pointer before a new empty-owner checkout',
    () async {
      final h = await _Harness.open();
      try {
        h.inventory([]);
        h.rows = [];
        await h.signIn('00000000-0000-4000-8000-000000000082');
        await h.signIn(_owner);
        await h.store.initialize();
        await h.buy();
        expect(h.play.launches, 1);
        expect(
          (h.play.last! as GooglePlayPurchaseParam).changeSubscriptionParam,
          isNull,
        );
      } finally {
        await h.close();
      }
    },
  );
}
