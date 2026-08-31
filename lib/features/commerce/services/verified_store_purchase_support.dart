part of 'verified_store_purchase_service.dart';

enum VerifiedStoreState {
  loading,
  ready,
  unavailable,
  offline,
  purchasePending,
  verified,
  cancelled,
  failed,
}

/// Produces an opaque, deterministic StoreKit account token while preserving
/// the existing Google Play account hash byte-for-byte.
String storeAccountIdentifier({
  required String ownerId,
  required TargetPlatform platform,
}) {
  if (platform != TargetPlatform.iOS) {
    return sha256.convert(utf8.encode(ownerId)).toString();
  }
  final digest = sha256.convert(utf8.encode('bil-store-account:$ownerId'));
  final bytes = List<int>.from(digest.bytes.take(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

bool _selectedGoogleOfferHasFreePhase(ProductDetails value) {
  if (value is! GooglePlayProductDetails || value.subscriptionIndex == null) {
    return false;
  }
  final offers = value.productDetails.subscriptionOfferDetails;
  final index = value.subscriptionIndex!;
  if (offers == null || index < 0 || index >= offers.length) return false;
  return offers[index].pricingPhases.any(
    (phase) => phase.priceAmountMicros == 0,
  );
}

bool isExactGoogleSevenDayTrialPhase(PricingPhaseWrapper phase) =>
    phase.priceAmountMicros == 0 &&
    phase.billingPeriod ==
        StoreCatalogConfiguration.googleAiTrialPeriodIso8601 &&
    phase.billingCycleCount == 1 &&
    phase.recurrenceMode == RecurrenceMode.finiteRecurring;

bool _isApprovedGoogleAiTrial(ProductDetails value) {
  if (value is! GooglePlayProductDetails || value.subscriptionIndex == null) {
    return false;
  }
  if (!StoreCatalogConfiguration.isAiTrialProduct(value.id)) return false;
  final offers = value.productDetails.subscriptionOfferDetails;
  final index = value.subscriptionIndex!;
  if (offers == null || index < 0 || index >= offers.length) return false;
  final offer = offers[index];
  final freePhases = offer.pricingPhases
      .where((phase) => phase.priceAmountMicros == 0)
      .toList(growable: false);
  return offer.offerId == StoreCatalogConfiguration.googleAiTrialOfferId &&
      offer.offerTags.contains(
        StoreCatalogConfiguration.googleAiTrialOfferTag,
      ) &&
      freePhases.length == 1 &&
      isExactGoogleSevenDayTrialPhase(freePhases.single);
}

bool _appleProductHasFreeIntroductoryOffer(ProductDetails value) {
  if (value is AppStoreProduct2Details) {
    final subscription = value.sk2Product.subscription;
    if (subscription == null) return false;
    return subscription.promotionalOffers.any(
      (offer) =>
          offer.type == SK2SubscriptionOfferType.introductory &&
          offer.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial &&
          offer.price == 0,
    );
  }
  if (value is AppStoreProductDetails) {
    final offer = value.skProduct.introductoryPrice;
    return offer != null &&
        offer.type == SKProductDiscountType.introductory &&
        offer.paymentMode == SKProductDiscountPaymentMode.freeTrail &&
        double.tryParse(offer.price) == 0;
  }
  return false;
}

bool _isApprovedAppleAiTrial(ProductDetails value) {
  if (!StoreCatalogConfiguration.isAiTrialProduct(value.id)) return false;
  if (value is AppStoreProduct2Details) {
    final subscription = value.sk2Product.subscription;
    if (subscription == null) return false;
    final freeIntros = subscription.promotionalOffers
        .where(
          (offer) =>
              offer.type == SK2SubscriptionOfferType.introductory &&
              offer.paymentMode == SK2SubscriptionOfferPaymentMode.freeTrial &&
              offer.price == 0,
        )
        .toList(growable: false);
    if (freeIntros.length != 1) return false;
    final offer = freeIntros.single;
    final sevenDays =
        (offer.period.unit == SK2SubscriptionPeriodUnit.week &&
            offer.period.value == 1) ||
        (offer.period.unit == SK2SubscriptionPeriodUnit.day &&
            offer.period.value == 7);
    return offer.periodCount == 1 && sevenDays;
  }
  if (value is AppStoreProductDetails) {
    final offer = value.skProduct.introductoryPrice;
    final period = offer?.subscriptionPeriod;
    if (offer == null || period == null) return false;
    final sevenDays =
        (period.unit == SKSubscriptionPeriodUnit.week &&
            period.numberOfUnits == 1) ||
        (period.unit == SKSubscriptionPeriodUnit.day &&
            period.numberOfUnits == 7);
    return offer.type == SKProductDiscountType.introductory &&
        offer.paymentMode == SKProductDiscountPaymentMode.freeTrail &&
        double.tryParse(offer.price) == 0 &&
        offer.numberOfPeriods == 1 &&
        sevenDays;
  }
  return false;
}

/// The single infinite paid phase that owns the selected Play subscription's
/// renewal price and period. Finite introductory phases and malformed offers
/// are never used as the release billing authority.
PricingPhaseWrapper? googlePlayRecurringPhase(ProductDetails value) {
  if (value is! GooglePlayProductDetails || value.subscriptionIndex == null) {
    return null;
  }
  final offers = value.productDetails.subscriptionOfferDetails;
  final index = value.subscriptionIndex!;
  if (offers == null || index < 0 || index >= offers.length) return null;
  final recurring = offers[index].pricingPhases
      .where(
        (phase) =>
            phase.priceAmountMicros > 0 &&
            phase.billingCycleCount == 0 &&
            phase.recurrenceMode == RecurrenceMode.infiniteRecurring,
      )
      .toList(growable: false);
  return recurring.length == 1 ? recurring.single : null;
}

String? _storeProductBillingPeriod(ProductDetails value) {
  if (value is GooglePlayProductDetails && value.subscriptionIndex != null) {
    return googlePlayRecurringPhase(value)?.billingPeriod;
  }
  if (value is AppStoreProduct2Details) {
    final period = value.sk2Product.subscription?.subscriptionPeriod;
    if (period == null || period.value <= 0) return null;
    final unit = switch (period.unit) {
      SK2SubscriptionPeriodUnit.day => 'D',
      SK2SubscriptionPeriodUnit.week => 'W',
      SK2SubscriptionPeriodUnit.month => 'M',
      SK2SubscriptionPeriodUnit.year => 'Y',
    };
    return 'P${period.value}$unit';
  }
  if (value is AppStoreProductDetails) {
    final period = value.skProduct.subscriptionPeriod;
    if (period == null || period.numberOfUnits <= 0) return null;
    final unit = switch (period.unit) {
      SKSubscriptionPeriodUnit.day => 'D',
      SKSubscriptionPeriodUnit.week => 'W',
      SKSubscriptionPeriodUnit.month => 'M',
      SKSubscriptionPeriodUnit.year => 'Y',
    };
    return 'P${period.numberOfUnits}$unit';
  }
  return null;
}

bool _storeProductMatchesBindingTerm(
  ProductDetails value,
  SubscriptionTerm term,
) {
  final expected = switch (term) {
    SubscriptionTerm.oneMonth => 'P1M',
    SubscriptionTerm.oneYear => 'P1Y',
    SubscriptionTerm.threeMonths => 'P3M',
    SubscriptionTerm.sixMonths => 'P6M',
  };
  return _storeProductBillingPeriod(value) == expected;
}

/// Rejects any subscription candidate that could apply a trial outside the
/// two exact Premium + AI Coach product ids. On Play, the approved offer id,
/// eligibility tag, and seven-day free phase must all match. A regular
/// Premium product returned only with a trial is omitted instead of being
/// purchased under terms the release policy forbids.
bool releaseEligibleStoreProduct(ProductDetails value) {
  final binding = StoreCatalogConfiguration.bindingForProduct(value.id);
  if (binding == null) return value.id == StoreCatalogConfiguration.aiBoost;
  if (!_storeProductMatchesBindingTerm(value, binding.term)) return false;
  final aiTrialProduct = StoreCatalogConfiguration.isAiTrialProduct(value.id);

  if (value is GooglePlayProductDetails) {
    final hasFreePhase = _selectedGoogleOfferHasFreePhase(value);
    if (!hasFreePhase) return true;
    return aiTrialProduct && _isApprovedGoogleAiTrial(value);
  }
  if (value is AppStoreProduct2Details || value is AppStoreProductDetails) {
    final hasFreeIntro = _appleProductHasFreeIntroductoryOffer(value);
    return !hasFreeIntro || (aiTrialProduct && _isApprovedAppleAiTrial(value));
  }
  return true;
}

/// Selects deterministically when a store returns multiple entries for one
/// product id. Only the exact approved AI trial can outrank a paid/base plan.
/// Invalid or forbidden trial candidates are discarded fail-closed.
ProductDetails? preferredStoreProduct(
  ProductDetails? current,
  ProductDetails candidate,
) {
  final eligibleCurrent =
      current != null && releaseEligibleStoreProduct(current) ? current : null;
  if (!releaseEligibleStoreProduct(candidate)) return eligibleCurrent;
  if (eligibleCurrent == null) return candidate;
  if (!_isApprovedGoogleAiTrial(eligibleCurrent) &&
      _isApprovedGoogleAiTrial(candidate)) {
    return candidate;
  }
  if (!_isApprovedGoogleAiTrial(eligibleCurrent) &&
      !_isApprovedGoogleAiTrial(candidate) &&
      !_isGoogleBasePlan(eligibleCurrent) &&
      _isGoogleBasePlan(candidate)) {
    return candidate;
  }
  return eligibleCurrent;
}

bool _isGoogleBasePlan(ProductDetails value) {
  if (value is! GooglePlayProductDetails || value.subscriptionIndex == null) {
    return false;
  }
  final offers = value.productDetails.subscriptionOfferDetails;
  final index = value.subscriptionIndex!;
  return offers != null &&
      index >= 0 &&
      index < offers.length &&
      offers[index].offerId == null &&
      !_selectedGoogleOfferHasFreePhase(value);
}

/// Builds the purchase request with the exact eligible one-time offer token
/// that produced the displayed price. Other platforms keep their native
/// ProductDetails selection unchanged.
PurchaseParam verifiedBoostPurchaseParam({
  required ProductDetails product,
  required String accountHash,
  required TargetPlatform platform,
  String? offerToken,
}) {
  if (platform == TargetPlatform.android &&
      product is GooglePlayProductDetails) {
    return GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: accountHash,
      obfuscatedProfileId: accountHash,
      offerToken: offerToken,
    );
  }
  return PurchaseParam(
    productDetails: product,
    applicationUserName: accountHash,
  );
}

final class VerifiedStoreEntitlement {
  const VerifiedStoreEntitlement({
    required this.plan,
    required this.lifecycle,
    required this.verifiedAt,
    this.renewsOrExpiresAt,
    this.gracePeriodEndsAt,
    this.provider,
  });

  final CommercePlan plan;
  final String lifecycle;
  final DateTime verifiedAt;
  final DateTime? renewsOrExpiresAt;
  final DateTime? gracePeriodEndsAt;
  final String? provider;

  bool get grantsPaidAccess {
    if (plan == CommercePlan.free) return false;
    final boundary = lifecycle == 'grace_period'
        ? gracePeriodEndsAt
        : renewsOrExpiresAt;
    return const {
          'active',
          'trial',
          'grace_period',
          'cancelled',
        }.contains(lifecycle) &&
        boundary != null &&
        boundary.toUtc().isAfter(DateTime.now().toUtc());
  }
}

/// Store transport that can never grant an entitlement locally.
