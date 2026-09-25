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
    ]) {
      expect(manifest, contains('android.permission.health.$permission'));
    }
    final healthPermissions = RegExp(
      r'android:name="android\.permission\.health\.([^"]+)"',
    ).allMatches(manifest).map((match) => match.group(1)).toSet();
    expect(healthPermissions, {
      'READ_STEPS',
      'READ_DISTANCE',
      'READ_ACTIVE_CALORIES_BURNED',
    });
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
      expect(ios, contains('private static let readPageLimit = 100'));
      expect(readChanges, contains('withStart: historyStart'));
      expect(readChanges, contains('anchor: anchors[name]'));
      expect(
        readChanges,
        contains(
          'limit: max(1, Self.readPageLimit - records.count - deleted.count)',
        ),
      );
      expect(
        readChanges,
        contains(
          'guard records.count + deleted.count < Self.readPageLimit else',
        ),
      );
      expect(readChanges, contains('nextAnchors[name] = newAnchor'));
      expect(readChanges, contains('"hasMore": pageHasMore'));
      expect(readChanges, contains('healthQueryQueue.async'));
      expect(readChanges, contains('func executeNext()'));
      expect(ios, contains('case "cancelReadChanges"'));
      expect(ios, contains('store.stop(query)'));
      expect(readChanges, isNot(contains('withStart: nil')));
      expect(readChanges, isNot(contains('HKObjectQueryNoLimit')));
    },
  );

  test('initial Health Connect import consumes every records page', () {
    final android = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILGlobalHealthBridge.kt',
    ).readAsStringSync();
    final initialStart = android.indexOf(
      'suspend fun <T : Record> readInitialPage',
    );
    final initialEnd = android.indexOf(
      '// Once the bounded history is complete',
      initialStart,
    );
    final initialRead = android.substring(initialStart, initialEnd);

    expect(android, contains('asOf.minusSeconds(30L * 24L * 60L * 60L)'));
    expect(android, isNot(contains('PERMISSION_READ_HEALTH_DATA_HISTORY')));
    expect(android, isNot(contains('HISTORY_PERMISSION_SCOPE_MARKER')));
    expect(android, contains('TimeRangeFilter.between('));
    expect(android, contains('val asOf = call.argument<String>("asOf")'));
    expect(
      android.indexOf('getChangesToken(ChangesTokenRequest(classes))'),
      lessThan(android.indexOf('suspend fun <T : Record> readInitialPage')),
      reason:
          'The incremental boundary must be created before history is read.',
    );
    expect(android, isNot(contains('366L')));
    expect(initialRead, contains('pageToken = pageToken'));
    expect(
      initialRead,
      contains('return page.pageToken?.trim()?.takeIf(String::isNotEmpty)'),
    );
    expect(
      initialRead,
      contains('pageToken = null'),
      reason:
          'The page cursor must reset when advancing to the next record family.',
    );
    expect(
      android,
      contains('"changesTokenExpired" to response.changesTokenExpired'),
      reason:
          'Expired Health Connect tokens must be surfaced instead of saving '
          'their unusable next token.',
    );
    expect(android, isNot(contains('HeartRateRecord')));
    expect(android, contains('"health_connect_write_not_available"'));
    expect(android, contains('.filter(supportedNames::contains)'));
    expect(android, contains('if (recordPermissions.isEmpty())'));
    expect(android, contains('if (supportedRequestedNames.isEmpty())'));
    // Status inspection needs a default scope; mutation/read requests do not.
    expect(
      android,
      contains(
        'permissionSnapshot(call.argument<List<String>>("types") ?: supportedNames)',
      ),
    );
    expect(
      android,
      contains(
        'val names = call.argument<List<String>>("types") ?: emptyList()',
      ),
    );
  });
}
