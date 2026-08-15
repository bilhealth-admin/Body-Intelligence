import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../global_platform/core/global_platform_core.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';
import '../../global_platform/intelligence/global_health_evidence_graph.dart';
import '../../global_platform/product/global_product_access.dart';
import '../../global_platform/product/global_product_coordinators.dart';
import '../../global_platform/runtime/global_product_composition_root.dart';
import '../connected_health_model.dart';

abstract interface class ConnectedHealthGateway {
  Future<ConnectedHealthSnapshot> load();
  Future<ConnectedHealthSnapshot> synchronize();
  Future<ConnectedHealthSnapshot> requestPermissions();
  Future<ConnectedHealthSnapshot> requestWeightWritePermission();
  Future<ConnectedHealthSnapshot> revokePermissions();
  Future<void> openSystemSettings();
}

final connectedHealthGatewayProvider = Provider<ConnectedHealthGateway>((ref) {
  final ready = GlobalNativeIntegrationHost.instance.productFlows;
  return ready == null
      ? DeferredConnectedHealthGateway()
      : NativeConnectedHealthGateway(ref.read(globalProductFlowsProvider));
});

/// Keeps the expensive optional global SQLite/runtime host off the launch
/// path. Reading the dashboard state is cheap; native initialization starts
/// only after the user explicitly requests a permission or synchronization.
final class DeferredConnectedHealthGateway implements ConnectedHealthGateway {
  Future<NativeConnectedHealthGateway> _native() async {
    final host = GlobalNativeIntegrationHost.instance;
    await host.initialize();
    final flows = host.productFlows;
    if (flows == null) throw StateError('global_product_flows_not_initialized');
    return NativeConnectedHealthGateway(flows);
  }

  @override
  Future<ConnectedHealthSnapshot> load() async {
    final flows = GlobalNativeIntegrationHost.instance.productFlows;
    if (flows == null) return const ConnectedHealthSnapshot.unavailable();
    return NativeConnectedHealthGateway(flows).load();
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() async =>
      (await _native()).synchronize();

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async =>
      (await _native()).requestPermissions();

  @override
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async =>
      (await _native()).requestWeightWritePermission();

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async =>
      (await _native()).revokePermissions();

  @override
  Future<void> openSystemSettings() async =>
      (await _native()).openSystemSettings();
}

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
  bool _mutationInFlight = false;

