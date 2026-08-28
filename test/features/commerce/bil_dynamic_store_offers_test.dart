import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/presentation/bil_dynamic_store_offers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not invent prices when store metadata is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Premium AI Coach'), findsNothing);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Price unavailable on this device'), findsNWidgets(2));
    expect(find.text('Loading price from the store…'), findsNothing);
    expect(find.text('Scan food barcode'), findsOneWidget);
    expect(find.text('Macro and nutrient trends'), findsOneWidget);
    expect(find.text('1,500 recipes'), findsOneWidget);
    // The published 302-video inventory is included in Premium.
    expect(find.text('300+ home workout videos'), findsOneWidget);
    expect(find.text('100+ video-guided weight-training plans'), findsNothing);
    expect(find.text('Live fasting timer'), findsOneWidget);
    expect(find.text('Compatible fitness device connections'), findsOneWidget);
    expect(find.text('YOUR COACH. YOUR PLAN. EVERY DAY.'), findsOneWidget);
    expect(find.textContaining('speaks every language'), findsOneWidget);
    expect(
      find.text('Daily, weekly, and monthly plans for your goal'),
      findsOneWidget,
    );
  });

  testWidgets('renders store price and emits request without granting access', (
    tester,
  ) async {
    BilStoreOfferMetadata? requested;
    const offer = BilStoreOfferMetadata(
      productId: 'premium_monthly_owner_placeholder',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'EGP 99.00',
      currencyCode: 'EGP',
      priceMicros: 99000000,
      storeCountryCode: 'EG',
      billingPeriodIso8601: 'P1M',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [offer],
          onPurchaseRequested: (value) => requested = value,
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('store-purchase-cta')));
    expect(requested, same(offer));
    expect(find.textContaining('EGP 99.00'), findsNWidgets(2));
  });

  testWidgets('annual value uses monthly and annual store metadata only', (
    tester,
  ) async {
    const monthly = BilStoreOfferMetadata(
      productId: 'premium.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'EGP 200.00',
      currencyCode: 'EGP',
      priceMicros: 200000000,
      billingPeriodIso8601: 'P1M',
    );
    const annual = BilStoreOfferMetadata(
      productId: 'premium.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: 'EGP 1,200.00',
      currencyCode: 'EGP',
      priceMicros: 1200000000,
      billingPeriodIso8601: 'P1Y',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BilDynamicStoreOffers(
          locale: 'en',
          offers: const [monthly, annual],
          onPurchaseRequested: (_) {},
          onRestore: () {},
          onManage: () {},
        ),
      ),
    );

    expect(find.text('EGP 1,200.00'), findsOneWidget);
    expect(find.textContaining('12 monthly payments:'), findsOneWidget);
    expect(find.textContaining('Monthly equivalent:'), findsOneWidget);
    expect(find.text('Save 50% versus 12 monthly payments'), findsOneWidget);
    final comparisonText = tester.widget<Text>(
      find.textContaining('12 monthly payments:'),
    );
    expect(comparisonText.style?.decoration, TextDecoration.lineThrough);
  });
}
