import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../global_platform/medical_devices/ble_medical_device_platform.dart';
import '../../global_platform/medical_devices/native_ble_medical_bridge.dart';
import '../../global_platform/core/global_platform_core.dart';
import '../../global_platform/product/global_product_access.dart';

enum MedicalDeviceConnectionStatus {
  unavailable,
  idle,
  requestingPermission,
  scanning,
  connecting,
  connected,
  failed,
}

final class MedicalDeviceSnapshot {
  const MedicalDeviceSnapshot({
    required this.status,
    this.devices = const <BlePeripheral>[],
    this.connectedDeviceId,
    this.failureCode,
    this.measurements = const <Map<String, Object?>>[],
    this.lastMeasurementAt,
    this.batteryPercent,
  });

  final MedicalDeviceConnectionStatus status;
  final List<BlePeripheral> devices;
  final String? connectedDeviceId;
  final String? failureCode;
  final List<Map<String, Object?>> measurements;
  final DateTime? lastMeasurementAt;
  final int? batteryPercent;

  bool get supported => status != MedicalDeviceConnectionStatus.unavailable;
}

final medicalBleBridgeProvider = Provider<BleMedicalBridge>(
  (_) => MethodChannelBleMedicalBridge(),
);

final medicalDeviceProvider =
    StateNotifierProvider<MedicalDeviceController, MedicalDeviceSnapshot>((
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
      return MedicalDeviceController(
        ref.read(medicalBleBridgeProvider),
        store: store,
      );
    });

final class MedicalDeviceController
    extends StateNotifier<MedicalDeviceSnapshot> {
  MedicalDeviceController(this._bridge, {this._store})
    : super(
        MedicalDeviceSnapshot(
          status:
              !kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS)
              ? MedicalDeviceConnectionStatus.idle
              : MedicalDeviceConnectionStatus.unavailable,
        ),
      ) {
    _restoreLocalRegistry();
  }

  final BleMedicalBridge _bridge;
  final GlobalDurableStore? _store;
  final Set<String> _seenSamples = <String>{};

  Future<void> _restoreLocalRegistry() async {
    final store = _store;
    if (store == null || !state.supported) return;
    final rows = await store.list('connected_medical_devices');
    final devices = <BlePeripheral>[];
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      devices.add(
        BlePeripheral(
          id: id,
          name: row['name'] as String? ?? 'Medical device',
          firmwareVersion: row['firmwareVersion'] as String? ?? 'unknown',
          manufacturer: row['manufacturer'] as String? ?? 'unknown',
          profiles: {
            for (final name in row['profiles'] as List<Object?>? ?? const [])
              if (BleMedicalProfile.values.asNameMap().containsKey('$name'))
                BleMedicalProfile.values.byName('$name'),
          },
        ),
      );
    }
    if (devices.isNotEmpty) {
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.idle,
        devices: devices,
      );
    }
  }

  Future<void> scan() async {
    if (!state.supported) return;
    state = MedicalDeviceSnapshot(
      status: MedicalDeviceConnectionStatus.requestingPermission,
      devices: state.devices,
    );
    try {
      await _bridge.requestPermissions();
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.scanning,
        devices: state.devices,
      );
      final devices = await _bridge.discover(const Duration(seconds: 6));
      final store = _store;
      if (store != null) {
        for (final device in devices) {
          await store
              .put('connected_medical_devices', device.id, <String, Object?>{
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
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.idle,
        devices: devices,
      );
    } catch (error) {
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.failed,
        devices: state.devices,
        failureCode: error.runtimeType.toString(),
      );
    }
  }

  Future<void> connect(BlePeripheral peripheral) async {
    state = MedicalDeviceSnapshot(
      status: MedicalDeviceConnectionStatus.connecting,
      devices: state.devices,
    );
    try {
      await _bridge.pair(peripheral.id);
      final bridge = _bridge;
      final managedBridge = bridge is ManagedBleMedicalBridge ? bridge : null;
      final status = managedBridge != null
          ? await managedBridge.deviceStatus(peripheral.id)
          : const <String, Object?>{};
      final battery = status['batteryPercent'] as int?;
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.connected,
        devices: state.devices,
        connectedDeviceId: peripheral.id,
        batteryPercent: battery?.clamp(0, 100).toInt(),
      );
      await _store?.put(
        'connected_medical_device_state',
        peripheral.id,
        <String, Object?>{
          'connected': true,
          'connectedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await refreshMeasurements(peripheral);
    } catch (error) {
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.failed,
        devices: state.devices,
        failureCode: error.runtimeType.toString(),
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
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.connected,
        devices: state.devices,
        connectedDeviceId: id,
        measurements: accepted,
        lastMeasurementAt: accepted.isEmpty ? null : receivedAt,
        batteryPercent: state.batteryPercent,
      );
      await _store?.put('connected_medical_measurements', id, <String, Object?>{
        'lastMeasurementAt': accepted.isEmpty
            ? null
            : receivedAt.toIso8601String(),
        'measurements': accepted,
      });
    } catch (error) {
      state = MedicalDeviceSnapshot(
        status: MedicalDeviceConnectionStatus.connected,
        devices: state.devices,
        connectedDeviceId: id,
        measurements: state.measurements,
        lastMeasurementAt: state.lastMeasurementAt,
        batteryPercent: state.batteryPercent,
        failureCode: error.runtimeType.toString(),
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
    } else if (kind == 'temperature' && unit == 'fahrenheit') {
      numeric = (numeric - 32) * 5 / 9;
    } else if (kind == 'glucose' && unit == 'mmol/L') {
      numeric *= 18;
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
      await _store?.put('connected_medical_device_state', id, <String, Object?>{
        'connected': false,
        'disconnectedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
    state = MedicalDeviceSnapshot(
      status: MedicalDeviceConnectionStatus.idle,
      devices: state.devices,
    );
  }

  Future<void> removeDevice(String peripheralId) async {
    await _bridge.disconnect(peripheralId);
    final bridge = _bridge;
    final managedBridge = bridge is ManagedBleMedicalBridge ? bridge : null;
    await managedBridge?.forget(peripheralId);
    await _store?.remove('connected_medical_devices', peripheralId);
    await _store?.remove('connected_medical_device_state', peripheralId);
    await _store?.remove('connected_medical_measurements', peripheralId);
    _seenSamples.removeWhere((sample) => sample.startsWith('$peripheralId:'));
    state = MedicalDeviceSnapshot(
      status: MedicalDeviceConnectionStatus.idle,
      devices: state.devices
          .where((device) => device.id != peripheralId)
          .toList(growable: false),
    );
  }
}
