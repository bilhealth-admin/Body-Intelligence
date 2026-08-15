import '../domain/commerce_plan.dart';
import '../domain/entitlement_resolver.dart';
import '../domain/free_plan.dart';
import '../domain/subscription_lifecycle.dart';
import '../domain/subscription_recovery_decision.dart';
import '../domain/subscription_recovery_policy.dart';
import '../domain/subscription_snapshot.dart';

/// Deterministic offline recovery from a previously verified snapshot.
final class SubscriptionRecoveryEngine {
  const SubscriptionRecoveryEngine({
    this.entitlementResolver = const EntitlementResolver(),
  });

  final EntitlementResolver entitlementResolver;

  SubscriptionRecoveryDecision recover({
    required SubscriptionSnapshot? snapshot,
    required SubscriptionRecoveryPolicy policy,
    required DateTime now,
  }) {
    if (snapshot == null) {
      return SubscriptionRecoveryDecision(
        state: FreePlan.createState(),
        action: SubscriptionRecoveryAction.restoreFromProvider,
        usedCachedRecord: false,
      );
    }

    if (snapshot.record.plan == CommercePlan.free) {
      return SubscriptionRecoveryDecision(
        state: FreePlan.createState(),
        action: SubscriptionRecoveryAction.discardInvalidCache,
        usedCachedRecord: false,
      );
    }

    if (policy.isStale(verifiedAt: snapshot.verifiedAt, now: now)) {
      return SubscriptionRecoveryDecision(
        state: FreePlan.createState(),
        action: SubscriptionRecoveryAction.refreshFromProvider,
        usedCachedRecord: false,
      );
    }

    final state = entitlementResolver.resolve(
      record: snapshot.record,
      now: now,
    );
    final requiresRefresh = _requiresRefresh(snapshot, now.toUtc());

    return SubscriptionRecoveryDecision(
      state: state,
      action: requiresRefresh
          ? SubscriptionRecoveryAction.refreshFromProvider
          : SubscriptionRecoveryAction.none,
      usedCachedRecord: true,
    );
  }

  bool _requiresRefresh(SubscriptionSnapshot snapshot, DateTime now) {
    final record = snapshot.record;
    return switch (record.lifecycle) {
      SubscriptionLifecycle.trial =>
        record.trialEndsAt == null || now.isAfter(record.trialEndsAt!.toUtc()),
      SubscriptionLifecycle.gracePeriod =>
        record.gracePeriodEndsAt == null ||
            now.isAfter(record.gracePeriodEndsAt!.toUtc()),
      SubscriptionLifecycle.active || SubscriptionLifecycle.cancelled =>
        record.currentPeriodEndsAt == null ||
            now.isAfter(record.currentPeriodEndsAt!.toUtc()),
      SubscriptionLifecycle.inactive ||
      SubscriptionLifecycle.pending ||
      SubscriptionLifecycle.billingRetry ||
      SubscriptionLifecycle.accountHold ||
      SubscriptionLifecycle.paused ||
      SubscriptionLifecycle.suspended ||
      SubscriptionLifecycle.deferred ||
      SubscriptionLifecycle.expired ||
      SubscriptionLifecycle.refunded ||
      SubscriptionLifecycle.revoked => true,
    };
  }
}
