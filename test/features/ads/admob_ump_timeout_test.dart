import 'dart:async';

import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';

const _shortMachineTimeout = Duration(milliseconds: 5);

void main() {
  test(
    'consent-information update timeout fails closed before any form',
    () async {
      final update = Completer<void>();
      final platform = _ControllableUmpPlatform()..pendingUpdate = update;
      final gate = _shortTimeoutGate(platform);

      final snapshot = await gate.refresh(force: true);

      expect(snapshot.phase, UmpConsentPhase.blocked);
      expect(snapshot.canRequestAds, isFalse);
      expect(snapshot.failure, isA<TimeoutException>());
      expect(platform.updateCalls, 1);
      expect(platform.consentFormCalls, 0);
    },
  );

  test(
    'privacy-requirement timeout fails closed before canRequestAds',
    () async {
      final privacyRequirement = Completer<UmpPrivacyOptionsRequirement>();
      final platform = _ControllableUmpPlatform()
        ..pendingPrivacyRequirement = privacyRequirement;
      final gate = _shortTimeoutGate(platform);

      final snapshot = await gate.refresh(force: true);

      expect(snapshot.phase, UmpConsentPhase.blocked);
      expect(snapshot.canRequestAds, isFalse);
      expect(snapshot.failure, isA<TimeoutException>());
      expect(platform.consentFormCalls, 1);
      expect(platform.privacyRequirementCalls, 1);
      expect(platform.canRequestCalls, 0);
    },
  );

  test('canRequestAds timeout fails closed and ignores late grant', () async {
    final canRequest = Completer<bool>();
    final platform = _ControllableUmpPlatform()..pendingCanRequest = canRequest;
    final gate = _shortTimeoutGate(platform);

    final timedOut = await gate.refresh(force: true);
    expect(timedOut.phase, UmpConsentPhase.blocked);
    expect(timedOut.canRequestAds, isFalse);
    expect(timedOut.failure, isA<TimeoutException>());

    canRequest.complete(true);
    await _drainMicrotasks();

    expect(gate.snapshot.phase, UmpConsentPhase.blocked);
    expect(gate.snapshot.canRequestAds, isFalse);
  });

  test('force refresh recovers after timed-out machine read', () async {
    final canRequest = Completer<bool>();
    final platform = _ControllableUmpPlatform()..pendingCanRequest = canRequest;
    final gate = _shortTimeoutGate(platform);

    expect((await gate.refresh(force: true)).phase, UmpConsentPhase.blocked);
    platform
      ..pendingCanRequest = null
      ..canRequest = true;

    final recovered = await gate.refresh(force: true);

    expect(recovered.phase, UmpConsentPhase.ready);
    expect(recovered.canRequestAds, isTrue);
    expect(platform.updateCalls, 2);
    expect(platform.consentFormCalls, 2);
  });

  test('blocked machine failure retries without requiring force', () async {
    final update = Completer<void>();
    final platform = _ControllableUmpPlatform()
      ..pendingUpdate = update
      ..canRequest = true;
    final gate = _shortTimeoutGate(platform);

    expect((await gate.refresh(force: true)).phase, UmpConsentPhase.blocked);
    platform.pendingUpdate = null;

    final recovered = await gate.refresh();

    expect(recovered.phase, UmpConsentPhase.ready);
    expect(recovered.canRequestAds, isTrue);
    expect(platform.updateCalls, 2);
  });

  test('ready user-denied state stays cached without form re-prompt', () async {
    final platform = _ControllableUmpPlatform()..canRequest = false;
    final gate = _shortTimeoutGate(platform);

    final denied = await gate.refresh(force: true);
    final cached = await gate.refresh();

    expect(denied.phase, UmpConsentPhase.ready);
    expect(denied.canRequestAds, isFalse);
    expect(cached, same(denied));
    expect(platform.updateCalls, 1);
    expect(platform.consentFormCalls, 1);
  });

  test('interactive consent form is not timed out or overlapped', () async {
    final consentForm = Completer<void>();
    final platform = _ControllableUmpPlatform()
      ..pendingConsentForm = consentForm
      ..canRequest = true;
    final gate = _shortTimeoutGate(platform);

    final first = gate.refresh(force: true);
    await _drainMicrotasks();
    expect(platform.consentFormCalls, 1);

    await Future<void>.delayed(_shortMachineTimeout * 3);
    expect(gate.snapshot.phase, UmpConsentPhase.updating);
    expect(gate.snapshot.canRequestAds, isFalse);

    final shared = gate.refresh(force: true);
    await _drainMicrotasks();
    expect(platform.consentFormCalls, 1);

    consentForm.complete();
    final snapshots = await Future.wait([first, shared]);
    expect(snapshots, everyElement(isA<UmpConsentSnapshot>()));
    expect(snapshots.last.phase, UmpConsentPhase.ready);
    expect(platform.consentFormCalls, 1);
  });

  test('privacy form and forced refresh share one human interaction', () async {
    final privacyForm = Completer<void>();
    final platform = _ControllableUmpPlatform()
      ..privacyRequirement = UmpPrivacyOptionsRequirement.required
      ..canRequest = true;
    final gate = _shortTimeoutGate(platform);
    await gate.refresh(force: true);
    platform.pendingPrivacyForm = privacyForm;

    final first = gate.showPrivacyOptions();
    await _drainMicrotasks();
    expect(platform.privacyFormCalls, 1);

    final second = gate.showPrivacyOptions();
    final forcedRefresh = gate.refresh(force: true);
    await _drainMicrotasks();
    expect(platform.privacyFormCalls, 1);
    expect(platform.updateCalls, 1);

    privacyForm.complete();
    final snapshots = await Future.wait([first, second, forcedRefresh]);
    expect(snapshots, everyElement(isA<UmpConsentSnapshot>()));
    expect(snapshots.last.phase, UmpConsentPhase.ready);
    expect(platform.privacyFormCalls, 1);
  });

  test('late verify read cannot overwrite a newer privacy decision', () async {
    final platform = _ControllableUmpPlatform()
      ..privacyRequirement = UmpPrivacyOptionsRequirement.required
      ..canRequest = true;
    final gate = _shortTimeoutGate(platform);
    await gate.refresh(force: true);

    final staleCanRequest = Completer<bool>();
    platform.pendingCanRequest = staleCanRequest;
    final verification = gate.verifyCanRequestAds();
    await _drainMicrotasks();
    expect(platform.canRequestCalls, 2);

    final privacyForm = Completer<void>();
    platform.pendingPrivacyForm = privacyForm;
    final privacyDecision = gate.showPrivacyOptions();
    expect(gate.snapshot.phase, UmpConsentPhase.updating);
    expect(gate.snapshot.canRequestAds, isFalse);

    staleCanRequest.complete(true);
    await _drainMicrotasks();
    expect(gate.snapshot.phase, UmpConsentPhase.updating);
    expect(gate.snapshot.canRequestAds, isFalse);

    platform
      ..pendingCanRequest = null
      ..canRequest = false;
    privacyForm.complete();

    final privacySnapshot = await privacyDecision;
    final verificationSnapshot = await verification;
    expect(privacySnapshot.phase, UmpConsentPhase.ready);
    expect(privacySnapshot.canRequestAds, isFalse);
    expect(verificationSnapshot.phase, UmpConsentPhase.ready);
    expect(verificationSnapshot.canRequestAds, isFalse);
    expect(gate.snapshot.canRequestAds, isFalse);
  });
}

