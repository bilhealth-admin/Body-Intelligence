import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete cloud platform retains required production branches', () {
    const required = [
      'lib/features/cloud_platform/persistence/sqlite_cloud_platform_store.dart',
      'lib/features/cloud_platform/services/durable_offline_first_cloud_platform.dart',
      'lib/features/cloud_platform/services/cloud_identity_runtime.dart',
      'lib/features/cloud_platform/services/cloud_backup_restore_engine.dart',
      'lib/features/cloud_platform/services/cloud_privacy_lifecycle_engine.dart',
      'lib/features/cloud_platform/services/cloud_observability_runtime.dart',
      'lib/features/cloud_platform/services/cloud_schema_negotiator.dart',
    ];
    for (final path in required) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
