import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('localized price and offer data remain store-owned', () {
    const offer = BilStoreOfferMetadata(
      productId: 'premium_monthly',
      kind: BilStoreProductKind.premiumSubscription,
      localizedTitle: 'Premium',
      localizedPrice: 'EGP 149.99',
      currencyCode: 'EGP',
      priceMicros: 149990000,
      storeCountryCode: 'EG',
      billingPeriodIso8601: 'P1M',
      offerId: 'trial-eligible',
      basePlanId: 'monthly',
      localizedOriginalPrice: 'EGP 199.99',
      savingsPercent: 25,
      trialPeriodIso8601: 'P7D',
      trialEligible: true,
    );
    expect(offer.valid, isTrue);
    expect(offer.localizedPrice, 'EGP 149.99');
    expect(offer.productId, isNot(contains('149')));
  });

  test('placeholder never invents a price before store response', () {
    const placeholder = BilStoreCatalogPlaceholder(
      productId: 'owner_pending_premium_ai_coach_monthly',
      kind: BilStoreProductKind.premiumAiCoachSubscription,
    );
    expect(placeholder.localizedPrice, isNull);
  });
}
