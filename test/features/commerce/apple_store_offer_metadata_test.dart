import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

AppStoreProduct2Details productWithOffer({
  SK2SubscriptionOfferPaymentMode paymentMode =
      SK2SubscriptionOfferPaymentMode.freeTrial,
  double offerPrice = 0,
}) {
  return AppStoreProduct2Details.fromSK2Product(
    SK2Product(
      id: 'bil_premium_ai_coach',
      displayName: 'BIL Premium AI Coach',
      displayPrice: r'$5.99',
      description: 'Premium plus AI Coach',
      price: 5.99,
      type: SK2ProductType.autoRenewable,
      priceLocale: SK2PriceLocale(currencyCode: 'USD', currencySymbol: r'$'),
      subscription: SK2SubscriptionInfo(
        subscriptionGroupID: 'bil-premium',
        subscriptionPeriod: const SK2SubscriptionPeriod(
          value: 1,
          unit: SK2SubscriptionPeriodUnit.month,
        ),
        promotionalOffers: [
          SK2SubscriptionOffer(
            price: offerPrice,
            type: SK2SubscriptionOfferType.introductory,
            period: const SK2SubscriptionPeriod(
              value: 1,
              unit: SK2SubscriptionPeriodUnit.week,
            ),
            periodCount: 1,
            paymentMode: paymentMode,
          ),
        ],
      ),
    ),
  );
}

void main() {
  test('returns an eligible configured Apple one-week free trial', () async {
    final metadata = await appleStoreOfferMetadata(
      productWithOffer(),
      isIntroductoryOfferEligible: (_) async => true,
    );

    expect(metadata, isNotNull);
    expect(metadata!.billingPeriodIso8601, 'P1M');
    expect(metadata.trialEligible, isTrue);
    expect(metadata.trialPeriodIso8601, 'P1W');
  });

  test('configured trial stays hidden when StoreKit says ineligible', () async {
    final metadata = await appleStoreOfferMetadata(
      productWithOffer(),
      isIntroductoryOfferEligible: (_) async => false,
    );

    expect(metadata, isNotNull);
    expect(metadata!.trialEligible, isFalse);
    expect(metadata.trialPeriodIso8601, isNull);
  });

  test('paid introductory offers cannot masquerade as a free trial', () async {
    var eligibilityChecked = false;
    final metadata = await appleStoreOfferMetadata(
      productWithOffer(
        paymentMode: SK2SubscriptionOfferPaymentMode.payAsYouGo,
        offerPrice: 0.99,
      ),
      isIntroductoryOfferEligible: (_) async {
        eligibilityChecked = true;
        return true;
      },
    );

    expect(metadata, isNotNull);
    expect(metadata!.trialEligible, isFalse);
    expect(metadata.trialPeriodIso8601, isNull);
    expect(eligibilityChecked, isFalse);
  });

  test('eligibility lookup failure fails closed', () async {
    final metadata = await appleStoreOfferMetadata(
      productWithOffer(),
      isIntroductoryOfferEligible: (_) => throw StateError('store unavailable'),
    );

    expect(metadata, isNotNull);
    expect(metadata!.trialEligible, isFalse);
    expect(metadata.trialPeriodIso8601, isNull);
  });
}
