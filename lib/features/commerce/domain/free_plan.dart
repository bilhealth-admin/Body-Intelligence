import 'commerce_entitlement.dart';
import 'commerce_plan.dart';
import 'subscription_state.dart';

/// Canonical offline-first Free plan shipped with every BIL installation.
final class FreePlan {
  const FreePlan._();

  static const entitlements = <CommerceEntitlement>{
    CommerceEntitlement.localTracking,
    CommerceEntitlement.nutritionFoundation,
    CommerceEntitlement.explainableNutrition,
    CommerceEntitlement.localAnalytics,
    CommerceEntitlement.dataExport,
  };

  static SubscriptionState createState() => SubscriptionState(
    plan: CommercePlan.free,
    entitlements: entitlements,
    authority: EntitlementAuthority.localDefault,
    isPurchasable: false,
    canRestorePurchases: false,
  );
}
