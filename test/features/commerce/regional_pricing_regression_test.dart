import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/country_pricing_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('existing commerce plan identities remain stable', () {
    expect(CommercePlan.free.id, 'free');
    expect(CommercePlan.plus.id, 'plus');
    expect(CommercePlan.enterprise.id, 'enterprise');
  });

  test('account country remains fallback when store country is absent', () {
    const context = CountryPricingContext(
      deviceCountryCode: 'US',
      accountCountryCode: 'JO',
      storeCountryCode: null,
    );
    expect(context.billingCountryCode, 'JO');
    expect(context.hasMismatch, isTrue);
  });
}
