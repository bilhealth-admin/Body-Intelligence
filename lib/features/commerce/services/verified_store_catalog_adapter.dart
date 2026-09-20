import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../domain/commerce_plan.dart';
import '../domain/store_catalog_configuration.dart';
import '../domain/store_offer_metadata.dart';
import 'verified_store_purchase_service.dart';

final class GooglePlayOfferMetadata {
  const GooglePlayOfferMetadata({
    required this.localizedPrice,
    required this.currencyCode,
    required this.priceMicros,
    required this.billingPeriodIso8601,
    required this.offerId,
    required this.basePlanId,
    required this.trialPeriodIso8601,
    required this.trialEligible,
  });

  final String localizedPrice;
  final String currencyCode;
  final int priceMicros;
  final String? billingPeriodIso8601;
  final String? offerId;
  final String? basePlanId;
  final String? trialPeriodIso8601;
  final bool trialEligible;
}

final class AppleStoreOfferMetadata {
  const AppleStoreOfferMetadata({
    required this.billingPeriodIso8601,
    required this.trialPeriodIso8601,
    required this.trialEligible,
  });

  final String? billingPeriodIso8601;
  final String? trialPeriodIso8601;
  final bool trialEligible;
}

typedef AppleIntroductoryEligibility = Future<bool> Function(String productId);

String? _storeKit2PeriodIso8601(
  SK2SubscriptionPeriod period, {
  int multiplier = 1,
}) {
  final value = period.value * multiplier;
  if (value <= 0) return null;
  final unit = switch (period.unit) {
    SK2SubscriptionPeriodUnit.day => 'D',
    SK2SubscriptionPeriodUnit.week => 'W',
    SK2SubscriptionPeriodUnit.month => 'M',
    SK2SubscriptionPeriodUnit.year => 'Y',
  };
  return 'P$value$unit';
}

String? _storeKit1PeriodIso8601(
  SKProductSubscriptionPeriodWrapper? period, {
  int multiplier = 1,
}) {
  if (period == null) return null;
  final value = period.numberOfUnits * multiplier;
  if (value <= 0) return null;
  final unit = switch (period.unit) {
    SKSubscriptionPeriodUnit.day => 'D',
    SKSubscriptionPeriodUnit.week => 'W',
    SKSubscriptionPeriodUnit.month => 'M',
    SKSubscriptionPeriodUnit.year => 'Y',
  };
  return 'P$value$unit';
}

Future<bool> _defaultAppleIntroductoryEligibility(String productId) async {
  try {
    return await SK2Product.isIntroductoryOfferEligible(productId);
  } on Object {
    // Eligibility must be authoritative. A platform failure cannot turn an
    // introductory offer into a user-visible free-trial promise.
    return false;
  }
}

/// Reads only a configured, zero-price Apple introductory free trial and then
/// asks StoreKit whether the current account is eligible. Missing metadata or
/// an eligibility error fails closed.
Future<AppleStoreOfferMetadata?> appleStoreOfferMetadata(
  ProductDetails product, {
  AppleIntroductoryEligibility? isIntroductoryOfferEligible,
}) async {
  String? billingPeriod;
  String? configuredTrialPeriod;
  final trialProduct = StoreCatalogConfiguration.isAiTrialProduct(product.id);

  if (product is AppStoreProduct2Details) {
    final subscription = product.sk2Product.subscription;
    if (subscription == null) return null;
    billingPeriod = _storeKit2PeriodIso8601(subscription.subscriptionPeriod);
    if (trialProduct) {
      final freeIntros = subscription.promotionalOffers
          .where(
            (offer) =>
                offer.type == SK2SubscriptionOfferType.introductory &&
                offer.paymentMode ==
                    SK2SubscriptionOfferPaymentMode.freeTrial &&
                offer.price == 0,
          )
          .toList(growable: false);
      if (freeIntros.length == 1 && freeIntros.single.periodCount == 1) {
        final period = _storeKit2PeriodIso8601(freeIntros.single.period);
        if (const {'P1W', 'P7D'}.contains(period)) {
          configuredTrialPeriod = period;
        }
      }
    }
  } else if (product is AppStoreProductDetails) {
    billingPeriod = _storeKit1PeriodIso8601(
      product.skProduct.subscriptionPeriod,
    );
    final offer = product.skProduct.introductoryPrice;
    if (trialProduct &&
        offer != null &&
        offer.type == SKProductDiscountType.introductory &&
        offer.paymentMode == SKProductDiscountPaymentMode.freeTrail &&
        double.tryParse(offer.price) == 0 &&
        offer.numberOfPeriods == 1) {
      final period = _storeKit1PeriodIso8601(offer.subscriptionPeriod);
      if (const {'P1W', 'P7D'}.contains(period)) {
        configuredTrialPeriod = period;
      }
    }
  } else {
    return null;
  }

  if (configuredTrialPeriod == null) {
    return AppleStoreOfferMetadata(
      billingPeriodIso8601: billingPeriod,
      trialPeriodIso8601: null,
      trialEligible: false,
    );
  }

  final eligibility =
      isIntroductoryOfferEligible ?? _defaultAppleIntroductoryEligibility;
  var eligible = false;
  try {
    eligible = await eligibility(product.id);
  } on Object {
    // StoreKit eligibility is authoritative. If it cannot be resolved, hide
    // the trial instead of presenting an offer the account may not receive.
    eligible = false;
  }
  return AppleStoreOfferMetadata(
    billingPeriodIso8601: billingPeriod,
    trialPeriodIso8601: eligible ? configuredTrialPeriod : null,
    trialEligible: eligible,
  );
}

