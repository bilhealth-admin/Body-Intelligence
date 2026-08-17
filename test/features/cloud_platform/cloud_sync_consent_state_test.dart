import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/cloud_platform/services/cloud_sync_consent_repository.dart';

void main() {
  test('available state can enable sync', () {
    const state = CloudSyncConsentState(
      availability: CloudSyncConsentAvailability.available,
    );

    expect(state.canEnable, isTrue);
    expect(state.canDisable, isFalse);
    expect(state.canChange, isTrue);
  });

  test('premium loss blocks enabling but never traps an existing consent', () {
    const off = CloudSyncConsentState(
      availability: CloudSyncConsentAvailability.premiumRequired,
    );
    const on = CloudSyncConsentState(
      availability: CloudSyncConsentAvailability.premiumRequired,
      granted: true,
    );

    expect(off.canChange, isFalse);
    expect(on.canEnable, isFalse);
    expect(on.canDisable, isTrue);
    expect(on.canChange, isTrue);
  });

  test('signed-out and unavailable states are fail closed', () {
    for (final availability in <CloudSyncConsentAvailability>[
      CloudSyncConsentAvailability.signedOut,
      CloudSyncConsentAvailability.unavailable,
    ]) {
      final state = CloudSyncConsentState(availability: availability);
      expect(state.canChange, isFalse);
    }
  });
}
