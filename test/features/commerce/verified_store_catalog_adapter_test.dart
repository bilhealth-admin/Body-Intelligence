import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses recurring Play price and eligible free-trial metadata', () {
    const wrapper = ProductDetailsWrapper(
      description: 'Premium AI Coach',
      name: 'Premium AI Coach',
      productId: 'bil_premium_ai_coach',
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
      productId: 'bil_premium',
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
        productId: 'bil_premium_ai_coach',
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

  test('regular Premium prefers paid/base and rejects its trial offer', () {
    const wrapper = ProductDetailsWrapper(
      description: 'Premium',
      name: 'Premium',
      productId: 'bil_premium',
      productType: ProductType.subs,
      title: 'Premium',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerTags: <String>[],
          offerIdToken: 'paid-token',
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
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerId: 'trial-7-day',
          offerTags: <String>['new-customer'],
          offerIdToken: 'forbidden-trial-token',
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
              formattedPrice: 'EGP 149.99',
              priceAmountMicros: 149990000,
              priceCurrencyCode: 'EGP',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final products = GooglePlayProductDetails.fromProductDetails(wrapper);

    final selected = preferredStoreProduct(products.first, products.last);

    expect(selected, same(products.first));
    expect((selected as GooglePlayProductDetails).offerToken, 'paid-token');
    final forbiddenMetadata = googlePlayOfferMetadata(products.last);
    expect(forbiddenMetadata, isNotNull);
    expect(forbiddenMetadata!.trialEligible, isFalse);
    expect(forbiddenMetadata.trialPeriodIso8601, isNull);
  });

  test('regular Premium with only a trial candidate fails closed', () {
    const wrapper = ProductDetailsWrapper(
      description: 'Premium',
      name: 'Premium',
      productId: 'bil_premium_annual',
      productType: ProductType.subs,
      title: 'Premium',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'annual',
          offerId: 'trial-7-day',
          offerTags: <String>['new-customer'],
          offerIdToken: 'forbidden-trial-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P7D',
              formattedPrice: 'Free',
              priceAmountMicros: 0,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1Y',
              formattedPrice: r'$49.99',
              priceAmountMicros: 49990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    expect(preferredStoreProduct(null, product), isNull);
    expect(releaseEligibleStoreProduct(product), isFalse);
  });

  test(
    'catalog adapter independently omits a forbidden Premium trial',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const wrapper = ProductDetailsWrapper(
        description: 'Premium',
        name: 'Premium',
        productId: 'bil_premium',
        productType: ProductType.subs,
        title: 'Premium',
        subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'trial-7-day',
            offerTags: <String>['new-customer'],
            offerIdToken: 'forbidden-trial-token',
            pricingPhases: <PricingPhaseWrapper>[
              PricingPhaseWrapper(
                billingCycleCount: 1,
                billingPeriod: 'P7D',
                formattedPrice: 'Free',
                priceAmountMicros: 0,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.finiteRecurring,
              ),
              PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: r'$4.99',
                priceAmountMicros: 4990000,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      );
      final product = GooglePlayProductDetails.fromProductDetails(
        wrapper,
      ).single;
      final store = VerifiedStorePurchaseService()
        ..products = {product.id: product};
      addTearDown(store.dispose);

      final offers = await VerifiedStoreCatalogAdapter(
        store,
      ).loadOffers({product.id});

      expect(offers, isEmpty);
    },
  );

  test('AI trial aliases and wrong identity fail closed', () {
    const wrapper = ProductDetailsWrapper(
      description: 'AI Coach',
      name: 'AI Coach',
      productId: 'bil_premium_ai_coach',
      productType: ProductType.subs,
      title: 'AI Coach',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerId: 'trial_7_day',
          offerTags: <String>['new-customer'],
          offerIdToken: 'wrong-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P7D',
              formattedPrice: 'Free',
              priceAmountMicros: 0,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1M',
              formattedPrice: r'$7.99',
              priceAmountMicros: 7990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    expect(preferredStoreProduct(null, product), isNull);
    expect(googlePlayOfferMetadata(product)?.trialEligible, isFalse);
  });

  test('multi-cycle or non-finite free phases cannot claim a 7-day trial', () {
    for (final phase in <PricingPhaseWrapper>[
      const PricingPhaseWrapper(
        billingCycleCount: 2,
        billingPeriod: 'P7D',
        formattedPrice: 'Free',
        priceAmountMicros: 0,
        priceCurrencyCode: 'USD',
        recurrenceMode: RecurrenceMode.finiteRecurring,
      ),
      const PricingPhaseWrapper(
        billingCycleCount: 1,
        billingPeriod: 'P7D',
        formattedPrice: 'Free',
        priceAmountMicros: 0,
        priceCurrencyCode: 'USD',
        recurrenceMode: RecurrenceMode.infiniteRecurring,
      ),
    ]) {
      final wrapper = ProductDetailsWrapper(
        description: 'AI Coach',
        name: 'AI Coach',
        productId: 'bil_premium_ai_coach',
        productType: ProductType.subs,
        title: 'AI Coach',
        subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
          SubscriptionOfferDetailsWrapper(
            basePlanId: 'monthly',
            offerId: 'trial-7-day',
            offerTags: const <String>['new-customer'],
            offerIdToken: 'unsafe-token',
            pricingPhases: <PricingPhaseWrapper>[
              phase,
              const PricingPhaseWrapper(
                billingCycleCount: 0,
                billingPeriod: 'P1M',
                formattedPrice: r'$7.99',
                priceAmountMicros: 7990000,
                priceCurrencyCode: 'USD',
                recurrenceMode: RecurrenceMode.infiniteRecurring,
              ),
            ],
          ),
        ],
      );
      final product = GooglePlayProductDetails.fromProductDetails(
        wrapper,
      ).single;
      expect(releaseEligibleStoreProduct(product), isFalse);
      expect(preferredStoreProduct(null, product), isNull);
      expect(googlePlayOfferMetadata(product)?.trialEligible, isFalse);
    }
  });

  test('product id with the wrong recurring term fails closed', () {
    const wrapper = ProductDetailsWrapper(
      description: 'AI Coach',
      name: 'AI Coach',
      productId: 'bil_premium_ai_coach',
      productType: ProductType.subs,
      title: 'AI Coach',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'wrong-annual-plan',
          offerTags: <String>[],
          offerIdToken: 'wrong-term-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1Y',
              formattedPrice: r'$49.99',
              priceAmountMicros: 49990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    expect(releaseEligibleStoreProduct(product), isFalse);
    expect(preferredStoreProduct(null, product), isNull);
  });

  test('trial without one infinite recurring paid phase fails closed', () {
    const wrapper = ProductDetailsWrapper(
      description: 'AI Coach',
      name: 'AI Coach',
      productId: 'bil_premium_ai_coach',
      productType: ProductType.subs,
      title: 'AI Coach',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerId: 'trial-7-day',
          offerTags: <String>['new-customer'],
          offerIdToken: 'finite-only-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P7D',
              formattedPrice: 'Free',
              priceAmountMicros: 0,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P1M',
              formattedPrice: r'$7.99',
              priceAmountMicros: 7990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
          ],
        ),
      ],
    );
    final product = GooglePlayProductDetails.fromProductDetails(wrapper).single;

    expect(googlePlayRecurringPhase(product), isNull);
    expect(googlePlayOfferMetadata(product), isNull);
    expect(releaseEligibleStoreProduct(product), isFalse);
    expect(preferredStoreProduct(null, product), isNull);
  });

  test('regular Premium prefers the paid base plan over a paid offer', () {
    const wrapper = ProductDetailsWrapper(
      description: 'Premium',
      name: 'Premium',
      productId: 'bil_premium',
      productType: ProductType.subs,
      title: 'Premium',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerId: 'paid-intro',
          offerTags: <String>['discount'],
          offerIdToken: 'paid-intro-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 1,
              billingPeriod: 'P1M',
              formattedPrice: r'$2.99',
              priceAmountMicros: 2990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1M',
              formattedPrice: r'$4.99',
              priceAmountMicros: 4990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerTags: <String>[],
          offerIdToken: 'base-token',
          pricingPhases: <PricingPhaseWrapper>[
            PricingPhaseWrapper(
              billingCycleCount: 0,
              billingPeriod: 'P1M',
              formattedPrice: r'$4.99',
              priceAmountMicros: 4990000,
              priceCurrencyCode: 'USD',
              recurrenceMode: RecurrenceMode.infiniteRecurring,
            ),
          ],
        ),
      ],
    );
    final products = GooglePlayProductDetails.fromProductDetails(wrapper);

    final selected = preferredStoreProduct(products.first, products.last);

    expect(selected, same(products.last));
    expect((selected as GooglePlayProductDetails).offerToken, 'base-token');
  });
}
