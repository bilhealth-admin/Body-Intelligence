import 'commerce_plan.dart';
import 'store_offer_metadata.dart';

/// Commercial boundary shared by the store surface and market gating.
abstract final class MarketOfferPolicy {
  static const double monthlyProfitFloorUsd = 6;
  static const double annualProfitFloorUsd = 35;

  /// Resolves the one subscription family exposed by the device storefront.
  /// If both families are accidentally returned, Premium wins fail-safe so an
  /// underpriced AI-inclusive subscription can never leak into a token market.
  static CommercePlan? targetPlanForKinds(Iterable<BilStoreProductKind> kinds) {
    final values = kinds.toSet();
    final hasPremium = values.contains(BilStoreProductKind.premiumSubscription);
    final hasCoach = values.contains(
      BilStoreProductKind.premiumAiCoachSubscription,
    );
    if (hasPremium) return CommercePlan.premium;
    if (hasCoach) return CommercePlan.premiumAiCoach;
    return null;
  }

  static List<BilStoreOfferMetadata> visibleOffers(
    Iterable<BilStoreOfferMetadata> offers,
  ) {
    final valid = offers.where((offer) => offer.valid).toList(growable: false);
    final target = targetPlanForKinds(valid.map((offer) => offer.kind));
    return valid
        .where((offer) {
          if (offer.kind == BilStoreProductKind.aiBoostConsumable) return true;
          return switch (target) {
            CommercePlan.premium =>
              offer.kind == BilStoreProductKind.premiumSubscription,
            CommercePlan.premiumAiCoach =>
              offer.kind == BilStoreProductKind.premiumAiCoachSubscription,
            _ => false,
          };
        })
        .toList(growable: false);
  }
}
