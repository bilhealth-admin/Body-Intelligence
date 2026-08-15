import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/domain/subscription_state.dart';

enum AdConsentStatus { unknown, declined, contextualOnly }

enum AdAgeEligibility { unknown, under18, adult }

enum AdRegionEligibility { unknown, restricted, eligible }

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
  consentMissing,
  sensitiveContext,
  providerUnavailable,
  offline,
  ageUnknown,
  underage,
  regionUnknown,
  regionRestricted,
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
/// diagnosis data. The only inputs are entitlement, explicit consent,
/// placement classification, connectivity, and provider readiness.
final class AdPolicy {
  const AdPolicy();

  static const _nonSensitivePlacements = <AdPlacement>{
    AdPlacement.wellnessLibrary,
    AdPlacement.generalDiscovery,
  };

  AdPolicyDecision evaluate({
    required SubscriptionState subscription,
    required AdConsentStatus consent,
    required AdPlacement placement,
    required bool providerConfigured,
    required bool isOnline,
    AdAgeEligibility ageEligibility = AdAgeEligibility.adult,
    AdRegionEligibility regionEligibility = AdRegionEligibility.eligible,
  }) {
    if (subscription.plan != CommercePlan.free) {
      return const AdPolicyDecision._(AdSuppressionReason.paidSubscription);
    }
    if (ageEligibility == AdAgeEligibility.unknown) {
      return const AdPolicyDecision._(AdSuppressionReason.ageUnknown);
    }
    if (ageEligibility == AdAgeEligibility.under18) {
      return const AdPolicyDecision._(AdSuppressionReason.underage);
    }
    if (regionEligibility == AdRegionEligibility.unknown) {
      return const AdPolicyDecision._(AdSuppressionReason.regionUnknown);
    }
    if (regionEligibility == AdRegionEligibility.restricted) {
      return const AdPolicyDecision._(AdSuppressionReason.regionRestricted);
    }
    if (consent != AdConsentStatus.contextualOnly) {
      return const AdPolicyDecision._(AdSuppressionReason.consentMissing);
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
