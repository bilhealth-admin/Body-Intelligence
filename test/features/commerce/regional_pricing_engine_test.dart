import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/country_eligibility.dart';
import 'package:body_intelligence_log/features/commerce/domain/country_pricing_context.dart';
import 'package:body_intelligence_log/features/commerce/domain/money_amount.dart';
import 'package:body_intelligence_log/features/commerce/domain/pricing_region.dart';
import 'package:body_intelligence_log/features/commerce/domain/regional_price.dart';
import 'package:body_intelligence_log/features/commerce/repositories/local_regional_pricing_repository.dart';
import 'package:body_intelligence_log/features/commerce/services/regional_pricing_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = LocalRegionalPricingRepository(
    eligibilities: [
      CountryEligibility(
        countryCode: 'EG',
        region: PricingRegion.emergingMarkets,
        eligiblePlans: {CommercePlan.plus, CommercePlan.pro},
        developingMarketDiscountPercent: 40,
      ),
    ],
    prices: const [
      RegionalPrice(
        plan: CommercePlan.plus,
        region: PricingRegion.emergingMarkets,
        countryCode: 'EG',
        basePrice: MoneyAmount(
          minorUnits: 999,
          currencyCode: 'USD',
          currencySymbol: r'$',
        ),
        localPrice: MoneyAmount(
          minorUnits: 29900,
          currencyCode: 'EGP',
          currencySymbol: 'E£',
        ),
      ),
    ],
  );
  final engine = RegionalPricingEngine(repository);

  test('store country is authoritative over device country', () {
    final decision = engine.resolve(
      plan: CommercePlan.plus,
      context: const CountryPricingContext(
        deviceCountryCode: 'US',
        accountCountryCode: 'EG',
        storeCountryCode: 'EG',
      ),
    );
    expect(decision.allowed, isTrue);
    expect(decision.price!.localPrice.currencyCode, 'EGP');
    expect(decision.requiresCountryReview, isTrue);
  });

  test('device country alone never establishes billing country', () {
    final decision = engine.resolve(
      plan: CommercePlan.plus,
      context: const CountryPricingContext(
        deviceCountryCode: 'EG',
        accountCountryCode: null,
        storeCountryCode: null,
      ),
    );
    expect(decision.allowed, isFalse);
    expect(decision.reason, 'billing_country_unavailable');
  });

  test('ineligible plans are rejected deterministically', () {
    final decision = engine.resolve(
      plan: CommercePlan.enterprise,
      context: const CountryPricingContext(
        deviceCountryCode: 'EG',
        accountCountryCode: 'EG',
        storeCountryCode: 'EG',
      ),
    );
    expect(decision.allowed, isFalse);
    expect(decision.reason, 'plan_not_eligible');
  });

  test('money percentage discount rounds to minor units', () {
    const amount = MoneyAmount(
      minorUnits: 999,
      currencyCode: 'USD',
      currencySymbol: r'$',
    );
    expect(amount.discountedByPercent(33).minorUnits, 669);
  });
}