final class GooglePlayOneTimeDiscountMetadata {
  const GooglePlayOneTimeDiscountMetadata({
    required this.localizedPrice,
    required this.localizedOriginalPrice,
    required this.currencyCode,
    required this.priceMicros,
    required this.originalPriceMicros,
    required this.savingsPercent,
    required this.offerId,
    required this.offerToken,
  });

  final String localizedPrice;
  final String? localizedOriginalPrice;
  final String currencyCode;
  final int priceMicros;
  final int originalPriceMicros;
  final int savingsPercent;
  final String offerId;
  final String offerToken;
}

/// Reads an explicit Google Play one-time discount offer when the platform
/// wrapper exposes the Billing Library offer fields. The currently bundled
/// wrapper does not yet surface those newer fields, so it safely returns null
/// instead of inferring a promotion from a list of unrelated prices.
GooglePlayOneTimeDiscountMetadata? googlePlayOneTimeDiscountMetadata(
  ProductDetails product,
) {
  if (product is! GooglePlayProductDetails ||
      product.subscriptionIndex != null) {
    return null;
  }
  final offers = product.productDetails.oneTimePurchaseOfferDetailsList;
  if (offers == null) return null;

  for (final offer in offers) {
    final dynamic platformOffer = offer;
    final fullPriceMicros = _readPositiveInt(
      () => platformOffer.fullPriceMicros,
    );
    final discountInfo = _readObject(() => platformOffer.discountDisplayInfo);
    final percentageDiscount = discountInfo == null
        ? null
        : _readPositiveInt(() => (discountInfo as dynamic).percentageDiscount);
    final offerId = _readNonEmptyString(() => platformOffer.offerId);
    final offerToken = _readNonEmptyString(() => platformOffer.offerToken);

    if (fullPriceMicros == null ||
        percentageDiscount != 50 ||
        offerId == null ||
        offerToken == null ||
        offer.priceAmountMicros <= 0 ||
        storeDerivedSavingsPercent(
              priceMicros: offer.priceAmountMicros,
              originalPriceMicros: fullPriceMicros,
            ) !=
            percentageDiscount) {
      continue;
    }
    String? localizedOriginalPrice;
    for (final original in offers) {
      if (original.priceAmountMicros == fullPriceMicros &&
          original.priceCurrencyCode == offer.priceCurrencyCode) {
        localizedOriginalPrice = original.formattedPrice;
        break;
      }
    }
    return GooglePlayOneTimeDiscountMetadata(
      localizedPrice: offer.formattedPrice,
      localizedOriginalPrice: localizedOriginalPrice,
      currencyCode: offer.priceCurrencyCode,
      priceMicros: offer.priceAmountMicros,
      originalPriceMicros: fullPriceMicros,
      savingsPercent: percentageDiscount!,
      offerId: offerId,
      offerToken: offerToken,
    );
  }
  return null;
}

Object? _readObject(Object? Function() read) {
  try {
    return read();
  } on Object {
    return null;
  }
}

int? _readPositiveInt(Object? Function() read) {
  final value = _readObject(read);
  return value is num && value > 0 ? value.toInt() : null;
}

