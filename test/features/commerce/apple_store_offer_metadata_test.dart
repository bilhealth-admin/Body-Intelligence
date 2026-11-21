import 'dart:async';

import 'package:body_intelligence_log/features/commerce/domain/store_offer_metadata.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_catalog_adapter.dart';
import 'package:body_intelligence_log/features/commerce/services/verified_store_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

AppStoreProduct2Details productWithOffer({
  String productId = 'bil_premium_ai_coach',
  double price = 5.99,
  String displayPrice = r'$5.99',
  SK2SubscriptionOfferPaymentMode paymentMode =
      SK2SubscriptionOfferPaymentMode.freeTrial,
  double offerPrice = 0,
  SK2SubscriptionPeriod trialPeriod = const SK2SubscriptionPeriod(
    value: 1,
    unit: SK2SubscriptionPeriodUnit.week,
  ),
  SK2SubscriptionPeriod subscriptionPeriod = const SK2SubscriptionPeriod(
    value: 1,
    unit: SK2SubscriptionPeriodUnit.month,
  ),
  int trialPeriodCount = 1,
  bool includeSecondFreeTrial = false,
}) {
  return AppStoreProduct2Details.fromSK2Product(
    SK2Product(
      id: productId,
      displayName: 'BIL Premium AI Coach',
      displayPrice: displayPrice,
      description: 'Premium plus AI Coach',
      price: price,
      type: SK2ProductType.autoRenewable,
      priceLocale: SK2PriceLocale(currencyCode: 'USD', currencySymbol: r'$'),
      subscription: SK2SubscriptionInfo(
        subscriptionGroupID: 'bil-premium',
        subscriptionPeriod: subscriptionPeriod,
        promotionalOffers: [
          SK2SubscriptionOffer(
            price: offerPrice,
            type: SK2SubscriptionOfferType.introductory,
            period: trialPeriod,
            periodCount: trialPeriodCount,
            paymentMode: paymentMode,
          ),
          if (includeSecondFreeTrial)
            SK2SubscriptionOffer(
              price: 0,
              type: SK2SubscriptionOfferType.introductory,
              period: const SK2SubscriptionPeriod(
                value: 7,
                unit: SK2SubscriptionPeriodUnit.day,
              ),
              periodCount: 1,
              paymentMode: SK2SubscriptionOfferPaymentMode.freeTrial,
            ),
        ],
      ),
    ),
  );
}

class _AppleCatalogStore extends VerifiedStorePurchaseService {
  @override
  String get catalogStoreCountryCode => 'US';

  @override
  Future<String?> readStorefrontCountry() async => 'US';
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
    expect(metadata!.trialEligible, isNull);
    expect(metadata.trialPeriodIso8601, isNull);
  });

  testWidgets('unanswered StoreKit eligibility preserves both priced offers', (
    tester,
  ) async {
    final monthly = productWithOffer();
    final annual = productWithOffer(
      productId: 'bil_premium_ai_coach_annual',
      price: 54.99,
      displayPrice: r'$54.99',
      subscriptionPeriod: const SK2SubscriptionPeriod(
        value: 1,
        unit: SK2SubscriptionPeriodUnit.year,
      ),
    );
    final store = _AppleCatalogStore()
      ..products = {monthly.id: monthly, annual.id: annual};
    final unanswered = Completer<bool>();
    final asked = <String>[];
    List<BilStoreOfferMetadata>? offers;
    try {
      final load = VerifiedStoreCatalogAdapter(
        store,
        isIntroductoryOfferEligible: (id) {
          asked.add(id);
          return unanswered.future;
        },
      ).loadOffers({monthly.id, annual.id}).then((result) => offers = result);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(asked, [monthly.id, annual.id]);
      expect(
        offers,
        isNotNull,
        reason: 'both offers settle before the 12-second page deadline',
      );
      await load;
      expect(offers!.map((o) => o.localizedPrice), [r'$5.99', r'$54.99']);
      expect(offers!.map((o) => o.billingPeriodIso8601), ['P1M', 'P1Y']);
      expect(
        offers!.every(
          (o) => o.trialEligible == null && o.trialPeriodIso8601 == null,
        ),
        isTrue,
      );
      unanswered.complete(true);
      await tester.pump();
      expect(offers!.every((o) => o.trialEligible == null), isTrue);
    } finally {
      if (!unanswered.isCompleted) unanswered.complete(false);
      store.dispose();
    }
  });

  test(
    'regular Premium ignores configured intro and is not purchasable',
    () async {
      var eligibilityChecked = false;
      final product = productWithOffer(productId: 'bil_premium');

      final metadata = await appleStoreOfferMetadata(
        product,
        isIntroductoryOfferEligible: (_) async {
          eligibilityChecked = true;
          return true;
        },
      );

      expect(metadata, isNotNull);
      expect(metadata!.billingPeriodIso8601, 'P1M');
      expect(metadata.trialEligible, isFalse);
      expect(metadata.trialPeriodIso8601, isNull);
      expect(eligibilityChecked, isFalse);
      expect(releaseEligibleStoreProduct(product), isFalse);
      expect(preferredStoreProduct(null, product), isNull);
    },
  );

  test('AI trial with a non-seven-day period fails closed', () async {
    final product = productWithOffer(
      trialPeriod: const SK2SubscriptionPeriod(
        value: 2,
        unit: SK2SubscriptionPeriodUnit.week,
      ),
    );

    final metadata = await appleStoreOfferMetadata(
      product,
      isIntroductoryOfferEligible: (_) async => true,
    );

    expect(metadata, isNotNull);
    expect(metadata!.trialEligible, isFalse);
    expect(metadata.trialPeriodIso8601, isNull);
    expect(releaseEligibleStoreProduct(product), isFalse);
  });

  test('Apple product id with the wrong recurring term fails closed', () {
    final product = productWithOffer(
      subscriptionPeriod: const SK2SubscriptionPeriod(
        value: 1,
        unit: SK2SubscriptionPeriodUnit.year,
      ),
    );

    expect(releaseEligibleStoreProduct(product), isFalse);
    expect(preferredStoreProduct(null, product), isNull);
  });

  test(
    'Apple trial requires one period and one free introductory offer',
    () async {
      for (final product in <AppStoreProduct2Details>[
        productWithOffer(trialPeriodCount: 2),
        productWithOffer(includeSecondFreeTrial: true),
      ]) {
        final metadata = await appleStoreOfferMetadata(
          product,
          isIntroductoryOfferEligible: (_) async => true,
        );

        expect(metadata, isNotNull);
        expect(metadata!.trialEligible, isFalse);
        expect(metadata.trialPeriodIso8601, isNull);
        expect(releaseEligibleStoreProduct(product), isFalse);
        expect(preferredStoreProduct(null, product), isNull);
      }
    },
  );
}
