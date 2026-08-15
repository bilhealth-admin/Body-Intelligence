import 'store_offer_metadata.dart';

final class BilStoreMetadataReadiness {
  const BilStoreMetadataReadiness._();

  static List<String> issues(BilStoreOfferMetadata offer) {
    final issues = <String>[];
    if (!offer.valid) issues.add('invalid_core_metadata');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(offer.currencyCode)) {
      issues.add('invalid_currency_code');
    }
    if (offer.kind != BilStoreProductKind.aiBoostConsumable &&
        !const {'P1M', 'P1Y'}.contains(offer.billingPeriodIso8601)) {
      issues.add('unsupported_subscription_period');
    }
    if (offer.kind == BilStoreProductKind.aiBoostConsumable &&
        offer.billingPeriodIso8601 != null) {
      issues.add('consumable_has_billing_period');
    }
    if (offer.trialEligible == true && offer.trialPeriodIso8601 == null) {
      issues.add('trial_period_missing');
    }
    return List.unmodifiable(issues);
  }
}
