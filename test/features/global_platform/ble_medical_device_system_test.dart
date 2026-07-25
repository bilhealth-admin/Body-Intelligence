import 'package:flutter_test/flutter_test.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/medical_devices/ble_medical_device_platform.dart';

final class _Bridge implements BleMedicalBridge {
  int reads = 0;
  int pairs = 0;

  @override
  Future<void> disconnect(String id) async {}

  @override
  Future<List<BlePeripheral>> discover(Duration timeout) async =>
      <BlePeripheral>[
        const BlePeripheral(
          id: 'bp',
          name: 'BP',
          profiles: <BleMedicalProfile>{BleMedicalProfile.bloodPressure},
          firmwareVersion: '1.2',
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
        'kind': 'blood_pressure_systolic',
        'value': 120,
        'unit': 'mmHg',
        'observedAt': asOf.add(const Duration(minutes: 1)).toIso8601String(),
        'deviceClockOffsetSeconds': 60,
        'confidence': .95,
        'calibrated': true,
        'userConfirmed': true,
      },
      <String, Object?>{
        'sampleId': 'bad',
        'kind': 'blood_pressure_systolic',
        'value': 900,
        'unit': 'mmHg',
        'observedAt': asOf.toIso8601String(),
        'userConfirmed': true,
      },
    ];
  }
}

void main() {
  test(
    'BLE pipeline persists recovery state, validates and deduplicates packets',
    () async {
      final store = InMemoryGlobalStore();
      final provider = BleMedicalDeviceProvider(
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
      expect(first.single.value, 120);
      expect(second, isEmpty);
      expect(
        (await store.get('medical_device_registry', 'bp'))?['pairingState'],
        'ready',
      );
    },
  );
}