AdMobUmpConsentGate _shortTimeoutGate(_ControllableUmpPlatform platform) =>
    AdMobUmpConsentGate(
      platform: platform,
      isApplicable: true,
      consentInfoTimeout: _shortMachineTimeout,
      machineReadTimeout: _shortMachineTimeout,
    );

Future<void> _drainMicrotasks() async {
  for (var index = 0; index < 4; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _ControllableUmpPlatform implements UmpPlatformBridge {
  Completer<void>? pendingUpdate;
  Completer<void>? pendingConsentForm;
  Completer<UmpPrivacyOptionsRequirement>? pendingPrivacyRequirement;
  Completer<bool>? pendingCanRequest;
  Completer<void>? pendingPrivacyForm;

  UmpPrivacyOptionsRequirement privacyRequirement =
      UmpPrivacyOptionsRequirement.notRequired;
  bool canRequest = false;

  int updateCalls = 0;
  int consentFormCalls = 0;
  int privacyRequirementCalls = 0;
  int canRequestCalls = 0;
  int privacyFormCalls = 0;

  @override
  Future<void> requestConsentInfoUpdate() {
    updateCalls++;
    return pendingUpdate?.future ?? Future<void>.value();
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    consentFormCalls++;
    return pendingConsentForm?.future ?? Future<void>.value();
  }

  @override
  Future<UmpPrivacyOptionsRequirement> getPrivacyOptionsRequirement() {
    privacyRequirementCalls++;
    return pendingPrivacyRequirement?.future ??
        Future<UmpPrivacyOptionsRequirement>.value(privacyRequirement);
  }

  @override
  Future<bool> canRequestAds() {
    canRequestCalls++;
    return pendingCanRequest?.future ?? Future<bool>.value(canRequest);
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    privacyFormCalls++;
    return pendingPrivacyForm?.future ?? Future<void>.value();
  }
}
