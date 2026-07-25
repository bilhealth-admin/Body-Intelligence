import '../core/global_platform_core.dart';
import '../platform/native_platform_bridges.dart';

final class MedicalDeviceIdentity {
  const MedicalDeviceIdentity({
    required this.id,
    required this.kind,
    required this.manufacturer,
    required this.calibrationState,
  });
  final String id;
  final String kind;
  final String manufacturer;
  final String calibrationState;
}

final class MedicalMeasurement {
  MedicalMeasurement({
    required this.deviceId,
    required this.kind,
    required this.value,
    required this.unit,
    required DateTime observedAt,
    required this.confidence,
    required this.calibrated,
    required this.provenance,
    required this.sampleId,
  }) : observedAt = observedAt.toUtc();
  final String deviceId, kind, unit, provenance, sampleId;
  final double value, confidence;
  final DateTime observedAt;
  final bool calibrated;
}

abstract interface class MedicalDeviceProvider {
  String get id;
  Future<List<MedicalDeviceIdentity>> discover();
  Future<List<MedicalMeasurement>> ingest({
    required String deviceId,
    required DateTime asOf,
  });
}

final class NativeMedicalDeviceProvider implements MedicalDeviceProvider {
  NativeMedicalDeviceProvider({required this.id, required this.bridge});
  @override
  final String id;
  final MethodChannelMedicalDeviceBridge bridge;
  @override
  Future<List<MedicalDeviceIdentity>> discover() async => [
    for (final row in await bridge.discover())
      MedicalDeviceIdentity(
        id: row['id']! as String,
        kind: row['kind']! as String,
        manufacturer: row['manufacturer'] as String? ?? 'unknown',
        calibrationState: row['calibrationState'] as String? ?? 'unknown',
      ),
  ];
  @override
  Future<List<MedicalMeasurement>> ingest({
    required String deviceId,
    required DateTime asOf,
  }) async => [
    for (final row in await bridge.readBatch(deviceId: deviceId, asOf: asOf))
      MedicalMeasurement(
        deviceId: deviceId,
        kind: row['kind']! as String,
        value: (row['value']! as num).toDouble(),
        unit: row['unit']! as String,
        observedAt: DateTime.parse(row['observedAt']! as String),
        confidence: (row['confidence'] as num? ?? .5).toDouble(),
        calibrated: row['calibrated'] == true,
        provenance: row['provenance'] as String? ?? id,
        sampleId: row['sampleId']! as String,
      ),
  ];
}

final class MedicalDeviceRuntime {
  MedicalDeviceRuntime({
    required this.providers,
    required this.store,
    required this.audit,
  });
  final List<MedicalDeviceProvider> providers;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;

  Future<List<MedicalMeasurement>> ingest(DateTime asOf) async {
    final out = <MedicalMeasurement>[];
    for (final provider in providers) {
      for (final device in await provider.discover()) {
        await store.put('medical_devices', device.id, <String, Object?>{
          'kind': device.kind,
          'manufacturer': device.manufacturer,
          'calibrationState': device.calibrationState,
        });
        for (final measurement in await provider.ingest(
          deviceId: device.id,
          asOf: asOf,
        )) {
          if (measurement.observedAt.isAfter(asOf.toUtc())) continue;
          if (measurement.provenance.isEmpty ||
              measurement.confidence < .4 ||
              !_possible(measurement)) {
            continue;
          }
          if (!measurement.calibrated &&
              _requiresCalibration(measurement.kind)) {
            continue;
          }
          final identity = '${provider.id}:${measurement.sampleId}';
          if (await store.get('medical_seen', identity) != null) continue;
          await store.put('medical_seen', identity, <String, Object?>{
            'sampleId': measurement.sampleId,
            'deviceId': measurement.deviceId,
            'kind': measurement.kind,
            'observedAt': measurement.observedAt.toIso8601String(),
          });
          out.add(measurement);
        }
      }
    }
    await audit.record(
      GlobalAuditEvent(
        action: 'medical.ingested',
        subjectId: 'local-user',
        at: asOf,
        metadata: <String, Object?>{'count': out.length},
      ),
    );
    return List<MedicalMeasurement>.unmodifiable(out);
  }

  bool _requiresCalibration(String kind) => <String>{
    'glucose',
    'blood_pressure_systolic',
    'blood_pressure_diastolic',
  }.contains(kind);
  bool _possible(MedicalMeasurement m) => switch (m.kind) {
    'glucose' => m.value > 10 && m.value < 700,
    'blood_pressure_systolic' => m.value > 40 && m.value < 300,
    'blood_pressure_diastolic' => m.value > 20 && m.value < 200,
    'oxygen' => m.value >= 50 && m.value <= 100,
    'temperature' => m.value >= 30 && m.value <= 45,
    _ => m.value.isFinite,
  };
}
