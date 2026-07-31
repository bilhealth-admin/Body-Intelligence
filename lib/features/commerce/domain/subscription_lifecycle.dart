/// Stable lifecycle vocabulary for a commercial subscription.
enum SubscriptionLifecycle {
  inactive,
  trial,
  active,
  gracePeriod,
  paused,
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
    SubscriptionLifecycle.paused ||
    SubscriptionLifecycle.expired ||
    SubscriptionLifecycle.refunded ||
    SubscriptionLifecycle.revoked => false,
  };
}
