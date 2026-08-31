import 'dart:convert';
import 'dart:typed_data';

import 'package:body_intelligence_log/features/global_platform/fitness_devices/native_ble_fitness_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = BleGattMeasurementParser();
  final now = DateTime.utc(2026, 7, 24);

  test('parses heart-rate and weight Bluetooth SIG characteristics', () {
    final heart = parser.parse(<String, Object?>{
      'peripheralId': 'p1',
      'characteristic': '00002A37-0000-1000-8000-00805F9B34FB',
      'packet': base64Encode(Uint8List.fromList(<int>[0, 72])),
      'receivedAt': now.toIso8601String(),
    }, asOf: now);
    expect(heart.single['kind'], 'heart_rate');
    expect(heart.single['value'], 72);

    final weight = parser.parse(<String, Object?>{
      'peripheralId': 'p1',
      'characteristic': '2A9D',
      'packet': base64Encode(Uint8List.fromList(<int>[0, 32, 78])),
      'receivedAt': now.toIso8601String(),
    }, asOf: now);
    expect(weight.single['kind'], 'weight');
    expect(weight.single['value'], closeTo(100, .001));
  });

  test('unknown characteristics abstain safely', () {
    expect(
      parser.parse(<String, Object?>{
        'peripheralId': 'p1',
        'characteristic': 'FFFF',
        'packet': base64Encode(Uint8List(0)),
        'receivedAt': now.toIso8601String(),
      }, asOf: now),
      isEmpty,
    );
  });
}
