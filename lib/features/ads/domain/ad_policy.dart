import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/domain/subscription_state.dart';

enum AdAgeEligibility { unknown, under18, adult }

enum AdPlacement {
  wellnessLibrary,
  generalDiscovery,
  dashboard,
  dailyLog,
  foodEntry,
  progress,
  weeklyReport,
  connectedHealth,
  profile,
  settings,
  paywall,
}

enum AdSuppressionReason {
  allowed,
  paidSubscription,
  entitlementUnverified,
  sensitiveContext,
  providerUnavailable,
  offline,
  ageUnknown,
  underage,
}

final class AdPolicyDecision {
  const AdPolicyDecision._(this.reason);

  const AdPolicyDecision.entitlementUnverified()
    : reason = AdSuppressionReason.entitlementUnverified;

  final AdSuppressionReason reason;
  bool get mayRequestAd => reason == AdSuppressionReason.allowed;
}

/// Privacy-first advertising policy.
///
/// It accepts no health, nutrition, weight, location, profile, search, or
/// diagnosis data. The only inputs are server-verified entitlement, the
/// existing product-wide adult gate, placement classification, connectivity,
/// and provider readiness. Google UMP remains the final consent authority at
/// the provider boundary immediately before every ad request.
final class AdPolicy {
  const AdPolicy();

  static const _nonSensitivePlacements = <AdPlacement>{
    AdPlacement.generalDiscovery,
  };

  AdPolicyDecision evaluate({
    required SubscriptionState subscription,
    required AdPlacement placement,
    required bool providerConfigured,
    required bool isOnline,
    AdAgeEligibility ageEligibility = AdAgeEligibility.unknown,
  }) {
    if (subscription.authority != EntitlementAuthority.verifiedServer) {
      return const AdPolicyDecision.entitlementUnverified();
    }
    if (subscription.plan != CommercePlan.free) {
      return const AdPolicyDecision._(AdSuppressionReason.paidSubscription);
    }
    if (ageEligibility == AdAgeEligibility.unknown) {
      return const AdPolicyDecision._(AdSuppressionReason.ageUnknown);
    }
    if (ageEligibility == AdAgeEligibility.under18) {
      return const AdPolicyDecision._(AdSuppressionReason.underage);
    }
    if (!_nonSensitivePlacements.contains(placement)) {
      return const AdPolicyDecision._(AdSuppressionReason.sensitiveContext);
    }
    if (!providerConfigured) {
      return const AdPolicyDecision._(AdSuppressionReason.providerUnavailable);
    }
    if (!isOnline) {
      return const AdPolicyDecision._(AdSuppressionReason.offline);
    }
    return const AdPolicyDecision._(AdSuppressionReason.allowed);
  }
}
