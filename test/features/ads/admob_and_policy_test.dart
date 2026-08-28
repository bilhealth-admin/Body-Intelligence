import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/providers/ad_providers.dart';
import 'package:body_intelligence_log/features/ads/services/admob_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('advertising reuses the existing 18+ product boundary', () {
    expect(adAgeEligibilityForSavedAge(null), AdAgeEligibility.unknown);
    expect(adAgeEligibilityForSavedAge(17), AdAgeEligibility.under18);
    expect(adAgeEligibilityForSavedAge(18), AdAgeEligibility.adult);
  });

  test(
    'development uses official test banners and production stays disabled',
    () {
      expect(
        BilAdMobConfiguration.bannerId(
          platform: BilAdPlatform.android,
          useTestUnits: true,
        ),
        'ca-app-pub-3940256099942544/6300978111',
      );
      expect(
        BilAdMobConfiguration.productionConfigured(BilAdPlatform.android),
        isFalse,
      );
      expect(
        BilAdMobConfiguration.productionConfigured(BilAdPlatform.ios),
        isFalse,
      );
      expect(BilAdMobConfiguration.appAdsRecord(), isNull);
    },
  );

  test('AdGate allows only Free in reviewed non-sensitive placement', () {
    const policy = AdPolicy();
    final free = _verifiedFree();
    AdPolicyDecision decide(SubscriptionState subscription) => policy.evaluate(
      subscription: subscription,
      placement: AdPlacement.generalDiscovery,
      providerConfigured: true,
      isOnline: true,
      ageEligibility: AdAgeEligibility.adult,
    );
    expect(decide(free).mayRequestAd, isTrue);
    for (final plan in const [
      CommercePlan.premium,
      CommercePlan.premiumAiCoach,
    ]) {
      final paid = SubscriptionState(
        plan: plan,
        entitlements: const {},
        authority: EntitlementAuthority.verifiedServer,
        isPurchasable: false,
        canRestorePurchases: true,
      );
      expect(
        decide(paid).reason,
        AdSuppressionReason.paidSubscription,
        reason: plan.name,
      );
    }
  });

  test('health logging and unknown age remain ad-free', () {
    const policy = AdPolicy();
    final free = _verifiedFree();
    expect(
      policy
          .evaluate(
            subscription: free,
            placement: AdPlacement.foodEntry,
            providerConfigured: true,
            isOnline: true,
            ageEligibility: AdAgeEligibility.adult,
          )
          .reason,
      AdSuppressionReason.sensitiveContext,
    );
    expect(
      policy
          .evaluate(
            subscription: free,
            placement: AdPlacement.generalDiscovery,
            providerConfigured: true,
            isOnline: true,
          )
          .reason,
      AdSuppressionReason.ageUnknown,
    );
  });

  test('unverified entitlement can never request an ad', () {
    const decision = AdPolicyDecision.entitlementUnverified();
    expect(decision.mayRequestAd, isFalse);
    expect(decision.reason, AdSuppressionReason.entitlementUnverified);

    final providers = File(
      'lib/features/ads/providers/ad_providers.dart',
    ).readAsStringSync();
    expect(providers, contains('verifiedSubscriptionStateProvider'));
    expect(providers, isNot(contains('ref.watch(subscriptionStateProvider)')));
  });
}

SubscriptionState _verifiedFree() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);
