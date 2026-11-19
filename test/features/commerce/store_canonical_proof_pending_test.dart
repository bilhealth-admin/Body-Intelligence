import 'dart:async';
import 'dart:convert';

import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '00000000-0000-4000-8000-000000000071';
const _other = '00000000-0000-4000-8000-000000000072';
const _offer = BilStoreOfferMetadata(
  productId: StoreCatalogConfiguration.premiumMonthly,
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Premium',
  localizedPrice: '2.49',
  currencyCode: 'USD',
  priceMicros: 2490000,
  billingPeriodIso8601: 'P1M',
);

// This tests the platform-independent real receipt service, not a native store.
class _Native extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  PurchaseDetails? restored;
  int launches = 0, finishes = 0, restores = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          AppStoreProduct2Details.fromSK2Product(
            SK2Product(
              id: _offer.productId,
              displayName: 'Premium',
              description: 'Synthetic test',
              displayPrice: '2.49',
              price: 2.49,
              type: SK2ProductType.autoRenewable,
              priceLocale: SK2PriceLocale(
                currencyCode: 'USD',
                currencySymbol: r'$',
              ),
              subscription: SK2SubscriptionInfo(
                subscriptionGroupID: 'synthetic-premium',
                promotionalOffers: const [],
                subscriptionPeriod: const SK2SubscriptionPeriod(
                  value: 1,
                  unit: SK2SubscriptionPeriodUnit.month,
                ),
              ),
            ),
          ),
        ],
        notFoundIDs: const [],
      );
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    launches++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
    if (restored != null) updates.add([restored!]);
  }
}

class _Store extends VerifiedStorePurchaseService {
  _Store(_Native native) : super(purchase: native);
  @override
  bool get configured => true;
}

class _Catalog implements BilStoreCatalogGateway {
  _Catalog(this.store);
  final _Store store;
  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> ids) async => [
    _offer,
  ];
  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) =>
      store.purchasePlan(CommercePlan.premium, term: SubscriptionTerm.oneMonth);
  @override
  Future<void> restorePurchases() => store.restore();
  @override
  Future<void> openManageSubscriptions() async {}
}

