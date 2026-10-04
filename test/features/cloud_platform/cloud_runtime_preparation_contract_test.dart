import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production preparation is wired but transport remains locked', () {
    final providers = File(
      'lib/features/cloud_platform/providers/cloud_sync_providers.dart',
    ).readAsStringSync();
    final startup = File(
      'lib/features/startup/startup_page.dart',
    ).readAsStringSync();
    final gate = File(
      'lib/features/cloud_platform/services/cloud_runtime_access_gate.dart',
    ).readAsStringSync();

    expect(providers, contains('cloudRuntimePreparationProvider'));
    expect(providers, contains('CloudRuntimeAccessGate'));
    expect(providers, contains('CloudAccountKeyRepository'));
    expect(providers, contains('AesGcmCloudPayloadCipher'));
    expect(providers, contains('AppDatabaseCloudOutboxProducer'));
    expect(providers, contains('CloudTransportActivationLock'));
    expect(providers, isNot(contains('.synchronize(')));
    expect(startup, contains('ref.watch(cloudRuntimePreparationProvider)'));
    expect(
      startup,
      contains('ref.invalidate(cloudRuntimePreparationProvider)'),
    );
    // The current-policy field is necessary to reject an unfamiliar latest
    // receipt; actual host tests prove newer denial/tie/version behavior.
    expect(gate, contains("select('granted, recorded_at, policy_version')"));
    expect(gate, contains(".order('recorded_at', ascending: false)"));
    expect(gate, contains(".order('granted', ascending: true)"));
    expect(gate, contains('consentGrantedAt'));
  });
}
