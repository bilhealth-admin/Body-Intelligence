import '../../support/google_subscription_replacement_fixture.dart';
import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_lifecycle.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/commerce/services/android_store_purchase_readiness.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/src/billing_client_wrappers/billing_config_wrapper.dart';
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
const _boostId = StoreCatalogConfiguration.aiBoost;

GooglePlayProductDetails _subscription(String id, {String token = 'token'}) =>
    GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        productId: id,
        name: id,
        title: id,
        description: 'Synthetic regional checkout boundary',
        productType: ProductType.subs,
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: id.endsWith('_annual') ? 'yearly' : 'monthly',
            offerId: null,
            offerTags: const [],
            offerIdToken: token,
            pricingPhases: [
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: id.endsWith('_annual') ? 'P1Y' : 'P1M',
                formattedPrice: 'USD 9.99',
                priceAmountMicros: 9990000,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      ),
    ).single;

ProductDetails _boost() => ProductDetails(
  id: _boostId,
  title: 'Boost',
  description: 'Synthetic global credit pack',
  price: 'USD 2.49',
  rawPrice: 2.49,
  currencyCode: 'USD',
);

class _Play extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  String country = '';
  Future<String> Function(int)? countryReader;
  Future<ProductDetailsResponse> Function(Set<String>)? query;
  List<ProductDetails> catalog = [
    ...StoreCatalogConfiguration.productIds.map(_subscription),
    _boost(),
  ];
  int countryReads = 0, queries = 0, subscriptions = 0, boosts = 0;
  PurchaseParam? lastPurchase;
  @override
  Future<String> countryCode() {
    final index = ++countryReads;
    return countryReader?.call(index) ?? Future.value(country);
  }

  @override
  Future<bool> isAvailable() async => true;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    queries++;
    return query?.call(ids) ??
        Future.value(
          ProductDetailsResponse(
            productDetails: catalog,
            notFoundIDs: const [],
          ),
        );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    subscriptions++;
    lastPurchase = purchaseParam;
    return false;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    expect(autoConsume, isFalse);
    boosts++;
    lastPurchase = purchaseParam;
    return false;
  }
}

class _CountryBilling extends billing.NativeBillingClient {
  _CountryBilling(this.code);
  final BillingResponse code;
  @override
  Future<BillingConfigWrapper> getBillingConfig() async => BillingConfigWrapper(
    responseCode: code,
    debugMessage: 'Synthetic missing native billing config',
    countryCode: '',
  );
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Play play)
    : super(
        googleReplacementReader: emptyGoogleSubscriptionProofFixture(),
        purchase: play,
        androidReadiness: _licensedReadinessForBillingBoundary(),
        handlesBoost: false,
      );
  @override
  bool get configured => true;
}

