import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/services/admob_configuration.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
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
    final free = FreePlan.createState();
    final paid = SubscriptionState(
      plan: CommercePlan.pro,
      entitlements: const {},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: false,
      canRestorePurchases: true,
    );
    AdPolicyDecision decide(SubscriptionState subscription) => policy.evaluate(
      subscription: subscription,
      consent: AdConsentStatus.contextualOnly,
      placement: AdPlacement.wellnessLibrary,
      providerConfigured: true,
      isOnline: true,
    );
    expect(decide(free).mayRequestAd, isTrue);
    expect(decide(paid).reason, AdSuppressionReason.paidSubscription);
  });

  test('health logging and unknown consent remain ad-free', () {
    const policy = AdPolicy();
    final free = FreePlan.createState();
    expect(
      policy
          .evaluate(
            subscription: free,
            consent: AdConsentStatus.contextualOnly,
            placement: AdPlacement.foodEntry,
            providerConfigured: true,
            isOnline: true,
          )
          .reason,
      AdSuppressionReason.sensitiveContext,
    );
    expect(
      policy
          .evaluate(
            subscription: free,
            consent: AdConsentStatus.unknown,
            placement: AdPlacement.generalDiscovery,
            providerConfigured: true,
            isOnline: true,
          )
          .reason,
      AdSuppressionReason.consentMissing,
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
