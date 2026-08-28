import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS bridge files are compiled by Runner and Bluetooth use is declared',
    () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(project, contains('BILGlobalHealthBridge.swift in Sources'));
      expect(project, contains('BILMedicalBleBridge.swift in Sources'));
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('NSBluetoothAlwaysUsageDescription'));
    },
  );

  test('iOS Bluetooth bridge scans fitness GATT services only', () {
    final source = File(
      'ios/Runner/BILMedicalBleBridge.swift',
    ).readAsStringSync();
    final serviceList = RegExp(
      r'private var supportedServices:\s*\[CBUUID\]\s*\{\s*\[(.*?)\]\.map',
      dotAll: true,
    ).firstMatch(source)?.group(1);

    expect(serviceList, isNotNull);
    final serviceUuids = RegExp(
      r'"([0-9A-Fa-f]{4})"',
    ).allMatches(serviceList!).map((match) => match.group(1)!.toUpperCase());
    expect(
      serviceUuids,
      unorderedEquals(<String>['181D', '181B', '180D']),
    );

    expect(source, contains('"Fitness device"'));
    expect(source, isNot(contains('"Medical device"')));
  });

  test('Android Bluetooth and internet permissions are declared', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final permission in <String>[
      'android.permission.INTERNET',
      'android.permission.BLUETOOTH_SCAN',
      'android.permission.BLUETOOTH_CONNECT',
    ]) {
      expect(manifest, contains(permission));
    }
  });

  test('native host opens a persistent production database', () {
    final source = File(
      'lib/features/global_platform/runtime/global_product_composition_root.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('SqliteGlobalPlatformStore.memory()')));
    expect(source, contains('getApplicationSupportDirectory'));
    expect(source, contains('bil_global_platform.sqlite3'));
  });
}
