import 'commerce_entitlement.dart';
import 'commerce_plan.dart';

/// Source of an entitlement decision.
enum EntitlementAuthority {
  /// Deterministic local default shipped with the application.
  localDefault,

  /// Reserved for a future server-verified commerce adapter.
  verifiedServer,
}

/// Immutable commercial access snapshot consumed by product surfaces.
final class SubscriptionState {
  SubscriptionState({
    required this.plan,
    required Set<CommerceEntitlement> entitlements,
    required this.authority,
    required this.isPurchasable,
    required this.canRestorePurchases,
  }) : entitlements = Set.unmodifiable(entitlements) {
    if (authority == EntitlementAuthority.localDefault &&
        (isPurchasable || canRestorePurchases)) {
      throw ArgumentError(
        'Local default commerce state cannot advertise purchase or restore.',
      );
    }
  }

  final CommercePlan plan;
  final Set<CommerceEntitlement> entitlements;
  final EntitlementAuthority authority;
  final bool isPurchasable;
  final bool canRestorePurchases;

  bool grants(CommerceEntitlement entitlement) =>
      entitlements.contains(entitlement);
}
