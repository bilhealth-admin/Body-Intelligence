import 'package:body_intelligence_log/features/connected_health/device_compatibility.dart';
import 'package:body_intelligence_log/features/connected_health/providers/fitness_device_provider.dart';
import 'package:body_intelligence_log/features/global_platform/core/global_platform_core.dart';
import 'package:body_intelligence_log/features/global_platform/health_data/unified_health_data_integration.dart';
import 'package:body_intelligence_log/features/global_platform/fitness_devices/ble_fitness_device_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ManagedBridge implements ManagedBleFitnessBridge {
  bool connected = true;
  bool forgotten = false;
  bool disconnected = false;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<List<BlePeripheral>> discover(Duration timeout) async => const [
    BlePeripheral(
      id: 'scale-1',
      name: 'Verified scale',
      profiles: {BleFitnessProfile.weightScale},
      firmwareVersion: '1.0',
      manufacturer: 'Test manufacturer',
    ),
    BlePeripheral(
      id: 'unsupported-1',
      name: 'Unsupported regulated profile',
      profiles: {},
      firmwareVersion: '1.0',
      manufacturer: 'Test manufacturer',
    ),
  ];

  @override
  Future<void> pair(String peripheralId) async {}

  @override
  Future<void> disconnect(String peripheralId) async {
    disconnected = true;
  }

  @override
  Future<Map<String, Object?>> deviceStatus(String peripheralId) async => {
    'connected': connected,
    'batteryPercent': 74,
    'batteryVerified': true,
  };

  @override
  Future<void> forget(String peripheralId) async {
    forgotten = true;
  }

  @override
  Future<List<Map<String, Object?>>> readMeasurements({
    required BlePeripheral peripheral,
    required DateTime asOf,
  }) async => [
    {
      'sampleId': '${peripheral.id}:valid',
      'kind': 'weight',
      'value': 220.46226218,
      'unit': 'lb',
      'observedAt': asOf.subtract(const Duration(minutes: 1)).toIso8601String(),
    },
    {
      'sampleId': '${peripheral.id}:stale',
      'kind': 'weight',
      'value': 80,
      'unit': 'kg',
      'observedAt': asOf.subtract(const Duration(days: 8)).toIso8601String(),
    },
    {
      'sampleId': '${peripheral.id}:bad-unit',
      'kind': 'weight',
      'value': 80,
      'unit': 'stone',
      'observedAt': asOf.toIso8601String(),
    },
    {
      'sampleId': '${peripheral.id}:regulated',
      'kind': 'oxygen',
      'value': 98,
      'unit': '%',
      'observedAt': asOf.toIso8601String(),
    },
  ];
}

final class _HealthBridge implements NativeHealthBridge {
  @override
  String get id => 'health-test';

  @override
  Future<void> delete(List<String> recordIds) async {}

  @override
  Future<Map<String, bool>> permissions() async => const {};

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => const NativeHealthPage(
    records: [],
    deletedIds: [],
    nextAnchor: null,
    hasMore: false,
  );

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}
}

final class _CapabilityBridge
    implements NativeHealthBridge, NativeHealthCapabilityBridge {
  _CapabilityBridge({required this.available});

  bool available;
  double value = 80;
  int backgroundRequests = 0;

  @override
  String get id => 'capability-health';

  @override
  Future<Map<String, Object?>> availability() async => {
    'available': available,
    'platform': 'test',
  };

  @override
  Future<void> enableBackgroundDelivery(Set<String> types) async {
    backgroundRequests++;
  }

  @override
  Future<Map<String, Object?>> revokeAccess() async => {'revoked': true};

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> delete(List<String> recordIds) async {}

  @override
  Future<Map<String, bool>> permissions() async => {'weight': true};

  @override
  Future<void> request(Set<String> types, {required bool write}) async {}

  @override
  Future<NativeHealthPage> readChanges({
    required String? anchor,
    required DateTime asOf,
    required Set<String> types,
  }) async => NativeHealthPage(
    records: [
      NativeHealthRecord(
        id: 'weight-1',
        type: HealthDataType.weight,
        value: value,
        unit: 'kg',
        observedAt: asOf.subtract(const Duration(minutes: 1)),
        sourceId: 'scale',
        deviceId: 'scale-1',
        confidence: .95,
        providerId: id,
        timeZoneId: 'Africa/Cairo',
      ),
    ],
    deletedIds: const [],
    nextAnchor: 'anchor',
    hasMore: false,
  );

  @override
  Future<void> write(List<GlobalHealthSignal> signals) async {}
}

