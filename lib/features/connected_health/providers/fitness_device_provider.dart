import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../global_platform/fitness_devices/ble_fitness_device_platform.dart';
import '../../global_platform/fitness_devices/native_ble_fitness_bridge.dart';
import '../../global_platform/core/global_platform_core.dart';
import '../../global_platform/product/global_product_access.dart';

enum FitnessDeviceConnectionStatus {
  unavailable,
  idle,
  requestingPermission,
  scanning,
  connecting,
  connected,
  failed,
}

final class FitnessDeviceSnapshot {
  const FitnessDeviceSnapshot({
    required this.status,
    this.devices = const <BlePeripheral>[],
    this.connectedDeviceId,
    this.failureCode,
    this.measurements = const <Map<String, Object?>>[],
    this.lastMeasurementAt,
    this.batteryPercent,
  });

  final FitnessDeviceConnectionStatus status;
  final List<BlePeripheral> devices;
  final String? connectedDeviceId;
  final String? failureCode;
  final List<Map<String, Object?>> measurements;
  final DateTime? lastMeasurementAt;
  final int? batteryPercent;

  bool get supported => status != FitnessDeviceConnectionStatus.unavailable;
}

final fitnessBleBridgeProvider = Provider<BleFitnessBridge>(
  (_) => MethodChannelBleFitnessBridge(),
);

final fitnessDeviceProvider =
    StateNotifierProvider<FitnessDeviceController, FitnessDeviceSnapshot>((
      ref,
    ) {
      GlobalDurableStore? store;
      try {
        store = ref.read(globalProductFlowsProvider).store;
      } on Object {
        // Widget tests and unsupported platform shells may intentionally run
        // without the global product runtime. BLE remains honest and usable;
        // only durable restoration is unavailable in that boundary.
      }
      return FitnessDeviceController(
        ref.read(fitnessBleBridgeProvider),
        store: store,
      );
    });

