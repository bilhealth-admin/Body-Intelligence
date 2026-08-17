import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime gate requires owner, verified cloud entitlement, and consent', () {
    final source = File(
      'lib/features/cloud_platform/services/cloud_runtime_access_gate.dart',
    ).readAsStringSync();

    expect(source, contains('LocalDataAccountBoundary'));
    expect(source, contains('CommerceEntitlement.cloudSync'));
    expect(source, contains("consentPurpose = 'cloud_sync'"));
    expect(source, contains("consentPolicyVersion = '1'"));
    expect(source, contains(".eq('granted', true)"));
  });

  test('phase 3A security primitives do not start synchronization', () {
    for (final path in <String>[
      'lib/features/cloud_platform/services/cloud_account_key_repository.dart',
      'lib/features/cloud_platform/services/aes_gcm_cloud_payload_cipher.dart',
      'lib/features/cloud_platform/services/cloud_runtime_access_gate.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('.synchronize(')), reason: path);
      expect(source, isNot(contains('bil_sync_records')), reason: path);
    }
  });
}