class _Harness {
  final native = _Native();
  late final store = _Store(native);
  final verifyEntered = Completer<void>();
  final response = Completer<http.Response>();
  bool afterVerification = false, canonicalFails = false;
  int verifies = 0, postVerifyReads = 0;
  List<Map<String, Object?>> rows = [];
  Future<void> Function()? beforeCanonical;
  PurchaseDetails receipt({PurchaseStatus status = PurchaseStatus.purchased}) =>
      PurchaseDetails(
        purchaseID: 'same-exact-synthetic-receipt',
        productID: _offer.productId,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'synthetic',
          serverVerificationData: 'synthetic-signed-evidence',
          source: 'app_store',
        ),
        transactionDate: '1',
        status: status,
      )..pendingCompletePurchase = true;

  static Future<_Harness> open() async {
    final h = _Harness();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
    await Supabase.initialize(
      url: 'https://canonical-pending-test.invalid',
      publishableKey: 'synthetic-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/rest/v1/bil_subscriptions') {
          if (h.afterVerification) {
            h.postVerifyReads++;
            await h.beforeCanonical?.call();
            if (h.canonicalFails) {
              throw StateError('synthetic canonical network error');
            }
          }
          return http.Response(
            jsonEncode(h.rows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path == '/functions/v1/verify-store-purchase') {
          h.verifies++;
          if (!h.verifyEntered.isCompleted) h.verifyEntered.complete();
          final result = await h.response.future;
          h.afterVerification = true;
          return result;
        }
        throw StateError('Unexpected synthetic endpoint: ${request.url.path}');
      }),
    );
    await h.owner(_owner);
    await h.store.initialize();
    expect(h.store.canStartPurchase, isTrue);
    return h;
  }

  Future<void> owner(String value) async {
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-session-token',
        'token_type': 'bearer',
        'user': {
          'id': value,
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }

  Future<void> emit({bool explicit = true}) async {
    if (explicit) {
      await store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      expect(native.launches, 1);
    }
    native.updates.add([receipt()]);
    await verifyEntered.future.timeout(const Duration(seconds: 3));
  }

  void verified({int status = 200, Map<String, Object?>? body}) =>
      response.complete(
        http.Response(
          jsonEncode(body ?? {'verified': true, 'entitlement_active': true}),
          status,
          headers: {'content-type': 'application/json'},
        ),
      );

  Future<void> settled() async {
    final done = Completer<void>();
    void changed() {
      if (!done.isCompleted && !store.busy) done.complete();
    }

    store.addListener(changed);
    try {
      changed();
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      store.removeListener(changed);
    }
  }

  void publishPaid() {
    final now = DateTime.now().toUtc();
    rows = [
      {
        'owner_id': _owner,
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
  }

  Future<void> close() async {
    store.dispose();
    if (!response.isCompleted) verified(body: {'verified': false});
    await native.updates.close();
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
    VerifiedStorePurchaseService.resetTransactionReplayProtectionForTesting();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'verified active response with three empty canonical reads remains neutral and blocked',
    () async {
      final h = await _Harness.open();
      addTearDown(h.close);
      await h.emit();
      h.verified();
      await h.settled();
      expect(h.postVerifyReads, 3);
      expect(h.verifies, 1);
      expect(h.store.messageCode, 'purchase_status_unknown');
      expect(h.store.entitlement?.grantsPaidAccess ?? false, isFalse);
      expect(h.store.verifiedBenefitRevision, 0);
      expect(h.native.finishes, 0);
      expect(h.store.canStartPurchase, isFalse);
      await h.store.purchasePlan(
        CommercePlan.premium,
        term: SubscriptionTerm.oneMonth,
      );
      expect(h.native.launches, 1);
      expect(h.verifies, 1, reason: 'No new automatic verification request.');
      // Existing explicit verification action may settle this exact receipt later.
      h.publishPaid();
      h.native.restored = h.receipt(status: PurchaseStatus.restored);
      await h.store.continueVerification();
      await h.settled();
      expect(h.store.state, VerifiedStoreState.verified);
      expect(h.store.entitlement!.grantsPaidAccess, isTrue);
      expect(h.native.finishes, 1);
      expect(h.native.launches, 1);
      expect(
        h.verifies,
        2,
        reason: 'Only the existing explicit recovery re-verifies.',
      );
    },
  );

  testWidgets(
    'real Plans shows pending not red after verified response and canonical lag',
    (tester) async {
      final h = (await tester.runAsync(_Harness.open))!;
      addTearDown(h.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BilStorePlansPage(
            store: h.store,
            catalog: _Catalog(h.store),
            productIds: {_offer.productId},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await h.emit();
        h.verified();
        await h.settled();
      });
      await tester.pump();
      expect(h.postVerifyReads, 3);
      expect(h.native.finishes, 0);
      expect(h.store.verifiedBenefitRevision, 0);
      final pending = find.text(
        BilStoreCopy.text('en', 'purchase_confirmation_pending'),
      );
      expect(pending, findsOneWidget);
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_verification_unavailable')),
        findsNothing,
      );
      final label = tester.widget<Text>(pending);
      expect(
        label.style?.color,
        isNot(Theme.of(tester.element(pending)).colorScheme.error),
      );
      expect(h.store.canStartPurchase, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'passive canonical lag stays hidden without granting or finishing',
    (tester) async {
      final h = (await tester.runAsync(_Harness.open))!;
      addTearDown(h.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BilStorePlansPage(
            store: h.store,
            catalog: _Catalog(h.store),
            productIds: {_offer.productId},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await h.emit(explicit: false);
        h.verified();
        await h.settled();
      });
      await tester.pump();
      expect(h.postVerifyReads, 3);
      expect(h.native.launches, 0);
      expect(h.native.finishes, 0);
      expect(h.store.verifiedBenefitRevision, 0);
      expect(h.store.canStartPurchase, isFalse);
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_confirmation_pending')),
        findsNothing,
      );
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_verification_unavailable')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final failure in [
    'backend',
    'ownership',
    'canonical-network',
    'canonical-invalid',
  ]) {
    test('genuine $failure remains a failed verification', () async {
      final h = await _Harness.open();
      addTearDown(h.close);
      await h.emit();
      if (failure == 'canonical-network') h.canonicalFails = true;
      if (failure == 'canonical-invalid') {
        h.rows = [
          {'verified_at': 'unreadable'},
        ];
      }
      h.verified(
        status: failure == 'ownership' ? 409 : 200,
        body: failure == 'backend'
            ? {'verified': false}
            : failure == 'ownership'
            ? {'error': 'purchase_owned_by_another_account'}
            : null,
      );
      await h.settled();
      expect(
        h.store.messageCode,
        failure == 'ownership'
            ? 'purchase_owned_by_another_account'
            : 'verification_failed',
      );
      expect(h.store.canStartPurchase, isFalse);
      expect(h.native.finishes, 0);
      expect(h.store.verifiedBenefitRevision, 0);
    });
  }

  test(
    'owner A to B to A during held canonical read retires old receipt',
    () async {
      final h = await _Harness.open();
      addTearDown(h.close);
      final entered = Completer<void>(), release = Completer<void>();
      h.beforeCanonical = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      await h.emit();
      h.verified();
      await entered.future.timeout(const Duration(seconds: 3));
      await h.owner(_other);
      await h.owner(_owner);
      release.complete();
      await h.settled();
      expect(h.native.finishes, 0);
      expect(h.store.verifiedBenefitRevision, 0);
      expect(h.store.messageCode, 'authentication_required');
      expect(h.store.entitlement, isNull);
    },
  );
}
