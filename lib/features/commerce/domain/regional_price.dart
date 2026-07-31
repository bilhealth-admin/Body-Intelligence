import 'commerce_plan.dart';
import 'money_amount.dart';
import 'pricing_region.dart';

final class RegionalPrice {
  const RegionalPrice({
    required this.plan,
    required this.region,
    required this.basePrice,
    required this.localPrice,
    this.countryCode,
    this.offerId,
  });
  final CommercePlan plan;
  final PricingRegion region;
  final MoneyAmount basePrice;
  final MoneyAmount localPrice;
  final String? countryCode;
  final String? offerId;
}
