import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/scheduler.dart';

import '../../global_platform/core/global_platform_core.dart';
import '../../global_platform/health_data/unified_health_data_integration.dart';
import '../../global_platform/intelligence/global_health_evidence_graph.dart';
import '../../global_platform/product/global_product_access.dart';
import '../../global_platform/product/global_product_coordinators.dart';
import '../../global_platform/runtime/global_product_composition_root.dart';
import '../connected_health_model.dart';

part 'connected_health_gateway_helpers.dart';

@visibleForTesting
Set<HealthDataType> connectedHealthReadTypesForPlatform(
  TargetPlatform platform,
) {
  if (platform == TargetPlatform.iOS) return BilHealthScope.read;
  if (platform == TargetPlatform.android) {
    return Set<HealthDataType>.unmodifiable(
      BilHealthScope.read.where(
        (type) => BilHealthScope.healthConnectReadTypeNames.contains(type.name),
      ),
    );
  }
  return const <HealthDataType>{};
}

@visibleForTesting
Set<String> connectedHealthWriteTypeNamesForPlatform(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS => BilHealthScope.appleHealthWriteTypeNames,
      TargetPlatform.android => BilHealthScope.healthConnectWriteTypeNames,
      _ => const <String>{},
    };

@visibleForTesting
ConnectedHealthStatus connectedHealthStatusAfterSynchronization({
  required TargetPlatform platform,
  required bool hasVerifiedNativeEvidence,
}) => platform == TargetPlatform.iOS && !hasVerifiedNativeEvidence
    ? ConnectedHealthStatus.authorizationRequested
    : ConnectedHealthStatus.synchronized;

/// Keeps trusted metrics visible when a native read returns an empty or
/// partial snapshot during a transient permission/provider failure.
@visibleForTesting
ConnectedHealthSnapshot preserveTrustedConnectedHealthSignals({
  required ConnectedHealthSnapshot previous,
  required ConnectedHealthSnapshot incoming,
}) {
  if (previous.signals.isEmpty) return incoming;
  final validIncoming = incoming.signals
      .where(
        (signal) =>
            signal.value.isFinite &&
            signal.source.trim().isNotEmpty &&
            signal.confidence > 0,
      )
      .toList(growable: false);
  final incomingKeys = validIncoming.map((signal) => signal.key).toSet();
  final merged = <ConnectedHealthSignalView>[
    ...validIncoming,
    for (final signal in previous.signals)
      if (!incomingKeys.contains(signal.key)) signal,
  ];
  if (merged.isEmpty) return incoming;
  return incoming.copyWith(
    signals: merged,
    importedCount: incoming.importedCount > 0
        ? incoming.importedCount
        : previous.importedCount,
    lastSyncAt: incoming.lastSyncAt ?? previous.lastSyncAt,
    deviceVerified: incoming.deviceVerified || previous.deviceVerified,
  );
}

