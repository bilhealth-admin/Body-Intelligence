import '../../support/google_subscription_replacement_fixture.dart';
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/paid_plan_catalog.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_provider.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/commerce/services/android_store_purchase_readiness.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_native_purchase_completion_test.dart' as billing;

// These tests start after a positive Android licensing preflight and retain
// their original country, native Billing, receipt and owner assertions.
// Dedicated readiness tests cover licensing rejection and remediation.
AndroidStorePurchaseReadiness _licensedReadinessForBillingBoundary() {
  return AndroidStorePurchaseReadiness(
    probe: (_, _) async {},
    recover: (_) async {
      throw StateError('Unexpected license remediation in billing fixture');
    },
    release: (_) async {},
  );
}

const _owner = '00000000-0000-4000-8000-000000000001';
const _other = '00000000-0000-4000-8000-000000000002';
const _sku = StoreCatalogConfiguration.premiumAiCoachAnnual;

PurchasesResultWrapper _result(
  BillingResponse code, [
  List<PurchaseWrapper> purchases = const [],
]) => PurchasesResultWrapper(
  responseCode: code,
  purchasesList: purchases,
  billingResult: BillingResultWrapper(
    responseCode: code,
    debugMessage: 'Synthetic native result',
  ),
);

PurchaseWrapper _purchase(String product, PurchaseStateWrapper state) =>
    PurchaseWrapper(
      orderId: 'synthetic-order',
      packageName: StoreCatalogConfiguration.packageName,
      purchaseTime: 1,
      signature: 'synthetic-signature',
      products: [product],
      purchaseToken: 'synthetic-receipt-not-a-real-token',
      isAutoRenewing: true,
      originalJson: '',
      developerPayload: '',
      isAcknowledged: false,
      purchaseState: state,
    );

List<ProductDetails> _products() => [
  ...GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      productId: _sku,
      name: 'AI Coach',
      title: 'AI Coach',
      description: 'Synthetic',
      productType: ProductType.subs,
      subscriptionOfferDetails: [
        for (final (base, period, token) in const [
          ('annual', 'P1M', 'synthetic-wrong-monthly-token'),
          ('yearly', 'P1Y', 'synthetic-exact-yearly-token'),
        ])
          SubscriptionOfferDetailsWrapper(
            basePlanId: base,
            offerId: null,
            offerTags: const [],
            offerIdToken: token,
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: period,
                formattedPrice: 'JOD 35.350',
                priceAmountMicros: 35350000,
                priceCurrencyCode: 'JOD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
      ],
    ),
  ),
  ...GooglePlayProductDetails.fromProductDetails(
    const ProductDetailsWrapper(
      productId: StoreCatalogConfiguration.aiBoost,
      name: 'Boost',
      title: 'Boost',
      description: 'Synthetic',
      productType: ProductType.inapp,
      oneTimePurchaseOfferDetails: OneTimePurchaseOfferDetailsWrapper(
        formattedPrice: 'JOD 1.000',
        priceAmountMicros: 1000000,
        priceCurrencyCode: 'JOD',
      ),
    ),
  ),
];

class _Billing extends billing.NativeBillingClient {
  _Billing(this.events);
  final List<String> events;
  late PurchasesUpdatedListener emit;
  Future<PurchasesResultWrapper> Function(ProductType, int)? read;
  Future<BillingResultWrapper> Function()? launch;
  int queryCount = 0, launches = 0;
  String? lastProduct, lastOfferToken;
  @override
  Future<PurchasesResultWrapper> queryPurchases(ProductType type) async {
    final index = queryCount++;
    events.add('native:${type.name}');
    return read == null ? _result(BillingResponse.ok) : read!(type, index);
  }

  @override
  Future<BillingResultWrapper> launchBillingFlow({
    required String product,
    String? offerToken,
    String? accountId,
    String? obfuscatedProfileId,
    String? oldProduct,
    String? purchaseToken,
    ReplacementMode? replacementMode,
  }) async {
    launches++;
    lastProduct = product;
    lastOfferToken = offerToken;
    return launch == null
        ? const BillingResultWrapper(responseCode: BillingResponse.ok)
        : launch!();
  }
}

