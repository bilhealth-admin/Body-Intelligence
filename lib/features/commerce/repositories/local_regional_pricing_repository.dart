import '../domain/commerce_plan.dart';
import '../domain/country_eligibility.dart';
import '../domain/regional_price.dart';
import 'regional_pricing_repository.dart';

final class LocalRegionalPricingRepository
    implements RegionalPricingRepository {
  LocalRegionalPricingRepository({
    required Iterable<CountryEligibility> eligibilities,
    required Iterable<RegionalPrice> prices,
  }) : _eligibilities = {
         for (final item in eligibilities) item.countryCode.toUpperCase(): item,
       },
       _prices = {
         for (final item in prices)
           '${item.countryCode?.toUpperCase()}:${item.plan.id}': item,
       };
  final Map<String, CountryEligibility> _eligibilities;
  final Map<String, RegionalPrice> _prices;
  @override
  CountryEligibility? eligibilityFor(String countryCode) =>
      _eligibilities[countryCode.toUpperCase()];
  @override
  RegionalPrice? priceFor(CommercePlan plan, String countryCode) =>
      _prices['${countryCode.toUpperCase()}:${plan.id}'];
}
