import 'dart:convert';

import 'package:flutter/services.dart';

import 'ble_medical_device_platform.dart';

final class MethodChannelBleMedicalBridge implements BleMedicalBridge {
  MethodChannelBleMedicalBridge({
    MethodChannel? channel,
    BleGattMeasurementParser? parser,
  }) : _channel = channel ?? const MethodChannel('bil.global/medical_ble'),
       _parser = parser ?? const BleGattMeasurementParser();

  final MethodChannel _channel;
  final BleGattMeasurementParser _parser;

  @override
  Future<List<BlePeripheral>> discover(Duration timeout) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'discover',
          <String, Object?>{'timeoutMs': timeout.inMilliseconds},
        ) ??
        const <Map<Object?, Object?>>[];
    return rows
        .map((row) {
          final profiles = <BleMedicalProfile>{};
          for (final value in (row['profiles'] as List? ?? const <Object?>[])) {
            final parsed = _profileFromNative(value.toString());
            if (parsed != null) profiles.add(parsed);
          }
          return BlePeripheral(
            id: row['id']! as String,
            name: row['name'] as String? ?? 'Medical device',
            profiles: profiles,
            firmwareVersion: row['firmwareVersion'] as String? ?? 'unknown',
            manufacturer: row['manufacturer'] as String? ?? 'unknown',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> pair(String peripheralId) => _channel.invokeMethod<void>(
    'pair',
    <String, Object?>{'peripheralId': peripheralId},
  );

  @override
  Future<void> disconnect(String peripheralId) => _channel.invokeMethod<void>(
    'disconnect',
    <String, Object?>{'peripheralId': peripheralId},
  );

  @override
  Future<List<Map<String, Object?>>> readMeasurements({
    required BlePeripheral peripheral,
    required DateTime asOf,
  }) async {
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'readMeasurements',
          <String, Object?>{
            'peripheralId': peripheral.id,
            'profiles': peripheral.profiles.map((e) => e.name).toList(),
            'asOf': asOf.toUtc().toIso8601String(),
          },
        ) ??
        const <Map<Object?, Object?>>[];
    final parsed = <Map<String, Object?>>[];
    for (final row in rows) {
      parsed.addAll(_parser.parse(Map<String, Object?>.from(row), asOf: asOf));
    }
    return List<Map<String, Object?>>.unmodifiable(parsed);
  }

  BleMedicalProfile? _profileFromNative(String value) {
    final normalized = value.toUpperCase().replaceAll('-', '');
    return switch (normalized) {
      '1810' || 'BLOODPRESSURE' => BleMedicalProfile.bloodPressure,
      '1808' || 'GLUCOSE' => BleMedicalProfile.glucose,
      '181D' || 'WEIGHTSCALE' => BleMedicalProfile.weightScale,
      '181B' || 'BODYCOMPOSITION' => BleMedicalProfile.bodyComposition,
      '1822' || 'PULSEOXIMETER' => BleMedicalProfile.pulseOximeter,
      '180D' || 'HEARTRATE' => BleMedicalProfile.heartRate,
      '1809' || 'THERMOMETER' => BleMedicalProfile.thermometer,
      _ => null,
    };
  }
}

final class BleGattMeasurementParser {
  const BleGattMeasurementParser();

  List<Map<String, Object?>> parse(
    Map<String, Object?> row, {
    required DateTime asOf,
  }) {
    final packet = row['packet'];
    if (packet is! String) return const <Map<String, Object?>>[];
    final bytes = base64Decode(packet);
    final characteristic = _shortUuid(row['characteristic'] as String? ?? '');
    final peripheralId = row['peripheralId'] as String? ?? 'unknown';
    final observedAt =
        DateTime.tryParse(row['receivedAt'] as String? ?? '')?.toUtc() ??
        asOf.toUtc();
    final samplePrefix = '$peripheralId:$characteristic:${base64Encode(bytes)}';

    return switch (characteristic) {
      '2A35' => _bloodPressure(bytes, samplePrefix, observedAt),
      '2A18' => _glucose(bytes, samplePrefix, observedAt),
      '2A9D' => _weight(bytes, samplePrefix, observedAt),
      '2A9C' => _bodyComposition(bytes, samplePrefix, observedAt),
      '2A5F' => _oxygen(bytes, samplePrefix, observedAt),
      '2A37' => _heartRate(bytes, samplePrefix, observedAt),
      '2A1C' => _temperature(bytes, samplePrefix, observedAt),
      _ => const <Map<String, Object?>>[],
    };
  }

  List<Map<String, Object?>> _bloodPressure(
    Uint8List data,
    String id,
    DateTime at,
  ) {
    if (data.length < 7) return const <Map<String, Object?>>[];
    final unit = (data[0] & 0x01) == 0 ? 'mmHg' : 'kPa';
    return <Map<String, Object?>>[
      _packet(
        '$id:s',
        'blood_pressure_systolic',
        _sfloat(data, 1),
        unit,
        at,
        confirmed: false,
      ),
      _packet(
        '$id:d',
        'blood_pressure_diastolic',
        _sfloat(data, 3),
        unit,
        at,
        confirmed: false,
      ),
    ];
  }

  List<Map<String, Object?>> _glucose(Uint8List data, String id, DateTime at) {
    if (data.length < 12) return const <Map<String, Object?>>[];
    final molar = (data[0] & 0x04) != 0;
    return <Map<String, Object?>>[
      _packet(
        id,
        'glucose',
        _sfloat(data, 10),
        molar ? 'mmol/L' : 'mg/dL',
        at,
        confirmed: false,
      ),
    ];
  }

  List<Map<String, Object?>> _weight(Uint8List data, String id, DateTime at) {
    if (data.length < 3) return const <Map<String, Object?>>[];
    final imperial = (data[0] & 0x01) != 0;
    final raw = data[1] | (data[2] << 8);
    return <Map<String, Object?>>[
      _packet(
        id,
        'weight',
        raw * (imperial ? 0.01 : 0.005),
        imperial ? 'lb' : 'kg',
        at,
      ),
    ];
  }

  List<Map<String, Object?>> _bodyComposition(
    Uint8List data,
    String id,
    DateTime at,
  ) {
    if (data.length < 4) return const <Map<String, Object?>>[];
    final raw = data[2] | (data[3] << 8);
    return <Map<String, Object?>>[_packet(id, 'body_fat', raw * 0.1, '%', at)];
  }

  List<Map<String, Object?>> _oxygen(Uint8List data, String id, DateTime at) {
    if (data.length < 3) return const <Map<String, Object?>>[];
    return <Map<String, Object?>>[
      _packet(id, 'oxygen', _sfloat(data, 1), '%', at, confirmed: false),
    ];
  }

  List<Map<String, Object?>> _heartRate(
    Uint8List data,
    String id,
    DateTime at,
  ) {
    if (data.length < 2) return const <Map<String, Object?>>[];
    final wide = (data[0] & 0x01) != 0;
    if (wide && data.length < 3) return const <Map<String, Object?>>[];
    final value = wide
        ? (data[1] | (data[2] << 8)).toDouble()
        : data[1].toDouble();
    return <Map<String, Object?>>[_packet(id, 'heart_rate', value, 'bpm', at)];
  }

  List<Map<String, Object?>> _temperature(
    Uint8List data,
    String id,
    DateTime at,
  ) {
    if (data.length < 5) return const <Map<String, Object?>>[];
    final fahrenheit = (data[0] & 0x01) != 0;
    return <Map<String, Object?>>[
      _packet(
        id,
        'temperature',
        _float32(data, 1),
        fahrenheit ? 'fahrenheit' : 'celsius',
        at,
        confirmed: false,
      ),
    ];
  }

  Map<String, Object?> _packet(
    String sampleId,
    String kind,
    double value,
    String unit,
    DateTime at, {
    bool confirmed = true,
  }) => <String, Object?>{
    'sampleId': sampleId,
    'kind': kind,
    'value': value,
    'unit': unit,
    'observedAt': at.toUtc().toIso8601String(),
    'deviceClockOffsetSeconds': 0,
    'confidence': .95,
    'calibrated': true,
    'userConfirmed': confirmed,
  };

  String _shortUuid(String value) {
    final normalized = value.toUpperCase();
    final match = RegExp(
      r'0000([0-9A-F]{4})-0000-1000-8000-00805F9B34FB',
    ).firstMatch(normalized);
    if (match != null) return match.group(1)!;
    return normalized.replaceAll('-', '').length == 4
        ? normalized.replaceAll('-', '')
        : normalized;
  }

  double _sfloat(Uint8List data, int offset) {
    if (offset + 1 >= data.length) return double.nan;
    final raw = data[offset] | (data[offset + 1] << 8);
    var mantissa = raw & 0x0FFF;
    var exponent = raw >> 12;
    if ((mantissa & 0x0800) != 0) mantissa -= 0x1000;
    if ((exponent & 0x0008) != 0) exponent -= 0x0010;
    return mantissa * _pow10(exponent);
  }

  double _float32(Uint8List data, int offset) {
    if (offset + 3 >= data.length) return double.nan;
    final raw =
        data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
    var mantissa = raw & 0x00FFFFFF;
    var exponent = (raw >> 24) & 0xFF;
    if ((mantissa & 0x00800000) != 0) mantissa -= 0x01000000;
    if ((exponent & 0x80) != 0) exponent -= 0x100;
    return mantissa * _pow10(exponent);
  }

  double _pow10(int exponent) {
    var result = 1.0;
    if (exponent >= 0) {
      for (var i = 0; i < exponent; i++) {
        result *= 10;
      }
    } else {
      for (var i = 0; i > exponent; i--) {
        result /= 10;
      }
    }
    return result;
  }
}