String? _readNonEmptyString(Object? Function() read) {
  final value = _readObject(read)?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

/// Reads only the exact Google Play offer represented by [product]. Google
/// Play filters subscription offers for the current user, but BIL still
/// recognizes a trial only for the two exact AI products and the approved
/// offer id/tag/seven-day phase. Regular Premium metadata is always paid.
GooglePlayOfferMetadata? googlePlayOfferMetadata(ProductDetails product) {
  if (product is! GooglePlayProductDetails ||
      product.subscriptionIndex == null) {
    return null;
  }
  final offers = product.productDetails.subscriptionOfferDetails;
  final index = product.subscriptionIndex!;
  if (offers == null || index < 0 || index >= offers.length) return null;
  final offer = offers[index];
  if (offer.pricingPhases.isEmpty) return null;
  final paid = googlePlayRecurringPhase(product);
  if (paid == null) return null;
  final freePhases = offer.pricingPhases
      .where((phase) => phase.priceAmountMicros == 0)
      .toList(growable: false);
  final trialPhase =
      freePhases.length == 1 &&
          isExactGoogleSevenDayTrialPhase(freePhases.single)
      ? freePhases.single
      : null;
  final approvedTrial =
      StoreCatalogConfiguration.isAiTrialProduct(product.id) &&
      offer.offerId == StoreCatalogConfiguration.googleAiTrialOfferId &&
      offer.offerTags.contains(StoreCatalogConfiguration.googleAiTrialOfferTag);
  final trial = approvedTrial ? trialPhase : null;
  return GooglePlayOfferMetadata(
    localizedPrice: paid.formattedPrice,
    currencyCode: paid.priceCurrencyCode,
    priceMicros: paid.priceAmountMicros,
    billingPeriodIso8601: paid.billingPeriod,
    offerId: offer.offerId,
    basePlanId: offer.basePlanId,
    trialPeriodIso8601: trial?.billingPeriod,
    trialEligible: trial != null,
  );
}

/// Adapts the existing verified store transport to provider-neutral UI
/// metadata. It cannot grant access; receipt verification remains server-side.
final class VerifiedStoreCatalogAdapter implements BilStoreCatalogGateway {
  VerifiedStoreCatalogAdapter(this.store);

  final VerifiedStorePurchaseService store;

  @override
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> productIds) async {
    if (store.products.isEmpty) await store.initialize();
    final offers = <BilStoreOfferMetadata>[];
    for (final product in store.products.values.where(
      (product) => productIds.contains(product.id),
    )) {
      // Keep the adapter independently fail-closed. The production purchase
      // service already filters its map, but injected/restored catalog state
      // must not be able to surface a forbidden Premium trial or malformed
      // recurring term if it bypasses that first layer.
      if (!releaseEligibleStoreProduct(product)) continue;
      if (product.id == StoreCatalogConfiguration.aiBoost) {
        final discount = googlePlayOneTimeDiscountMetadata(product);
        offers.add(
          BilStoreOfferMetadata(
            productId: product.id,
            kind: BilStoreProductKind.aiBoostConsumable,
            localizedTitle: product.title,
            localizedPrice: discount?.localizedPrice ?? product.price,
            currencyCode: discount?.currencyCode ?? product.currencyCode,
            priceMicros:
                discount?.priceMicros ?? (product.rawPrice * 1000000).round(),
            localizedOriginalPrice: discount?.localizedOriginalPrice,
            originalPriceMicros: discount?.originalPriceMicros,
            savingsPercent: discount?.savingsPercent,
            offerId: discount?.offerId,
            purchaseOfferToken: discount?.offerToken,
          ),
        );
        continue;
      }
      final binding = StoreCatalogConfiguration.bindingForProduct(product.id);
      if (binding == null) continue;
      final playOffer = googlePlayOfferMetadata(product);
      final appleOffer = await appleStoreOfferMetadata(product);
      final allowsTrial =
          binding.plan == CommercePlan.premiumAiCoach &&
          StoreCatalogConfiguration.isAiTrialProduct(product.id);
      offers.add(
        BilStoreOfferMetadata(
          productId: product.id,
          kind: binding.plan == CommercePlan.premiumAiCoach
              ? BilStoreProductKind.premiumAiCoachSubscription
              : BilStoreProductKind.premiumSubscription,
          localizedTitle: product.title,
          localizedPrice: playOffer?.localizedPrice ?? product.price,
          currencyCode: playOffer?.currencyCode ?? product.currencyCode,
          priceMicros:
              playOffer?.priceMicros ?? (product.rawPrice * 1000000).round(),
          billingPeriodIso8601:
              playOffer?.billingPeriodIso8601 ??
              appleOffer?.billingPeriodIso8601 ??
              switch (binding.term.months) {
                1 => 'P1M',
                12 => 'P1Y',
                _ => null,
              },
          offerId: playOffer?.offerId,
          basePlanId: playOffer?.basePlanId,
          trialPeriodIso8601: allowsTrial
              ? playOffer?.trialPeriodIso8601 ?? appleOffer?.trialPeriodIso8601
              : null,
          trialEligible: allowsTrial
              ? playOffer?.trialEligible ?? appleOffer?.trialEligible
              : false,
        ),
      );
    }
    return offers;
  }

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
    if (offer.kind == BilStoreProductKind.aiBoostConsumable) {
      await store.purchaseBoost(offerToken: offer.purchaseOfferToken);
      return;
    }
    final binding = StoreCatalogConfiguration.bindingForProduct(
      offer.productId,
    );
    if (binding == null) return;
    await store.purchasePlan(binding.plan, term: binding.term);
  }

  @override
  Future<void> restorePurchases() => store.restore();

  @override
  Future<void> openManageSubscriptions() => store.manageSubscription();
}
