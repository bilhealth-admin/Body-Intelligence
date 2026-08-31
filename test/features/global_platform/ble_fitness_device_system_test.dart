import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/ble_fitness_device_platform.dart';

final class _Bridge implements BleFitnessBridge {
  @override
  Future<void> requestPermissions() async {}

  int reads = 0;
  int pairs = 0;

  @override
  Future<void> disconnect(String id) async {}

  @override
  Future<List<BlePeripheral>> discover(Duration timeout) async =>
      <BlePeripheral>[
        const BlePeripheral(
          id: 'scale',
          name: 'Scale',
          profiles: <BleFitnessProfile>{BleFitnessProfile.weightScale},
          firmwareVersion: '1.2',
          manufacturer: 'BIL',
        ),
        const BlePeripheral(
          id: 'unsupported',
          name: 'Unsupported',
          profiles: <BleFitnessProfile>{},
          firmwareVersion: '1.0',
          manufacturer: 'BIL',
        ),
      ];

  @override
  Future<void> pair(String id) async {
    pairs++;
    if (pairs == 1) {
      throw StateError('temporary_pairing_failure');
    }
  }

  @override
  Future<List<Map<String, Object?>>> readMeasurements({
    required BlePeripheral peripheral,
    required DateTime asOf,
  }) async {
    reads++;
    return <Map<String, Object?>>[
      <String, Object?>{
        'sampleId': 's1',
        'kind': 'weight',
        'value': 80,
        'unit': 'kg',
        'observedAt': asOf.add(const Duration(minutes: 1)).toIso8601String(),
        'deviceClockOffsetSeconds': 60,
        'confidence': .95,
        'calibrated': true,
      },
      <String, Object?>{
        'sampleId': 'bad',
        'kind': 'weight',
        'value': 900,
        'unit': 'kg',
        'observedAt': asOf.toIso8601String(),
      },
      <String, Object?>{
        'sampleId': 'regulated',
        'kind': 'glucose',
        'value': 100,
        'unit': 'mg/dL',
        'observedAt': asOf.toIso8601String(),
      },
      for (final kind in <String>[
        'oxygen',
        'blood_pressure_systolic',
        'blood_pressure_diastolic',
        'temperature',
        'respiratory_rate',
      ])
        <String, Object?>{
          'sampleId': 'regulated-$kind',
          'kind': kind,
          'value': 100,
          'unit': 'legacy-unit',
          'observedAt': asOf.toIso8601String(),
        },
    ];
  }
}

void main() {
  test(
    'BLE pipeline persists recovery state, validates and deduplicates packets',
    () async {
      final store = InMemoryGlobalStore();
      final provider = BleFitnessDeviceProvider(
        bridge: _Bridge(),
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      final devices = await provider.discover();
      final first = await provider.ingest(
        deviceId: devices.single.id,
        asOf: DateTime.utc(2026),
      );
      final second = await provider.ingest(
        deviceId: devices.single.id,
        asOf: DateTime.utc(2026),
      );
      expect(first.single.value, 80);
      expect(second, isEmpty);
      for (final sampleId in <String>[
        'regulated',
        'regulated-oxygen',
        'regulated-blood_pressure_systolic',
        'regulated-blood_pressure_diastolic',
        'regulated-temperature',
        'regulated-respiratory_rate',
      ]) {
        expect(
          await store.get('fitness_packet_seen', 'scale:$sampleId'),
          isNull,
        );
      }
      expect(
        (await store.get('fitness_device_registry', 'scale'))?['pairingState'],
        'ready',
      );
    },
  );
}
