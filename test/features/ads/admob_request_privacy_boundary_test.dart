import 'dart:async';

import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/services/admob_contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Exercise the SDK's real platform codec rather than a second request adapter.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'native request contains no health, owner or targeting payload',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        calls.add(call);
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus(<String, AdapterStatus>{});
        }
        if (call.method == 'loadBannerAd') {
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
        }
        return null;
      });
      final gate = _Consent();
      final gateway = _gateway(gate);
      try {
        final handle = await gateway.loadBanner(AdPlacement.generalDiscovery);
        expect(handle, isNotNull);
        expect(gate.verifications, 1);
        // The SDK singleton registers its channel once per isolate. Randomized
        // test ordering may have registered it already; a cold registration may
        // only precede this exact privacy configuration/SDK-init/load sequence.
        final registrations = calls.where((c) => c.method == '_init');
        expect(registrations.length, lessThanOrEqualTo(1));
        if (registrations.isNotEmpty) expect(calls.first.method, '_init');
        expect(calls.where((c) => c.method != '_init').map((c) => c.method), [
          'MobileAds#setSameAppKeyEnabled',
          'MobileAds#initialize',
          'loadBannerAd',
        ]);
        expect(
          calls
              .singleWhere((c) => c.method == 'MobileAds#setSameAppKeyEnabled')
              .arguments,
          {'isEnabled': false},
        );
        final payload =
            calls.singleWhere((c) => c.method == 'loadBannerAd').arguments
                as Map;
        final request = payload['request'] as AdRequest;
        expect(request.nonPersonalizedAds, isTrue);
        expect(request.keywords, isNull);
        expect(request.contentUrl, isNull);
        expect(request.neighboringContentUrls, isNull);
        expect(request.extras, isNull);
        // Verify the SDK's retained legacy wire field is absent too; the app
        // does not call this deprecated targeting API.
        // ignore: deprecated_member_use
        expect(request.mediationExtrasIdentifier, isNull);
        expect(request.mediationExtras, isNull);
        expect(payload.toString(), isNot(contains('private-owner-marker')));
        handle!.dispose();
        await Future<void>.delayed(Duration.zero);
      } finally {
        gateway.dispose();
      }
    },
  );

  test(
    'fresh denial cannot initialize SDK or issue a native request',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        calls.add(call.method);
        return null;
      });
      final gate = _Consent()..allowed = false;
      final gateway = _gateway(gate);
      try {
        expect(await gateway.loadBanner(AdPlacement.generalDiscovery), isNull);
        expect(gate.verifications, 1);
        expect(calls, isEmpty);
      } finally {
        gateway.dispose();
      }
    },
  );

  for (final revokeOwner in [false, true]) {
    test(
      'revocation during SDK initialization blocks load: owner=$revokeOwner',
      () async {
        final started = Completer<void>();
        final initialize = Completer<Object?>();
        final calls = <String>[];
        messenger.setMockMethodCallHandler(instanceManager.channel, (
          call,
        ) async {
          calls.add(call.method);
          if (call.method == 'MobileAds#initialize') {
            started.complete();
            return initialize.future;
          }
          return null;
        });
        final gate = _Consent();
        String? owner = 'private-owner-marker';
        final gateway = _gateway(gate, owner: () => owner);
        try {
          final load = gateway.loadBanner(AdPlacement.generalDiscovery);
          await started.future;
          if (revokeOwner) {
            owner = null;
          } else {
            gate.allowed = false;
          }
          initialize.complete(InitializationStatus(<String, AdapterStatus>{}));
          expect(await load, isNull);
          expect(calls, isNot(contains('loadBannerAd')));
        } finally {
          gateway.dispose();
        }
      },
    );
  }
}

AdMobContextualAdGateway _gateway(
  _Consent consent, {
  String? Function()? owner,
}) => AdMobContextualAdGateway(
  configuredOverride: true,
  useTestUnits: true,
  umpConsent: consent,
  adultConfirmed: () => true,
  accountKey: owner ?? () => 'private-owner-marker',
);

final class _Consent implements UmpConsentCoordinator {
  bool allowed = true;
  int verifications = 0;
  @override
  bool get isApplicable => true;
  @override
  UmpConsentSnapshot get snapshot => UmpConsentSnapshot(
    phase: allowed ? UmpConsentPhase.ready : UmpConsentPhase.blocked,
    canRequestAds: allowed,
    privacyOptionsRequirement: UmpPrivacyOptionsRequirement.required,
  );
  @override
  Future<UmpConsentSnapshot> verifyCanRequestAds() async {
    verifications++;
    return snapshot;
  }

  @override
  Future<UmpConsentSnapshot> refresh({bool force = false}) async => snapshot;
  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() async => snapshot;
}
