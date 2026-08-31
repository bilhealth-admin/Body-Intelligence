import 'commerce_plan.dart';
import 'free_plan.dart';
import 'paid_plan_catalog.dart';
import 'subscription_lifecycle.dart';
import 'subscription_record.dart';
import 'subscription_state.dart';

/// Deterministic, offline entitlement resolution from verified local facts.
final class EntitlementResolver {
  const EntitlementResolver();

  SubscriptionState resolve({
    required SubscriptionRecord record,
    required DateTime now,
  }) {
    final normalizedNow = now.toUtc();
    final grantsPaid = _grantsPaidAccess(record, normalizedNow);
    final resolvedPlan = grantsPaid ? record.plan : CommercePlan.free;
    final resolvedEntitlements = grantsPaid
        ? PaidPlanCatalog.composedEntitlementsFor(record.plan)
        : FreePlan.entitlements;

    return SubscriptionState(
      plan: resolvedPlan,
      entitlements: resolvedEntitlements,
      authority: record.authorityVerified
          ? EntitlementAuthority.verifiedServer
          : EntitlementAuthority.localDefault,
      lifecycle: record.lifecycle,
      provider: record.provider,
      startedAt: record.startedAt,
      currentPeriodEndsAt: record.currentPeriodEndsAt,
      trialEndsAt: record.trialEndsAt,
      gracePeriodEndsAt: record.gracePeriodEndsAt,
      isPurchasable: false,
      canRestorePurchases: record.authorityVerified && record.provider != null,
    );
  }

  bool _grantsPaidAccess(SubscriptionRecord record, DateTime now) {
    if (record.plan == CommercePlan.free || !record.authorityVerified) {
      return false;
    }
    if (!record.lifecycle.mayGrantPaidAccess) {
      return false;
    }
    final startedAt = record.startedAt?.toUtc();
    if (startedAt != null && now.isBefore(startedAt)) {
      return false;
    }

    return switch (record.lifecycle) {
      SubscriptionLifecycle.trial => _beforeBoundary(now, record.trialEndsAt),
      SubscriptionLifecycle.active => _beforeBoundary(
        now,
        record.currentPeriodEndsAt,
      ),
      SubscriptionLifecycle.gracePeriod => _beforeBoundary(
        now,
        record.gracePeriodEndsAt,
      ),
      SubscriptionLifecycle.cancelled => _beforeBoundary(
        now,
        record.currentPeriodEndsAt,
      ),
      SubscriptionLifecycle.inactive ||
      SubscriptionLifecycle.pending ||
      SubscriptionLifecycle.billingRetry ||
      SubscriptionLifecycle.accountHold ||
      SubscriptionLifecycle.paused ||
      SubscriptionLifecycle.suspended ||
      SubscriptionLifecycle.deferred ||
      SubscriptionLifecycle.expired ||
      SubscriptionLifecycle.refunded ||
      SubscriptionLifecycle.revoked => false,
    };
  }

  bool _beforeBoundary(DateTime now, DateTime? boundary) {
    if (boundary == null) {
      return false;
    }
    // Store and SQL lifecycle authorities treat the boundary instant itself
    // as expired. Keeping the client strict prevents a one-tick stale grant.
    return boundary.toUtc().isAfter(now.toUtc());
  }
}