  Future<void> _runMutation(
    Future<ConnectedHealthSnapshot> Function() operation,
  ) async {
    if (_mutationInFlight) return;
    _mutationInFlight = true;
    state = const AsyncValue.loading();
    try {
      state = await AsyncValue.guard(operation);
    } finally {
      _mutationInFlight = false;
    }
  }

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
    await _runMutation(_gateway.requestPermissions);
  }

  Future<void> requestWeightWritePermission() async {
    await _runMutation(_gateway.requestWeightWritePermission);
  }

  Future<void> revokePermissions() async {
    await _runMutation(_gateway.revokePermissions);
  }

  Future<void> openSystemSettings() async {
    if (_mutationInFlight) return;
    _mutationInFlight = true;
    final previous = state.value;
    state = const AsyncValue.loading();
    try {
      await _gateway.openSystemSettings();
      if (previous != null) state = AsyncValue.data(previous);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    } finally {
      _mutationInFlight = false;
    }
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
      final availability = _bridge is NativeHealthCapabilityBridge
          ? await (_bridge as NativeHealthCapabilityBridge).availability()
          : const <String, Object?>{'available': true};
      if (availability['available'] != true) {
        final status = availability['status']?.toString();
        return ConnectedHealthSnapshot(
          status: status == '2'
              ? ConnectedHealthStatus.updateRequired
              : ConnectedHealthStatus.unavailable,
          platformSource: source,
          availableSources: const <String>[],
          signals: const <ConnectedHealthSignalView>[],
          importedCount: 0,
          lastSyncAt: null,
          failureCode: 'native_health_unavailable',
          availabilityStatus: status,
        );
      }
      final permissions = await _bridge.permissions();
      final consentState = await _flows.store.get(
        'connected_health_consent',
        source,
      );
      final stored = await _flows.store.get('connected_health_ui', 'snapshot');
      final signals = <ConnectedHealthSignalView>[
        for (final raw in stored?['signals'] as List<Object?>? ?? const [])
          ConnectedHealthSignalView.fromSignal(
            GlobalHealthSignal.fromMap(Map<String, Object?>.from(raw! as Map)),
          ),
      ];
      final explicitlyRequested = consentState?['readRequested'] == true;
      // HealthKit deliberately does not reveal whether read access was
      // granted or denied. authorizationStatus(for:) reports sharing/write
      // status, so an iOS request must remain indeterminate until records are
      // actually returned. Never present it as granted from that snapshot.
      final granted =
          explicitlyRequested &&
          !_isIos &&
          permissions.values.any((value) => value);
      final lastSyncRaw = stored?['lastSyncAt'] as String?;
      return ConnectedHealthSnapshot(
        status: _isIos && explicitlyRequested
            ? (signals.isNotEmpty
                  ? ConnectedHealthStatus.synchronized
                  : ConnectedHealthStatus.authorizationRequested)
            : granted
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
        availabilityStatus: availability['status']?.toString(),
        deviceVerified: true,
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
        BilHealthScope.read.map((type) => type.name).toSet(),
        write: false,
      );
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            'readRequested': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      final loaded = await load();
      return !_isIos &&
              loaded.status == ConnectedHealthStatus.permissionRequired
          ? loaded.copyWith(
              status: ConnectedHealthStatus.permissionDenied,
              failureCode: 'health_permission_denied',
            )
          : loaded;
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
  Future<ConnectedHealthSnapshot> requestWeightWritePermission() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      await _bridge.request(
        BilHealthScope.write.map((type) => type.name).toSet(),
        write: true,
      );
      final current =
          await _flows.store.get('connected_health_consent', source) ??
          <String, Object?>{};
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            ...current,
            'weightWriteRequested': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      return load();
    } catch (_) {
      final cached = await load();
      return cached.copyWith(failureCode: 'health_write_permission_failed');
    }
  }

  @override
  Future<ConnectedHealthSnapshot> revokePermissions() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }
    try {
      final result = _bridge is NativeHealthCapabilityBridge
          ? await (_bridge as NativeHealthCapabilityBridge).revokeAccess()
          : const <String, Object?>{'revoked': false};
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            'readRequested': false,
            'weightWriteRequested': false,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      await _flows.store.put(
        'connected_health_ui',
        'snapshot',
        <String, Object?>{'importedCount': 0, 'signals': <Object?>[]},
      );
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: result['revoked'] == true
            ? null
            : 'revoke_in_system_settings_required',
        deviceVerified: true,
      );
    } catch (_) {
      return (await load()).copyWith(failureCode: 'health_revoke_failed');
    }
  }

  @override
  Future<void> openSystemSettings() async {
    if (_bridge is NativeHealthCapabilityBridge) {
      await (_bridge as NativeHealthCapabilityBridge).openSettings();
    }
  }

  @override
  Future<ConnectedHealthSnapshot> synchronize() async {
    final source = _source;
    if (source == null || _capability?.available != true) {
      return const ConnectedHealthSnapshot.unavailable();
    }

    final consentState = await _flows.store.get(
      'connected_health_consent',
      source,
    );
    if (consentState?['readRequested'] != true) {
      return ConnectedHealthSnapshot(
        status: ConnectedHealthStatus.permissionRequired,
        platformSource: source,
        availableSources: <String>[source],
        signals: const <ConnectedHealthSignalView>[],
        importedCount: 0,
        lastSyncAt: null,
        failureCode: 'explicit_health_consent_required',
      );
    }

    try {
      final now = DateTime.now();
      final consent = GlobalConsentGrant(
        scope: _isIos ? 'apple_health_read' : 'health_connect_read',
        state: GlobalConsentState.granted,
        updatedAt: now,
      );
      final records = _isIos
          ? await _flows.appleHealth.integration.synchronize(
              asOf: now,
              consent: consent,
              types: BilHealthScope.read,
            )
          : await _flows.healthConnect.integration.synchronize(
              asOf: now,
              consent: consent,
              types: BilHealthScope.read,
            );
      final persistedRows = await _flows.store.list('health_signals');
      final persisted = <GlobalHealthSignal>[];
      for (final row in persistedRows) {
        try {
          persisted.add(GlobalHealthSignal.fromMap(row));
        } on Object {
          // A corrupt local row is ignored; valid evidence remains available.
        }
      }
      final graph = await BilGlobalHealthEvidenceGraphEngine(
        memory: SourceReliabilityMemory(store: _flows.store),
      ).build(persisted);
      final ordered = graph.selectedSignals.toList()
        ..sort(
          (a, b) => b.provenance.observedAt.compareTo(a.provenance.observedAt),
        );
      final selected = _selectRepresentativeSignals(ordered);
      await _flows.store
          .put('connected_health_evidence', 'latest', <String, Object?>{
            'selectedIds': graph.nodes
                .where((node) => node.selected)
                .map((node) => node.id)
                .toList(),
            'conflictCount': graph.conflicts.length,
            'confidence': graph.confidence,
            'updatedAt': now.toUtc().toIso8601String(),
          });
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
        deviceVerified: true,
      );
    } catch (_) {
      final cached = await load();
      return cached.copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: 'health_sync_failed_offline_cache_preserved',
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
      byKey.update(
        signal.key,
        (current) => HealthSignalConflictResolver.prefer(current, signal),
        ifAbsent: () => signal,
      );
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
