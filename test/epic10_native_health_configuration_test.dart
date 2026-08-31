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
      'READ_SLEEP',
      'READ_HEART_RATE',
      'READ_RESTING_HEART_RATE',
      'READ_HEART_RATE_VARIABILITY',
      'READ_WEIGHT',
      'WRITE_WEIGHT',
    ]) {
      expect(manifest, contains('android.permission.health.$permission'));
    }
    for (final excludedPermission in <String>[
      'READ_BLOOD_GLUCOSE',
      'READ_BLOOD_PRESSURE',
      'READ_BODY_TEMPERATURE',
      'READ_RESPIRATORY_RATE',
      'READ_OXYGEN_SATURATION',
    ]) {
      expect(manifest, isNot(contains(excludedPermission)));
    }
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
      for (final excludedRecord in <String>[
        'BloodGlucoseRecord',
        'BloodPressureRecord',
        'BodyTemperatureRecord',
        'RespiratoryRateRecord',
        'OxygenSaturationRecord',
      ]) {
        expect(android, isNot(contains(excludedRecord)));
      }
      expect(ios, contains('HKHealthStore.isHealthDataAvailable'));
      expect(ios, contains('requiresSystemSettings'));
      expect(plist, contains('NSHealthShareUsageDescription'));
      expect(plist, contains('NSHealthUpdateUsageDescription'));
      expect(entitlements, contains('com.apple.developer.healthkit'));
    },
  );

  test('initial Health Connect import consumes every records page', () {
    final android = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt',
    ).readAsStringSync();
    final initialStart = android.indexOf(
      'suspend fun <T : Record> readInitial',
    );
    final initialEnd = android.indexOf(
      'for (name in supportedRequestedNames)',
      initialStart,
    );
    final initialRead = android.substring(initialStart, initialEnd);

    expect(initialRead, contains('pageToken = pageToken'));
    expect(initialRead, contains('pageToken = page.pageToken'));
    expect(initialRead, contains('while (pageToken != null)'));
  });
}
