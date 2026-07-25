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