final class FitnessDeviceController
    extends StateNotifier<FitnessDeviceSnapshot> {
  FitnessDeviceController(this._bridge, {this._store})
    : super(
        FitnessDeviceSnapshot(
          status:
              !kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS)
              ? FitnessDeviceConnectionStatus.idle
              : FitnessDeviceConnectionStatus.unavailable,
        ),
      ) {
    _restoreLocalRegistry();
  }

  final BleFitnessBridge _bridge;
  final GlobalDurableStore? _store;
  final Set<String> _seenSamples = <String>{};

  Future<void> _restoreLocalRegistry() async {
    final store = _store;
    if (store == null || !state.supported) return;
    final rows = await store.list('connected_fitness_devices');
    final devices = <BlePeripheral>[];
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final profiles = <BleFitnessProfile>{
        for (final name in row['profiles'] as List<Object?>? ?? const [])
          if (BleFitnessProfile.values.asNameMap().containsKey('$name'))
            BleFitnessProfile.values.byName('$name'),
      }.intersection(bleFitnessProfiles);
      if (profiles.isEmpty) continue;
      devices.add(
        BlePeripheral(
          id: id,
          name: row['name'] as String? ?? 'Fitness device',
          firmwareVersion: row['firmwareVersion'] as String? ?? 'unknown',
          manufacturer: row['manufacturer'] as String? ?? 'unknown',
          profiles: profiles,
        ),
      );
    }
    if (devices.isNotEmpty) {
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.idle,
        devices: devices,
      );
    }
  }

  Future<void> scan() async {
    if (!state.supported) return;
    state = FitnessDeviceSnapshot(
      status: FitnessDeviceConnectionStatus.requestingPermission,
      devices: state.devices,
    );
    try {
      await _bridge.requestPermissions();
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.scanning,
        devices: state.devices,
      );
      final devices = <BlePeripheral>[
        for (final device in await _bridge.discover(const Duration(seconds: 6)))
          if (device.profiles.intersection(bleFitnessProfiles).isNotEmpty)
            BlePeripheral(
              id: device.id,
              name: device.name,
              profiles: device.profiles.intersection(bleFitnessProfiles),
              firmwareVersion: device.firmwareVersion,
              manufacturer: device.manufacturer,
            ),
      ];
      final store = _store;
      if (store != null) {
        for (final device in devices) {
          await store
              .put('connected_fitness_devices', device.id, <String, Object?>{
                'id': device.id,
                'name': device.name,
                'firmwareVersion': device.firmwareVersion,
                'manufacturer': device.manufacturer,
                'profiles': device.profiles
                    .map((profile) => profile.name)
                    .toList(),
                'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
              });
        }
      }
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.idle,
        devices: devices,
      );
    } catch (error) {
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.failed,
        devices: state.devices,
        failureCode: _bleFailureCode(error),
      );
    }
  }

  Future<void> connect(BlePeripheral peripheral) async {
    final profiles = peripheral.profiles.intersection(bleFitnessProfiles);
    if (profiles.isEmpty) {
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.failed,
        devices: state.devices,
        failureCode: 'unsupported_fitness_device',
      );
      return;
    }
    final fitnessPeripheral = BlePeripheral(
      id: peripheral.id,
      name: peripheral.name,
      profiles: profiles,
      firmwareVersion: peripheral.firmwareVersion,
      manufacturer: peripheral.manufacturer,
    );
    state = FitnessDeviceSnapshot(
      status: FitnessDeviceConnectionStatus.connecting,
      devices: state.devices,
    );
    try {
      await _bridge.pair(peripheral.id);
      final bridge = _bridge;
      final managedBridge = bridge is ManagedBleFitnessBridge ? bridge : null;
      final status = managedBridge != null
          ? await managedBridge.deviceStatus(peripheral.id)
          : const <String, Object?>{};
      if (managedBridge != null && status['connected'] != true) {
        throw StateError('ble_connection_not_verified');
      }
      final battery = status['batteryPercent'] as int?;
      final receivedAt = DateTime.now().toUtc();
      final packets = await _bridge.readMeasurements(
        peripheral: fitnessPeripheral,
        asOf: receivedAt,
      );
      final accepted = packets
          .map((packet) => _normalizeDisplayPacket(packet, receivedAt))
          .whereType<Map<String, Object?>>()
          .toList(growable: false);
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.connected,
        devices: state.devices,
        connectedDeviceId: peripheral.id,
        measurements: accepted,
        lastMeasurementAt: accepted.isEmpty ? null : receivedAt,
        batteryPercent: battery?.clamp(0, 100).toInt(),
      );
      await _store?.put(
        'connected_fitness_device_state',
        peripheral.id,
        <String, Object?>{
          'connected': true,
          'connectedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _store?.put(
        'connected_fitness_measurements',
        peripheral.id,
        <String, Object?>{
          'lastMeasurementAt': accepted.isEmpty
              ? null
              : receivedAt.toIso8601String(),
          'measurements': accepted,
        },
      );
    } catch (error) {
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.failed,
        devices: state.devices,
        failureCode: _bleFailureCode(error),
      );
    }
  }

  Future<void> refreshMeasurements([BlePeripheral? peripheral]) async {
    final id = state.connectedDeviceId;
    var device = peripheral;
    if (device == null) {
      for (final candidate in state.devices) {
        if (candidate.id == id) {
          device = candidate;
          break;
        }
      }
    }
    if (id == null || device == null) return;
    try {
      final receivedAt = DateTime.now().toUtc();
      final packets = await _bridge.readMeasurements(
        peripheral: device,
        asOf: receivedAt,
      );
      final accepted = packets
          .map((packet) => _normalizeDisplayPacket(packet, receivedAt))
          .whereType<Map<String, Object?>>()
          .toList(growable: false);
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.connected,
        devices: state.devices,
        connectedDeviceId: id,
        measurements: accepted,
        lastMeasurementAt: accepted.isEmpty ? null : receivedAt,
        batteryPercent: state.batteryPercent,
      );
      await _store?.put('connected_fitness_measurements', id, <String, Object?>{
        'lastMeasurementAt': accepted.isEmpty
            ? null
            : receivedAt.toIso8601String(),
        'measurements': accepted,
      });
    } catch (error) {
      state = FitnessDeviceSnapshot(
        status: FitnessDeviceConnectionStatus.connected,
        devices: state.devices,
        connectedDeviceId: id,
        measurements: state.measurements,
        lastMeasurementAt: state.lastMeasurementAt,
        batteryPercent: state.batteryPercent,
        failureCode: _bleFailureCode(error),
      );
    }
  }

  Map<String, Object?>? _normalizeDisplayPacket(
    Map<String, Object?> packet,
    DateTime receivedAt,
  ) {
    final kind = packet['kind'] as String?;
    final value = packet['value'];
    final unit = packet['unit'] as String?;
    final sampleId = packet['sampleId'] as String?;
    final observedAt = DateTime.tryParse(packet['observedAt'] as String? ?? '');
    if (kind == null || value is! num || unit == null || sampleId == null) {
      return null;
    }
    final policy = BleMeasurementPolicy.supported[kind];
    if (policy == null ||
        observedAt == null ||
        _seenSamples.contains(sampleId)) {
      return null;
    }
    if (observedAt.toUtc().isAfter(
          receivedAt.add(const Duration(minutes: 5)),
        ) ||
        observedAt.toUtc().isBefore(
          receivedAt.subtract(const Duration(days: 7)),
        )) {
      return null;
    }
    var numeric = value.toDouble();
    if (kind == 'weight' && unit == 'lb') {
      numeric /= 2.2046226218;
    } else if (unit != policy.canonicalUnit) {
      return null;
    }
    if (!numeric.isFinite ||
        numeric < policy.minimum ||
        numeric > policy.maximum) {
      return null;
    }
    _seenSamples.add(sampleId);
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      ...packet,
      'value': numeric,
      'unit': policy.canonicalUnit,
      'observedAt': observedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> disconnect() async {
    final id = state.connectedDeviceId;
    if (id != null) await _bridge.disconnect(id);
    if (id != null) {
      await _store?.put('connected_fitness_device_state', id, <String, Object?>{
        'connected': false,
        'disconnectedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    state = FitnessDeviceSnapshot(
      status: FitnessDeviceConnectionStatus.idle,
      devices: state.devices,
    );
  }

  Future<void> removeDevice(String peripheralId) async {
    await _bridge.disconnect(peripheralId);
    final bridge = _bridge;
    final managedBridge = bridge is ManagedBleFitnessBridge ? bridge : null;
    await managedBridge?.forget(peripheralId);
    await _store?.remove('connected_fitness_devices', peripheralId);
    await _store?.remove('connected_fitness_device_state', peripheralId);
    await _store?.remove('connected_fitness_measurements', peripheralId);
    _seenSamples.removeWhere((sample) => sample.startsWith('$peripheralId:'));
    state = FitnessDeviceSnapshot(
      status: FitnessDeviceConnectionStatus.idle,
      devices: state.devices
          .where((device) => device.id != peripheralId)
          .toList(growable: false),
    );
  }
}

String _bleFailureCode(Object error) => switch (error) {
  PlatformException(code: final code) => code,
  StateError(message: final message) => message,
  _ => error.runtimeType.toString(),
};
