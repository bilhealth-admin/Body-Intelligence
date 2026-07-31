import 'regional_price.dart';

final class RegionalPricingDecision {
  const RegionalPricingDecision({
    required this.allowed,
    required this.reason,
    this.price,
    this.requiresCountryReview = false,
  });
  final bool allowed;
  final String reason;
  final RegionalPrice? price;
  final bool requiresCountryReview;
}