/// Converts HealthKit's overlapping in-bed/awake/stage samples into one
/// measured asleep duration per source/night. Android SleepSessionRecord rows
/// already carry a session total with nested stages and pass through unchanged.
/// No stage percentages or missing edges are fabricated.
@visibleForTesting
List<GlobalHealthSignal> aggregateConnectedSleepSignals(
  List<GlobalHealthSignal> records,
) {
  final output = <GlobalHealthSignal>[];
  final stagedByNight = <String, List<GlobalHealthSignal>>{};
  for (final signal in records) {
    if (signal.key != 'sleep') {
      output.add(signal);
      continue;
    }
    final stage = signal.attributes['sleepStage']?.toString();
    if (stage == null || signal.attributes['stages'] is List) {
      output.add(signal);
      continue;
    }
    if (stage == 'inBed' || stage == 'awake' || stage == 'unknown') {
      // These records describe the bed window or wake time, not sleep.
      continue;
    }
    final endedAt = DateTime.tryParse(
      signal.attributes['endedAt']?.toString() ?? '',
    );
    if (endedAt == null || !endedAt.isAfter(signal.provenance.observedAt)) {
      continue;
    }
    final localEnd = endedAt.toLocal();
    final night =
        '${localEnd.year.toString().padLeft(4, '0')}-'
        '${localEnd.month.toString().padLeft(2, '0')}-'
        '${localEnd.day.toString().padLeft(2, '0')}';
    final key =
        '${signal.provenance.providerId}|${signal.provenance.sourceId}|$night';
    stagedByNight.putIfAbsent(key, () => <GlobalHealthSignal>[]).add(signal);
  }

  for (final entry in stagedByNight.entries) {
    final rows = entry.value
      ..sort(
        (a, b) => a.provenance.observedAt.compareTo(b.provenance.observedAt),
      );
    final intervals = <({DateTime start, DateTime end})>[];
    for (final row in rows) {
      final end = DateTime.parse(row.attributes['endedAt']!.toString()).toUtc();
      final start = row.provenance.observedAt.toUtc();
      if (intervals.isEmpty || start.isAfter(intervals.last.end)) {
        intervals.add((start: start, end: end));
      } else if (end.isAfter(intervals.last.end)) {
        intervals[intervals.length - 1] = (
          start: intervals.last.start,
          end: end,
        );
      }
    }
    final hours = intervals.fold<double>(
      0,
      (sum, interval) =>
          sum + interval.end.difference(interval.start).inSeconds / 3600,
    );
    if (!hours.isFinite || hours <= 0 || hours > 24) continue;
    final template = rows.reduce(
      (a, b) =>
          a.provenance.observedAt.isAfter(b.provenance.observedAt) ? a : b,
    );
    final first = intervals.first.start;
    final last = intervals.last.end;
    output.add(
      GlobalHealthSignal(
        key: 'sleep',
        canonicalValue: hours,
        canonicalUnit: 'h',
        provenance: GlobalProvenance(
          providerId: template.provenance.providerId,
          sourceId: template.provenance.sourceId,
          recordId:
              'sleep-night:${entry.key}:${first.microsecondsSinceEpoch}:${last.microsecondsSinceEpoch}',
          observedAt: first,
          confidence: rows
              .map((row) => row.provenance.confidence)
              .reduce((a, b) => a < b ? a : b),
          deviceId: template.provenance.deviceId,
          timeZoneId: template.provenance.timeZoneId,
        ),
        attributes: <String, Object?>{
          'endedAt': last.toIso8601String(),
          'sourceSessionIds': [for (final row in rows) row.provenance.recordId],
          'measuredStages': [
            for (final row in rows) row.attributes['sleepStage'],
          ],
        },
      ),
    );
  }
  return List<GlobalHealthSignal>.unmodifiable(output);
}

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
    // The dashboard watches this provider while it is building. Let that
    // first frame reach the screen before opening SQLite, restoring plugins,
    // loading locale catalogs, and composing the optional native runtimes.
    // Explicit Apps & Devices actions called after the frame remain immediate.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await SchedulerBinding.instance.endOfFrame;
    }
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
  ConnectedHealthController(
    this._gateway, {
    this._operationTimeout = const Duration(seconds: 12),
  }) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ConnectedHealthGateway _gateway;
  final Duration _operationTimeout;
  Future<void>? _mutationTask;
  Future<void>? _refreshTask;
  var _disposed = false;
  var _lifecycleGeneration = 0;

  bool _isCurrent(int generation) =>
      !_disposed && generation == _lifecycleGeneration;

  @override
  void dispose() {
    _disposed = true;
    _lifecycleGeneration += 1;
    super.dispose();
  }

  Future<ConnectedHealthSnapshot> _synchronizeWithinDeadline(
    ConnectedHealthSnapshot fallback,
  ) async {
    try {
      final incoming = await _gateway.synchronize().timeout(_operationTimeout);
      return preserveTrustedConnectedHealthSignals(
        previous: fallback,
        incoming: incoming,
      );
    } on TimeoutException {
      // A platform-channel read can outlive this screen. Do not leave the
      // dashboard or Apps & Devices trapped in a perpetual syncing state; the
      // next explicit Sync can safely continue from its persisted anchor.
      return fallback.copyWith(
        status: ConnectedHealthStatus.degraded,
        failureCode: 'health_sync_timed_out_cache_preserved',
      );
    }
  }

  Future<void> _runMutation(
    Future<ConnectedHealthSnapshot> Function() operation, {
    ConnectedHealthSnapshot Function(ConnectedHealthSnapshot current)?
    transition,
  }) {
    if (_disposed) return Future<void>.value();
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
    final generation = _lifecycleGeneration;
    try {
      // The constructor starts a refresh immediately. A user action must wait
      // for it rather than being silently discarded when the screen is opened
      // and the permission button is tapped quickly.
      final activeRefresh = _refreshTask;
      if (activeRefresh != null) await activeRefresh;
      if (!_isCurrent(generation)) return;

      final current = state.value;
      if (transition != null && current != null) {
        if (_isCurrent(generation)) {
          state = AsyncValue.data(transition(current));
        }
      } else {
        if (_isCurrent(generation)) state = const AsyncValue.loading();
      }
      // Let the syncing state paint before HealthKit starts its native query.
      // This branch is deliberately iOS-only; Android/Health Connect keeps its
      // existing timing and Bluetooth remains untouched.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Future<void>.delayed(Duration.zero);
        if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
          await SchedulerBinding.instance.endOfFrame;
        }
      }
      if (!_isCurrent(generation)) return;
      final result = await AsyncValue.guard(operation);
      if (_isCurrent(generation)) state = result;
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
    final generation = _lifecycleGeneration;
    try {
      // Foreground/resume refreshes can arrive while a permission sheet or
      // another explicit action is completing. Queue the refresh so neither
      // operation is lost.
      final activeMutation = _mutationTask;
      if (activeMutation != null) await activeMutation;
      if (!_isCurrent(generation)) return;

      final previous = state.value;
      if (previous == null && _isCurrent(generation)) {
        state = const AsyncValue.loading();
      }
      try {
        // Refresh only reads the cached connection state. It deliberately
        // never begins a HealthKit/Health Connect import: this provider is
        // also watched by the dashboard, and automatic imports were making
        // normal navigation wait behind a potentially large native history.
        // Imports remain explicit through the Sync button or post-consent
        // first import below.
        final loaded = await _gateway.load();
        if (_isCurrent(generation)) state = AsyncValue.data(loaded);
      } catch (error, stackTrace) {
        if (!_isCurrent(generation)) return;
        // A lifecycle notification must not replace useful cached content with
        // a transient blank/error screen.
        state = previous == null
            ? AsyncValue.error(error, stackTrace)
            : AsyncValue.data(
                previous.copyWith(
                  status: ConnectedHealthStatus.degraded,
                  failureCode: 'health_refresh_failed_offline_cache_preserved',
                ),
              );
      }
    } finally {
      _refreshTask = null;
    }
  }

  Future<void> synchronize() => _runMutation(
    () => _synchronizeWithinDeadline(
      state.value ?? const ConnectedHealthSnapshot.unavailable(),
    ),
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
      return firstReadPending
          ? await _synchronizeWithinDeadline(requested)
          : requested;
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
      final retainedSignalMaps = <Map<String, Object?>>[];
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
      if (removedLegacyClinicalSignal && stored != null) {
        await _flows.store
            .put('connected_health_ui', 'snapshot', <String, Object?>{
              ...stored,
              'signals': retainedSignalMaps,
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
