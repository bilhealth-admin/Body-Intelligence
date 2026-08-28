enum BilStoreProductKind {
  premiumSubscription,
  premiumAiCoachSubscription,
  aiBoostConsumable,
}

class BilStoreOfferMetadata {
  const BilStoreOfferMetadata({
    required this.productId,
    required this.kind,
    required this.localizedTitle,
    required this.localizedPrice,
    required this.currencyCode,
    required this.priceMicros,
    this.storeCountryCode,
    this.billingPeriodIso8601,
    this.offerId,
    this.basePlanId,
    this.localizedOriginalPrice,
    this.originalPriceMicros,
    this.savingsPercent,
    this.purchaseOfferToken,
    this.trialPeriodIso8601,
    this.trialEligible,
  });

  final String productId;
  final BilStoreProductKind kind;
  final String localizedTitle;
  final String localizedPrice;
  final String currencyCode;
  final int priceMicros;

  /// Storefront country when the platform API exposes it. Some generic
  /// ProductDetails transports do not, so absence must not invalidate price.
  final String? storeCountryCode;
  final String? billingPeriodIso8601;
  final String? offerId;
  final String? basePlanId;
  final String? localizedOriginalPrice;
  final int? originalPriceMicros;
  final int? savingsPercent;
  final String? purchaseOfferToken;
  final String? trialPeriodIso8601;
  final bool? trialEligible;

  /// Returns 50 only when the store supplied a complete, internally
  /// consistent half-price AI Boost offer that can be selected at checkout.
  /// A plain localized price, or two unrelated prices, never qualifies.
  int? get verifiedAiBoostDiscountPercent {
    if (kind != BilStoreProductKind.aiBoostConsumable ||
        savingsPercent != 50 ||
        priceMicros <= 0 ||
        originalPriceMicros == null ||
        originalPriceMicros != priceMicros * 2 ||
        !(offerId?.trim().isNotEmpty ?? false) ||
        !(purchaseOfferToken?.trim().isNotEmpty ?? false)) {
      return null;
    }
    return 50;
  }

  bool get valid =>
      productId.trim().isNotEmpty &&
      localizedTitle.trim().isNotEmpty &&
      localizedPrice.trim().isNotEmpty &&
      currencyCode.trim().isNotEmpty &&
      priceMicros >= 0 &&
      (originalPriceMicros == null || originalPriceMicros! > 0) &&
      (savingsPercent == null ||
          (savingsPercent! >= 0 && savingsPercent! <= 100));
}

abstract interface class BilStoreCatalogGateway {
  Future<List<BilStoreOfferMetadata>> loadOffers(Set<String> productIds);
  Future<void> requestPurchase(BilStoreOfferMetadata offer);
  Future<void> restorePurchases();
  Future<void> openManageSubscriptions();
}

class BilStoreCatalogPlaceholder {
  const BilStoreCatalogPlaceholder({
    required this.productId,
    required this.kind,
  });

  final String productId;
  final BilStoreProductKind kind;

  /// No invented price is shown while the device store has not responded.
  String? get localizedPrice => null;
}
