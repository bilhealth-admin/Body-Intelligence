import 'commerce_entitlement.dart';
import 'commerce_plan.dart';
import 'free_plan.dart';
import 'plan_catalog_entry.dart';

/// Canonical local metadata for the paid BIL plan hierarchy.
///
/// This catalog is intentionally non-authoritative. It composes product
/// capabilities for presentation and policy planning, while runtime access
/// remains controlled exclusively by a verified [SubscriptionState].
final class PaidPlanCatalog {
  const PaidPlanCatalog._();

  static final entries = <CommercePlan, PlanCatalogEntry>{
    CommercePlan.plus: PlanCatalogEntry(
      plan: CommercePlan.plus,
      rank: 10,
      parentPlans: const <CommercePlan>{CommercePlan.free},
      addedEntitlements: const <CommerceEntitlement>{
        CommerceEntitlement.cloudSync,
      },
    ),
    CommercePlan.pro: PlanCatalogEntry(
      plan: CommercePlan.pro,
      rank: 20,
      parentPlans: const <CommercePlan>{CommercePlan.plus},
      addedEntitlements: const <CommerceEntitlement>{
        CommerceEntitlement.advancedIntelligence,
      },
    ),
    CommercePlan.elite: PlanCatalogEntry(
      plan: CommercePlan.elite,
      rank: 30,
      parentPlans: const <CommercePlan>{CommercePlan.pro},
      addedEntitlements: const <CommerceEntitlement>{},
    ),
    CommercePlan.coach: PlanCatalogEntry(
      plan: CommercePlan.coach,
      rank: 40,
      parentPlans: const <CommercePlan>{CommercePlan.pro},
      addedEntitlements: const <CommerceEntitlement>{
        CommerceEntitlement.coachWorkspace,
      },
    ),
    CommercePlan.clinic: PlanCatalogEntry(
      plan: CommercePlan.clinic,
      rank: 50,
      parentPlans: const <CommercePlan>{CommercePlan.pro},
      addedEntitlements: const <CommerceEntitlement>{
        CommerceEntitlement.clinicWorkspace,
      },
    ),
    CommercePlan.enterprise: PlanCatalogEntry(
      plan: CommercePlan.enterprise,
      rank: 60,
      parentPlans: const <CommercePlan>{
        CommercePlan.coach,
        CommercePlan.clinic,
      },
      addedEntitlements: const <CommerceEntitlement>{
        CommerceEntitlement.enterpriseAdministration,
      },
    ),
  };

  static List<PlanCatalogEntry> get orderedEntries {
    final ordered = entries.values.toList(growable: false)
      ..sort((left, right) => left.rank.compareTo(right.rank));
    return List.unmodifiable(ordered);
  }

  static PlanCatalogEntry entryFor(CommercePlan plan) {
    if (plan == CommercePlan.free) {
      throw ArgumentError('Free is defined by FreePlan, not PaidPlanCatalog.');
    }
    final entry = entries[plan];
    if (entry == null) {
      throw StateError('Paid plan catalog entry missing for ${plan.id}.');
    }
    return entry;
  }

  /// Returns the catalog-composed capabilities for product metadata only.
  ///
  /// The returned set must never be converted directly into runtime access.
  static Set<CommerceEntitlement> composedEntitlementsFor(CommercePlan plan) {
    if (plan == CommercePlan.free) {
      return Set.unmodifiable(FreePlan.entitlements);
    }

    final resolved = <CommerceEntitlement>{};
    final visiting = <CommercePlan>{};
    _compose(plan, resolved, visiting);
    return Set.unmodifiable(resolved);
  }

  static void _compose(
    CommercePlan plan,
    Set<CommerceEntitlement> resolved,
    Set<CommercePlan> visiting,
  ) {
    if (plan == CommercePlan.free) {
      resolved.addAll(FreePlan.entitlements);
      return;
    }
    if (!visiting.add(plan)) {
      throw StateError(
        'Circular paid plan inheritance detected at ${plan.id}.',
      );
    }

    final entry = entryFor(plan);
    for (final parent in entry.parentPlans) {
      _compose(parent, resolved, visiting);
    }
    resolved.addAll(entry.addedEntitlements);
    visiting.remove(plan);
  }
}
