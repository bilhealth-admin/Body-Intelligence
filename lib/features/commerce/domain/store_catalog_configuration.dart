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

  static const proMonthly = String.fromEnvironment('BIL_STORE_PRO_MONTHLY');
  static const proAnnual = String.fromEnvironment('BIL_STORE_PRO_ANNUAL');
  static const premiumPlusMonthly = String.fromEnvironment(
    'BIL_STORE_PREMIUM_PLUS_MONTHLY',
  );
  static const premiumPlusAnnual = String.fromEnvironment(
    'BIL_STORE_PREMIUM_PLUS_ANNUAL',
  );

  /// Code-owned gate: do not expose Premium+ until its Meal Planner routes,
  /// persistence and entitlement checks are implemented and reviewed.
  static const premiumPlusMealPlannerReady = false;

  static const products = <StoreProductBinding>[
    StoreProductBinding(
      plan: CommercePlan.pro,
      term: SubscriptionTerm.oneMonth,
      productId: proMonthly,
    ),
    StoreProductBinding(
      plan: CommercePlan.pro,
      term: SubscriptionTerm.oneYear,
      productId: proAnnual,
    ),
    StoreProductBinding(
      plan: CommercePlan.plus,
      term: SubscriptionTerm.oneMonth,
      productId: premiumPlusMonthly,
    ),
    StoreProductBinding(
      plan: CommercePlan.plus,
      term: SubscriptionTerm.oneYear,
      productId: premiumPlusAnnual,
    ),
  ];

  static bool get consumerProductsConfigured {
    final normalized = products
        .where((binding) => binding.plan == CommercePlan.pro)
        .map((binding) => binding.productId.trim())
        .toList(growable: false);
    return normalized.every((id) => id.isNotEmpty) &&
        normalized.toSet().length == normalized.length;
  }

  static Set<String> get productIds => products
      .where(
        (binding) =>
            binding.plan == CommercePlan.pro || premiumPlusMealPlannerReady,
      )
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
