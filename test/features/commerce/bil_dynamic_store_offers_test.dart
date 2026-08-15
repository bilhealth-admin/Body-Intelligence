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
    expect(find.text('Premium AI Coach'), findsOneWidget);
    expect(find.text('BIL AI Boost'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Price unavailable on this device'), findsNWidgets(3));
    expect(find.text('Loading price from the store…'), findsNothing);
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
    await tester.tap(
      find.byKey(
        const ValueKey('store-offer-premium_monthly_owner_placeholder'),
      ),
    );
    expect(requested, same(offer));
    expect(find.textContaining('EGP 99.00'), findsOneWidget);
  });
}
