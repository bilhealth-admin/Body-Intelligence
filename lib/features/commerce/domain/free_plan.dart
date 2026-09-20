import 'commerce_entitlement.dart';
import 'commerce_plan.dart';
import 'subscription_lifecycle.dart';
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
    // Basic encrypted continuity belongs to the signed-in account. Keeping
    // profile, weight, and hydration recoverable across reinstalls is not a
    // paid insight and must not disappear when a user is on Free.
    CommerceEntitlement.cloudSync,
  };

  static SubscriptionState createState() => SubscriptionState(
    plan: CommercePlan.free,
    entitlements: entitlements,
    authority: EntitlementAuthority.localDefault,
    lifecycle: SubscriptionLifecycle.inactive,
    isPurchasable: false,
    canRestorePurchases: false,
  );
}
