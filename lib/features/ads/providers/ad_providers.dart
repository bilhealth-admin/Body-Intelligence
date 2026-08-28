import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../commerce/domain/commerce_plan.dart';
import '../../commerce/domain/subscription_state.dart';
import '../../commerce/providers/commerce_providers.dart';
import '../../onboarding/domain/adult_eligibility.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../domain/ad_policy.dart';
import '../services/admob_contextual_ad_gateway.dart';
import '../services/contextual_ad_gateway.dart';

/// Connectivity must be asserted by the host connectivity boundary. The
/// default is deliberately offline so a newly configured provider cannot make
/// a request before runtime network state is known.
final adOnlineProvider = StreamProvider<bool>((ref) async* {
  bool connected(List<ConnectivityResult> values) =>
      values.any((value) => value != ConnectivityResult.none);
  final connectivity = Connectivity();
  yield connected(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(connected).distinct();
});

/// Reuses BIL's product-wide 18+ account gate. No second advertising age
/// confirmation is stored, and a Guest never inherits an authenticated
/// account's age after logout.
AdAgeEligibility adAgeEligibilityForSavedAge(int? age) {
  if (age == null) return AdAgeEligibility.unknown;
  return BilAdultEligibility.isEligibleAge(age)
      ? AdAgeEligibility.adult
      : AdAgeEligibility.under18;
}

final adAgeEligibilityProvider = Provider<AdAgeEligibility>((ref) {
  final owner = ref.watch(verifiedEntitlementOwnerProvider);
  if (owner.isLoading || owner.hasError || owner.asData?.value == null) {
    return AdAgeEligibility.unknown;
  }
  final profile = ref.watch(userProfileProvider);
  if (profile.isLoading || profile.hasError) {
    return AdAgeEligibility.unknown;
  }
  final age = profile.asData?.value?.age;
  return adAgeEligibilityForSavedAge(age);
});

/// The complete account boundary used before UMP is started. This is false
/// while either auth ownership or the server entitlement is changing, so an
/// ad grant can never cross a logout or account switch.
final registeredAdultFreeAdAudienceProvider = Provider<bool>((ref) {
  final owner = ref.watch(verifiedEntitlementOwnerProvider);
  if (owner.isLoading || owner.hasError || owner.asData?.value == null) {
    return false;
  }
  final subscription = ref.watch(verifiedSubscriptionStateProvider);
  if (subscription.isLoading || subscription.hasError) return false;
  final value = subscription.asData?.value;
  return value != null &&
      value.authority == EntitlementAuthority.verifiedServer &&
      value.plan == CommercePlan.free &&
      ref.watch(adAgeEligibilityProvider) == AdAgeEligibility.adult;
});

final contextualAdGatewayProvider = Provider<ContextualAdGateway>(
  (ref) => AdMobContextualAdGateway(
    adultConfirmed: () => ref.read(registeredAdultFreeAdAudienceProvider),
  ),
);

final adPolicyProvider = Provider<AdPolicy>((ref) => const AdPolicy());

final adDecisionProvider = Provider.family<AdPolicyDecision, AdPlacement>((
  ref,
  placement,
) {
  final owner = ref.watch(verifiedEntitlementOwnerProvider);
  if (owner.isLoading || owner.hasError || owner.asData?.value == null) {
    return const AdPolicyDecision.entitlementUnverified();
  }
  final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
  if (verifiedSubscription.isLoading || verifiedSubscription.hasError) {
    return const AdPolicyDecision.entitlementUnverified();
  }
  final subscription = verifiedSubscription.asData?.value;
  if (subscription == null) {
    return const AdPolicyDecision.entitlementUnverified();
  }
  return ref
      .watch(adPolicyProvider)
      .evaluate(
        subscription: subscription,
        placement: placement,
        providerConfigured: ref.watch(contextualAdGatewayProvider).isConfigured,
        isOnline: ref.watch(adOnlineProvider).value ?? false,
        ageEligibility: ref.watch(adAgeEligibilityProvider),
      );
});
