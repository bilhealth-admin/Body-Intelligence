import 'dart:async';

import 'package:body_intelligence_log/features/ads/services/admob_ump_consent_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'newer denial wins when concurrent live reads complete in reverse',
    () async {
      final platform = _QueuedUmpPlatform();
      final gate = _gate(platform);
      await gate.refresh(force: true);

      final staleGrant = Completer<bool>();
      final newerDenial = Completer<bool>();
      platform.enqueueCanRequest(staleGrant.future);
      platform.enqueueCanRequest(newerDenial.future);

      final first = gate.verifyCanRequestAds();
      await _drainMicrotasks();
      final second = gate.verifyCanRequestAds();
      await _drainMicrotasks();
      expect(platform.canRequestCalls, 3);

      newerDenial.complete(false);
      final secondSnapshot = await second;
      expect(secondSnapshot.canRequestAds, isFalse);
      expect(gate.snapshot.canRequestAds, isFalse);

      staleGrant.complete(true);
      final firstSnapshot = await first;
      expect(firstSnapshot.canRequestAds, isFalse);
      expect(gate.snapshot.canRequestAds, isFalse);
    },
  );

  test('newer error wins over an older delayed grant', () async {
    final platform = _QueuedUmpPlatform();
    final gate = _gate(platform);
    await gate.refresh(force: true);

    final staleGrant = Completer<bool>();
    final newerFailure = Completer<bool>();
    platform.enqueueCanRequest(staleGrant.future);
    platform.enqueueCanRequest(newerFailure.future);

    final first = gate.verifyCanRequestAds();
    await _drainMicrotasks();
    final second = gate.verifyCanRequestAds();
    await _drainMicrotasks();

    newerFailure.completeError(StateError('live UMP read failed'));
    final secondSnapshot = await second;
    expect(secondSnapshot.phase, UmpConsentPhase.blocked);
    expect(secondSnapshot.canRequestAds, isFalse);

    staleGrant.complete(true);
    final firstSnapshot = await first;
    expect(firstSnapshot.phase, UmpConsentPhase.blocked);
    expect(firstSnapshot.canRequestAds, isFalse);
    expect(gate.snapshot.phase, UmpConsentPhase.blocked);
    expect(gate.snapshot.canRequestAds, isFalse);
  });
}

AdMobUmpConsentGate _gate(_QueuedUmpPlatform platform) => AdMobUmpConsentGate(
  platform: platform,
  isApplicable: true,
  consentInfoTimeout: const Duration(seconds: 1),
  machineReadTimeout: const Duration(seconds: 1),
);

Future<void> _drainMicrotasks() async {
  for (var index = 0; index < 4; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _QueuedUmpPlatform implements UmpPlatformBridge {
  final List<Future<bool>> _canRequestResults = <Future<bool>>[];
  int canRequestCalls = 0;

  void enqueueCanRequest(Future<bool> result) {
    _canRequestResults.add(result);
  }

  @override
  Future<bool> canRequestAds() {
    canRequestCalls++;
    if (_canRequestResults.isNotEmpty) {
      return _canRequestResults.removeAt(0);
    }
    return Future<bool>.value(true);
  }

  @override
  Future<UmpPrivacyOptionsRequirement> getPrivacyOptionsRequirement() async =>
      UmpPrivacyOptionsRequirement.required;

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {}

  @override
  Future<void> requestConsentInfoUpdate() async {}

  @override
  Future<void> showPrivacyOptionsForm() async {}
}
