import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/services/admob_contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:body_intelligence_log/features/ads/services/ios_no_idfa_ad_sdk_boundary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('bil/ads_privacy');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var sdkCalls = 0;
  var statusCalls = 0;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    sdkCalls = 0;
    statusCalls = 0;
    for (final name in [
      'plugins.flutter.io/google_mobile_ads',
      'plugins.flutter.io/google_mobile_ads/ump',
    ]) {
      messenger.setMockMessageHandler(name, (_) async {
        sdkCalls++;
        return const StandardMethodCodec().encodeErrorEnvelope(
          code: 'unexpected_sdk_call',
        );
      });
    }
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(native, null);
    for (final name in [
      'plugins.flutter.io/google_mobile_ads',
      'plugins.flutter.io/google_mobile_ads/ump',
    ]) {
      messenger.setMockMessageHandler(name, null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  for (final status in [
    'authorized',
    'denied',
    'restricted',
    'unknown',
    'unsupported',
  ]) {
    test('legacy $status cannot reach any production UMP operation', () async {
      messenger.setMockMethodCallHandler(native, (call) async {
        expect(call.method, 'iosAdPrivacyStatus');
        statusCalls++;
        return {'trackingAuthorizationStatus': status};
      });
      const bridge = GoogleMobileAdsUmpPlatformBridge(
        tagForUnderAgeOfConsent: false,
      );
      await expectLater(
        bridge.requestConsentInfoUpdate(),
        throwsA(isA<UmpPlatformFailure>()),
      );
      await expectLater(
        bridge.loadAndShowConsentFormIfRequired(),
        throwsA(isA<UmpPlatformFailure>()),
      );
      expect(await bridge.canRequestAds(), isFalse);
      expect(
        await bridge.getPrivacyOptionsRequirement(),
        UmpPrivacyOptionsRequirement.unknown,
      );
      await expectLater(
        bridge.showPrivacyOptionsForm(),
        throwsA(isA<UmpPlatformFailure>()),
      );
      expect(statusCalls, 5);
      expect(sdkCalls, 0);
    });

    test(
      'legacy $status blocks SDK initialization even with a cached UMP grant',
      () async {
        messenger.setMockMethodCallHandler(
          native,
          (_) async => {'trackingAuthorizationStatus': status},
        );
        final ump = _ReadyUmp();
        final gateway = AdMobContextualAdGateway(
          umpConsent: ump,
          configuredOverride: true,
          adultConfirmed: () => true,
          accountKey: () => 'owner-A',
        );
        addTearDown(gateway.dispose);
        expect(await gateway.loadBanner(AdPlacement.generalDiscovery), isNull);
        expect(ump.verifications, 0);
        expect(sdkCalls, 0);
      },
    );
  }

  test(
    'notDetermined permits the actual production UMP machine read',
    () async {
      messenger.setMockMethodCallHandler(
        native,
        (_) async => {'trackingAuthorizationStatus': 'notDetermined'},
      );
      messenger.setMockMessageHandler(
        'plugins.flutter.io/google_mobile_ads/ump',
        (_) async {
          sdkCalls++;
          return const StandardMethodCodec().encodeSuccessEnvelope(true);
        },
      );
      const bridge = GoogleMobileAdsUmpPlatformBridge(
        tagForUnderAgeOfConsent: false,
      );
      expect(await bridge.canRequestAds(), isTrue);
      expect(sdkCalls, 1);
    },
  );

  test(
    'Android never queries iOS status and retains its SDK eligibility',
    () async {
      messenger.setMockMethodCallHandler(native, (_) async {
        statusCalls++;
        return null;
      });
      const boundary = NoIdfaIosAdSdkBoundary(
        platformOverride: TargetPlatform.android,
      );
      expect(await boundary.permitsSdkRequests(), isTrue);
      expect(statusCalls, 0);
      expect(sdkCalls, 0);
    },
  );

  for (final invalid in [
    null,
    <String, Object?>{},
    {'trackingAuthorizationStatus': true},
    {'trackingAuthorizationStatus': 'notDetermined '},
  ]) {
    test('missing or malformed native status fails closed $invalid', () async {
      messenger.setMockMethodCallHandler(native, (_) async => invalid);
      expect(
        await const NoIdfaIosAdSdkBoundary().permitsSdkRequests(),
        isFalse,
      );
      expect(sdkCalls, 0);
    });
  }

  test(
    'native errors and absent channel fail closed without SDK requests',
    () async {
      messenger.setMockMethodCallHandler(
        native,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      expect(
        await const NoIdfaIosAdSdkBoundary().permitsSdkRequests(),
        isFalse,
      );
      messenger.setMockMethodCallHandler(native, null);
      expect(
        await const NoIdfaIosAdSdkBoundary().permitsSdkRequests(),
        isFalse,
      );
      expect(sdkCalls, 0);
    },
  );

  test('timed-out status never becomes a cached late SDK grant', () async {
    final held = Completer<Map<String, Object?>>();
    messenger.setMockMethodCallHandler(native, (_) => held.future);
    const boundary = NoIdfaIosAdSdkBoundary(
      statusTimeout: Duration(milliseconds: 2),
    );
    expect(await boundary.permitsSdkRequests(), isFalse);
    held.complete({'trackingAuthorizationStatus': 'notDetermined'});
    messenger.setMockMethodCallHandler(
      native,
      (_) async => {'trackingAuthorizationStatus': 'authorized'},
    );
    expect(await boundary.permitsSdkRequests(), isFalse);
    expect(sdkCalls, 0);
  });

  test('native source is status-only and plist does not request ATT', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('ATTrackingManager.trackingAuthorizationStatus'));
    expect(swift, isNot(contains('requestTrackingAuthorization')));
    expect(swift, isNot(contains('import AdSupport')));
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      isNot(contains('NSUserTrackingUsageDescription')),
    );
  });
}

final class _ReadyUmp implements UmpConsentCoordinator {
  int verifications = 0;
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
  Future<UmpConsentSnapshot> verifyCanRequestAds() async {
    verifications++;
    return snapshot;
  }

  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() async => snapshot;
}
