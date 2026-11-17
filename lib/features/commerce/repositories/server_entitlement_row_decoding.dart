part of 'server_entitlement_repository.dart';

extension _ServerEntitlementRowDecoding on ServerEntitlementRepository {
  SubscriptionLifecycle? _lifecycleOrNull(String value) => switch (value) {
    'pending' => SubscriptionLifecycle.pending,
    'trial' => SubscriptionLifecycle.trial,
    'active' => SubscriptionLifecycle.active,
    'grace_period' => SubscriptionLifecycle.gracePeriod,
    'billing_retry' => SubscriptionLifecycle.billingRetry,
    'account_hold' => SubscriptionLifecycle.accountHold,
    'paused' => SubscriptionLifecycle.paused,
    'suspended' => SubscriptionLifecycle.suspended,
    'deferred' => SubscriptionLifecycle.deferred,
    'cancelled' => SubscriptionLifecycle.cancelled,
    'expired' => SubscriptionLifecycle.expired,
    'refunded' => SubscriptionLifecycle.refunded,
    'revoked' => SubscriptionLifecycle.revoked,
    _ => null,
  };
}
