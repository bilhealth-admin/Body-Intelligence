import 'commerce_plan.dart';
import 'paid_plan_catalog.dart';
import 'subscription_lifecycle.dart';
import 'subscription_state.dart';

/// An admin gift is a server lease, never a forged Apple/Google receipt.
SubscriptionState composeAdminSubscriptionAccess({
  required SubscriptionState store,
  required Object? grant,
  required String ownerId,
  required DateTime now,
}) {
  if (grant is! Map || grant['owner_id'] != ownerId) return store;
  final plan = switch (grant['plan_id']) {
    'premium' => CommercePlan.premium,
    'premium_ai_coach' => CommercePlan.premiumAiCoach,
    _ => null,
  };
  final until = DateTime.tryParse('${grant['access_until']}')?.toUtc();
  final created = DateTime.tryParse('${grant['created_at']}')?.toUtc();
  final expires = grant['expires_at'] == null
      ? null
      : DateTime.tryParse('${grant['expires_at']}')?.toUtc();
  if (plan == null ||
      until == null ||
      created == null ||
      !until.isAfter(now.toUtc()) ||
      until.isAfter(now.toUtc().add(const Duration(minutes: 6))) ||
      created.isAfter(now.toUtc().add(const Duration(minutes: 1))) ||
      (grant['expires_at'] != null &&
          (expires == null || !expires.isAfter(now.toUtc()))) ||
      (expires != null && until.isAfter(expires))) {
    return store;
  }
  final storeRank = store.plan == CommercePlan.free
      ? 0
      : PaidPlanCatalog.entryFor(store.plan).rank;
  final storeBoundary = store.lifecycle == SubscriptionLifecycle.gracePeriod
      ? store.gracePeriodEndsAt
      : store.lifecycle == SubscriptionLifecycle.trial
      ? store.trialEndsAt
      : store.currentPeriodEndsAt;
  if (store.authority == EntitlementAuthority.verifiedServer &&
      storeRank >= PaidPlanCatalog.entryFor(plan).rank &&
      storeBoundary != null &&
      storeBoundary.isAfter(now.toUtc())) {
    return store;
  }
  return SubscriptionState(
    plan: plan,
    entitlements: PaidPlanCatalog.composedEntitlementsFor(plan),
    authority: EntitlementAuthority.verifiedServer,
    lifecycle: SubscriptionLifecycle.active,
    startedAt: created,
    currentPeriodEndsAt: until,
    isPurchasable: false,
    canRestorePurchases: store.canRestorePurchases,
  );
}
