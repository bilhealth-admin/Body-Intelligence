import 'commerce_entitlement.dart';
import 'commerce_plan.dart';
import 'free_plan.dart';
import 'paid_plan_catalog.dart';

enum StoreExposure { includedFree, consumerSubscription, contractOnly, hidden }

final class PlanUsageLimits {
  const PlanUsageLimits({
    required this.cloudSync,
    required this.advancedIntelligence,
    required this.professionalWorkspace,
    required this.catalogTier,
  });

  final bool cloudSync;
  final bool advancedIntelligence;
  final bool professionalWorkspace;
  final CommercePlan catalogTier;
}

final class PlanPolicy {
  const PlanPolicy({
    required this.plan,
    required this.exposure,
    required this.limits,
    required this.entitlements,
  });

  final CommercePlan plan;
  final StoreExposure exposure;
  final PlanUsageLimits limits;
  final Set<CommerceEntitlement> entitlements;
}

/// One product-policy source shared by comparison and entitlement tests.
/// Numeric AI quotas are intentionally absent until a server-enforced quota is
/// configured; the client must never invent a limit or advertise one.
final class PlanPolicyCatalog {
  const PlanPolicyCatalog._();

  static final policies = <CommercePlan, PlanPolicy>{
    CommercePlan.free: PlanPolicy(
      plan: CommercePlan.free,
      exposure: StoreExposure.includedFree,
      limits: const PlanUsageLimits(
        cloudSync: false,
        advancedIntelligence: false,
        professionalWorkspace: false,
        catalogTier: CommercePlan.free,
      ),
      entitlements: FreePlan.entitlements,
    ),
    CommercePlan.plus: PlanPolicy(
      plan: CommercePlan.plus,
      // Reserved for Premium+; hidden until Meal Planner is implemented.
      exposure: StoreExposure.hidden,
      limits: const PlanUsageLimits(
        cloudSync: true,
        advancedIntelligence: true,
        professionalWorkspace: false,
        catalogTier: CommercePlan.plus,
      ),
      entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.plus),
    ),
    CommercePlan.pro: PlanPolicy(
      plan: CommercePlan.pro,
      exposure: StoreExposure.consumerSubscription,
      limits: const PlanUsageLimits(
        cloudSync: true,
        advancedIntelligence: true,
        professionalWorkspace: false,
        catalogTier: CommercePlan.pro,
      ),
      entitlements: PaidPlanCatalog.composedEntitlementsFor(CommercePlan.pro),
    ),
    for (final plan in <CommercePlan>[
      CommercePlan.coach,
      CommercePlan.clinic,
      CommercePlan.enterprise,
    ])
      plan: PlanPolicy(
        plan: plan,
        exposure: StoreExposure.contractOnly,
        limits: PlanUsageLimits(
          cloudSync: true,
          advancedIntelligence: true,
          professionalWorkspace: true,
          catalogTier: plan,
        ),
        entitlements: PaidPlanCatalog.composedEntitlementsFor(plan),
      ),
    CommercePlan.elite: PlanPolicy(
      plan: CommercePlan.elite,
      exposure: StoreExposure.hidden,
      limits: const PlanUsageLimits(
        cloudSync: false,
        advancedIntelligence: false,
        professionalWorkspace: false,
        catalogTier: CommercePlan.free,
      ),
      entitlements: const {},
    ),
  };
}
