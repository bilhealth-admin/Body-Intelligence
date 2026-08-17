import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  test('uses recurring Play price and eligible free-trial metadata', () {
    const wrapper = ProductDetailsWrapper(
      description: 'Premium AI Coach',
      name: 'Premium AI Coach',
      productId: 'bil.premium_ai_coach.monthly',
      productType: ProductType.subs,
      title: 'Premium AI Coach',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerId: 'trial-7-day',
          offerTags: <String>['new-customer'],
          offerIdToken: 'opaque-store-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P7D',
              formattedPrice: 'Free',
              priceAmountMicros: 0,
              priceCurrencyCode: 'EGP',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1M',
              formattedPrice: 'EGP 249.99',
              priceAmountMicros: 249990000,
              priceCurrencyCode: 'EGP',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    final metadata = googlePlayOfferMetadata(product);

    expect(metadata, isNotNull);
    expect(metadata!.localizedPrice, 'EGP 249.99');
    expect(metadata.currencyCode, 'EGP');
    expect(metadata.priceMicros, 249990000);
    expect(metadata.billingPeriodIso8601, 'P1M');
    expect(metadata.trialPeriodIso8601, 'P7D');
    expect(metadata.trialEligible, isTrue);
    expect(metadata.offerId, 'trial-7-day');
    expect(metadata.basePlanId, 'monthly');
  });

  test('does not invent a trial for a paid-only Play offer', () {
    const wrapper = ProductDetailsWrapper(
      description: 'Premium',
      name: 'Premium',
      productId: 'bil.premium.monthly',
      productType: ProductType.subs,
      title: 'Premium',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerTags: <String>[],
          offerIdToken: 'opaque-store-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1M',
              formattedPrice: 'EGP 149.99',
              priceAmountMicros: 149990000,
              priceCurrencyCode: 'EGP',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    final metadata = googlePlayOfferMetadata(product);

    expect(metadata, isNotNull);
    expect(metadata!.trialEligible, isFalse);
    expect(metadata.trialPeriodIso8601, isNull);
    expect(metadata.localizedPrice, 'EGP 149.99');
  });

  test(
    'prefers the eligible trial when Play returns duplicate product ids',
    () {
      const wrapper = ProductDetailsWrapper(
        description: 'Premium AI Coach',
        name: 'Premium AI Coach',
        productId: 'bil.premium_ai_coach.monthly',
        productType: ProductType.subs,
        title: 'Premium AI Coach',
        subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerTags: <String>[],
            offerIdToken: 'base-token',
            pricingPhases: <PricingPhaseWrapper>[
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: 'EGP 249.99',
                priceAmountMicros: 249990000,
                priceCurrencyCode: 'EGP',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'trial-7-day',
            offerTags: <String>['new-customer'],
            offerIdToken: 'trial-token',
            pricingPhases: <PricingPhaseWrapper>[
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P7D',
                formattedPrice: 'Free',
                priceAmountMicros: 0,
                priceCurrencyCode: 'EGP',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: 'EGP 249.99',
                priceAmountMicros: 249990000,
                priceCurrencyCode: 'EGP',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      );
      final products = GooglePlayProductDetails.fromProductDetails(wrapper);

      final selected = preferredStoreProduct(products.first, products.last);

      expect(selected, same(products.last));
      expect((selected as GooglePlayProductDetails).offerToken, 'trial-token');
    },
  );
}
