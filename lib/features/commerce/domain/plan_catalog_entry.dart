import 'commerce_entitlement.dart';
import 'commerce_plan.dart';

/// Immutable metadata for one commercial plan in the local catalog.
///
/// Catalog entries describe product structure only. They never prove purchase,
/// grant runtime access, or imply that a store product is available.
final class PlanCatalogEntry {
  PlanCatalogEntry({
    required this.plan,
    required this.rank,
    required Set<CommercePlan> parentPlans,
    required Set<CommerceEntitlement> addedEntitlements,
  }) : parentPlans = Set.unmodifiable(parentPlans),
       addedEntitlements = Set.unmodifiable(addedEntitlements) {
    if (rank < 0) {
      throw ArgumentError.value(rank, 'rank', 'must be non-negative');
    }
    if (parentPlans.contains(plan)) {
      throw ArgumentError('A plan cannot inherit from itself.');
    }
  }

  final CommercePlan plan;
  final int rank;
  final Set<CommercePlan> parentPlans;
  final Set<CommerceEntitlement> addedEntitlements;
}
