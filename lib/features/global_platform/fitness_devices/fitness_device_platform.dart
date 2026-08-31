import '../core/global_platform_core.dart';
import '../platform/native_platform_bridges.dart';

const Set<String> fitnessDeviceMeasurementKinds = <String>{
  'weight',
  'body_fat',
  'heart_rate',
};

final class FitnessDeviceIdentity {
  const FitnessDeviceIdentity({
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

final class FitnessMeasurement {
  FitnessMeasurement({
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

abstract interface class FitnessDeviceProvider {
  String get id;
  Future<List<FitnessDeviceIdentity>> discover();
  Future<List<FitnessMeasurement>> ingest({
    required String deviceId,
    required DateTime asOf,
  });
}

final class NativeFitnessDeviceProvider implements FitnessDeviceProvider {
  NativeFitnessDeviceProvider({required this.id, required this.bridge});
  @override
  final String id;
  final MethodChannelFitnessDeviceBridge bridge;
  @override
  Future<List<FitnessDeviceIdentity>> discover() async => [
    for (final row in await bridge.discover())
      FitnessDeviceIdentity(
        id: row['id']! as String,
        kind: row['kind']! as String,
        manufacturer: row['manufacturer'] as String? ?? 'unknown',
        calibrationState: row['calibrationState'] as String? ?? 'unknown',
      ),
  ];
  @override
  Future<List<FitnessMeasurement>> ingest({
    required String deviceId,
    required DateTime asOf,
  }) async => [
    for (final row in await bridge.readBatch(deviceId: deviceId, asOf: asOf))
      FitnessMeasurement(
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

final class FitnessDeviceRuntime {
  FitnessDeviceRuntime({
    required this.providers,
    required this.store,
    required this.audit,
  });
  final List<FitnessDeviceProvider> providers;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;

  Future<List<FitnessMeasurement>> ingest(DateTime asOf) async {
    final out = <FitnessMeasurement>[];
    for (final provider in providers) {
      for (final device in await provider.discover()) {
        await store.put('fitness_devices', device.id, <String, Object?>{
          'kind': device.kind,
          'manufacturer': device.manufacturer,
          'calibrationState': device.calibrationState,
        });
        for (final measurement in await provider.ingest(
          deviceId: device.id,
          asOf: asOf,
        )) {
          if (!fitnessDeviceMeasurementKinds.contains(measurement.kind)) {
            continue;
          }
          if (measurement.observedAt.isAfter(asOf.toUtc())) continue;
          if (measurement.provenance.isEmpty ||
              measurement.confidence < .4 ||
              !_possible(measurement)) {
            continue;
          }
          final identity = '${provider.id}:${measurement.sampleId}';
          if (await store.get('fitness_seen', identity) != null) continue;
          await store.put('fitness_seen', identity, <String, Object?>{
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
        action: 'fitness.ingested',
        subjectId: 'local-user',
        at: asOf,
        metadata: <String, Object?>{'count': out.length},
      ),
    );
    return List<FitnessMeasurement>.unmodifiable(out);
  }

  bool _possible(FitnessMeasurement m) => switch (m.kind) {
    'weight' => m.value >= 2 && m.value <= 500,
    'body_fat' => m.value >= 1 && m.value <= 75,
    'heart_rate' => m.value >= 20 && m.value <= 260,
    _ => false,
  };
}
