import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native BLE release exposes approved fitness profiles only', () {
    final swift = File(
      'ios/Runner/BILMedicalBleBridge.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/BILMedicalBleBridge.kt',
    ).readAsStringSync();
    for (final token in ['181D', '181B', '180D']) {
      expect(swift, contains(token));
      expect(kotlin, contains(token));
    }
    final dart = File(
      'lib/features/global_platform/medical_devices/native_ble_medical_bridge.dart',
    ).readAsStringSync();
    for (final characteristic in ['2A9D', '2A9C', '2A37']) {
      expect(dart, contains(characteristic));
    }
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('BILMedicalBleBridge.register'),
    );
    expect(
      File(
        'android/app/src/main/kotlin/com/bilhealth/bodyintelligencelog/MainActivity.kt',
      ).readAsStringSync(),
      contains('BILMedicalBleBridge'),
    );
  });
}
