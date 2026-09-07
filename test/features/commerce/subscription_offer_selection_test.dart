import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _monthly = BilStoreOfferMetadata(
  productId: 'bil_premium',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'BIL Premium Monthly',
  localizedPrice: 'EGP 129.99',
  currencyCode: 'EGP',
  priceMicros: 129990000,
  storeCountryCode: 'EGY',
  billingPeriodIso8601: 'P1M',
);

const _annual = BilStoreOfferMetadata(
  productId: 'bil_premium_annual',
  kind: BilStoreProductKind.premiumSubscription,
  localizedTitle: 'BIL Premium Annual',
  localizedPrice: 'EGP 999.99',
  currencyCode: 'EGP',
  priceMicros: 999990000,
  storeCountryCode: 'EGY',
  billingPeriodIso8601: 'P1Y',
);

Widget _testSurface({required bool purchaseInProgress}) {
  return MaterialApp(
    home: BilDynamicStoreOffers(
      locale: 'en',
      offers: const [_monthly, _annual],
      purchaseInProgress: purchaseInProgress,
      onPurchaseRequested: (_) {},
      onRestore: () {},
      onManage: () {},
      currentPlan: CommercePlan.free,
    ),
  );
}

void main() {
  testWidgets(
    'monthly and annual selection resumes immediately after purchase cancel',
    (tester) async {
      await tester.pumpWidget(_testSurface(purchaseInProgress: false));
      await tester.pumpAndSettle();

      final monthlyTile = find.byKey(const ValueKey('store-offer-bil_premium'));
      final annualTile = find.byKey(
        const ValueKey('store-offer-bil_premium_annual'),
      );
      final purchaseCta = find.byKey(const ValueKey('store-purchase-cta'));

      expect(
        find.descendant(
          of: purchaseCta,
          matching: find.textContaining(_annual.localizedPrice),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(_testSurface(purchaseInProgress: true));
      await tester.pump();
      await tester.ensureVisible(monthlyTile);
      await tester.tap(monthlyTile);
      await tester.pump();
      expect(
        find.descendant(
          of: annualTile,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(_testSurface(purchaseInProgress: false));
      await tester.pump();
      await tester.ensureVisible(monthlyTile);
      await tester.tap(monthlyTile);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: purchaseCta,
          matching: find.textContaining(_monthly.localizedPrice),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: annualTile,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
    },
  );
}
