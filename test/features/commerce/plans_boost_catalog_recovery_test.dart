import 'dart:async';

import 'package:body_intelligence_log/app/localization/app_localizations.dart';

import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_benefit_delivery.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/providers/app_purchase_providers.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/ai_boost_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _BoostNative extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  String price = '2.49';
  int launches = 0, queries = 0;
  bool finishFails = false;
  bool launchFails = false;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (finishFails) throw StateError('fixture finish failure');
  }

  ProductDetails get product => ProductDetails(
    id: StoreCatalogConfiguration.aiBoost,
    title: 'Boost',
    description: 'Fixture only',
    price: price,
    rawPrice: double.parse(price),
    currencyCode: 'USD',
  );
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queries++;
    return ProductDetailsResponse(productDetails: [product], notFoundIDs: []);
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    expect(autoConsume, isFalse);
    expect(purchaseParam.productDetails.price, price);
    launches++;
    if (launchFails) throw StateError('native launch result unavailable');
    return false;
  }
}

class _SubscriptionLane extends VerifiedStorePurchaseService {
  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets(
    'Plans re-entry keeps unresolved Boost visible without repeating purchase',
    (tester) async {
      final native = _BoostNative()..launchFails = true;
      final subscription = _SubscriptionLane()
        ..products = {StoreCatalogConfiguration.aiBoost: native.product}
        ..state = VerifiedStoreState.ready;
      final boost = AiBoostPurchaseService(
        purchase: native,
        owner: () => 'catalog-owner',
        ownerChanges: const Stream.empty(),
        verify: (_, _) async => false,
        reconcile: () async => [],
      );
      await boost.initialize();
      await boost.purchaseBoost();
      expect(boost.errorCode, 'purchase_status_unknown');
      final scope = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('catalog-owner'),
          appSubscriptionPurchaseFactoryProvider.overrideWithValue(
            () => subscription,
          ),
          appBoostPurchaseFactoryProvider.overrideWithValue(() => boost),
        ],
      );
      addTearDown(() async {
        await native.updates.close();
      });
      Widget page() => UncontrolledProviderScope(
        container: scope,
        child: const MaterialApp(
          home: BilStorePlansPage(initialFocus: 'boost'),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_verification_unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('store-continue-verification')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('store-purchase-cta')))
            .onTap,
        isNull,
      );
      expect(native.launches, 1);
      expect(boost.verifiedCreditsRevision, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
      await tester.pump();
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'actual Plans inactive Boost never advertises success while native finish retries',
    (tester) async {
      final native = _BoostNative()..finishFails = true;
      final subscription = _SubscriptionLane()
        ..products = {StoreCatalogConfiguration.aiBoost: native.product}
        ..state = VerifiedStoreState.ready;
      final boost = AiBoostPurchaseService(
        purchase: native,
        owner: () => 'catalog-owner',
        ownerChanges: const Stream.empty(),
        verifyDelivery: (_, owner) async => StoreVerificationOutcome(
          true,
          delivery: StoreBenefitDelivery(
            ownerId: owner,
            store: 'app_store',
            environment: 'sandbox',
            eventKey: 'a' * 64,
            productId: StoreCatalogConfiguration.aiBoost,
            verifiedAt: DateTime.now().toUtc(),
            active: false,
            isBoost: true,
            finishPending: false,
            quantity: 0,
          ),
        ),
        reconcile: () async => [],
      );
      final scope = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('catalog-owner'),
          // Inactive Boost delivers no subscription; keep the real local Free state.
          verifiedSubscriptionStateProvider.overrideWith(
            (ref) async => ref.read(subscriptionStateProvider),
          ),
          appSubscriptionPurchaseFactoryProvider.overrideWithValue(
            () => subscription,
          ),
          appBoostPurchaseFactoryProvider.overrideWithValue(() => boost),
        ],
      );
      addTearDown(() async {
        scope.dispose();
        await native.updates.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: BilStorePlansPage(initialFocus: 'boost'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final beforeRefresh = scope.read(aiCoachUsageRefreshProvider);
      final receipt = PurchaseDetails(
        purchaseID: 'fixture-refunded-transaction',
        productID: StoreCatalogConfiguration.aiBoost,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'fixture-only',
          source: 'app_store',
        ),
        transactionDate: '1',
        status: PurchaseStatus.restored,
      )..pendingCompletePurchase = true;
      native.updates.add([receipt]);
      await tester.pumpAndSettle();
      expect(boost.state, AiBoostPurchaseState.ready);
      expect(boost.errorCode, 'store_finish_pending');
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_verified')),
        findsNothing,
      );
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_inactive')),
        findsOneWidget,
      );
      expect(scope.read(aiCoachUsageRefreshProvider), beforeRefresh + 1);
      expect(boost.canPurchase, isFalse);
      native.finishFails = false;
      await boost.retryPendingTransaction();
      await tester.pumpAndSettle();
      expect(boost.canPurchase, isTrue);
      expect(
        find.text(BilStoreCopy.text('en', 'purchase_verified')),
        findsNothing,
      );
      expect(native.launches, 0);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'actual Plans Boost price mismatch refreshes offer and next tap uses fresh product',
    (tester) async {
      final native = _BoostNative();
      final subscription = _SubscriptionLane()
        ..products = {StoreCatalogConfiguration.aiBoost: native.product}
        ..state = VerifiedStoreState.ready;
      final boost = AiBoostPurchaseService(
        purchase: native,
        owner: () => 'catalog-owner',
        ownerChanges: const Stream.empty(),
        verify: (_, _) async => false,
        reconcile: () async => [],
      );
      final scope = ProviderContainer(
        overrides: [
          verifiedEntitlementOwnerIdProvider.overrideWithValue('catalog-owner'),
          appSubscriptionPurchaseFactoryProvider.overrideWithValue(
            () => subscription,
          ),
          appBoostPurchaseFactoryProvider.overrideWithValue(() => boost),
        ],
      );
      addTearDown(() async {
        scope.dispose();
        await native.updates.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: BilStorePlansPage(initialFocus: 'boost'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2.49'), findsWidgets);
      expect(boost.canPurchase, isTrue);
      native.price = '3.49';
      await tester.tap(find.byKey(const Key('store-purchase-cta')));
      await tester.pumpAndSettle();
      expect(
        native.launches,
        0,
        reason: 'changed offer needs a fresh explicit decision',
      );
      expect(find.text('3.49'), findsWidgets);
      expect(find.text('2.49'), findsNothing);
      final cta = find.byKey(const Key('store-purchase-cta'));
      expect(cta.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: cta, matching: find.text('Continue · 3.49')),
        findsOneWidget,
      );
      expect(find.text('Continue · 2.49'), findsNothing);
      expect(boost.canPurchase, isTrue);
      await tester.tap(find.byKey(const Key('store-purchase-cta')));
      await tester.pumpAndSettle();
      expect(native.launches, 1);
      expect(boost.product!.price, '3.49');
      expect(native.queries, greaterThanOrEqualTo(3));
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
