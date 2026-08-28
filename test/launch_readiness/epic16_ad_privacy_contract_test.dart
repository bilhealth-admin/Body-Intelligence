import 'dart:io';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/advertising_privacy_page.dart';
import 'package:body_intelligence_log/features/ads/services/contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/safe_contextual_ad_controller.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_entitlement.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/app/localization/runtime_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AdPolicy();

  test(
    'free contextual ads require an adult account and configured provider',
    () {
      final free = _verifiedFree();
      expect(
        policy
            .evaluate(
              subscription: free,
              placement: AdPlacement.generalDiscovery,
              providerConfigured: true,
              isOnline: true,
              ageEligibility: AdAgeEligibility.unknown,
            )
            .reason,
        AdSuppressionReason.ageUnknown,
      );
      expect(
        policy
            .evaluate(
              subscription: free,
              placement: AdPlacement.generalDiscovery,
              providerConfigured: false,
              isOnline: true,
              ageEligibility: AdAgeEligibility.adult,
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
      subscription: _verifiedFree(),
      placement: AdPlacement.generalDiscovery,
      providerConfigured: true,
      isOnline: true,
      ageEligibility: AdAgeEligibility.unknown,
    );
    final result = await controller.requestIfAllowed(
      decision: decision,
      placement: AdPlacement.generalDiscovery,
    );
    expect(result, ContextualAdResult.unavailable);
    expect(gateway.calls, 0);
  });

  test('sensitive routes never request advertising', () {
    final free = _verifiedFree();
    for (final placement in AdPlacement.values.where(
      (value) => value != AdPlacement.generalDiscovery,
    )) {
      expect(
        policy
            .evaluate(
              subscription: free,
              placement: placement,
              providerConfigured: true,
              isOnline: true,
              ageEligibility: AdAgeEligibility.adult,
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
            placement: AdPlacement.generalDiscovery,
            providerConfigured: true,
            isOnline: true,
          )
          .reason,
      AdSuppressionReason.paidSubscription,
    );
  });

  test('unknown age and minors fail closed', () {
    final free = _verifiedFree();
    AdPolicyDecision decision(AdAgeEligibility age) => policy.evaluate(
      subscription: free,
      placement: AdPlacement.generalDiscovery,
      providerConfigured: true,
      isOnline: true,
      ageEligibility: age,
    );

    expect(
      decision(AdAgeEligibility.unknown).reason,
      AdSuppressionReason.ageUnknown,
    );
    expect(
      decision(AdAgeEligibility.under18).reason,
      AdSuppressionReason.underage,
    );
  });

  test(
    'offline and disabled gateway fail closed without invented fill',
    () async {
      final free = _verifiedFree();
      expect(
        policy
            .evaluate(
              subscription: free,
              placement: AdPlacement.generalDiscovery,
              providerConfigured: true,
              isOnline: false,
              ageEligibility: AdAgeEligibility.adult,
            )
            .reason,
        AdSuppressionReason.offline,
      );
      expect(
        await const DisabledContextualAdGateway().show(
          AdPlacement.generalDiscovery,
        ),
        ContextualAdResult.unavailable,
      );
    },
  );

  test('publisher-created ad-free and second age switches are removed', () {
    expect(
      File(
        'lib/features/ads/repositories/ad_consent_repository.dart',
      ).existsSync(),
      isFalse,
    );
    final page = File(
      'lib/features/ads/advertising_privacy_page.dart',
    ).readAsStringSync();
    expect(page, isNot(contains('advertising-consent-declined')));
    expect(page, isNot(contains('advertising-consent-contextual')));
    expect(page, isNot(contains('advertising-adult-confirmation')));
  });

  test('advertising privacy entry is reviewed in every production locale', () {
    expect(RuntimeCopy.supported, hasLength(25));
    final english = advertisingPrivacySurfaceCopy('en');
    expect(english, hasLength(19));
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
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AdvertisingPrivacyPage())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advertising-provider-unavailable')), findsOne);
    expect(find.byKey(const Key('advertising-contextual-policy')), findsOne);
    expect(find.byKey(const Key('advertising-consent-declined')), findsNothing);
    expect(
      find.byKey(const Key('advertising-adult-confirmation')),
      findsNothing,
    );
  });
}

SubscriptionState _verifiedFree() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const <CommerceEntitlement>{},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);

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
