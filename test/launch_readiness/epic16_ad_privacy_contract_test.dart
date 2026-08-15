import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/advertising_privacy_page.dart';
import 'package:body_intelligence_log/features/ads/services/contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/safe_contextual_ad_controller.dart';
import 'package:body_intelligence_log/features/ads/repositories/ad_consent_repository.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/free_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const policy = AdPolicy();

  test(
    'free contextual ads require explicit consent and configured provider',
    () {
      final free = FreePlan.createState();
      expect(
        policy
            .evaluate(
              subscription: free,
              consent: AdConsentStatus.unknown,
              placement: AdPlacement.wellnessLibrary,
              providerConfigured: true,
              isOnline: true,
            )
            .reason,
        AdSuppressionReason.consentMissing,
      );
      expect(
        policy
            .evaluate(
              subscription: free,
              consent: AdConsentStatus.contextualOnly,
              placement: AdPlacement.wellnessLibrary,
              providerConfigured: false,
              isOnline: true,
            )
            .reason,
        AdSuppressionReason.providerUnavailable,
      );
    },
  );

  test('suppressed decision never invokes the provider gateway', () async {
    final gateway = _RecordingGateway();
    final controller = SafeContextualAdController(gateway);
    final decision = policy.evaluate(
      subscription: FreePlan.createState(),
      consent: AdConsentStatus.declined,
      placement: AdPlacement.generalDiscovery,
      providerConfigured: true,
      isOnline: true,
    );
    final result = await controller.requestIfAllowed(
      decision: decision,
      placement: AdPlacement.generalDiscovery,
    );
    expect(result, ContextualAdResult.unavailable);
    expect(gateway.calls, 0);
  });

  test('sensitive routes never request advertising', () {
    final free = FreePlan.createState();
    for (final placement in AdPlacement.values.where(
      (value) =>
          value != AdPlacement.wellnessLibrary &&
          value != AdPlacement.generalDiscovery,
    )) {
      expect(
        policy
            .evaluate(
              subscription: free,
              consent: AdConsentStatus.contextualOnly,
              placement: placement,
              providerConfigured: true,
              isOnline: true,
            )
            .reason,
        AdSuppressionReason.sensitiveContext,
      );
    }
  });

  test('verified paid access suppresses ads immediately', () {
    final paid = SubscriptionState(
      plan: CommercePlan.plus,
      entitlements: const <CommerceEntitlement>{},
      authority: EntitlementAuthority.verifiedServer,
      isPurchasable: false,
      canRestorePurchases: true,
    );
    expect(
      policy
          .evaluate(
            subscription: paid,
            consent: AdConsentStatus.contextualOnly,
            placement: AdPlacement.wellnessLibrary,
            providerConfigured: true,
            isOnline: true,
          )
          .reason,
      AdSuppressionReason.paidSubscription,
    );
  });

  test(
    'unknown age, minors, and unknown or restricted regions fail closed',
    () {
      final free = FreePlan.createState();
      AdPolicyDecision decision(
        AdAgeEligibility age,
        AdRegionEligibility region,
      ) => policy.evaluate(
        subscription: free,
        consent: AdConsentStatus.contextualOnly,
        placement: AdPlacement.wellnessLibrary,
        providerConfigured: true,
        isOnline: true,
        ageEligibility: age,
        regionEligibility: region,
      );

      expect(
        decision(AdAgeEligibility.unknown, AdRegionEligibility.eligible).reason,
        AdSuppressionReason.ageUnknown,
      );
      expect(
        decision(AdAgeEligibility.under18, AdRegionEligibility.eligible).reason,
        AdSuppressionReason.underage,
      );
      expect(
        decision(AdAgeEligibility.adult, AdRegionEligibility.unknown).reason,
        AdSuppressionReason.regionUnknown,
      );
      expect(
        decision(AdAgeEligibility.adult, AdRegionEligibility.restricted).reason,
        AdSuppressionReason.regionRestricted,
      );
    },
  );

  test(
    'offline and disabled gateway fail closed without invented fill',
    () async {
      final free = FreePlan.createState();
      expect(
        policy
            .evaluate(
              subscription: free,
              consent: AdConsentStatus.contextualOnly,
              placement: AdPlacement.wellnessLibrary,
              providerConfigured: true,
              isOnline: false,
            )
            .reason,
        AdSuppressionReason.offline,
      );
      expect(
        await const DisabledContextualAdGateway().show(
          AdPlacement.wellnessLibrary,
        ),
        ContextualAdResult.unavailable,
      );
    },
  );

  test('consent persists independently and can be revoked', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const repository = LocalAdConsentRepository();
    expect(await repository.read(), AdConsentStatus.unknown);
    await repository.write(AdConsentStatus.contextualOnly);
    expect(await repository.read(), AdConsentStatus.contextualOnly);
    await repository.write(AdConsentStatus.declined);
    expect(await repository.read(), AdConsentStatus.declined);
    await repository.clear();
    expect(await repository.read(), AdConsentStatus.unknown);
  });

  test('advertising privacy entry is reviewed in every production locale', () {
    expect(RuntimeCopy.supported, hasLength(25));
    final english = advertisingPrivacySurfaceCopy('en');
    expect(english, hasLength(24));
    for (final locale in RuntimeCopy.supported) {
      final surface = advertisingPrivacySurfaceCopy(locale);
      expect(surface, hasLength(english.length));
      expect(surface.every((value) => value.trim().isNotEmpty), isTrue);
      if (locale != 'en') {
        for (var index = 0; index < surface.length; index++) {
          expect(
            surface[index],
            isNot(english[index]),
            reason: 'English fallback at $locale/$index',
          );
        }
      }
      expect(advertisingPrivacyEntryTitle(locale).trim(), isNotEmpty);
      expect(
        advertisingPrivacyEntryStatus(locale, contextualAllowed: false).trim(),
        isNotEmpty,
      );
      expect(
        advertisingPrivacyEntryStatus(locale, contextualAllowed: true).trim(),
        isNotEmpty,
      );
    }
  });

  testWidgets('unconfigured provider is visible and cannot imply ad delivery', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AdvertisingPrivacyPage())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advertising-provider-unavailable')), findsOne);
    expect(find.byKey(const Key('advertising-consent-declined')), findsOne);
    expect(find.byKey(const Key('advertising-consent-contextual')), findsOne);
  });
}

final class _RecordingGateway implements ContextualAdGateway {
  int calls = 0;
  @override
  bool get isConfigured => true;
  @override
  Future<ContextualAdResult> show(AdPlacement placement) async {
    calls++;
    return ContextualAdResult.displayed;
  }
}
