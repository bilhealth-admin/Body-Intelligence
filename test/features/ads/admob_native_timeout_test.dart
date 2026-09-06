import 'dart:async';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/services/admob_contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The SDK's method codec/instance registry is not exported by its public API.
// Use its actual protocol here rather than creating a second native adapter.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final stalledMethod in [
    'MobileAds#setSameAppKeyEnabled',
    'MobileAds#initialize',
    'loadBannerAd',
  ]) {
    test(
      '$stalledMethod timeout is bounded, late-safe and retryable',
      () async {
        // First-party ID is an iOS-only SDK call; Android is a no-op.
        debugDefaultTargetPlatformOverride =
            stalledMethod == 'MobileAds#setSameAppKeyEnabled'
            ? TargetPlatform.iOS
            : TargetPlatform.android;
        final calls = <String>[];
        final stalled = Completer<Object?>();
        var shouldStall = true;
        messenger.setMockMethodCallHandler(instanceManager.channel, (
          call,
        ) async {
          calls.add(call.method);
          if (call.method == stalledMethod && shouldStall) {
            return stalled.future;
          }
          switch (call.method) {
            case 'MobileAds#initialize':
              return InitializationStatus(<String, AdapterStatus>{});
            case 'loadBannerAd':
              await messenger.handlePlatformMessage(
                instanceManager.channel.name,
                instanceManager.channel.codec.encodeMethodCall(
                  MethodCall('onAdEvent', {
                    'adId': (call.arguments as Map)['adId'],
                    'eventName': 'onAdLoaded',
                  }),
                ),
                (_) {},
              );
              return null;
            default:
              return null;
          }
        });
        final gateway = AdMobContextualAdGateway(
          configuredOverride: true,
          useTestUnits: true,
          umpConsent: const _ReadyConsent(),
          adultConfirmed: () => true,
          accountKey: () => 'test-adult-free',
          sdkOperationTimeout: const Duration(milliseconds: 50),
          bannerLoadTimeout: const Duration(milliseconds: 50),
        );
        try {
          expect(
            await gateway
                .loadBanner(AdPlacement.generalDiscovery)
                .timeout(const Duration(seconds: 2)),
            isNull,
          );
          expect(calls.where((call) => call == stalledMethod), hasLength(1));
          if (stalledMethod == 'loadBannerAd') {
            expect(calls.where((call) => call == 'disposeAd'), hasLength(1));
          } else {
            expect(calls, isNot(contains('loadBannerAd')));
          }

          // Completing the obsolete native acknowledgement cannot resurrect an
          // expired request or continue into another initialization/ad load.
          final beforeLateCompletion = List<String>.of(calls);
          stalled.complete(
            stalledMethod == 'MobileAds#initialize'
                ? InitializationStatus(<String, AdapterStatus>{})
                : null,
          );
          await Future<void>.delayed(Duration.zero);
          expect(calls, beforeLateCompletion);

          shouldStall = false;
          final retried = await gateway.loadBanner(
            AdPlacement.generalDiscovery,
          );
          expect(retried, isNotNull);
          expect(calls.where((call) => call == stalledMethod), hasLength(2));
          retried!.dispose();
          await Future<void>.delayed(Duration.zero);
        } finally {
          gateway.dispose();
        }
      },
    );
  }
}

final class _ReadyConsent implements UmpConsentCoordinator {
  const _ReadyConsent();

  @override
  bool get isApplicable => true;

  @override
  UmpConsentSnapshot get snapshot => const UmpConsentSnapshot(
    phase: UmpConsentPhase.ready,
    canRequestAds: true,
    privacyOptionsRequirement: UmpPrivacyOptionsRequirement.notRequired,
  );

  @override
  Future<UmpConsentSnapshot> refresh({bool force = false}) async => snapshot;

  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() async => snapshot;

  @override
  Future<UmpConsentSnapshot> verifyCanRequestAds() async => snapshot;
}
