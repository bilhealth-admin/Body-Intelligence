import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/store_catalog_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_term.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release catalog exposes the five immutable store identifiers', () {
    expect(StoreCatalogConfiguration.consumerProductsConfigured, isTrue);
    expect(
      StoreCatalogConfiguration.storefrontProductIds,
      equals({
        'bil_premium',
        'bil_premium_annual',
        'bil_premium_ai_coach',
        'bil_premium_ai_coach_annual',
        'bil_ai_boost',
      }),
    );
  });

  test('each subscription identifier maps to exactly one plan and term', () {
    final expected = <({CommercePlan plan, SubscriptionTerm term}), String>{
      (plan: CommercePlan.premium, term: SubscriptionTerm.oneMonth):
          'bil_premium',
      (plan: CommercePlan.premium, term: SubscriptionTerm.oneYear):
          'bil_premium_annual',
      (plan: CommercePlan.premiumAiCoach, term: SubscriptionTerm.oneMonth):
          'bil_premium_ai_coach',
      (plan: CommercePlan.premiumAiCoach, term: SubscriptionTerm.oneYear):
          'bil_premium_ai_coach_annual',
    };

    for (final entry in expected.entries) {
      final binding = StoreCatalogConfiguration.bindingFor(
        plan: entry.key.plan,
        term: entry.key.term,
      );
      expect(binding?.productId, entry.value);
      expect(
        StoreCatalogConfiguration.bindingForProduct(entry.value),
        same(binding),
      );
    }
  });

  test(
    'aliases, casing, whitespace, legacy ids, and unknown ids fail closed',
    () {
      for (final productId in <String>[
        '',
        ' bil_premium_ai_coach',
        'bil_premium_ai_coach ',
        'BIL_PREMIUM_AI_COACH',
        'premium_ai_coach',
        'bil_premium_ai_coach_legacy',
        'bil_plus',
        'unknown_subscription',
      ]) {
        expect(
          StoreCatalogConfiguration.bindingForProduct(productId),
          isNull,
          reason: productId,
        );
        expect(
          StoreCatalogConfiguration.isAiTrialProduct(productId),
          isFalse,
          reason: productId,
        );
      }
    },
  );
}
