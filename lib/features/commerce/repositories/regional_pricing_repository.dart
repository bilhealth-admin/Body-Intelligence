import '../domain/commerce_plan.dart';
import '../domain/country_eligibility.dart';
import '../domain/regional_price.dart';

abstract interface class RegionalPricingRepository {
  CountryEligibility? eligibilityFor(String countryCode);
  RegionalPrice? priceFor(CommercePlan plan, String countryCode);
}
