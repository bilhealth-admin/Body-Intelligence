import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/domain/subscription_lifecycle.dart';
import '../../commerce/domain/subscription_state.dart';
import 'wellness_content_pack.dart';

/// Fail-closed access policy shared by installation and presentation.
///
/// Installed catalog metadata is never an entitlement. Paid content is
/// available only when the current plan came from the verified server
/// boundary; local flags and cached selections cannot unlock it.
bool wellnessContentAccessGranted(
  WellnessContentAccess minimumAccess,
  SubscriptionState? subscription,
) {
  if (minimumAccess == WellnessContentAccess.free) return true;
  if (subscription == null ||
      subscription.authority != EntitlementAuthority.verifiedServer ||
      subscription.plan == CommercePlan.free ||
      !_paidWindowIsCurrent(subscription, DateTime.now().toUtc())) {
    return false;
  }

  final plan = subscription.plan;
  return switch (minimumAccess) {
    WellnessContentAccess.free => true,
    WellnessContentAccess.plus => plan != CommercePlan.free,
    WellnessContentAccess.pro =>
      plan == CommercePlan.premium ||
          plan == CommercePlan.premiumAiCoach ||
          plan == CommercePlan.pro ||
          plan == CommercePlan.elite ||
          plan == CommercePlan.coach ||
          plan == CommercePlan.clinic ||
          plan == CommercePlan.enterprise,
    WellnessContentAccess.coach =>
      plan == CommercePlan.coach || plan == CommercePlan.enterprise,
    WellnessContentAccess.clinic =>
      plan == CommercePlan.clinic || plan == CommercePlan.enterprise,
    WellnessContentAccess.enterprise => plan == CommercePlan.enterprise,
  };
}

bool _paidWindowIsCurrent(SubscriptionState subscription, DateTime now) {
  if (!subscription.lifecycle.mayGrantPaidAccess) return false;
  final startedAt = subscription.startedAt?.toUtc();
  if (startedAt != null && now.isBefore(startedAt)) return false;
  final boundary = switch (subscription.lifecycle) {
    SubscriptionLifecycle.trial => subscription.trialEndsAt,
    SubscriptionLifecycle.active ||
    SubscriptionLifecycle.cancelled => subscription.currentPeriodEndsAt,
    SubscriptionLifecycle.gracePeriod => subscription.gracePeriodEndsAt,
    SubscriptionLifecycle.inactive ||
    SubscriptionLifecycle.pending ||
    SubscriptionLifecycle.billingRetry ||
    SubscriptionLifecycle.accountHold ||
    SubscriptionLifecycle.paused ||
    SubscriptionLifecycle.suspended ||
    SubscriptionLifecycle.deferred ||
    SubscriptionLifecycle.expired ||
    SubscriptionLifecycle.refunded ||
    SubscriptionLifecycle.revoked => null,
  };
  return boundary != null && !now.isAfter(boundary.toUtc());
}
