import '../core/global_platform_core.dart';
import 'medical_device_platform.dart';

enum BleMedicalProfile {
  weightScale,
  bodyComposition,
  heartRate,
}

const Set<BleMedicalProfile> bleFitnessProfiles = <BleMedicalProfile>{
  BleMedicalProfile.weightScale,
  BleMedicalProfile.bodyComposition,
  BleMedicalProfile.heartRate,
};

const Set<String> bleFitnessMeasurementKinds = fitnessDeviceMeasurementKinds;

Set<String> _kindsFor(Set<BleMedicalProfile> profiles) => <String>{
  if (profiles.contains(BleMedicalProfile.weightScale)) 'weight',
  if (profiles.contains(BleMedicalProfile.bodyComposition)) 'body_fat',
  if (profiles.contains(BleMedicalProfile.heartRate)) 'heart_rate',
};

final class BlePeripheral {
  const BlePeripheral({
    required this.id,
    required this.name,
    required this.profiles,
    required this.firmwareVersion,
    required this.manufacturer,
  });

  final String id;
  final String name;
  final String firmwareVersion;
  final String manufacturer;
  final Set<BleMedicalProfile> profiles;
}

abstract interface class BleMedicalBridge {
  Future<void> requestPermissions();
  Future<List<BlePeripheral>> discover(Duration timeout);
  Future<void> pair(String peripheralId);
  Future<void> disconnect(String peripheralId);
  Future<List<Map<String, Object?>>> readMeasurements({
    required BlePeripheral peripheral,
    required DateTime asOf,
  });
}

/// Optional lifecycle operations. Implementations must report unknown battery
/// state as null and must not fabricate an unpair result.
abstract interface class ManagedBleMedicalBridge implements BleMedicalBridge {
  Future<Map<String, Object?>> deviceStatus(String peripheralId);
  Future<void> forget(String peripheralId);
}

final class BleMeasurementPolicy {
  const BleMeasurementPolicy({
    required this.canonicalUnit,
    required this.minimum,
    required this.maximum,
    required this.requiresConfirmation,
  });

  final String canonicalUnit;
  final double minimum;
  final double maximum;
  final bool requiresConfirmation;

  static const Map<String, BleMeasurementPolicy> supported =
      <String, BleMeasurementPolicy>{
        'weight': BleMeasurementPolicy(
          canonicalUnit: 'kg',
          minimum: 2,
          maximum: 500,
          requiresConfirmation: false,
        ),
        'body_fat': BleMeasurementPolicy(
          canonicalUnit: '%',
          minimum: 1,
          maximum: 75,
          requiresConfirmation: false,
        ),
        'heart_rate': BleMeasurementPolicy(
          canonicalUnit: 'bpm',
          minimum: 20,
          maximum: 260,
          requiresConfirmation: false,
        ),
      };
}

final class BleMedicalDeviceProvider implements MedicalDeviceProvider {
  BleMedicalDeviceProvider({
    required this.bridge,
    required this.store,
    required this.audit,
    this.maxReconnectAttempts = 3,
  });

  final BleMedicalBridge bridge;
  final GlobalDurableStore store;
  final GlobalAuditSink audit;
  final int maxReconnectAttempts;
  final Map<String, BlePeripheral> _discovered = <String, BlePeripheral>{};

  @override
  String get id => 'ble-medical';

