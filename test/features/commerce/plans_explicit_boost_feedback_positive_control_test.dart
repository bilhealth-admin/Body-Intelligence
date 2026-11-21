// Controlled widget reproduction of an observed cross-product feedback race.
// Real default Plans widget and real catalog adapter / real Boost notifier.
// Only native billing and authoritative Free account boundaries are fixtures.
// No production network, grants, receipts, credentials or phone input.
import 'dart:async';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/providers/app_purchase_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/store_account_visit.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

ProductDetails _product(String id, String price, double raw) {
  if (id == StoreCatalogConfiguration.aiBoost) {
    return ProductDetails(
      id: id,
      title: 'Controlled store product',
      description: 'Fixture',
      price: price,
      rawPrice: raw,
      currencyCode: 'EGP',
      currencySymbol: 'EGP',
    );
  }
  return AppStoreProduct2Details.fromSK2Product(
    SK2Product(
      id: id,
      displayName: 'Controlled store product',
      description: 'Fixture',
      displayPrice: price,
      price: raw,
      type: SK2ProductType.autoRenewable,
      priceLocale: SK2PriceLocale(currencyCode: 'EGP', currencySymbol: 'EGP'),
      subscription: SK2SubscriptionInfo(
        subscriptionGroupID: 'fixture-premium',
        promotionalOffers: const [],
        subscriptionPeriod: SK2SubscriptionPeriod(
          value: 1,
          unit: id == StoreCatalogConfiguration.premiumAnnual
              ? SK2SubscriptionPeriodUnit.year
              : SK2SubscriptionPeriodUnit.month,
        ),
      ),
    ),
  );
}

class _NativeBoundary extends InAppPurchasePlatform {
  int launches = 0, finishes = 0;
  final launchedProducts = <String>[];
  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    expect(autoConsume, isFalse);
    launches++;
    launchedProducts.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    finishes++;
  }

  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          _product(StoreCatalogConfiguration.aiBoost, 'EGP 99.99', 99.99),
        ],
        notFoundIDs: const [],
      );
}

class _HeldAnnualBoundary extends VerifiedStorePurchaseService {
  _HeldAnnualBoundary() : super(handlesBoost: false) {
    products = {
      StoreCatalogConfiguration.premiumAnnual: _product(
        StoreCatalogConfiguration.premiumAnnual,
        'EGP 599.99',
        599.99,
      ),
      StoreCatalogConfiguration.premiumMonthly: _product(
        StoreCatalogConfiguration.premiumMonthly,
        'EGP 99.99',
        99.99,
      ),
    };
    state = VerifiedStoreState.ready;
  }
  final completion = Completer<void>();
  final requested = <(CommercePlan, SubscriptionTerm)>[];
  @override
  bool get canStartPurchase => true;
  @override
  bool get busy => false;
  @override
  String? get catalogStoreCountryCode => 'EG';
  @override
  Future<String?> readStorefrontCountry() async => 'EG';
  @override
  StoreAccountSnapshot captureCatalogVisit() =>
      const StoreAccountSnapshot('fixture-owner', 0);
  @override
  bool isCurrentCatalogVisit(StoreAccountSnapshot visit) =>
      visit.ownerId == 'fixture-owner';
  @override
  Future<void> initialize() async {}
  @override
  Future<void> purchasePlan(
    CommercePlan plan, {
    required SubscriptionTerm term,
    GooglePlayPurchaseDetails? replacesGooglePurchase,
    bool downgradeAtRenewal = false,
    String? expectedGoogleOfferToken,
    String? expectedStoreCountryCode,
  }) {
    requested.add((plan, term));
    return completion
        .future; // Actual default Plans _purchaseRequestInFlight stays true.
  }
}

void main() {
  testWidgets(
    'explicit Boost retains pending and verified feedback on real default Plans',
    (tester) async {
      tester.view.physicalSize = const Size(428, 926);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final native = _NativeBoundary();
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      InAppPurchasePlatform.instance = native;
      final sdk = InAppPurchase.instance;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final store = _HeldAnnualBoundary();
      final boost = AiBoostPurchaseService(
        purchase: sdk,
        owner: () => 'fixture-owner',
        verify: (_, _) async =>
            true, // Controlled server-verification boundary only.
      );
      final free = SubscriptionState(
        plan: CommercePlan.free,
        entitlements: FreePlan.entitlements,
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: false,
      );
      final container = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('fixture-owner'),
          verifiedSubscriptionAccessProvider.overrideWithValue(
            AsyncValue.data(free),
          ),
          appSubscriptionPurchaseProvider.overrideWithValue(store),
          appBoostPurchaseProvider.overrideWithValue(boost),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: BilStorePlansPage(initialFocus: 'boost'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cta = find.byKey(const ValueKey('store-purchase-cta'));
        expect(cta, findsOneWidget);
        expect(
          find.descendant(of: cta, matching: find.textContaining('99.99')),
          findsOneWidget,
        );
        await tester.tap(
          cta,
        ); // Genuine page -> adapter -> production purchaseBoost.
        await tester.pump();
        await tester.pump();
        expect(native.launches, 1);
        expect(native.launchedProducts, [StoreCatalogConfiguration.aiBoost]);
        expect(store.requested, isEmpty);
        expect(boost.hasUserInitiatedFeedback, isTrue);
        expect(boost.state, AiBoostPurchaseState.pending);
        expect(
          find.text(BilStoreCopy.text('en', 'purchase_in_progress')),
          findsOneWidget,
        );

        final purchased = PurchaseDetails(
          purchaseID: 'controlled-explicit-boost-event',
          productID: StoreCatalogConfiguration.aiBoost,
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'fixture',
            source: 'app_store',
          ),
          transactionDate: '1',
          status: PurchaseStatus.purchased,
        )..pendingCompletePurchase = true;
        native.updates.add([purchased]);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(boost.state, AiBoostPurchaseState.verified);
        expect(boost.lastDeliveryIsUserPurchase, isTrue);
        expect(boost.hasUserInitiatedFeedback, isTrue);
        expect(
          find.text(BilStoreCopy.text('en', 'purchase_verified')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: cta, matching: find.textContaining('99.99')),
          findsOneWidget,
        );
        expect(native.launches, 1);
        expect(store.requested, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        if (!store.completion.isCompleted) store.completion.complete();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        boost.dispose();
        store.dispose();
        await native.updates.close();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
