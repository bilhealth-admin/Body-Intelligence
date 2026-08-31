import 'dart:convert';

import 'package:flutter/services.dart';

import 'ble_fitness_device_platform.dart';

final class MethodChannelBleFitnessBridge implements ManagedBleFitnessBridge {
  MethodChannelBleFitnessBridge({
    MethodChannel? channel,
    BleGattMeasurementParser? parser,
  }) : _channel = channel ?? const MethodChannel('bil.global/fitness_ble'),
       _parser = parser ?? const BleGattMeasurementParser();

  final MethodChannel _channel;
  final BleGattMeasurementParser _parser;

  @override
  Future<void> requestPermissions() =>
      _channel.invokeMethod<void>('requestPermissions');

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
          final profiles = <BleFitnessProfile>{};
          for (final value in (row['profiles'] as List? ?? const <Object?>[])) {
            final parsed = _profileFromNative(value.toString());
            if (parsed != null) profiles.add(parsed);
          }
          final peripheral = BlePeripheral(
            id: row['id']! as String,
            name: row['name'] as String? ?? 'Fitness device',
            profiles: profiles,
            firmwareVersion: row['firmwareVersion'] as String? ?? 'unknown',
            manufacturer: row['manufacturer'] as String? ?? 'unknown',
          );
          return peripheral;
        })
        .where(
          (peripheral) =>
              peripheral.profiles.intersection(bleFitnessProfiles).isNotEmpty,
        )
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
  Future<Map<String, Object?>> deviceStatus(String peripheralId) async =>
      Map<String, Object?>.from(
        await _channel.invokeMapMethod<String, Object?>(
              'deviceStatus',
              <String, Object?>{'peripheralId': peripheralId},
            ) ??
            const <String, Object?>{},
      );

  @override
  Future<void> forget(String peripheralId) => _channel.invokeMethod<void>(
    'forget',
    <String, Object?>{'peripheralId': peripheralId},
  );

  @override
  Future<List<Map<String, Object?>>> readMeasurements({
    required BlePeripheral peripheral,
    required DateTime asOf,
  }) async {
    final profiles = peripheral.profiles.intersection(bleFitnessProfiles);
    if (profiles.isEmpty) return const <Map<String, Object?>>[];
    final rows =
        await _channel.invokeListMethod<Map<Object?, Object?>>(
          'readMeasurements',
          <String, Object?>{
            'peripheralId': peripheral.id,
            'profiles': profiles.map((e) => e.name).toList(),
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

  BleFitnessProfile? _profileFromNative(String value) {
    final normalized = value.toUpperCase().replaceAll('-', '');
    return switch (normalized) {
      '181D' || 'WEIGHTSCALE' => BleFitnessProfile.weightScale,
      '181B' || 'BODYCOMPOSITION' => BleFitnessProfile.bodyComposition,
      '180D' || 'HEARTRATE' => BleFitnessProfile.heartRate,
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
      '2A9D' => _weight(bytes, samplePrefix, observedAt),
      '2A9C' => _bodyComposition(bytes, samplePrefix, observedAt),
      '2A37' => _heartRate(bytes, samplePrefix, observedAt),
      _ => const <Map<String, Object?>>[],
    };
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
}
