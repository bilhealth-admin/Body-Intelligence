import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android declares only the visible BIL health scope', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final permission in [
      'READ_STEPS',
      'READ_DISTANCE',
      'READ_ACTIVE_CALORIES_BURNED',
      'READ_EXERCISE',
      'READ_SLEEP',
      'READ_HEART_RATE',
      'READ_RESTING_HEART_RATE',
      'READ_HEART_RATE_VARIABILITY',
      'READ_WEIGHT',
      'WRITE_WEIGHT',
      'READ_BODY_FAT',
      'READ_LEAN_BODY_MASS',
      'READ_HYDRATION',
      'READ_NUTRITION',
      'WRITE_NUTRITION',
      'READ_HEALTH_DATA_HISTORY',
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
      expect(
        android,
        contains('metadata.dataOrigin.packageName == activity.packageName'),
      );
      expect(android, contains('Device.TYPE_WATCH'));
      expect(android, contains('"wearableKind"] = "wear_os_watch"'));
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
      expect(
        ios,
        contains('source.bundleIdentifier == Bundle.main.bundleIdentifier'),
      );
      expect(plist, contains('NSHealthShareUsageDescription'));
      expect(plist, contains('NSHealthUpdateUsageDescription'));
      expect(entitlements, contains('com.apple.developer.healthkit'));
    },
  );

  test(
    'HealthKit backfill and channel pages are bounded without losing anchors',
    () {
      final ios = File(
        'ios/Runner/BILGlobalHealthBridge.swift',
      ).readAsStringSync();
      final readStart = ios.indexOf('private func readChanges(');
      final readEnd = ios.indexOf('private func write(', readStart);
      final readChanges = ios.substring(readStart, readEnd);

      expect(ios, contains('private static let initialHistoryDays = 365'));
      expect(ios, contains('private static let readPageLimit = 500'));
      expect(readChanges, contains('withStart: historyStart'));
      expect(readChanges, contains('anchor: anchors[name]'));
      expect(readChanges, contains('limit: Self.readPageLimit'));
      expect(readChanges, contains('nextAnchors[name] = newAnchor'));
      expect(readChanges, contains('"hasMore": pageHasMore'));
      expect(readChanges, isNot(contains('withStart: nil')));
      expect(readChanges, isNot(contains('HKObjectQueryNoLimit')));
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

    expect(android, contains(') 365L else 30L'));
    expect(
      android,
      contains('HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY'),
    );
    expect(
      android,
      contains('HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY'),
    );
    expect(android, contains('HISTORY_PERMISSION_SCOPE_MARKER'));
    expect(android, contains('TimeRangeFilter.between('));
    expect(android, contains('val asOf = call.argument<String>("asOf")'));
    expect(
      android.indexOf('getChangesToken(ChangesTokenRequest(classes))'),
      lessThan(android.indexOf('suspend fun <T : Record> readInitial')),
      reason:
          'The incremental boundary must be created before history is read.',
    );
    expect(android, isNot(contains('366L')));
    expect(initialRead, contains('pageToken = pageToken'));
    expect(initialRead, contains('pageToken = page.pageToken'));
    expect(initialRead, contains('while (!pageToken.isNullOrEmpty())'));
    expect(
      android,
      contains('"changesTokenExpired" to response.changesTokenExpired'),
      reason:
          'Expired Health Connect tokens must be surfaced instead of saving '
          'their unusable next token.',
    );
    expect(
      android,
      contains('record.samples.mapIndexed'),
      reason: 'Every sample in a HeartRateRecord series must be imported.',
    );
    expect(android, contains('"parentRecordId" to metadata.id'));
    expect(
      android,
      contains(r'#heartRate#${sample.time.toEpochMilli()}#$index'),
      reason: 'Heart-rate child identities must be stable across retries.',
    );
  });
}
