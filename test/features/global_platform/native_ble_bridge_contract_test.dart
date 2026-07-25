import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native BLE hosts register channel and standard profiles', () {
    final swift = File(
      'ios/Runner/BILMedicalBleBridge.swift',
    ).readAsStringSync();
    final kotlin = File(
      'android/app/src/main/kotlin/com/example/body_intelligence_log/BILMedicalBleBridge.kt',
    ).readAsStringSync();
    for (final token in [
      '1810',
      '1808',
      '181D',
      '181B',
      '1822',
      '180D',
      '1809',
    ]) {
      expect(swift, contains(token));
      expect(kotlin, contains(token));
    }
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('BILMedicalBleBridge.register'),
    );
    expect(
      File(
        'android/app/src/main/kotlin/com/example/body_intelligence_log/MainActivity.kt',
      ).readAsStringSync(),
      contains('BILMedicalBleBridge'),
    );
  });
}
