import '../domain/commerce_plan.dart';
import '../domain/country_pricing_context.dart';
import '../domain/regional_pricing_decision.dart';
import '../repositories/regional_pricing_repository.dart';

final class RegionalPricingEngine {
  const RegionalPricingEngine(this.repository);
  final RegionalPricingRepository repository;

  RegionalPricingDecision resolve({
    required CommercePlan plan,
    required CountryPricingContext context,
  }) {
    final billingCountry = context.billingCountryCode;
    if (billingCountry == null) {
      return const RegionalPricingDecision(
        allowed: false,
        reason: 'billing_country_unavailable',
      );
    }
    final eligibility = repository.eligibilityFor(billingCountry);
    if (eligibility == null) {
      return RegionalPricingDecision(
        allowed: false,
        reason: 'country_not_supported',
        requiresCountryReview: context.hasMismatch,
      );
    }
    if (!eligibility.eligiblePlans.contains(plan)) {
      return RegionalPricingDecision(
        allowed: false,
        reason: 'plan_not_eligible',
        requiresCountryReview: context.hasMismatch,
      );
    }
    final price = repository.priceFor(plan, billingCountry);
    if (price == null) {
      return RegionalPricingDecision(
        allowed: false,
        reason: 'price_not_available',
        requiresCountryReview: context.hasMismatch,
      );
    }
    return RegionalPricingDecision(
      allowed: true,
      reason: 'eligible',
      price: price,
      requiresCountryReview: context.hasMismatch,
    );
  }
}
