import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_price_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('annual comparison derives savings from matching store offers', () {
    for (final fixture in const [
      (
        kind: BilStoreProductKind.premiumSubscription,
        currency: 'USD',
        monthlyMicros: 2490000,
        annualMicros: 21000000,
      ),
      (
        kind: BilStoreProductKind.premiumAiCoachSubscription,
        currency: 'USD',
        monthlyMicros: 5990000,
        annualMicros: 49990000,
      ),
    ]) {
      final monthly = BilStoreOfferMetadata(
        productId: '${fixture.kind.name}.monthly',
        kind: fixture.kind,
        localizedTitle: 'Monthly',
        localizedPrice: 'Store monthly price',
        currencyCode: fixture.currency,
        priceMicros: fixture.monthlyMicros,
        billingPeriodIso8601: 'P1M',
      );
      final annual = BilStoreOfferMetadata(
        productId: '${fixture.kind.name}.annual',
        kind: fixture.kind,
        localizedTitle: 'Annual',
        localizedPrice: 'Store annual price',
        currencyCode: fixture.currency,
        priceMicros: fixture.annualMicros,
        billingPeriodIso8601: 'P1Y',
      );

      final comparison = StorePriceComparison.forAnnualOffer(annual, [
        monthly,
        annual,
      ]);

      expect(comparison, isNotNull);
      expect(
        comparison!.twelveMonthlyPaymentsMicros,
        fixture.monthlyMicros * 12,
      );
      expect(
        comparison.monthlyEquivalentMicros,
        (fixture.annualMicros / 12).round(),
      );
      expect(comparison.savingsPercent, 30);
    }
  });

  test('store-tier rounding can produce a market-specific saving', () {
    for (final fixture in const [
      (
        currency: 'EGP',
        monthlyMicros: 129990000,
        annualMicros: 999990000,
        expectedSavings: 36,
      ),
      (
        currency: 'PKR',
        monthlyMicros: 700000000,
        annualMicros: 5900000000,
        expectedSavings: 30,
      ),
    ]) {
      final monthly = BilStoreOfferMetadata(
        productId: 'premium.monthly.${fixture.currency}',
        kind: BilStoreProductKind.premiumSubscription,
        localizedTitle: 'Monthly',
        localizedPrice: 'Store monthly price',
        currencyCode: fixture.currency,
        priceMicros: fixture.monthlyMicros,
        billingPeriodIso8601: 'P1M',
      );
      final annual = BilStoreOfferMetadata(
        productId: 'premium.annual.${fixture.currency}',
        kind: BilStoreProductKind.premiumSubscription,
        localizedTitle: 'Annual',
        localizedPrice: 'Store annual price',
        currencyCode: fixture.currency,
        priceMicros: fixture.annualMicros,
        billingPeriodIso8601: 'P1Y',
      );

      final comparison = StorePriceComparison.forAnnualOffer(annual, [
        monthly,
        annual,
      ]);
      expect(comparison, isNotNull);
      expect(comparison!.savingsPercent, fixture.expectedSavings);
      expect(
        comparison.twelveMonthlyPaymentsMicros,
        fixture.monthlyMicros * 12,
      );
    }
  });

  test('any real annual saving remains store-derived instead of fixed', () {
    const monthly = BilStoreOfferMetadata(
      productId: 'premium.monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Monthly',
      localizedPrice: 'Store monthly price',
      currencyCode: 'USD',
      priceMicros: 100000000,
      billingPeriodIso8601: 'P1M',
    );
    const annual = BilStoreOfferMetadata(
      productId: 'premium.annual',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Annual',
      localizedPrice: 'Store annual price',
      currencyCode: 'USD',
      priceMicros: 846000001,
      billingPeriodIso8601: 'P1Y',
    );

    final comparison = StorePriceComparison.forAnnualOffer(annual, const [
      monthly,
      annual,
    ]);
    expect(comparison, isNotNull);
    expect(comparison!.savingsPercent, 29);
    expect(comparison.hasSavings, isTrue);
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
