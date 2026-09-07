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

part 'connected_health_gateway_helpers.dart';

part 'connected_health_aggregations.dart';

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
    // The health page is the explicit entry point for the optional native
    // runtime. Initialising it here prevents a first visit from being falsely
    // rendered as "Unsupported platform" while the host is still deferred.
    // This does not run during app launch; this gateway is only read by the
    // connected-health provider when its page is opened.
    return (await _native()).load();
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
    }, dependencies: [connectedHealthGatewayProvider]);

final class ConnectedHealthController
    extends StateNotifier<AsyncValue<ConnectedHealthSnapshot>> {
  ConnectedHealthController(this._gateway) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ConnectedHealthGateway _gateway;
  Future<void>? _mutationTask;
  Future<void>? _refreshTask;

  Future<void> _runMutation(
    Future<ConnectedHealthSnapshot> Function() operation, {
    ConnectedHealthSnapshot Function(ConnectedHealthSnapshot current)?
    transition,
  }) {
    final existing = _mutationTask;
    if (existing != null) return existing;
    final task = _performMutation(operation, transition: transition);
    _mutationTask = task;
    return task;
  }

  Future<void> _performMutation(
    Future<ConnectedHealthSnapshot> Function() operation, {
    ConnectedHealthSnapshot Function(ConnectedHealthSnapshot current)?
    transition,
  }) async {
    try {
      // The constructor starts a refresh immediately. A user action must wait
      // for it rather than being silently discarded when the screen is opened
      // and the permission button is tapped quickly.
      final activeRefresh = _refreshTask;
      if (activeRefresh != null) await activeRefresh;

      final current = state.value;
      if (current != null) {
        final transitioned = transition?.call(current) ?? current;
        // Mutations must retain the rendered snapshot. The old AsyncLoading
        // transition caused the Apple Health controls to flash out of the
        // tree while the native permission sheet/write request completed.
        state = AsyncValue.data(transitioned.copyWith(isBusy: true));
      } else {
        state = const AsyncValue.loading();
      }
      final result = await AsyncValue.guard(operation);
      state = result.when(
        data: (snapshot) => AsyncValue.data(snapshot.copyWith(isBusy: false)),
        error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
        loading: () => current == null
            ? const AsyncValue.loading()
            : AsyncValue.data(current.copyWith(isBusy: false)),
      );
    } finally {
      _mutationTask = null;
    }
  }

  Future<void> refresh() {
    final existing = _refreshTask;
    if (existing != null) return existing;
    final task = _performRefresh();
    _refreshTask = task;
    return task;
  }

  Future<void> _performRefresh() async {
    try {
      // Foreground/resume refreshes can arrive while a permission sheet or
      // another explicit action is completing. Queue the refresh so neither
      // operation is lost.
      final activeMutation = _mutationTask;
      if (activeMutation != null) await activeMutation;

      final previous = state.value;
      if (previous == null) {
        state = const AsyncValue.loading();
      } else {
        // Keep the existing page mounted while native HealthKit/Health
        // Connect work is in flight. Replacing it with AsyncLoading makes the
        // list blink and briefly stops scrolling on a user-initiated refresh.
        state = AsyncValue.data(previous.copyWith(isBusy: true));
      }
      try {
        final loaded = await _gateway.load();
        // This is a foreground-only integration. Refreshing a connected source
        // must read native changes as well as reload the cached permission
        // snapshot, otherwise new Watch/Health Connect records remain stale.
        final shouldSynchronize =
            loaded.status == ConnectedHealthStatus.authorizationRequested ||
            loaded.status == ConnectedHealthStatus.ready ||
            loaded.status == ConnectedHealthStatus.synchronized;
        final refreshed = shouldSynchronize
            ? await _gateway.synchronize()
            : loaded;
        state = AsyncValue.data(refreshed.copyWith(isBusy: false));
      } catch (error, stackTrace) {
        // A lifecycle notification must not replace useful cached content with
        // a transient blank/error screen.
        state = previous == null
            ? AsyncValue.error(error, stackTrace)
            : AsyncValue.data(
                previous.copyWith(
                  status: ConnectedHealthStatus.degraded,
                  failureCode: 'health_refresh_failed_offline_cache_preserved',
                  isBusy: false,
                ),
              );
      }
    } finally {
      _refreshTask = null;
    }
  }

  Future<void> synchronize() => _runMutation(
    _gateway.synchronize,
    transition: (current) => current.copyWith(
      status: ConnectedHealthStatus.syncing,
      clearFailure: true,
    ),
  );

  Future<void> requestPermissions() async {
    await _runMutation(() async {
      final requested = await _gateway.requestPermissions();
      final firstReadPending =
          requested.status == ConnectedHealthStatus.authorizationRequested ||
          (requested.status == ConnectedHealthStatus.ready &&
              requested.lastSyncAt == null);
      // The native permission sheet has already completed at this point.
      // Import immediately so an Apple Watch/Health Connect user does not
      // need to leave and reopen this screen before seeing available data.
      return firstReadPending ? await _gateway.synchronize() : requested;
    });
  }

  Future<void> requestWeightWritePermission() async {
    await _runMutation(_gateway.requestWeightWritePermission);
  }

  Future<void> revokePermissions() async {
    await _runMutation(_gateway.revokePermissions);
  }

  Future<void> openSystemSettings() async {
    await _runMutation(() async {
      await _gateway.openSystemSettings();
      return state.value ?? const ConnectedHealthSnapshot.unavailable();
    }, transition: (current) => current);
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
      final signals = <ConnectedHealthSignalView>[];
      final stepHistory = <ConnectedHealthSignalView>[];
      final retainedSignalMaps = <Map<String, Object?>>[];
      final retainedStepHistoryMaps = <Map<String, Object?>>[];
      var hasVerifiedNativeEvidence = false;
      var removedLegacyClinicalSignal = false;
      for (final raw in stored?['signals'] as List<Object?>? ?? const []) {
        final signal = GlobalHealthSignal.fromMap(
          Map<String, Object?>.from(raw! as Map),
        );
        if (BilHealthScope.excludesKey(signal.key) ||
            await _isTombstoned(signal)) {
          removedLegacyClinicalSignal = true;
          continue;
        }
        retainedSignalMaps.add(signal.toMap());
        signals.add(ConnectedHealthSignalView.fromSignal(signal));
        hasVerifiedNativeEvidence =
            hasVerifiedNativeEvidence || _isEvidenceFromNativeBridge(signal);
      }
      for (final raw in stored?['stepHistory'] as List<Object?>? ?? const []) {
        if (raw is! Map) continue;
        try {
          final signal = GlobalHealthSignal.fromMap(
            Map<String, Object?>.from(raw),
          );
          if (signal.key != 'steps' ||
              signal.deleted ||
              await _isTombstoned(signal)) {
            continue;
          }
          retainedStepHistoryMaps.add(signal.toMap());
          stepHistory.add(ConnectedHealthSignalView.fromSignal(signal));
        } on Object {
          // A corrupt projection must not hide the latest valid snapshot.
        }
      }
      if (stepHistory.isEmpty) {
        stepHistory.addAll(signals.where((signal) => signal.key == 'steps'));
      }
      if (removedLegacyClinicalSignal && stored != null) {
        await _flows.store
            .put('connected_health_ui', 'snapshot', <String, Object?>{
              ...stored,
              'signals': retainedSignalMaps,
              'stepHistory': retainedStepHistoryMaps,
              'importedCount': retainedSignalMaps.length,
            });
      }
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
        deviceVerified: hasVerifiedNativeEvidence,
        stepHistory: List<ConnectedHealthSignalView>.unmodifiable(stepHistory),
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
        connectedHealthReadTypesForPlatform(
          defaultTargetPlatform,
        ).map((type) => type.name).toSet(),
        write: false,
      );
      await _flows.store
          .put('connected_health_consent', source, <String, Object?>{
            'readRequested': true,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
      // A pre-consent probe can create an empty HealthKit anchor. Reset it
      // after the user completes consent so the first authorized foreground
      // sync reads existing Apple Watch history, not only future changes.
      await _flows.store.remove('health_anchor', _bridge.id);
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
        connectedHealthWriteTypeNamesForPlatform(defaultTargetPlatform),
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
        <String, Object?>{
          'importedCount': 0,
          'signals': <Object?>[],
          'stepHistory': <Object?>[],
        },
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
        deviceVerified: false,
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
      if (_isIos && consentState?['historicalReadResetAt'] == null) {
        // Older builds could create a HealthKit anchor before the user
        // granted read access. Clear that one-time probe so existing Watch
        // records are included in the first authorized sync.
        await _flows.store.remove('health_anchor', _bridge.id);
        await _flows.store
            .put('connected_health_consent', source, <String, Object?>{
              ...(consentState ?? const <String, Object?>{}),
              'historicalReadResetAt': now.toUtc().toIso8601String(),
            });
      }
      final consent = GlobalConsentGrant(
        scope: _isIos ? 'apple_health_read' : 'health_connect_read',
        state: GlobalConsentState.granted,
        updatedAt: now,
      );
      final records = _isIos
          ? await _flows.appleHealth.integration.synchronize(
              asOf: now,
              consent: consent,
              types: connectedHealthReadTypesForPlatform(defaultTargetPlatform),
            )
          : await _flows.healthConnect.integration.synchronize(
              asOf: now,
              consent: consent,
              types: connectedHealthReadTypesForPlatform(defaultTargetPlatform),
            );
      final persistedRows = await _flows.store.list('health_signals');
      final persisted = <GlobalHealthSignal>[];
      for (final row in persistedRows) {
        try {
          final signal = GlobalHealthSignal.fromMap(row);
          if (BilHealthScope.excludesKey(signal.key) ||
              await _isTombstoned(signal)) {
            await _flows.store.remove('health_signals', signal.identity);
            await _flows.store.remove('health_seen', signal.identity);
            continue;
          }
          persisted.add(signal);
        } on Object {
          // A corrupt local row is ignored; valid evidence remains available.
        }
      }
      final normalizedPersisted = aggregateConnectedSleepSignals(persisted);
      final graph = await BilGlobalHealthEvidenceGraphEngine(
        memory: SourceReliabilityMemory(store: _flows.store),
      ).build(normalizedPersisted);
      final ordered = graph.selectedSignals.toList()
        ..sort(
          (a, b) => b.provenance.observedAt.compareTo(a.provenance.observedAt),
        );
      final selected = _selectRepresentativeSignals(ordered);
      final stepHistorySignals = aggregateConnectedStepSignals(
        graph.selectedSignals,
      );
      final hasVerifiedNativeEvidence = selected.any(
        _isEvidenceFromNativeBridge,
      );
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
          'stepHistory': <Map<String, Object?>>[
            for (final signal in stepHistorySignals) signal.toMap(),
          ],
        },
      );
      return ConnectedHealthSnapshot(
        // HealthKit intentionally makes read denial indistinguishable from an
        // empty store. Do not claim a connected/synchronized Apple source
        // until at least one native record provides affirmative evidence.
        status: connectedHealthStatusAfterSynchronization(
          platform: defaultTargetPlatform,
          hasVerifiedNativeEvidence: hasVerifiedNativeEvidence,
        ),
        platformSource: source,
        availableSources: <String>[source],
        signals: <ConnectedHealthSignalView>[
          for (final signal in selected)
            ConnectedHealthSignalView.fromSignal(signal),
        ],
        importedCount: records.length,
        lastSyncAt: now,
        failureCode: null,
        deviceVerified: hasVerifiedNativeEvidence,
        stepHistory: <ConnectedHealthSignalView>[
          for (final signal in stepHistorySignals)
            ConnectedHealthSignalView.fromSignal(signal),
        ],
      );
    } catch (_) {
      final cached = await load();
      return cached.copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: 'health_sync_failed_offline_cache_preserved',
      );
    }
  }
}
