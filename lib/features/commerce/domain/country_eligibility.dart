import 'commerce_plan.dart';
import 'pricing_region.dart';

final class CountryEligibility {
  CountryEligibility({
    required this.countryCode,
    required this.region,
    required Set<CommercePlan> eligiblePlans,
    this.developingMarketDiscountPercent = 0,
  }) : eligiblePlans = Set.unmodifiable(eligiblePlans) {
    if (developingMarketDiscountPercent < 0 ||
        developingMarketDiscountPercent > 100) {
      throw ArgumentError.value(
        developingMarketDiscountPercent,
        'developingMarketDiscountPercent',
      );
    }
  }
  final String countryCode;
  final PricingRegion region;
  final Set<CommercePlan> eligiblePlans;
  final int developingMarketDiscountPercent;
}
