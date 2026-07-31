import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../global_platform/core/global_platform_core.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';
import '../../global_platform/product/global_product_access.dart';
import '../../global_platform/product/global_product_coordinators.dart';
import '../connected_health_model.dart';

abstract interface class ConnectedHealthGateway {
  Future<ConnectedHealthSnapshot> load();
  Future<ConnectedHealthSnapshot> synchronize();
  Future<ConnectedHealthSnapshot> requestPermissions();
}

final connectedHealthGatewayProvider = Provider<ConnectedHealthGateway>((ref) {
  return NativeConnectedHealthGateway(ref.read(globalProductFlowsProvider));
});

final connectedHealthProvider =
    StateNotifierProvider<
      ConnectedHealthController,
      AsyncValue<ConnectedHealthSnapshot>
    >((ref) {
      return ConnectedHealthController(
        ref.read(connectedHealthGatewayProvider),
      );
    });

final class ConnectedHealthController
    extends StateNotifier<AsyncValue<ConnectedHealthSnapshot>> {
  ConnectedHealthController(this._gateway) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ConnectedHealthGateway _gateway;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_gateway.load);
  }

  Future<void> synchronize() async {
    final current = state.value ?? const ConnectedHealthSnapshot.unavailable();
    state = AsyncValue.data(
      current.copyWith(
        status: ConnectedHealthStatus.syncing,
        clearFailure: true,
      ),
    );
    state = await AsyncValue.guard(_gateway.synchronize);
  }

  Future<void> requestPermissions() async {
    state = await AsyncValue.guard(_gateway.requestPermissions);
  }
}

final class NativeConnectedHealthGateway implements ConnectedHealthGateway {
  NativeConnectedHealthGateway(this._flows);

  final GlobalProductFlows _flows;

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? get _source => _isIos
      ? 'Apple Health'
      : _isAndroid
      ? 'Health Connect'
      : null;

  GlobalProductCapabilityState? get _capability => _isIos
      ? _flows.capabilities['appleWatch']
      : _isAndroid
      ? _flows.capabilities['wearOs']
      : null;

  @override
  Future<ConnectedHealthSnapshot> load() async {
    final source = _source;
    final capability = _capability;
    if (source == null || capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    try {
      final permissions = await _bridge.permissions();
      final stored = await _flows.store.get('connected_health_ui', 'snapshot');
      final signals = <ConnectedHealthSignalView>[
        for (final raw in stored?['signals'] as List<Object?>? ?? const [])
          ConnectedHealthSignalView.fromSignal(
            GlobalHealthSignal.fromMap(Map<String, Object?>.from(raw! as Map)),
          ),
      ];
      final granted = permissions.values.any((value) => value);
      final lastSyncRaw = stored?['lastSyncAt'] as String?;
      return ConnectedHealthSnapshot(
        status: granted
            ? (lastSyncRaw == null
                  ? ConnectedHealthStatus.ready
                  : ConnectedHealthStatus.synchronized)
            : ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: signals,
        importedCount: stored?['importedCount'] as int? ?? signals.length,
        lastSyncAt: lastSyncRaw == null
            ? null
            : DateTime.parse(lastSyncRaw).toLocal(),
        failureCode: null,
      );
    } catch (_) {
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'native_health_status_unavailable',
      );
    }
  }

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      await _bridge.request(
        HealthDataType.values.map((type) => type.name).toSet(),
        write: false,
      );
      return load();
    } catch (_) {
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'health_permission_request_failed',
      );
    }
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    try {
      final now = DateTime.now();
      final consent = GlobalConsentGrant(
        scope: _isIos ? 'apple_health_read' : 'health_connect_read',
        state: GlobalConsentState.granted,
        updatedAt: now,
      );
      final records = _isIos
          ? await _flows.appleHealth.synchronize(asOf: now, consent: consent)
          : await _flows.healthConnect.synchronize(asOf: now, consent: consent);
      final ordered = records.where((signal) => !signal.deleted).toList()
        ..sort(
          (a, b) => b.provenance.observedAt.compareTo(a.provenance.observedAt),
        );
      final selected = _selectRepresentativeSignals(ordered);
      await _flows.store.put(
        'connected_health_ui',
        'snapshot',
        <String, Object?>{
          'lastSyncAt': now.toUtc().toIso8601String(),
          'importedCount': records.length,
          'signals': <Map<String, Object?>>[
            for (final signal in selected) signal.toMap(),
          ],
        },
      );
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.synchronized,
        platformSource: source,
        availableSources: <String>[source],
        signals: <ConnectedHealthSignalView>[
          for (final signal in selected)
            ConnectedHealthSignalView.fromSignal(signal),
        ],
        importedCount: records.length,
        lastSyncAt: now,
        failureCode: null,
      );
    } catch (_) {
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.degraded,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'health_sync_failed',
      );
    }
  }

  NativeHealthBridge get _bridge =>
      _isIos ? _flows.appleHealth.bridge : _flows.healthConnect.bridge;

  List<GlobalHealthSignal> _selectRepresentativeSignals(
    List<GlobalHealthSignal> records,
  ) {
    const priority = <String>[
      'steps',
      'sleep',
      'heartRate',
      'restingHeartRate',
      'activeEnergy',
      'oxygen',
      'weight',
      'glucose',
      'bloodPressureSystolic',
    ];
    final byKey = <String, GlobalHealthSignal>{};
    for (final signal in records) {
      byKey.putIfAbsent(signal.key, () => signal);
    }
    final selected = <GlobalHealthSignal>[];
    for (final key in priority) {
      final signal = byKey[key];
      if (signal != null) selected.add(signal);
    }
    for (final entry in byKey.entries) {
      if (!priority.contains(entry.key)) selected.add(entry.value);
    }
    return selected.take(8).toList(growable: false);
  }
}
