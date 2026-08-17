import 'commerce_plan.dart';
import 'subscription_term.dart';

final class StoreCatalogConfiguration {
  const StoreCatalogConfiguration._();

  static const packageName = String.fromEnvironment(
    'BIL_GOOGLE_PACKAGE_NAME',
    defaultValue: 'com.bilhealth.bodyintelligencelog',
  );
  static const appleBundleId = String.fromEnvironment(
    'BIL_APPLE_BUNDLE_ID',
    defaultValue: 'com.bilhealth.bodyintelligencelog',
  );
  static const appleSubscriptionGroup = String.fromEnvironment(
    'BIL_APPLE_SUBSCRIPTION_GROUP',
  );
  static const termsUrl = String.fromEnvironment('BIL_TERMS_URL');
  static const privacyUrl = String.fromEnvironment('BIL_PRIVACY_URL');

  static bool get legalLinksConfigured =>
      _isHttps(termsUrl) && _isHttps(privacyUrl);

  static bool _isHttps(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty;
  }

  static const premiumMonthly = String.fromEnvironment(
    'BIL_STORE_PREMIUM_MONTHLY',
  );
  static const premiumAnnual = String.fromEnvironment(
    'BIL_STORE_PREMIUM_ANNUAL',
  );
  static const premiumAiCoachMonthly = String.fromEnvironment(
    'BIL_STORE_PREMIUM_AI_COACH_MONTHLY',
  );
  static const premiumAiCoachAnnual = String.fromEnvironment(
    'BIL_STORE_PREMIUM_AI_COACH_ANNUAL',
  );

  static const products = <StoreProductBinding>[
    StoreProductBinding(
      plan: CommercePlan.premium,
      term: SubscriptionTerm.oneMonth,
      productId: premiumMonthly,
    ),
    StoreProductBinding(
      plan: CommercePlan.premium,
      term: SubscriptionTerm.oneYear,
      productId: premiumAnnual,
    ),
    StoreProductBinding(
      plan: CommercePlan.premiumAiCoach,
      term: SubscriptionTerm.oneMonth,
      productId: premiumAiCoachMonthly,
    ),
    StoreProductBinding(
      plan: CommercePlan.premiumAiCoach,
      term: SubscriptionTerm.oneYear,
      productId: premiumAiCoachAnnual,
    ),
  ];

  static bool get consumerProductsConfigured {
    final normalized = products
        .map((binding) => binding.productId.trim())
        .toList(growable: false);
    return normalized.length == 4 &&
        normalized.every((id) => id.isNotEmpty) &&
        normalized.toSet().length == normalized.length;
  }

  static Set<String> get productIds => products
      .map((binding) => binding.productId.trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  static StoreProductBinding? bindingFor({
    required CommercePlan plan,
    required SubscriptionTerm term,
  }) {
    for (final binding in products) {
      if (binding.plan == plan && binding.term == term) return binding;
    }
    return null;
  }

  static StoreProductBinding? bindingForProduct(String productId) {
    final normalizedProductId = productId.trim();
    for (final binding in products) {
      if (binding.productId.trim() == normalizedProductId) return binding;
    }
    return null;
  }
}

final class StoreProductBinding {
  const StoreProductBinding({
    required this.plan,
    required this.term,
    required this.productId,
  });

  final CommercePlan plan;
  final SubscriptionTerm term;
  final String productId;
}
