import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

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

/// Reads only the exact Google Play offer represented by [product]. Google
/// Play filters subscription offers for the current user, so a zero-priced
/// phase on this selected offer is an eligible trial, not an app-authored
/// promise.
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
  final paidPhases = offer.pricingPhases
      .where((phase) => phase.priceAmountMicros > 0)
      .toList(growable: false);
  if (paidPhases.isEmpty) return null;
  final paid = paidPhases.last;
  final trialPhases = offer.pricingPhases
      .where((phase) => phase.priceAmountMicros == 0)
      .toList(growable: false);
  final trial = trialPhases.isEmpty ? null : trialPhases.first;
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
    return store.products.values
        .where((product) => productIds.contains(product.id))
        .map((product) {
          final binding = StoreCatalogConfiguration.bindingForProduct(
            product.id,
          );
          if (binding == null) return null;
          final playOffer = googlePlayOfferMetadata(product);
          return BilStoreOfferMetadata(
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
                switch (binding.term.months) {
                  1 => 'P1M',
                  12 => 'P1Y',
                  _ => null,
                },
            offerId: playOffer?.offerId,
            basePlanId: playOffer?.basePlanId,
            trialPeriodIso8601: playOffer?.trialPeriodIso8601,
            trialEligible: playOffer?.trialEligible,
          );
        })
        .whereType<BilStoreOfferMetadata>()
        .toList(growable: false);
  }

  @override
  Future<void> requestPurchase(BilStoreOfferMetadata offer) async {
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
