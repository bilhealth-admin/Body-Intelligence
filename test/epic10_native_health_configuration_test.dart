import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declares only the visible BIL health scope', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final permission in [
      'READ_STEPS',
      'READ_ACTIVE_CALORIES_BURNED',
      'READ_EXERCISE',
      'READ_WEIGHT',
      'WRITE_WEIGHT',
    ]) {
      expect(manifest, contains('android.permission.health.$permission'));
    }
    expect(manifest, isNot(contains('READ_BLOOD_GLUCOSE')));
    expect(manifest, isNot(contains('READ_BLOOD_PRESSURE')));
    expect(
      manifest,
      contains('androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE'),
    );
  });

  test(
    'native health bridges expose honest availability and revoke behavior',
    () {
      final android = File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt',
      ).readAsStringSync();
      final ios = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();

      expect(android, contains('HealthConnectClient.getSdkStatus'));
      expect(android, contains('revokeAllPermissions'));
      expect(ios, contains('HKHealthStore.isHealthDataAvailable'));
      expect(ios, contains('requiresSystemSettings'));
      expect(plist, contains('NSHealthShareUsageDescription'));
      expect(plist, contains('NSHealthUpdateUsageDescription'));
      expect(entitlements, contains('com.apple.developer.healthkit'));
    },
  );
}
