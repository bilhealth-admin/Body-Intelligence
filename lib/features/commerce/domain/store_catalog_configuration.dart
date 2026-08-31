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

  /// Immutable cross-store product identifiers. Prices, trials, availability,
  /// tax and localized display text are always read from the active store.
  static const premiumMonthly = 'bil_premium';
  static const premiumAnnual = 'bil_premium_annual';
  static const premiumAiCoachMonthly = 'bil_premium_ai_coach';
  static const premiumAiCoachAnnual = 'bil_premium_ai_coach_annual';

  /// The only release-approved introductory offer. Trial decisions use exact
  /// identifiers deliberately: aliases, casing changes, whitespace, legacy
  /// SKUs, and missing metadata all fail closed.
  static const googleAiTrialOfferId = 'trial-7-day';
  static const googleAiTrialOfferTag = 'new-customer';
  static const googleAiTrialPeriodIso8601 = 'P7D';
  static const aiTrialProductIds = <String>{
    premiumAiCoachMonthly,
    premiumAiCoachAnnual,
  };

  static bool isAiTrialProduct(String productId) =>
      aiTrialProductIds.contains(productId);

  /// Repeatable AI credit pack. This identifier is intentionally stable
  /// across storefronts; regional price and availability remain store-owned.
  static const aiBoost = 'bil_ai_boost';

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

  /// All products queried from the device store. Subscription products may be
  /// intentionally absent because Play/App Store availability is mutually
  /// exclusive by market; AI Boost remains globally queryable.
  static Set<String> get storefrontProductIds => {...productIds, aiBoost};

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
    for (final binding in products) {
      if (binding.productId == productId) return binding;
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