GlobalHealthSignal _signal({
  required String provider,
  required double confidence,
  required DateTime at,
}) => GlobalHealthSignal(
  key: 'weight',
  canonicalValue: 80,
  canonicalUnit: 'kg',
  provenance: GlobalProvenance(
    providerId: provider,
    sourceId: provider,
    recordId: '$provider-${at.microsecondsSinceEpoch}',
    observedAt: at,
    confidence: confidence,
  ),
);

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('BIL requests only the health data consumed by visible flows', () {
    expect(BilHealthScope.read.map((type) => type.name).toSet(), {
      'steps',
      'distance',
      'activeEnergy',
      'workout',
      'sleep',
      'weight',
      'bodyFat',
      'leanMass',
      'heartRate',
      'restingHeartRate',
      'hrv',
      'water',
      'nutrition',
      'nutritionProtein',
      'nutritionCarbohydrates',
      'nutritionFat',
      'nutritionFiber',
      'nutritionSugar',
      'nutritionSodium',
      'nutritionPotassium',
    });
    expect(BilHealthScope.write.map((type) => type.name).toSet(), {
      'weight',
      'nutrition',
    });
    expect(BilHealthScope.excludesKey('unsupported_observation'), isTrue);
  });

  test('manual evidence wins a source conflict without losing provenance', () {
    final now = DateTime.utc(2026, 8, 4);
    final device = _signal(
      provider: 'health_connect',
      confidence: .99,
      at: now,
    );
    final manual = _signal(
      provider: 'manual',
      confidence: .8,
      at: now.subtract(const Duration(minutes: 1)),
    );
    expect(
      HealthSignalConflictResolver.prefer(device, manual).provenance.providerId,
      'manual',
    );
  });

  test(
    'health export requires consent and rejects unreviewed records',
    () async {
      final runtime = UnifiedHealthDataRuntime(
        bridges: [_HealthBridge()],
        store: InMemoryGlobalStore(),
        audit: InMemoryGlobalAuditSink(),
      );
      final now = DateTime.utc(2026, 8, 4);
      final consent = GlobalConsentGrant(
        scope: 'health_weight_write',
        state: GlobalConsentState.granted,
        updatedAt: now,
      );
      final steps = GlobalHealthSignal(
        key: 'steps',
        canonicalValue: 1000,
        canonicalUnit: 'count',
        provenance: GlobalProvenance(
          providerId: 'manual',
          sourceId: 'manual',
          recordId: 'steps-1',
          observedAt: now,
          confidence: 1,
        ),
      );
      await expectLater(
        runtime.export(
          bridge: _HealthBridge(),
          writeConsent: consent,
          signals: [steps],
        ),
        throwsStateError,
      );
    },
  );

  test('unavailable health source is not read or background-enabled', () async {
    final bridge = _CapabilityBridge(available: false);
    final result =
        await UnifiedHealthDataRuntime(
          bridges: [bridge],
          store: InMemoryGlobalStore(),
          audit: InMemoryGlobalAuditSink(),
        ).synchronize(
          asOf: DateTime.utc(2026, 8, 4),
          consent: GlobalConsentGrant(
            scope: 'health_read',
            state: GlobalConsentState.granted,
            updatedAt: DateTime.utc(2026, 8, 4),
          ),
        );
    expect(result, isEmpty);
    expect(bridge.backgroundRequests, 0);
  });

  test(
    'health sync deduplicates identical records but accepts an update',
    () async {
      final bridge = _CapabilityBridge(available: true);
      final store = InMemoryGlobalStore();
      final runtime = UnifiedHealthDataRuntime(
        bridges: [bridge],
        store: store,
        audit: InMemoryGlobalAuditSink(),
      );
      final consent = GlobalConsentGrant(
        scope: 'health_read',
        state: GlobalConsentState.granted,
        updatedAt: DateTime.utc(2026, 8, 4),
      );
      final at = DateTime.utc(2026, 8, 4);
      expect(
        await runtime.synchronize(asOf: at, consent: consent),
        hasLength(1),
      );
      expect(await runtime.synchronize(asOf: at, consent: consent), isEmpty);
      bridge.value = 81;
      final updated = await runtime.synchronize(asOf: at, consent: consent);
      expect(updated.single.canonicalValue, 81);
      expect(updated.single.provenance.timeZoneId, 'Africa/Cairo');
      expect(await store.list('health_signals'), hasLength(1));
    },
  );

  test(
    'BLE rejects stale and unknown-unit data, deduplicates, and forgets',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final bridge = _ManagedBridge();
      final store = InMemoryGlobalStore();
      final controller = FitnessDeviceController(bridge, store: store);

      await controller.scan();
      expect(controller.state.devices.map((device) => device.id), ['scale-1']);
      await controller.connect(controller.state.devices.single);

      expect(controller.state.status, FitnessDeviceConnectionStatus.connected);
      expect(controller.state.batteryPercent, 74);
      expect(controller.state.measurements, hasLength(1));
      expect(controller.state.measurements.single['unit'], 'kg');
      expect(
        controller.state.measurements.single['value'] as double,
        closeTo(100, .001),
      );

      await controller.refreshMeasurements();
      expect(controller.state.measurements, isEmpty);

      await controller.removeDevice('scale-1');
      expect(bridge.disconnected, isTrue);
      expect(bridge.forgotten, isTrue);
      expect(controller.state.devices, isEmpty);
      expect(controller.state.connectedDeviceId, isNull);
      expect(await store.get('connected_fitness_devices', 'scale-1'), isNull);
      expect(
        await store.get('connected_fitness_measurements', 'scale-1'),
        isNull,
      );
    },
  );

  test('BLE never reports connected when native status is false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final bridge = _ManagedBridge()..connected = false;
    final store = InMemoryGlobalStore();
    final controller = FitnessDeviceController(bridge, store: store);

    await controller.scan();
    await controller.connect(controller.state.devices.single);

    expect(controller.state.status, FitnessDeviceConnectionStatus.failed);
    expect(controller.state.failureCode, 'ble_connection_not_verified');
    expect(controller.state.connectedDeviceId, isNull);
    expect(
      await store.get('connected_fitness_device_state', 'scale-1'),
      isNull,
    );
  });

  test('compatibility matrix never claims physical-device verification', () {
    expect(BilDeviceCompatibilityMatrix.entries, isNotEmpty);
    expect(
      BilDeviceCompatibilityMatrix.entries.every(
        (entry) =>
            entry.verification ==
            DeviceVerificationLevel.implementationReadyDeviceRequired,
      ),
      isTrue,
    );
  });
}
