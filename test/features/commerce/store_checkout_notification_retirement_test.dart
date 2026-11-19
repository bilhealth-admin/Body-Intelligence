import '../../support/google_subscription_replacement_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/services/android_store_purchase_readiness.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ownerA = '00000000-0000-4000-8000-000000000001';
const ownerB = '00000000-0000-4000-8000-000000000002';
Future<void> signIn(String owner) =>
    Supabase.instance.client.auth.setInitialSession(
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
// A real release-eligible monthly Google subscription is necessary: a plain
// ProductDetails would fail freshness before reaching the pending notification.
GooglePlayProductDetails subscription() =>
    GooglePlayProductDetails.fromProductDetails(
      ProductDetailsWrapper(
        productId: 'bil_premium_ai_coach',
        name: 'AI Coach',
        title: 'AI Coach',
        description: 'Synthetic notification-boundary test',
        productType: ProductType.subs,
        subscriptionOfferDetails: [
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: null,
            offerTags: [],
            offerIdToken: 'synthetic-monthly-token',
            pricingPhases: [
              const PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: 'USD 4.25',
                priceAmountMicros: 4250000,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      ),
    ).single;
ProductDetails boost() => ProductDetails(
  id: AiBoostPurchaseService.productId,
  title: 'Boost',
  description: 'Synthetic boundary test',
  price: 'USD 2.49',
  rawPrice: 2.49,
  currencyCode: 'USD',
);
AndroidStorePurchaseReadiness positiveReadiness() =>
    AndroidStorePurchaseReadiness(
      probe: (_, _) async {},
      recover: (_) async => throw StateError('No dialog expected'),
      release: (_) async {},
    );

class Native extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  int queries = 0, billing = 0, finishes = 0;
  Completer<void>? quoteEntered;
  Completer<ProductDetailsResponse>? heldQuote;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> countryCode() async => 'JOR';
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queries++;
    final held = heldQuote;
    if (held != null) {
      quoteEntered!.complete();
      return held.future;
    }
    return ProductDetailsResponse(
      productDetails: [
        for (final id in ids)
          if (id == 'bil_premium_ai_coach') subscription() else boost(),
      ],
      notFoundIDs: [],
    );
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    expect(autoConsume, isFalse);
    billing++;
    return true;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    billing++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
  }
}

class Store extends VerifiedStorePurchaseService {
  Store(Native native)
    : super(
        googleReplacementReader: emptyGoogleSubscriptionProofFixture(),
        purchase: native,
        androidReadiness: positiveReadiness(),
      );
  @override
  bool get configured => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Native native;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.invalid',
      publishableKey: 'synthetic-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient(
        (_) async => throw StateError('No HTTP/verification expected'),
      ),
    );
    await signIn(ownerA);
    native = Native();
  });
  tearDown(() async {
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
  for (final boundary in [
    'legacy-quote-finally',
    'legacy-pending',
    'subscription-pending',
  ]) {
    test(
      '$boundary notification owner retirement prevents native Billing',
      () async {
        final service = Store(native)
          ..state = VerifiedStoreState.ready
          ..products = {
            'bil_premium_ai_coach': subscription(),
            AiBoostPurchaseService.productId: boost(),
          };
        var fired = false;
        void retire() {
          final atBoundary = boundary == 'legacy-quote-finally'
              ? native.queries == 1 &&
                    service.state == VerifiedStoreState.loading &&
                    !service.busy
              : service.state == VerifiedStoreState.purchasePending;
          if (fired || !atBoundary) return;
          fired = true;
          // Pinned GoTrue setInitialSession updates currentSession synchronously.
          // This avoids ChangeNotifier.dispose() during notifyListeners' stack.
          unawaited(signIn(ownerB));
          expect(Supabase.instance.client.auth.currentUser?.id, ownerB);
        }

        service.addListener(retire);
        try {
          if (boundary == 'subscription-pending') {
            await service.purchasePlan(
              CommercePlan.premiumAiCoach,
              term: SubscriptionTerm.oneMonth,
            );
          } else {
            await service.purchaseBoost();
          }
          await Future<void>.delayed(Duration.zero);
          expect(
            fired,
            isTrue,
            reason: 'Must reach the intended notification boundary',
          );
          expect(native.billing, 0);
          expect(native.finishes, 0);
          expect(service.verifiedBenefitRevision, 0);
        } finally {
          service.removeListener(retire);
          service.dispose();
        }
      },
    );
  }
  test(
    'dedicated Boost pending notification owner retirement prevents native Billing',
    () async {
      final service = AiBoostPurchaseService(
        purchase: native,
        owner: () => Supabase.instance.client.auth.currentUser?.id,
        verify: (_, _) async =>
            throw StateError('No receipt verification expected'),
        reconcile: () async => [],
        androidReadiness: positiveReadiness(),
      );
      var fired = false;
      void retire() {
        if (fired || service.state != AiBoostPurchaseState.pending) return;
        fired = true;
        unawaited(signIn(ownerB));
        expect(Supabase.instance.client.auth.currentUser?.id, ownerB);
      }

      try {
        await service.initialize();
        service.addListener(retire);
        await service.purchaseBoost();
        await Future<void>.delayed(Duration.zero);
        expect(fired, isTrue);
        expect(native.billing, 0);
        expect(native.finishes, 0);
        expect(service.verifiedCreditsRevision, 0);
      } finally {
        service.removeListener(retire);
        service.dispose();
      }
    },
  );
  test(
    'legacy held quote disposed before query completion cannot enter Billing',
    () async {
      final service = Store(native)
        ..state = VerifiedStoreState.ready
        ..products = {AiBoostPurchaseService.productId: boost()};
      final entered = native.quoteEntered = Completer<void>();
      final held = native.heldQuote = Completer<ProductDetailsResponse>();
      final events = <String>[];
      var disposed = false;
      try {
        final buying = service.purchaseBoost();
        await entered.future.timeout(const Duration(seconds: 2));
        events.add('query_entered');
        expect(native.queries, 1);
        expect(held.isCompleted, isFalse);
        expect(native.billing, 0);
        service.dispose();
        disposed = true;
        events.add('dispose_completed');
        held.complete(
          ProductDetailsResponse(productDetails: [boost()], notFoundIDs: []),
        );
        events.add('query_completed');
        await buying;
        events.add('purchase_returned');
        expect(events, [
          'query_entered',
          'dispose_completed',
          'query_completed',
          'purchase_returned',
        ]);
        expect(native.billing, 0);
        expect(native.finishes, 0);
      } finally {
        if (!disposed) service.dispose();
        if (!held.isCompleted) {
          held.complete(
            ProductDetailsResponse(productDetails: [], notFoundIDs: []),
          );
        }
      }
    },
  );
}