Future<void> _signIn(String owner) =>
    Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-test-token',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Play play;
  late _Store store;
  late VerifiedStoreCatalogAdapter adapter;
  final states = <VerifiedStoreState>[];

  void seed(String id) {
    final product = _subscription(id);
    store.products = {id: product};
    store.state = VerifiedStoreState.ready;
  }

  Future<void> buy(String id) {
    final binding = StoreCatalogConfiguration.bindingForProduct(id)!;
    return store.purchasePlan(binding.plan, term: binding.term);
  }

  void expectStopped() {
    expect(play.subscriptions, 0);
    expect(store.messageCode, 'store_catalog_changed');
    expect(store.state, VerifiedStoreState.ready);
    expect(store.busy, isFalse);
    expect(states, isNot(contains(VerifiedStoreState.purchasePending)));
    expect(store.entitlement, isNull);
    expect(store.verifiedBenefitRevision, 0);
  }

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://unknown-storefront-fixture.invalid',
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
        throw StateError('Unexpected network path: ${request.url.path}');
      }),
    );
    await _signIn(_owner);
    play = _Play();
    store = _Store(play);
    adapter = VerifiedStoreCatalogAdapter(store);
    states.clear();
    store.addListener(() => states.add(store.state));
  });
  tearDown(() async {
    store.dispose();
    await play.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final id in StoreCatalogConfiguration.productIds) {
    for (final missing in ['empty', 'unsupported', 'exception']) {
      test(
        'Android $id singleton with $missing country never launches',
        () async {
          seed(id);
          play.countryReader = (_) => missing == 'exception'
              ? Future.error(StateError('Synthetic native country failure'))
              : Future.value(missing == 'empty' ? '' : 'ZZ');
          await buy(id);
          expectStopped();
          expect(play.queries, 0);
        },
      );
    }
  }

  for (final code in [BillingResponse.ok, BillingResponse.serviceUnavailable]) {
    test(
      'pinned plugin empty country with ${code.name} cannot launch a singleton',
      () async {
        seed(StoreCatalogConfiguration.premiumAiCoachAnnual);
        final platform = billing.realAndroidPlatform(_CountryBilling(code));
        try {
          // Exercise the actual pinned Dart plugin: the convenience country API
          // returns only the empty country even when the lower result is non-OK.
          play.countryReader = (_) => platform.countryCode();
          await buy(StoreCatalogConfiguration.premiumAiCoachAnnual);
          expectStopped();
          expect(play.queries, 0);
        } finally {
          platform.billingClientManager.dispose();
        }
      },
    );
  }

  _testAndroidWidgets(
    'unanswered country expires before query or native purchase',
    (tester) async {
      seed(StoreCatalogConfiguration.premiumAiCoachAnnual);
      final held = Completer<String>();
      play.countryReader = (_) => held.future;
      final attempt = buy(StoreCatalogConfiguration.premiumAiCoachAnnual);
      await tester.pump(const Duration(seconds: 5));
      await attempt;
      expectStopped();
      expect(play.queries, 0);
      held.complete('JOR');
      await tester.pump();
      expect(play.subscriptions, 0);
    },
  );

  for (final id in [
    StoreCatalogConfiguration.premiumAnnual,
    StoreCatalogConfiguration.premiumAiCoachAnnual,
  ]) {
    test(
      '$id country becomes unknown after fresh query: no native purchase',
      () async {
        seed(id);
        play.countryReader = (index) => Future.value(
          index == 1
              ? (id == StoreCatalogConfiguration.premiumAnnual ? 'EGY' : 'JOR')
              : '',
        );
        await buy(id);
        expectStopped();
        expect(play.queries, 1);
      },
    );
    test(
      '$id preflight stays locked then uses current eligible token',
      () async {
        seed(id);
        play.country = id == StoreCatalogConfiguration.premiumAnnual
            ? 'EG'
            : 'JO';
        final held = Completer<ProductDetailsResponse>();
        play.query = (_) => held.future;
        final attempt = buy(id);
        await Future<void>.delayed(Duration.zero);
        expect(store.busy, isTrue);
        expect(store.state, VerifiedStoreState.loading);
        await buy(id);
        expect(play.queries, 1);
        expect(play.subscriptions, 0);
        final fresh = _subscription(id, token: 'fresh-synthetic-token');
        held.complete(
          ProductDetailsResponse(
            productDetails: [fresh],
            notFoundIDs: const [],
          ),
        );
        await attempt;
        expect(play.subscriptions, 1);
        expect(play.lastPurchase!.productDetails, same(fresh));
        expect(
          (play.lastPurchase as GooglePlayPurchaseParam).offerToken,
          'fresh-synthetic-token',
        );
        expect(store.entitlement, isNull);
      },
    );
  }

  for (final id in [
    StoreCatalogConfiguration.premiumAnnual,
    StoreCatalogConfiguration.premiumAiCoachAnnual,
  ]) {
    test(
      'unknown adapter hides singleton $id while preserving global Boost',
      () async {
        seed(id);
        store.products = {...store.products, _boostId: _boost()};
        final offers = await adapter.loadOffers(
          StoreCatalogConfiguration.storefrontProductIds,
        );
        expect(offers.map((offer) => offer.productId), [_boostId]);
        expect(play.queries, 0);
        expect(play.subscriptions, 0);
      },
    );
  }

  test(
    'known country after unknown refreshes the proper family without checkout',
    () async {
      seed(StoreCatalogConfiguration.premiumAiCoachAnnual);
      store.products = {...store.products, _boostId: _boost()};
      expect(
        (await adapter.loadOffers(
          StoreCatalogConfiguration.storefrontProductIds,
        )).map((offer) => offer.productId),
        [_boostId],
      );
      play.country = 'EGY';
      final recovered = await adapter.loadOffers(
        StoreCatalogConfiguration.storefrontProductIds,
      );
      expect(recovered.map((offer) => offer.productId).toSet(), {
        StoreCatalogConfiguration.premiumMonthly,
        StoreCatalogConfiguration.premiumAnnual,
        _boostId,
      });
      expect(recovered.map((offer) => offer.storeCountryCode).toSet(), {'EG'});
      expect(play.queries, 1);
      expect(play.subscriptions, 0);
    },
  );

  test(
    'generic subscription-service Boost path remains country independent',
    () async {
      store.products = {_boostId: _boost()};
      store.state = VerifiedStoreState.ready;
      await store.purchaseBoost();
      expect(play.boosts, 1);
      expect(play.countryReads, 0);
      expect(store.entitlement, isNull);
    },
  );
  test('exclusive Boost service remains country independent', () async {
    final boost = AiBoostPurchaseService(
      purchase: play,
      androidReadiness: _licensedReadinessForBillingBoundary(),
      owner: () => _owner,
      ownerChanges: const Stream.empty(),
      verify: (_, _) async => false,
      reconcile: () async => [],
    );
    try {
      await boost.initialize();
      await boost.purchaseBoost();
      expect(play.boosts, 1);
      expect(play.countryReads, 0);
      expect(boost.verifiedCreditsRevision, 0);
    } finally {
      boost.dispose();
    }
  });

  for (final roundTrip in [false, true]) {
    test(
      'owner ${roundTrip ? 'A B A' : 'A B'} retires delayed country read',
      () async {
        seed(StoreCatalogConfiguration.premiumAiCoachAnnual);
        final held = Completer<String>();
        play.countryReader = (_) => held.future;
        final attempt = buy(StoreCatalogConfiguration.premiumAiCoachAnnual);
        await Future<void>.delayed(Duration.zero);
        final delivered = <String?>[];
        final witness = Supabase.instance.client.auth.onAuthStateChange.listen(
          (event) => delivered.add(event.session?.user.id),
        );
        try {
          await _signIn(_other).timeout(const Duration(seconds: 5));
          if (roundTrip) {
            await _signIn(_owner).timeout(const Duration(seconds: 5));
          }
          await Future<void>.delayed(Duration.zero);
          expect(delivered, contains(_other));
          if (roundTrip) expect(delivered, contains(_owner));
          held.complete('JOR');
          await attempt.timeout(const Duration(seconds: 5));
          expect(play.queries, 0);
          expect(play.subscriptions, 0);
          expect(store.entitlement, isNull);
          expect(store.verifiedBenefitRevision, 0);
        } finally {
          await witness.cancel();
        }
      },
    );
  }

  test(
    'disposal retires delayed country without publishing or checkout',
    () async {
      seed(StoreCatalogConfiguration.premiumAiCoachAnnual);
      final held = Completer<String>();
      play.countryReader = (_) => held.future;
      final attempt = buy(StoreCatalogConfiguration.premiumAiCoachAnnual);
      await Future<void>.delayed(Duration.zero);
      store.dispose();
      final published = states.length;
      held.complete('JOR');
      await attempt.timeout(const Duration(seconds: 5));
      expect(states.length, published);
      expect(play.subscriptions, 0);
      expect(play.queries, 0);
    },
  );

  _testAndroidWidgets(
    'actual Plans removes stale restricted cards after unknown-country tap',
    (tester) async {
      ProviderContainer? container;
      try {
        play.country = 'JOR';
        await _hostOperation(tester, () => store.initialize());
        final free = SubscriptionState(
          plan: CommercePlan.free,
          entitlements: FreePlan.entitlements,
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
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('store-offer-bil_premium_ai_coach_annual')),
          findsOneWidget,
        );
        play.country = '';
        await tester.tap(find.byKey(const ValueKey('store-purchase-cta')));
        await tester.pumpAndSettle();
        expect(play.subscriptions, 0);
        expect(store.state, VerifiedStoreState.ready);
        expect(
          find.byKey(const ValueKey('store-offer-bil_premium_ai_coach_annual')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('store-offer-bil_ai_boost')),
          findsOneWidget,
        );
        expect(
          find.text(BilStoreCopy.text('en', 'purchase_confirmation_pending')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('store-continue-verification')),
          findsNothing,
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container?.dispose();
      }
    },
  );
}

Future<T> _hostOperation<T>(
  WidgetTester tester,
  Future<T> Function() operation,
) async {
  var complete = false;
  T? result;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    Future<T>.sync(operation).then<void>(
      (value) {
        result = value;
        complete = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    );
  });
  final elapsed = Stopwatch()..start();
  while (!complete && elapsed.elapsedMilliseconds < 5000) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(
    complete,
    isTrue,
    reason: 'Actual checkout fixture operation did not finish',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return result as T;
}

void _testAndroidWidgets(
  String description,
  Future<void> Function(WidgetTester) callback,
) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
