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
    expect(gate, contains("select('granted, recorded_at')"));
    expect(gate, contains('consentGrantedAt'));
  });
}
