import 'dart:io';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_contextual_banner_slot.dart';
import 'package:body_intelligence_log/features/ads/presentation/safe_free_ad_anchor.dart';
import 'package:body_intelligence_log/features/ads/providers/ad_providers.dart';
import 'package:body_intelligence_log/features/ads/services/admob_configuration.dart';
import 'package:body_intelligence_log/features/ads/services/admob_contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:body_intelligence_log/features/commerce/domain/commerce_plan.dart';
import 'package:body_intelligence_log/features/commerce/domain/subscription_state.dart';
import 'package:body_intelligence_log/features/commerce/providers/commerce_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';

const _networkTestEnabled = bool.fromEnvironment('BIL_ADS_NETWORK_TEST');
const _visualCaptureHold = Duration(seconds: 15);

final _sdkPlanProvider = StateProvider<SubscriptionState>(
  (_) => _verifiedSubscription(CommercePlan.free),
);

SubscriptionState _verifiedSubscription(CommercePlan plan) => SubscriptionState(
  plan: plan,
  entitlements: const {},
  authority: EntitlementAuthority.verifiedServer,
  isPurchasable: false,
  canRestorePurchases: plan != CommercePlan.free,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Google SDK test banner follows the verified Free and paid-plan boundary',
    (tester) async {
      expect(
        Platform.isAndroid,
        isTrue,
        reason: 'This native SDK integration proof runs on Android only.',
      );
      expect(
        kDebugMode,
        isTrue,
        reason: 'Google test units must never run in profile or release mode.',
      );
      expect(
        BilAdMobConfiguration.androidTestBanner,
        'ca-app-pub-3940256099942544/6300978111',
        reason: 'The integration must never request a production ad unit.',
      );

      // These values deliberately model only the already-tested BIL boundary.
      // They are not an actual reviewer/owner login and are not live UMP proof.
      const sdkAccountKey = 'sdk-integration-adult-free';
      var fixturePlan = CommercePlan.free;
      final consent = _SdkIntegrationConsent();
      final gateway = AdMobContextualAdGateway(
        useTestUnits: true,
        configuredOverride: true,
        umpConsent: consent,
        accountKey: () => sdkAccountKey,
        adultConfirmed: () => fixturePlan == CommercePlan.free,
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              verifiedEntitlementOwnerProvider.overrideWith(
                (_) => Stream.value(sdkAccountKey),
              ),
              verifiedSubscriptionStateProvider.overrideWith(
                (ref) async => ref.watch(_sdkPlanProvider),
              ),
              contextualAdGatewayProvider.overrideWithValue(gateway),
              if (!_networkTestEnabled)
                adOnlineProvider.overrideWith((_) => Stream.value(true)),
              adAgeEligibilityProvider.overrideWith(
                (_) => AdAgeEligibility.adult,
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SDK TEST (synthetic consent/account)',
                        key: Key('admob-sdk-test-disclosure'),
                      ),
                      SafeFreeAdAnchor(surface: SafeFreeAdSurface.more),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await _pumpUntil(
          tester,
          () => find.byType(AdWidget).evaluate().length == 1,
          reason: 'Google test banner did not load through the native SDK.',
        );
        expect(gateway.isConfigured, isTrue);
        expect(gateway.mayDisplayAd, isTrue);
        final firstBannerConsentChecks = consent.verifyCalls;
        expect(firstBannerConsentChecks, greaterThanOrEqualTo(1));
        expect(find.byType(AdWidget), findsOneWidget);
        expect(
          tester.getSize(find.byType(SafeFreeAdAnchor)).height,
          78,
          reason: '50dp native banner plus 14dp safe separation on each side.',
        );
        await _captureWindow(tester, 'NATIVE_GOOGLE_TEST_BANNER_VISIBLE');

        final scopeContext = tester.element(
          find.byType(SafeContextualBannerSlot),
        );
        final container = ProviderScope.containerOf(scopeContext);

        fixturePlan = CommercePlan.premium;
        container.read(_sdkPlanProvider.notifier).state = _verifiedSubscription(
          fixturePlan,
        );
        await _pumpUntil(
          tester,
          () => find.byType(AdWidget).evaluate().isEmpty,
          reason: 'Premium must remove the native banner immediately.',
          timeout: const Duration(seconds: 5),
        );
        _expectCollapsed(tester);

        fixturePlan = CommercePlan.free;
        container.read(_sdkPlanProvider.notifier).state = _verifiedSubscription(
          fixturePlan,
        );
        await _pumpUntil(
          tester,
          () => find.byType(AdWidget).evaluate().length == 1,
          reason: 'A verified Free grant did not restore the SDK test banner.',
        );
        final secondBannerConsentChecks = consent.verifyCalls;
        expect(
          secondBannerConsentChecks,
          greaterThan(firstBannerConsentChecks),
        );
        expect(find.byType(AdWidget), findsOneWidget);

        fixturePlan = CommercePlan.premiumAiCoach;
        container.read(_sdkPlanProvider.notifier).state = _verifiedSubscription(
          fixturePlan,
        );
        await _pumpUntil(
          tester,
          () => find.byType(AdWidget).evaluate().isEmpty,
          reason: 'Premium AI Coach must remove the native banner immediately.',
          timeout: const Duration(seconds: 5),
        );
        _expectCollapsed(tester);
        debugPrint('NATIVE_GOOGLE_PAID_SUPPRESSION_PASS');

        if (_networkTestEnabled) {
          // Disconnect while an actual Free banner is present, not while the
          // paid plan has already hidden it. This proves removal as well as
          // suppression of new requests throughout the outage.
          fixturePlan = CommercePlan.free;
          container.read(_sdkPlanProvider.notifier).state =
              _verifiedSubscription(fixturePlan);
          await _pumpUntil(
            tester,
            () => find.byType(AdWidget).evaluate().length == 1,
            reason: 'The Free banner was not visible before the network cut.',
          );
          final preOutageConsentChecks = consent.verifyCalls;
          expect(
            preOutageConsentChecks,
            greaterThan(secondBannerConsentChecks),
          );
          debugPrint('NATIVE_GOOGLE_PRE_OUTAGE_TEST_BANNER_VISIBLE');
          debugPrint('NATIVE_GOOGLE_NETWORK_OFF_REQUESTED');
          await _pumpUntil(
            tester,
            () => container.read(adOnlineProvider).asData?.value == false,
            reason: 'The emulator did not report the real network outage.',
            timeout: const Duration(seconds: 45),
          );
          debugPrint('NATIVE_GOOGLE_NETWORK_OFFLINE_CONFIRMED');

          await _pumpUntil(
            tester,
            () =>
                container
                    .read(adDecisionProvider(AdPlacement.generalDiscovery))
                    .reason ==
                AdSuppressionReason.offline,
            reason: 'A verified Free account did not remain offline-gated.',
            timeout: const Duration(seconds: 10),
          );
          _expectCollapsed(tester);
          debugPrint('NATIVE_GOOGLE_NETWORK_REMOVED_VISIBLE_BANNER_PASS');

          debugPrint('NATIVE_GOOGLE_NETWORK_RECOVERY_REQUESTED');
          await _pumpUntil(
            tester,
            () => container.read(adOnlineProvider).asData?.value == true,
            reason: 'The emulator did not report restored connectivity.',
            timeout: const Duration(seconds: 45),
          );
          await _pumpUntil(
            tester,
            () => find.byType(AdWidget).evaluate().length == 1,
            reason: 'The native Google test banner did not recover online.',
          );
          expect(consent.verifyCalls, greaterThan(preOutageConsentChecks));
          await _captureWindow(
            tester,
            'NATIVE_GOOGLE_RECOVERED_TEST_BANNER_VISIBLE',
          );
          debugPrint('NATIVE_GOOGLE_NETWORK_RECOVERY_PASS');
        }
      } finally {
        // Detach the slot before disposing the gateway so every native
        // BannerAd remains owned and disposed by the production boundary.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
        gateway.dispose();
        consent.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

void _expectCollapsed(WidgetTester tester) {
  expect(find.byType(AdWidget), findsNothing);
  expect(tester.getSize(find.byType(SafeFreeAdAnchor)).height, 0);
}

Future<void> _captureWindow(WidgetTester tester, String marker) async {
  // AdWidget existence precedes asynchronous Android PlatformView creation.
  // Keep pumping while the external driver captures actual pixels; sleeping
  // outside the binding alone can strand the native view's next Flutter frame.
  for (var frame = 0; frame < 3; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
  }
  debugPrint(marker);
  final deadline = DateTime.now().add(_visualCaptureHold);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  required String reason,
  Duration timeout = const Duration(seconds: 130),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(predicate(), isTrue, reason: reason);
}

/// Test-only consent fixture for the native SDK integration boundary.
///
/// It intentionally bypasses the live UMP form so this test proves only native
/// Google test-banner delivery and BIL entitlement suppression. Production UMP
/// remains covered separately and must still pass on every real account.
final class _SdkIntegrationConsent extends ChangeNotifier
    implements UmpConsentCoordinator {
  static const _allowed = UmpConsentSnapshot(
    phase: UmpConsentPhase.ready,
    canRequestAds: true,
    privacyOptionsRequirement: UmpPrivacyOptionsRequirement.notRequired,
  );

  int verifyCalls = 0;

  @override
  bool get isApplicable => true;

  @override
  UmpConsentSnapshot get snapshot => _allowed;

  @override
  Future<UmpConsentSnapshot> refresh({bool force = false}) async => _allowed;

  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() async => _allowed;

  @override
  Future<UmpConsentSnapshot> verifyCanRequestAds() async {
    verifyCalls++;
    return _allowed;
  }
}
