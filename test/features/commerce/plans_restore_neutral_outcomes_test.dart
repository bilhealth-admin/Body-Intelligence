import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_copy.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_store_plans_page.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _offer = BilStoreOfferMetadata(
  productId: StoreCatalogConfiguration.premiumMonthly,
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'Premium',
  localizedPrice: r'$2.49',
  currencyCode: 'USD',
  priceMicros: 2490000,
  billingPeriodIso8601: 'P1M',
);

void main() {
  for (final code in ['restore_cancelled', 'restore_unconfirmed']) {
    testWidgets('actual Plans restore shows neutral $code and allows retry', (
      tester,
    ) async {
      final store = _OutcomeStore();
      final catalog = _OutcomeCatalog(store, code);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BilStorePlansPage(
            store: store,
            catalog: catalog,
            productIds: const {StoreCatalogConfiguration.premiumMonthly},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final restore = find.text(BilStoreCopy.text('en', 'restore'));
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();

      final offers = tester.widget<BilDynamicStoreOffers>(
        find.byType(BilDynamicStoreOffers),
      );
      expect(offers.purchaseStatusMessage, BilStoreCopy.text('en', code));
      expect(offers.purchaseStatusIsError, isFalse);
      expect(offers.restoreInProgress, isFalse);
      expect(offers.purchaseInProgress, isFalse);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(BilStoreCopy.text('en', code)),
        ),
        findsOneWidget,
      );
      for (final incorrect in [
        'restore_none',
        'restore_checked',
        'restore_verified',
        'restore_failed',
        'restore_checking',
      ]) {
        expect(find.text(BilStoreCopy.text('en', incorrect)), findsNothing);
      }
      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('store-purchase-cta')))
            .onTap,
        isNotNull,
      );
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      expect(catalog.restores, 2);
      expect(catalog.purchases, 0);
      expect(store.verifiedBenefitRevision, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('late $code cannot clear a verified ownership conflict', (
      tester,
    ) async {
      final conflict = PurchaseOwnershipConflictStore()
        ..recordConflict(StoreCatalogConfiguration.premiumMonthly);
      final container = ProviderContainer(
        overrides: [
          purchaseOwnershipConflictStoreProvider.overrideWithValue(conflict),
        ],
      );
      final store = _OutcomeStore()
        ..lastVerifiedProductId = StoreCatalogConfiguration.premiumMonthly;
      final catalog = _OutcomeCatalog(store, code);
      addTearDown(container.dispose);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: BilStorePlansPage(
              store: store,
              catalog: catalog,
              productIds: const {StoreCatalogConfiguration.premiumMonthly},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      store.report(code);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BilDynamicStoreOffers>(find.byType(BilDynamicStoreOffers))
            .purchaseStatusMessage,
        BilStoreCopy.text('en', code),
      );
      expect(
        conflict.blockedFor(BilStoreProductKind.premiumSubscription),
        isTrue,
      );
      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('store-purchase-cta')))
            .onTap,
        isNull,
      );
      expect(catalog.purchases, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

final class _OutcomeStore extends VerifiedStorePurchaseService {
  _OutcomeStore() {
    state = VerifiedStoreState.ready;
  }

  @override
  bool get canStartPurchase => !busy;

  void report(String code) {
    state = VerifiedStoreState.ready;
    messageCode = code;
    notifyListeners();
  }
}

final class _OutcomeCatalog implements BilStoreCatalogGateway {
  _OutcomeCatalog(this.store, this.code);

  final _OutcomeStore store;
  final String code;
  int restores = 0;
  int purchases = 0;

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(
    Set<String> productIds,
  ) async => const [_offer];

  @override
  Future<void> openManageSubscriptions() async {}

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    purchases++;
  }

  @override
  Future<void> restorePurchases() async {
    restores++;
    store.report(code);
  }
}
