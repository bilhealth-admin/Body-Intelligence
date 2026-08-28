import 'dart:async';

import 'package:body_intelligence_log/features/ads/advertising_privacy_page.dart';
import 'package:body_intelligence_log/features/ads/domain/ad_policy.dart';
import 'package:body_intelligence_log/features/ads/presentation/ad_runtime_bootstrap.dart';
import 'package:body_intelligence_log/features/ads/services/admob_contextual_ad_gateway.dart';
import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('UMP must authorize before the contextual ad boundary opens', () async {
    final platform = _FakeUmpPlatform(
      canRequest: true,
      privacyRequirement: UmpPrivacyOptionsRequirement.required,
    );
    final gate = AdMobUmpConsentGate(platform: platform, isApplicable: true);

    final snapshot = await gate.refresh(force: true);

    expect(platform.updateCalls, 1);
    expect(platform.formCalls, 1);
    expect(snapshot.phase, UmpConsentPhase.ready);
    expect(snapshot.canRequestAds, isTrue);
    expect(snapshot.privacyOptionsRequired, isTrue);
  });

  test('UMP error fails closed without an ad request grant', () async {
    final platform = _FakeUmpPlatform()..failure = StateError('offline');
    final gate = AdMobUmpConsentGate(platform: platform, isApplicable: true);

    final snapshot = await gate.refresh(force: true);

    expect(snapshot.phase, UmpConsentPhase.blocked);
    expect(snapshot.canRequestAds, isFalse);
    expect(snapshot.failure, isA<StateError>());
  });

  test('non-Android UMP boundary remains not applicable and closed', () async {
    final platform = _FakeUmpPlatform(canRequest: true);
    final gate = AdMobUmpConsentGate(platform: platform, isApplicable: false);

    final snapshot = await gate.refresh(force: true);

    expect(snapshot.phase, UmpConsentPhase.notApplicable);
    expect(snapshot.canRequestAds, isFalse);
    expect(platform.updateCalls, 0);
  });

  test('privacy-options form is re-evaluated before ads resume', () async {
    final platform = _FakeUmpPlatform(
      canRequest: true,
      privacyRequirement: UmpPrivacyOptionsRequirement.required,
    );
    final gate = AdMobUmpConsentGate(platform: platform, isApplicable: true);
    await gate.refresh(force: true);

    platform.canRequest = false;
    final snapshot = await gate.showPrivacyOptions();

    expect(platform.privacyFormCalls, 1);
    expect(snapshot.canRequestAds, isFalse);
  });

  test(
    'required-form failure blocks before canRequestAds is consulted',
    () async {
      final platform = _FakeUmpPlatform(canRequest: true)
        ..formFailure = StateError('form failed');
      final gate = AdMobUmpConsentGate(platform: platform, isApplicable: true);

      final snapshot = await gate.refresh(force: true);

      expect(snapshot.phase, UmpConsentPhase.blocked);
      expect(snapshot.canRequestAds, isFalse);
      expect(platform.canRequestCalls, 0);
    },
  );

  test('parallel callers share one consent-information update', () async {
    final pending = Completer<void>();
    final platform = _FakeUmpPlatform()..pendingUpdate = pending;
    final gate = AdMobUmpConsentGate(platform: platform, isApplicable: true);

    final first = gate.refresh();
    final second = gate.refresh();
    expect(platform.updateCalls, 1);
    pending.complete();
    await Future.wait([first, second]);

    expect(platform.updateCalls, 1);
  });

  testWidgets(
    'launch ignores legacy BIL switches and starts UMP for adult Free',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bil.advertising.contextual_consent.v1': 'declined',
        'bil.advertising.adult_confirmation.v1': false,
      });
      final coordinator = _FakeCoordinator(
        const UmpConsentSnapshot(
          phase: UmpConsentPhase.ready,
          canRequestAds: false,
          privacyOptionsRequirement: UmpPrivacyOptionsRequirement.notRequired,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BilAndroidUmpBootstrap(
              enabled: true,
              audienceEligible: true,
              accountKey: 'free-a',
              coordinator: coordinator,
              child: const Text('BIL'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(coordinator.refreshCalls, 1);
      expect(coordinator.lastForce, isTrue);
    },
  );

  testWidgets('unknown age never starts UMP and remains fail closed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bil.advertising.contextual_consent.v1': 'contextual_only',
    });
    final coordinator = _FakeCoordinator(
      const UmpConsentSnapshot.uninitialized(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: BilAndroidUmpBootstrap(
            enabled: true,
            audienceEligible: false,
            accountKey: 'free-a',
            coordinator: coordinator,
            child: const Text('BIL'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coordinator.refreshCalls, 0);
  });

  testWidgets('disabled platform bootstrap leaves iOS ad state untouched', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bil.advertising.contextual_consent.v1': 'contextual_only',
      'bil.advertising.adult_confirmation.v1': true,
    });
    final coordinator = _FakeCoordinator(
      const UmpConsentSnapshot.uninitialized(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: BilAndroidUmpBootstrap(
            enabled: false,
            audienceEligible: true,
            accountKey: 'free-a',
            coordinator: coordinator,
            child: const Text('BIL'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coordinator.refreshCalls, 0);
  });

  testWidgets('account switch forces a new UMP refresh without Guest carry', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator(
      const UmpConsentSnapshot(
        phase: UmpConsentPhase.ready,
        canRequestAds: true,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.notRequired,
      ),
    );

    Widget app({required bool eligible, required String? owner}) =>
        ProviderScope(
          child: MaterialApp(
            home: BilAndroidUmpBootstrap(
              enabled: true,
              audienceEligible: eligible,
              accountKey: owner,
              coordinator: coordinator,
              child: const Text('BIL'),
            ),
          ),
        );

    await tester.pumpWidget(app(eligible: true, owner: 'free-a'));
    await tester.pumpAndSettle();
    expect(coordinator.refreshCalls, 1);

    await tester.pumpWidget(app(eligible: false, owner: null));
    await tester.pumpAndSettle();
    expect(coordinator.refreshCalls, 1);

    await tester.pumpWidget(app(eligible: true, owner: 'free-b'));
    await tester.pumpAndSettle();
    expect(coordinator.refreshCalls, 2);
  });

  test(
    'gateway exits before Mobile Ads initialization when UMP blocks',
    () async {
      final coordinator = _FakeCoordinator(
        const UmpConsentSnapshot(
          phase: UmpConsentPhase.blocked,
          canRequestAds: false,
          privacyOptionsRequirement: UmpPrivacyOptionsRequirement.unknown,
        ),
      );
      final gateway = AdMobContextualAdGateway(
        configuredOverride: true,
        umpConsent: coordinator,
        adultConfirmed: () => true,
      );

      expect(await gateway.loadBanner(AdPlacement.generalDiscovery), isNull);
      expect(coordinator.verifyCalls, 1);
    },
  );

  test(
    'gateway never starts UMP when adult eligibility is not confirmed',
    () async {
      final coordinator = _FakeCoordinator(
        const UmpConsentSnapshot(
          phase: UmpConsentPhase.ready,
          canRequestAds: true,
          privacyOptionsRequirement: UmpPrivacyOptionsRequirement.notRequired,
        ),
      );
      final gateway = AdMobContextualAdGateway(
        configuredOverride: true,
        umpConsent: coordinator,
        adultConfirmed: () => false,
      );

      expect(await gateway.loadBanner(AdPlacement.generalDiscovery), isNull);
      expect(coordinator.verifyCalls, 0);
    },
  );

  test('gateway re-checks live canRequestAds before every request', () async {
    final platform = _FakeUmpPlatform(canRequest: false);
    final gate = AdMobUmpConsentGate(platform: platform, isApplicable: true);
    await gate.refresh(force: true);
    final initialChecks = platform.canRequestCalls;
    final gateway = AdMobContextualAdGateway(
      configuredOverride: true,
      umpConsent: gate,
      adultConfirmed: () => true,
    );

    expect(await gateway.loadBanner(AdPlacement.generalDiscovery), isNull);
    expect(await gateway.loadBanner(AdPlacement.generalDiscovery), isNull);
    expect(platform.canRequestCalls, initialChecks + 2);
  });

  testWidgets('Advertising Privacy exposes required Google privacy options', (
    tester,
  ) async {
    final coordinator = _FakeCoordinator(
      const UmpConsentSnapshot(
        phase: UmpConsentPhase.ready,
        canRequestAds: true,
        privacyOptionsRequirement: UmpPrivacyOptionsRequirement.required,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: AdvertisingPrivacyPage(umpConsentCoordinator: coordinator),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final options = find.byKey(const Key('advertising-google-privacy-options'));
    expect(options, findsOneWidget);
    await tester.tap(options);
    await tester.pumpAndSettle();
    expect(coordinator.privacyCalls, 1);
  });
}

final class _FakeUmpPlatform implements UmpPlatformBridge {
  _FakeUmpPlatform({
    this.canRequest = false,
    this.privacyRequirement = UmpPrivacyOptionsRequirement.notRequired,
  });

  bool canRequest;
  UmpPrivacyOptionsRequirement privacyRequirement;
  Object? failure;
  Object? formFailure;
  Completer<void>? pendingUpdate;
  int updateCalls = 0;
  int formCalls = 0;
  int privacyFormCalls = 0;
  int canRequestCalls = 0;

  @override
  Future<bool> canRequestAds() async {
    canRequestCalls++;
    return canRequest;
  }

  @override
  Future<UmpPrivacyOptionsRequirement> getPrivacyOptionsRequirement() async =>
      privacyRequirement;

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    formCalls++;
    final error = formFailure;
    if (error != null) throw error;
  }

  @override
  Future<void> requestConsentInfoUpdate() async {
    updateCalls++;
    final error = failure;
    if (error != null) throw error;
    await pendingUpdate?.future;
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    privacyFormCalls++;
  }
}

final class _FakeCoordinator implements UmpConsentCoordinator {
  _FakeCoordinator(this.value);

  UmpConsentSnapshot value;
  int refreshCalls = 0;
  int verifyCalls = 0;
  int privacyCalls = 0;
  bool lastForce = false;

  @override
  bool get isApplicable => true;

  @override
  UmpConsentSnapshot get snapshot => value;

  @override
  Future<UmpConsentSnapshot> refresh({bool force = false}) async {
    refreshCalls++;
    lastForce = force;
    return value;
  }

  @override
  Future<UmpConsentSnapshot> verifyCanRequestAds() async {
    verifyCalls++;
    return value;
  }

  @override
  Future<UmpConsentSnapshot> showPrivacyOptions() async {
    privacyCalls++;
    return value;
  }
}
