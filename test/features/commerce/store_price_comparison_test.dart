import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_price_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('annual comparison is derived only from matching store offers', () {
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

    final comparison = StorePriceComparison.forAnnualOffer(annual, const [
      monthly,
      annual,
    ]);

    expect(comparison, isNotNull);
    expect(comparison!.twelveMonthlyPaymentsMicros, 2400000000);
    expect(comparison.monthlyEquivalentMicros, 100000000);
    expect(comparison.savingsPercent, 50);
  });

  test('comparison fails closed without matching monthly store metadata', () {
    const annual = BilStoreOfferMetadata(
      productId: 'premium.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: r'$30.00',
      currencyCode: 'USD',
      priceMicros: 30000000,
      billingPeriodIso8601: 'P1Y',
    );

    expect(StorePriceComparison.forAnnualOffer(annual, const [annual]), isNull);
  });
}
