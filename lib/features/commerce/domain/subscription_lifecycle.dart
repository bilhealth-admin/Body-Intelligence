/// Stable lifecycle vocabulary for a commercial subscription.
enum SubscriptionLifecycle {
  inactive,
  pending,
  trial,
  active,
  gracePeriod,
  billingRetry,
  accountHold,
  paused,
  suspended,
  deferred,
  expired,
  cancelled,
  refunded,
  revoked,
}

extension SubscriptionLifecycleAccess on SubscriptionLifecycle {
  /// Whether this lifecycle can ever retain paid access when its dates allow it.
  bool get mayGrantPaidAccess => switch (this) {
    SubscriptionLifecycle.trial ||
    SubscriptionLifecycle.active ||
    SubscriptionLifecycle.gracePeriod ||
    SubscriptionLifecycle.cancelled => true,
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