class _Native extends Fake implements InAppPurchase {
  _Native(this.platform, this.addition);
  final InAppPurchaseAndroidPlatform platform;
  final InAppPurchaseAndroidPlatformAddition addition;
  int finishes = 0, restores = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => platform.purchaseStream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> countryCode() async => 'JOR';
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: _products().where((p) => ids.contains(p.id)).toList(),
        notFoundIDs: const [],
      );
  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() =>
      addition as T;
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      platform.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) => platform.buyConsumable(
    purchaseParam: purchaseParam,
    autoConsume: autoConsume,
  );
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) {
    restores++;
    return platform.restorePurchases(applicationUserName: applicationUserName);
  }
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Native native)
    : super(
        googleReplacementReader: emptyGoogleSubscriptionProofFixture(),
        purchase: native,
        androidReadiness: _licensedReadinessForBillingBoundary(),
        handlesBoost: false,
      );
  @override
  bool get configured => true;
}

Future<void> _signIn(String owner) =>
    Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-fixture-token',
        'token_type': 'bearer',
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
Future<void> _drain() async {
  for (var turn = 0; turn < 12; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Billing api;
  late InAppPurchaseAndroidPlatform platform;
  late InAppPurchasePlatform previous;
  late _Native native;
  late _Store store;
  late AiBoostPurchaseService boost;
  final events = <String>[];
  var canonicalMode = 'paid';
  var verificationCalls = 0;
  var boostCreditBalance = 500;
  var boostVerifyCalls = 0;
  late Map<String, Object?> paidRow;

  Future<void> ready(String lane) async {
    if (lane == 'subscription') {
      await store.initialize();
    } else {
      await boost.initialize();
    }
    await _drain();
    events.clear();
    api.queryCount = 0;
  }

  Future<void> buy(String lane) => lane == 'subscription'
      ? store.purchasePlan(
          CommercePlan.premiumAiCoach,
          term: SubscriptionTerm.oneYear,
        )
      : boost.purchaseBoost();
  Future<void> retry(String lane) => lane == 'subscription'
      ? store.continueVerification()
      : boost.retryPendingTransaction();
  bool purchasable(String lane) =>
      lane == 'subscription' ? store.canStartPurchase : boost.canPurchase;
  String? code(String lane) =>
      lane == 'subscription' ? store.messageCode : boost.errorCode;
  void expectBlocked(String lane) {
    expect(code(lane), 'purchase_status_unknown');
    expect(purchasable(lane), isFalse);
  }

  Future<void> reject(
    String lane, {
    BillingResponse response = BillingResponse.itemUnavailable,
  }) async {
    await buy(lane);
    api.emit(
      _result(response),
    ); // Actual official plugin creates the blank-SKU event.
    await _drain();
    expect(
      lane == 'subscription'
          ? store.state == VerifiedStoreState.failed
          : boost.state == AiBoostPurchaseState.failed,
      isTrue,
    );
    expectBlocked(lane);
    events.clear();
    api.queryCount = 0;
  }

  void expectNoFinancialMutation() {
    expect(verificationCalls, 0);
    expect(boostVerifyCalls, 0);
    expect(boostCreditBalance, 500);
    expect(native.finishes, 0);
  }

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
    events.clear();
    canonicalMode = 'paid';
    verificationCalls = 0;
    boostCreditBalance = 500;
    boostVerifyCalls = 0;
    final now = DateTime.now().toUtc();
    paidRow = {
      'owner_id': _owner,
      'plan_id': 'premium_ai_coach',
      'lifecycle': 'active',
      'provider': 'google',
      'started_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      'expires_at': now.add(const Duration(days: 1)).toIso8601String(),
      'auto_renews': true,
      'verified_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'revision': 3,
      'original_transaction_id': 'synthetic-lineage',
    };
    await Supabase.initialize(
      url: 'https://android-checkout-proof.invalid',
      publishableKey: 'synthetic-test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/functions/')) {
          verificationCalls++;
          return http.Response(
            '{"verified":false}',
            503,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/rest/v1/bil_subscriptions') {
          events.add('cloud:store');
          if (canonicalMode == 'failed') {
            return http.Response('{}', 503, request: request);
          }
          final rows = canonicalMode == 'free' ? [] : [paidRow];
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/rest/v1/bil_ai_closed_test_grants') {
          events.add('cloud:closed');
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/rest/v1/rpc/bil_get_my_admin_subscription') {
          events.add('cloud:admin');
          return http.Response(
            'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected fixture path: $path');
      }),
    );
    await _signIn(_owner);
    previous = billing.existingOrIsolatedPurchasePlatform();
    api = _Billing(events);
    platform = InAppPurchaseAndroidPlatform(
      manager: BillingClientManager(
        billingClientFactory: (listener, alternative) {
          api.emit = listener;
          return api;
        },
      ),
    );
    InAppPurchasePlatform.instance = platform;
    native = _Native(
      platform,
      InAppPurchaseAndroidPlatformAddition(platform.billingClientManager),
    );
    store = _Store(native);
    boost = AiBoostPurchaseService(
      purchase: native,
      androidReadiness: _licensedReadinessForBillingBoundary(),
      verify: (_, _) async {
        boostVerifyCalls++;
        boostCreditBalance += 100;
        return true;
      },
    );
  });
  tearDown(() async {
    store.dispose();
    boost.dispose();
    platform.billingClientManager.dispose();
    InAppPurchasePlatform.instance = previous;
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'actual plugin blank cancellation then empty Restore keeps public recovery and requires fresh proof',
    (tester) async {
      ProviderContainer? container;
      try {
        canonicalMode = 'free';
        await tester.runAsync(() async {
          await ready('subscription');
          await reject('subscription', response: BillingResponse.userCanceled);
        });
        final benefitRevision = store.verifiedBenefitRevision;
        final creditRevision = boost.verifiedCreditsRevision;
        final free = SubscriptionState(
          plan: CommercePlan.free,
          entitlements: const {},
          authority: EntitlementAuthority.verifiedServer,
          lifecycle: SubscriptionLifecycle.inactive,
          verifiedAt: DateTime.now().toUtc(),
          isPurchasable: true,
          canRestorePurchases: true,
        );
        container = ProviderContainer(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (_) => Stream.value(_owner),
            ),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () async => free,
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: BilStorePlansPage(
                store: store,
                connectToDeviceStore: false,
                productIds: const {_sku},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final restore = find.text(BilStoreCopy.text('en', 'restore'));
        await tester.ensureVisible(restore);
        await tester.runAsync(() async {
          await tester.tap(restore);
          // Await the public Restore operation; it includes the production
          // one-second late-callback grace period. No service state is injected.
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (store.isRestoring && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await _drain();
        });
        await tester.pump();

        expect(native.restores, 1);
        expect(store.state, VerifiedStoreState.failed);
        expectBlocked('subscription');
        expect(store.hasAndroidCheckoutFailure, isTrue);
        expect(store.userOperationInProgress, isFalse);
        expect(store.busy, isFalse);
        final offers = tester.widget<BilDynamicStoreOffers>(
          find.byType(BilDynamicStoreOffers),
        );
        expect(offers.purchaseInProgress, isFalse);
        expect(offers.restoreInProgress, isFalse);
        expect(offers.purchaseEnabled, isFalse);
        final recovery = find.byKey(const Key('store-continue-verification'));
        expect(recovery, findsOneWidget);
        Future<void> waitForObservable(
          bool Function() predicate,
          String phase,
        ) async {
          final deadline = DateTime.now().add(const Duration(seconds: 20));
          while (!predicate() && DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(predicate(), isTrue, reason: phase);
        }

        Future<void> tapPublicRecoveryWithNativeGate() async {
          await tester.runAsync(() async {
            // Future captures its creation zone. Create and settle this gate
            // in runAsync, rather than completing a FakeAsync-born future
            // while that fake microtask queue is not being pumped.
            final firstNativeQuery = Completer<PurchasesResultWrapper>();
            api.read = (_, index) => index == 0
                ? firstNativeQuery.future
                : Future.value(_result(BillingResponse.ok));
            try {
              // This public TextButton is the only initiating action. If its
              // handler is missing, the native-query assertion must fail.
              await tester.tap(recovery);
              await waitForObservable(
                () => api.queryCount == 2 && store.isRecoveringSubscription,
                'The public recovery button must start native inventory',
              );
              expect(store.busy, isTrue);
              expect(store.canStartPurchase, isFalse);
              expect(
                events.where((event) => event.startsWith('cloud:')),
                isEmpty,
              );
              expect(api.launches, 1);
              expectNoFinancialMutation();
              firstNativeQuery.complete(_result(BillingResponse.ok));
              await waitForObservable(
                () => !store.isRecoveringSubscription,
                'The public recovery operation must settle within its bound',
              );
            } finally {
              if (!firstNativeQuery.isCompleted) {
                firstNativeQuery.complete(_result(BillingResponse.ok));
              }
              api.read = null;
            }
          });
        }

        expect(
          tester
              .widget<InkWell>(find.byKey(const Key('store-purchase-cta')))
              .onTap,
          isNotNull,
        );
        expect(api.launches, 1);
        expectNoFinancialMutation();

        // A single empty native inventory plus unreadable canonical authority
        // cannot settle the attempt or make another charge possible.
        canonicalMode = 'failed';
        events.clear();
        api.queryCount = 0;
        await tester.ensureVisible(recovery);
        await tapPublicRecoveryWithNativeGate();
        await tester.pumpAndSettle();
        expect(api.queryCount, 2); // One inventory queries inapp and subs.
        expectBlocked('subscription');
        expect(store.userOperationInProgress, isFalse);
        expect(
          find.byKey(const Key('store-continue-verification')),
          findsOneWidget,
        );
        expect(api.launches, 1);
        expectNoFinancialMutation();

        // Only the existing explicit two-empty-inventory proof around fresh
        // same-owner canonical authority retires the checkout blocker.
        canonicalMode = 'free';
        events.clear();
        api.queryCount = 0;
        await tapPublicRecoveryWithNativeGate();
        await tester.pumpAndSettle();
        expect(events, [
          'native:inapp',
          'native:subs',
          'cloud:closed',
          'cloud:store',
          'cloud:admin',
          'native:inapp',
          'native:subs',
        ]);
        expect(api.queryCount, 4);
        expect(store.state, VerifiedStoreState.ready);
        expect(store.messageCode, 'purchase_cancelled');
        expect(store.canStartPurchase, isTrue);
        expect(store.userOperationInProgress, isFalse);
        expect(store.hasAndroidCheckoutFailure, isFalse);
        expect(
          find.byKey(const Key('store-continue-verification')),
          findsNothing,
        );
        expect(api.launches, 1);
        expect(native.restores, 1);
        expect(store.verifiedBenefitRevision, benefitRevision);
        expect(boost.verifiedCreditsRevision, creditRevision);
        expectNoFinancialMutation();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container?.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final lane in ['subscription', 'boost']) {
    test(
      'actual plugin blank-SKU failure stops $lane spinner without enabling another charge',
      () async {
        await ready(lane);
        await reject(lane);
        expect(api.launches, 1);
        if (lane == 'subscription') {
          expect(api.lastProduct, _sku);
          expect(
            api.lastOfferToken,
            'synthetic-exact-yearly-token',
            reason: 'Legacy annual/P1M must not replace active yearly/P1Y.',
          );
        }
        expect(api.queryCount, 0);
        expect(native.restores, 0);
        expectNoFinancialMutation();
      },
    );

    for (final canonical in ['paid', 'free']) {
      test(
        'two empty native snapshots around fresh $canonical owner recover $lane without benefit mutation',
        () async {
          await ready(lane);
          await reject(lane);
          final entitlement = store.entitlement;
          final benefitRevision = store.verifiedBenefitRevision;
          final creditRevision = boost.verifiedCreditsRevision;
          canonicalMode = canonical;
          await retry(lane);
          await _drain();
          expect(events, [
            'native:inapp',
            'native:subs',
            'cloud:closed',
            'cloud:store',
            'cloud:admin',
            'native:inapp',
            'native:subs',
          ]);
          expect(purchasable(lane), isTrue);
          expect(code(lane), 'purchase_not_started');
          expect(identical(store.entitlement, entitlement), isTrue);
          expect(store.verifiedBenefitRevision, benefitRevision);
          expect(boost.verifiedCreditsRevision, creditRevision);
          expect(api.launches, 1);
          expect(native.restores, 0);
          expectNoFinancialMutation();
        },
      );
    }

    for (final type in [ProductType.inapp, ProductType.subs]) {
      for (final round in [0, 1]) {
        test(
          'actual plugin partial $type failure on empty round$round keeps $lane blocked',
          () async {
            await ready(lane);
            await reject(lane);
            api.read = (kind, index) async => _result(
              kind == type && index ~/ 2 == round
                  ? BillingResponse.error
                  : BillingResponse.ok,
            );
            await retry(lane);
            await _drain();
            expectBlocked(lane);
            expect(api.queryCount, round == 0 ? 2 : 4);
            expect(events, [
              'native:inapp',
              'native:subs',
              if (round == 1) ...[
                'cloud:closed',
                'cloud:store',
                'cloud:admin',
                'native:inapp',
                'native:subs',
              ],
            ]);
            expect(api.launches, 1);
            expectNoFinancialMutation();
          },
        );
      }
    }

    for (final state in [
      PurchaseStateWrapper.pending,
      PurchaseStateWrapper.purchased,
    ]) {
      test(
        'unknown native item $state blocks $lane recovery without verification or finish',
        () async {
          await ready(lane);
          await reject(lane);
          api.read = (_, _) async => _result(BillingResponse.ok, [
            _purchase('foreign-unconfigured-item', state),
          ]);
          await retry(lane);
          await _drain();
          expectBlocked(lane);
          expect(events.where((e) => e.startsWith('cloud:')), isEmpty);
          expect(api.queryCount, 2);
          expectNoFinancialMutation();
        },
      );
    }

    test(
      'canonical transport failure never converts cached paid authority into fresh $lane proof',
      () async {
        await ready(lane);
        await reject(lane);
        canonicalMode = 'failed';
        await retry(lane);
        await _drain();
        expectBlocked(lane);
        expect(api.queryCount, 2);
        // Pinned Postgrest 2.8.0 retries a GET returning 503 three times.
        expect(events, [
          'native:inapp',
          'native:subs',
          'cloud:closed',
          'cloud:store',
          'cloud:store',
          'cloud:store',
          'cloud:store',
        ]);
        expect(api.launches, 1);
        expectNoFinancialMutation();
      },
    );

    test(
      'known pending receipt survives a blank native error in $lane',
      () async {
        await ready(lane);
        await buy(lane);
        api.emit(
          _result(BillingResponse.ok, [
            _purchase(
              lane == 'subscription' ? _sku : StoreCatalogConfiguration.aiBoost,
              PurchaseStateWrapper.pending,
            ),
          ]),
        );
        await _drain();
        final before = code(lane);
        api.emit(_result(BillingResponse.itemUnavailable));
        await _drain();
        expect(code(lane), before);
        expect(purchasable(lane), isFalse);
        events.clear();
        api.queryCount = 0;
        await retry(lane);
        await _drain();
        expect(purchasable(lane), isFalse);
        expectNoFinancialMutation();
      },
    );

    test('actual A B A retires held $lane empty proof', () async {
      await ready(lane);
      await reject(lane);
      final held = Completer<PurchasesResultWrapper>();
      api.read = (_, _) => held.future;
      final recovery = retry(lane);
      await _drain();
      expect(api.queryCount, 2);
      final owners = <String>[];
      var previousOwner = _owner;
      final delivered = Supabase.instance.client.auth.onAuthStateChange.listen((
        s,
      ) {
        final id = s.session?.user.id;
        if (id != null && id != previousOwner) {
          owners.add(id);
          previousOwner = id;
        }
      });
      await _signIn(_other);
      await _drain();
      await _signIn(_owner);
      await _drain();
      expect(owners, [_other, _owner]);
      await delivered.cancel();
      held.complete(_result(BillingResponse.ok));
      await recovery;
      await _drain();
      expect(purchasable(lane), isFalse);
      expect(code(lane), 'authentication_required');
      expect(events.where((e) => e.startsWith('cloud:')), isEmpty);
      expect(api.launches, 1);
      expectNoFinancialMutation();
    });

    test('new receipt generation retires held $lane proof', () async {
      await ready(lane);
      await reject(lane);
      final held = Completer<PurchasesResultWrapper>();
      api.read = (_, _) => held.future;
      final recovery = retry(lane);
      await _drain();
      api.emit(
        _result(BillingResponse.ok, [
          _purchase(
            lane == 'subscription' ? _sku : StoreCatalogConfiguration.aiBoost,
            PurchaseStateWrapper.pending,
          ),
        ]),
      );
      await _drain();
      final before = code(lane);
      held.complete(_result(BillingResponse.ok));
      await recovery;
      await _drain();
      expect(code(lane), before);
      expect(purchasable(lane), isFalse);
      expect(events.where((e) => e.startsWith('cloud:')), isEmpty);
      expectNoFinancialMutation();
    });

    for (final callbackKind in ['other-lane', 'foreign']) {
      test(
        '$callbackKind native receipt retires held $lane proof without being consumed',
        () async {
          await ready(lane);
          await reject(lane);
          final held = Completer<PurchasesResultWrapper>();
          api.read = (_, _) => held.future;
          final recovering = retry(lane);
          await _drain();
          expect(api.queryCount, 2);
          final product = callbackKind == 'foreign'
              ? 'foreign-unconfigured-item'
              : lane == 'subscription'
              ? StoreCatalogConfiguration.aiBoost
              : _sku;
          api.emit(
            _result(BillingResponse.ok, [
              _purchase(product, PurchaseStateWrapper.purchased),
            ]),
          );
          await _drain();
          held.complete(_result(BillingResponse.ok));
          await recovering;
          await _drain();
          expectBlocked(lane);
          expect(api.queryCount, 2);
          expect(events.where((e) => e.startsWith('cloud:')), isEmpty);
          expect(api.launches, 1);
          expectNoFinancialMutation();
        },
      );
    }

    for (final response in [
      BillingResponse.userCanceled,
      BillingResponse.error,
    ]) {
      for (final callbackKind in ['other-lane', 'foreign']) {
        test(
          'receipt-bearing $response $callbackKind retires held $lane proof',
          () async {
            await ready(lane);
            await reject(lane);
            final held = Completer<PurchasesResultWrapper>();
            api.read = (_, _) => held.future;
            final recovering = retry(lane);
            await _drain();
            expect(api.queryCount, 2);
            final product = callbackKind == 'foreign'
                ? 'foreign-unconfigured-item'
                : lane == 'subscription'
                ? StoreCatalogConfiguration.aiBoost
                : _sku;
            final converted = Completer<PurchaseDetails>();
            final witness = platform.purchaseStream.listen((updates) {
              for (final item in updates) {
                if (item.productID == product && !converted.isCompleted) {
                  converted.complete(item);
                }
              }
            });
            try {
              api.emit(
                _result(response, [
                  _purchase(product, PurchaseStateWrapper.purchased),
                ]),
              );
              final actual = await converted.future.timeout(
                const Duration(seconds: 2),
              );
              expect(
                actual.status,
                response == BillingResponse.userCanceled
                    ? PurchaseStatus.canceled
                    : PurchaseStatus.purchased,
              );
              expect(actual.error, isNotNull);
              expect(
                actual.verificationData.serverVerificationData,
                isNotEmpty,
              );
              await _drain();
              held.complete(_result(BillingResponse.ok));
              await recovering;
              await _drain();
              expectBlocked(lane);
              expect(api.queryCount, 2);
              expect(events.where((e) => e.startsWith('cloud:')), isEmpty);
              expect(api.launches, 1);
              expectNoFinancialMutation();
            } finally {
              if (!held.isCompleted) held.complete(_result(BillingResponse.ok));
              await witness.cancel();
            }
          },
        );
      }
    }

    test(
      'actual plugin blank cancellation still needs empty proof in $lane',
      () async {
        await ready(lane);
        await reject(lane, response: BillingResponse.userCanceled);
        await retry(lane);
        await _drain();
        expect(api.queryCount, 4);
        expect(purchasable(lane), isTrue);
        expect(code(lane), 'purchase_cancelled');
        expect(api.launches, 1);
        expectNoFinancialMutation();
      },
    );

    test(
      'late false launch future cannot erase witnessed $lane rejection',
      () async {
        await ready(lane);
        final launch = Completer<BillingResultWrapper>();
        api.launch = () => launch.future;
        final buying = buy(lane);
        await _drain();
        expect(api.launches, 1);
        api.emit(_result(BillingResponse.itemUnavailable));
        await _drain();
        expectBlocked(lane);
        launch.complete(
          const BillingResultWrapper(responseCode: BillingResponse.error),
        );
        await buying;
        await _drain();
        expectBlocked(lane);
        expectNoFinancialMutation();
      },
    );

    test(
      'blank native replay without an active $lane checkout stays quiet',
      () async {
        await ready(lane);
        final before = code(lane);
        api.emit(_result(BillingResponse.itemUnavailable));
        await _drain();
        expect(code(lane), before);
        expect(purchasable(lane), isTrue);
        expect(api.launches, 0);
        expect(api.queryCount, 0);
        expectNoFinancialMutation();
      },
    );

    test(
      'unwitnessed native launch exception with no canonical subscription remains blocked in $lane',
      () async {
        canonicalMode = 'free';
        await ready(lane);
        api.launch = () async =>
            throw StateError('Synthetic unknown launch result');
        await buy(lane);
        await _drain();
        expectBlocked(lane);
        events.clear();
        api.queryCount = 0;
        await retry(lane);
        await _drain();
        expectBlocked(lane);
        expect(
          events.where(
            (e) => e.startsWith('cloud:closed') || e.startsWith('cloud:admin'),
          ),
          isEmpty,
        );
        expectNoFinancialMutation();
      },
    );
  }

  test(
    'unwitnessed subscription retry preserves legacy canonical paid restore without a new charge',
    () async {
      await ready('subscription');
      final previousEntitlement = store.entitlement;
      final previousBenefitRevision = store.verifiedBenefitRevision;
      expect(previousEntitlement?.grantsPaidAccess, isTrue);
      api.launch = () async =>
          throw StateError('Synthetic unknown launch result');
      await buy('subscription');
      await _drain();
      expectBlocked('subscription');
      events.clear();
      api.queryCount = 0;
      await retry('subscription');
      await _drain();
      // This is the existing explicit Restore path, not the new two-snapshot
      // blank-native-error proof: it confirms an already-valid canonical plan.
      expect(events, ['native:inapp', 'native:subs', 'cloud:store']);
      expect(native.restores, 1);
      expect(api.queryCount, 2);
      expect(store.state, VerifiedStoreState.verified);
      expect(store.messageCode, 'subscription_verified');
      expect(store.canStartPurchase, isTrue);
      expect(store.entitlement?.plan, previousEntitlement?.plan);
      expect(store.entitlement?.verifiedAt, previousEntitlement?.verifiedAt);
      expect(store.verifiedBenefitRevision, previousBenefitRevision);
      expect(api.launches, 1);
      expectNoFinancialMutation();
    },
  );

  for (final active in ['subscription', 'boost']) {
    test(
      'unscoped callback settles only active $active when both live services listen',
      () async {
        await store.initialize();
        await boost.initialize();
        await _drain();
        events.clear();
        api.queryCount = 0;
        await reject(active);
        final idle = active == 'subscription' ? 'boost' : 'subscription';
        expect(purchasable(idle), isTrue);
        expect(code(idle), isNull);
        expect(api.launches, 1);
        expectNoFinancialMutation();
      },
    );
  }

  testWidgets(
    'real Plans shows native failure with recovery, not waiting confirmation',
    (tester) async {
      ProviderContainer? container;
      try {
        await tester.runAsync(() async {
          await ready('subscription');
          await reject('subscription');
        });
        final paid = SubscriptionState(
          plan: CommercePlan.premiumAiCoach,
          entitlements: PaidPlanCatalog.composedEntitlementsFor(
            CommercePlan.premiumAiCoach,
          ),
          authority: EntitlementAuthority.verifiedServer,
          provider: SubscriptionProvider.google,
          lifecycle: SubscriptionLifecycle.active,
          startedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
          currentPeriodEndsAt: DateTime.now().toUtc().add(
            const Duration(days: 1),
          ),
          verifiedAt: DateTime.now().toUtc(),
          isPurchasable: true,
          canRestorePurchases: true,
        );
        container = ProviderContainer(
          overrides: [
            verifiedEntitlementOwnerProvider.overrideWith(
              (_) => Stream.value(_owner),
            ),
            verifiedEntitlementLoaderProvider.overrideWithValue(
              () async => paid,
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: BilStorePlansPage(
                store: store,
                connectToDeviceStore: false,
                productIds: const {_sku},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(BilStoreCopy.text('en', 'purchase_confirmation_pending')),
          findsNothing,
        );
        expect(
          find.text(BilStoreCopy.text('en', 'purchase_error')),
          findsOneWidget,
        );
        expect(purchasable('subscription'), isFalse);
        expect(api.launches, 1);
        expectNoFinancialMutation();
      } finally {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          container?.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      }
    },
  );
}
