import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../commerce/providers/commerce_providers.dart';
import '../domain/ad_policy.dart';
import '../services/contextual_ad_gateway.dart';
import '../services/admob_contextual_ad_gateway.dart';

final adConsentProvider = StateProvider<AdConsentStatus>(
  (ref) => AdConsentStatus.unknown,
);

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
final adRegionProvider = StateProvider<AdRegionEligibility>(
  (ref) => AdRegionEligibility.unknown,
);
final adAgeEligibilityProvider = StateProvider<AdAgeEligibility>(
  (ref) => AdAgeEligibility.unknown,
);

final contextualAdGatewayProvider = Provider<ContextualAdGateway>(
  (ref) => AdMobContextualAdGateway(),
);

final adPolicyProvider = Provider<AdPolicy>((ref) => const AdPolicy());

final adDecisionProvider = Provider.family<AdPolicyDecision, AdPlacement>((
  ref,
  placement,
) {
  final verifiedSubscription = ref.watch(verifiedSubscriptionStateProvider);
  return verifiedSubscription.when(
    loading: () => const AdPolicyDecision.entitlementUnverified(),
    error: (_, _) => const AdPolicyDecision.entitlementUnverified(),
    data: (subscription) => ref
        .watch(adPolicyProvider)
        .evaluate(
          subscription: subscription,
          consent: ref.watch(adConsentProvider),
          placement: placement,
          providerConfigured: ref
              .watch(contextualAdGatewayProvider)
              .isConfigured,
          isOnline: ref.watch(adOnlineProvider).value ?? false,
          ageEligibility: ref.watch(adAgeEligibilityProvider),
          regionEligibility: ref.watch(adRegionProvider),
        ),
  );
});