  @override
  Future<List<MedicalDeviceIdentity>> discover() async {
    final devices = <BlePeripheral>[
      for (final device in await bridge.discover(const Duration(seconds: 12)))
        if (device.profiles.intersection(bleFitnessProfiles).isNotEmpty)
          BlePeripheral(
            id: device.id,
            name: device.name,
            profiles: device.profiles.intersection(bleFitnessProfiles),
            firmwareVersion: device.firmwareVersion,
            manufacturer: device.manufacturer,
          ),
    ];
    for (final device in devices) {
      _discovered[device.id] = device;
      await store.put('medical_device_registry', device.id, <String, Object?>{
        'name': device.name,
        'manufacturer': device.manufacturer,
        'firmwareVersion': device.firmwareVersion,
        'profiles': device.profiles.map((e) => e.name).toList()..sort(),
        'pairingState': 'discovered',
        'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    return <MedicalDeviceIdentity>[
      for (final device in devices)
        MedicalDeviceIdentity(
          id: device.id,
          kind: device.profiles.map((e) => e.name).join(','),
          manufacturer: device.manufacturer,
          calibrationState: 'provider-reported',
        ),
    ];
  }

  @override
  Future<List<MedicalMeasurement>> ingest({
    required String deviceId,
    required DateTime asOf,
  }) async {
    final peripheral = _discovered[deviceId];
    if (peripheral == null) {
      throw StateError('unknown_ble_device');
    }
    if (peripheral.profiles.intersection(bleFitnessProfiles).isEmpty) {
      throw StateError('unsupported_fitness_device');
    }

    Object? lastError;
    for (var attempt = 1; attempt <= maxReconnectAttempts; attempt++) {
      try {
        await bridge.pair(deviceId);
        await _updateDeviceState(peripheral, 'paired', asOf, attempt: attempt);
        final packets = await bridge.readMeasurements(
          peripheral: peripheral,
          asOf: asOf,
        );
        final output = <MedicalMeasurement>[];
        for (final packet in packets) {
          final sampleId = packet['sampleId'] as String;
          final dedupKey = '$deviceId:$sampleId';
          if (await store.get('medical_packet_seen', dedupKey) != null) {
            continue;
          }
          final kind = packet['kind'] as String;
          final policy = BleMeasurementPolicy.supported[kind];
          if (policy == null ||
              !_kindsFor(peripheral.profiles).contains(kind)) {
            await _auditRejected(
              deviceId,
              sampleId,
              kind,
              'unsupported_kind',
              asOf,
            );
            continue;
          }
          final normalized = _normalize(
            (packet['value'] as num).toDouble(),
            packet['unit'] as String,
            policy.canonicalUnit,
          );
          if (normalized < policy.minimum || normalized > policy.maximum) {
            await _auditRejected(
              deviceId,
              sampleId,
              kind,
              'impossible_value',
              asOf,
            );
            continue;
          }
          if (policy.requiresConfirmation && packet['userConfirmed'] != true) {
            await _auditRejected(
              deviceId,
              sampleId,
              kind,
              'confirmation_required',
              asOf,
            );
            continue;
          }

          final observed = DateTime.parse(
            packet['observedAt'] as String,
          ).toUtc();
          final corrected = _correctClock(
            observed,
            asOf.toUtc(),
            (packet['deviceClockOffsetSeconds'] as num? ?? 0).toInt(),
          );
          await store.put('medical_packet_seen', dedupKey, <String, Object?>{
            'receivedAt': asOf.toUtc().toIso8601String(),
            'firmware': peripheral.firmwareVersion,
            'kind': kind,
            'checksum': '$kind:$normalized:${corrected.toIso8601String()}',
          });
          output.add(
            MedicalMeasurement(
              deviceId: deviceId,
              kind: kind,
              value: normalized,
              unit: policy.canonicalUnit,
              observedAt: corrected,
              confidence: (packet['confidence'] as num? ?? .9).toDouble(),
              calibrated: packet['calibrated'] == true,
              provenance:
                  'ble:${peripheral.manufacturer}:${peripheral.firmwareVersion}:$sampleId',
              sampleId: sampleId,
            ),
          );
        }
        await _updateDeviceState(peripheral, 'ready', asOf, attempt: attempt);
        await audit.record(
          GlobalAuditEvent(
            action: 'medical.ble.batch',
            subjectId: deviceId,
            at: asOf,
            metadata: <String, Object?>{
              'records': output.length,
              'attempt': attempt,
            },
          ),
        );
        return output;
      } catch (error) {
        lastError = error;
        await _updateDeviceState(
          peripheral,
          'recovering',
          asOf,
          attempt: attempt,
          error: error.runtimeType.toString(),
        );
        if (attempt < maxReconnectAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 40 * attempt));
        }
      } finally {
        await bridge.disconnect(deviceId);
      }
    }
    await _updateDeviceState(
      peripheral,
      'failed',
      asOf,
      error: lastError.runtimeType.toString(),
    );
    throw StateError('ble_ingestion_failed:${lastError.runtimeType}');
  }

  Future<void> _updateDeviceState(
    BlePeripheral peripheral,
    String state,
    DateTime at, {
    int? attempt,
    String? error,
  }) async {
    final current =
        await store.get('medical_device_registry', peripheral.id) ??
        <String, Object?>{};
    await store.put('medical_device_registry', peripheral.id, <String, Object?>{
      ...current,
      'pairingState': state,
      'updatedAt': at.toUtc().toIso8601String(),
      'attempt': ?attempt,
      'error': ?error,
    });
  }

  Future<void> _auditRejected(
    String deviceId,
    String sampleId,
    String kind,
    String reason,
    DateTime at,
  ) => audit.record(
    GlobalAuditEvent(
      action: 'medical.measurement.rejected',
      subjectId: deviceId,
      at: at,
      metadata: <String, Object?>{
        'sampleId': sampleId,
        'kind': kind,
        'reason': reason,
      },
    ),
  );

  double _normalize(double value, String unit, String canonicalUnit) {
    if (unit == canonicalUnit) {
      return value;
    }
    if (unit == 'lb' && canonicalUnit == 'kg') {
      return value * 0.45359237;
    }
    throw StateError('unsupported_medical_unit:$unit:$canonicalUnit');
  }

  DateTime _correctClock(DateTime observed, DateTime asOf, int offsetSeconds) {
    final corrected = observed.subtract(Duration(seconds: offsetSeconds));
    return corrected.isAfter(asOf) ? asOf : corrected;
  }
}
