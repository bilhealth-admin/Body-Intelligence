import 'package:body_intelligence_log/app/environment/app_environment.dart';
import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/features/ads/advertising_privacy_page.dart';
import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/presentation/ad_runtime_bootstrap.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_contextual_banner_slot.dart';
import 'package:body_intelligence_log/features/ads/providers/ad_providers.dart';
import 'package:body_intelligence_log/features/ads/services/admob_contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:body_intelligence_log/features/profile/providers/user_profile_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ownerId = '00000000-0000-4000-8000-000000000008';

// google_mobile_ads 9.1.0 declares these in AdInstanceManager,
// UserMessagingChannel, and AppStateEventNotifier. Raw handlers deliberately
// avoid depending on either of the plugin's custom MethodCodecs.
const _googleMobileAdsPlatformChannels = <String>[
  'plugins.flutter.io/google_mobile_ads',
  'plugins.flutter.io/google_mobile_ads/ump',
  'plugins.flutter.io/google_mobile_ads/app_state_method',
  'plugins.flutter.io/google_mobile_ads/app_state_event',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'deferred AdMob flags keep eligible adult Free $platform off native SDK',
      (tester) async {
        // This test must be compiled with the same explicit false flags as the
        // deferred-AdMob upload. Failing here prevents an enabled build from
        // being mistaken for valid disabled-runtime evidence.
        expect(
          const bool.fromEnvironment('BIL_ADS_ENABLED', defaultValue: false),
          isFalse,
        );
        expect(
          const bool.fromEnvironment(
            'BIL_AD_PROVIDER_READY',
            defaultValue: false,
          ),
          isFalse,
        );
        expect(AppEnvironment.adsEnabled, isFalse);
        expect(AppEnvironment.adProviderReady, isFalse);
        expect(AppEnvironment.adsConfigured, isFalse);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );

        final nativeMessages = <String>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        for (final channel in _googleMobileAdsPlatformChannels) {
          messenger.setMockMessageHandler(channel, (ByteData? _) async {
            nativeMessages.add(channel);
            throw TestFailure(
              'Disabled AdMob runtime called native channel $channel.',
            );
          });
        }
        addTearDown(() {
          for (final channel in _googleMobileAdsPlatformChannels) {
            messenger.setMockMessageHandler(channel, null);
          }
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedEntitlementOwnerProvider.overrideWith(
                (_) => Stream.value(_ownerId),
              ),
              verifiedSubscriptionStateProvider.overrideWith(
                (_) async => _verifiedFreeSubscription(),
              ),
              userProfileProvider.overrideWith(
                (_) => Stream.value(_adultProfile()),
              ),
              adOnlineProvider.overrideWith((_) => Stream.value(true)),
            ],
            child: const BilMobileUmpBootstrap(
              child: MaterialApp(
                home: Stack(
                  fit: StackFit.expand,
                  children: [
                    AdvertisingPrivacyPage(),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeContextualBannerSlot(
                        placement: AdPlacement.generalDiscovery,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AdvertisingPrivacyPage)),
        );
        await container.read(verifiedEntitlementOwnerProvider.future);
        await container.read(verifiedSubscriptionStateProvider.future);
        await container.read(userProfileProvider.future);
        await container.read(adOnlineProvider.future);
        await tester.pumpAndSettle();

        // Keep every normal request precondition open. Provider readiness from
        // the two compile-time switches must be the sole suppression reason.
        expect(container.read(registeredAdultFreeAdAudienceProvider), isTrue);
        expect(
          container.read(adAgeEligibilityProvider),
          AdAgeEligibility.adult,
        );
        expect(container.read(adOnlineProvider).value, isTrue);

        final gateway = container.read(contextualAdGatewayProvider);
        expect(gateway, isA<AdMobContextualAdGateway>());
        final realGateway = gateway as AdMobContextualAdGateway;
        expect(realGateway.configuredOverride, isNull);
        expect(
          realGateway.useTestUnits,
          isTrue,
          reason: 'The false build flags, not missing test IDs, must close it.',
        );
        expect(realGateway.isConfigured, isFalse);
        expect(
          container
              .read(adDecisionProvider(AdPlacement.generalDiscovery))
              .reason,
          AdSuppressionReason.providerUnavailable,
        );

        expect(
          find.byKey(const Key('advertising-provider-unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('advertising-google-privacy-options')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('advertising-google-consent-blocked')),
          findsNothing,
        );
        expect(find.byType(SafeContextualBannerSlot), findsOneWidget);

        // Exercise the direct real gateway boundary too; it must return before
        // live UMP verification, MobileAds initialization, or BannerAd.load.
        expect(
          await realGateway.loadBanner(AdPlacement.generalDiscovery),
          isNull,
        );

        // Advancing beyond every bounded retry window catches a hidden slot or
        // bootstrap timer that might otherwise call the SDK after the assertion.
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();
        expect(nativeMessages, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(nativeMessages, isEmpty);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}

SubscriptionState _verifiedFreeSubscription() => SubscriptionState(
  plan: CommercePlan.free,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: false,
);

UserProfileData _adultProfile() {
  final recordedAt = DateTime.utc(2026, 9, 6);
  return UserProfileData(
    id: 8,
    uuid: _ownerId,
    gender: 'unspecified',
    age: 30,
    height: 170,
    currentWeight: 70,
    targetWeight: 70,
    activityLevel: 'moderate',
    exercises: true,
    createdAt: recordedAt,
    updatedAt: recordedAt,
    revision: 1,
    syncStatus: 'synced',
  );
}
