import 'dart:async';

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
part 'connected_health_native_gateway.dart';

abstract interface class ConnectedHealthGateway {
  Future<ConnectedHealthSnapshot> load();
  Future<ConnectedHealthSnapshot> synchronize();
  Future<ConnectedHealthSnapshot> requestPermissions();
  Future<ConnectedHealthSnapshot> requestWeightWritePermission();
  Future<ConnectedHealthSnapshot> revokePermissions();
  Future<void> openSystemSettings();
}

/// Bounded activity totals only: no permission prompts, raw-history import,
/// anchor reset, or remote transfer during a dashboard visit.
abstract interface class ConnectedHealthDailyActivityGateway {
  Future<ConnectedHealthSnapshot> loadDailyActivity();
}

/// An initial native sheet is permitted after the user's setup completes.
/// No repeat sheet, settings redirect, or silent grant is inferred here.
abstract interface class ConnectedHealthStartupPermissionGateway {
  Future<ConnectedHealthSnapshot?> requestStartupPermissions();
}

final connectedHealthGatewayProvider = Provider<ConnectedHealthGateway>((ref) {
  final ready = GlobalNativeIntegrationHost.instance.productFlows;
  return ready == null
      ? DeferredConnectedHealthGateway()
      : NativeConnectedHealthGateway(ref.read(globalProductFlowsProvider));
});

/// Keeps the expensive optional global SQLite/runtime host off the launch
/// path. Native initialization starts after setup on the first dashboard,
/// or from an explicit permission/synchronization action.
final class DeferredConnectedHealthGateway
    implements
        ConnectedHealthGateway,
        ConnectedHealthDailyActivityGateway,
        ConnectedHealthStartupPermissionGateway {
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
  Future<ConnectedHealthSnapshot> loadDailyActivity() async =>
      (await _native()).loadDailyActivity();

  @override
  Future<ConnectedHealthSnapshot> requestPermissions() async =>
      (await _native()).requestPermissions();

  @override
  Future<ConnectedHealthSnapshot?> requestStartupPermissions() async =>
      (await _native()).requestStartupPermissions();

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

enum _HealthMutation {
  startupPermission,
  dailyActivity,
  synchronize,
  permissions,
  weightWritePermission,
  revoke,
  systemSettings,
}

final class ConnectedHealthController
    extends StateNotifier<AsyncValue<ConnectedHealthSnapshot>> {
  static const Duration _defaultSynchronizationTimeout = Duration(seconds: 25);

  ConnectedHealthController(this._gateway, {Duration? synchronizationTimeout})
    : _synchronizationTimeout =
          synchronizationTimeout ?? _defaultSynchronizationTimeout,
      super(const AsyncValue.data(ConnectedHealthSnapshot.unavailable()));

  final ConnectedHealthGateway _gateway;
  final Duration _synchronizationTimeout;
  Future<void>? _mutationTask;
  _HealthMutation? _mutationKind;
  Future<void>? _refreshTask;
  Future<ConnectedHealthSnapshot>? _nativeSyncTask;
  Future<void>? _startupPermissionTask;
  DateTime? _activityRefreshedAt;

  // Retain the completed future too: switching tabs, returning from the native
  // sheet, and rebuilding the dashboard cannot schedule another startup sheet.
  Future<void> requestStartupPermissions() =>
      _startupPermissionTask ??= _requestStartupPermissions();

  Future<void> _requestStartupPermissions() async {
    if (!mounted) return;
    final gateway = _gateway;
    if (gateway is! ConnectedHealthStartupPermissionGateway) return;
    await _runMutation(_HealthMutation.startupPermission, () async {
      final result = await (gateway as ConnectedHealthStartupPermissionGateway)
          .requestStartupPermissions();
      if (!mounted) return const ConnectedHealthSnapshot.unavailable();
      return result ??
          state.value ??
          const ConnectedHealthSnapshot.unavailable();
    });
  }

  Future<void> refreshDailyActivity({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _activityRefreshedAt != null &&
        now.difference(_activityRefreshedAt!) < const Duration(minutes: 1)) {
      return;
    }
    final gateway = _gateway;
    if (gateway is! ConnectedHealthDailyActivityGateway) {
      return;
    }
    await _runMutation(
      _HealthMutation.dailyActivity,
      () =>
          (gateway as ConnectedHealthDailyActivityGateway).loadDailyActivity(),
    );
    if (mounted && state.asData?.value.failureCode == null && !state.hasError) {
      _activityRefreshedAt = now;
    }
  }

  Future<ConnectedHealthSnapshot> _readNativeOnce() {
    // A visible timeout cannot cancel a HealthKit query. Retain its single
    // flight so another tap cannot start a competing importer/cache write.
    return _nativeSyncTask ??= _gateway.synchronize().whenComplete(() {
      _nativeSyncTask = null;
    });
  }

  Future<void> _runMutation(
    _HealthMutation kind,
    Future<ConnectedHealthSnapshot> Function() operation, {
    ConnectedHealthSnapshot Function(ConnectedHealthSnapshot current)?
    transition,
  }) {
    if (!mounted) return Future<void>.value();
    final existing = _mutationTask;
    if (existing != null && _mutationKind == kind) return existing;
    // Only duplicate adjacent actions share a future. A different explicit
    // action must run, even if a passive activity update is still in flight.
    // Capture both predecessors now, before publishing this task, so a later
    // refresh cannot form a wait cycle with this queued mutation.
    final activeRefresh = _refreshTask;
    late final Future<void> task;
    task =
        _performMutation(
          operation,
          previousMutation: existing,
          previousRefresh: activeRefresh,
          transition: transition,
        ).whenComplete(() {
          if (identical(_mutationTask, task)) {
            _mutationTask = null;
            _mutationKind = null;
          }
        });
    _mutationTask = task;
    _mutationKind = kind;
    return task;
  }

  Future<void> _performMutation(
    Future<ConnectedHealthSnapshot> Function() operation, {
    Future<void>? previousMutation,
    Future<void>? previousRefresh,
    ConnectedHealthSnapshot Function(ConnectedHealthSnapshot current)?
    transition,
  }) async {
    // A status read may already be running because the Apps & Devices page
    // was opened. Queue an explicit mutation behind it so it is never lost.
    if (previousMutation != null) await previousMutation;
    if (previousRefresh != null) await previousRefresh;
    if (!mounted) return;

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
    if (!mounted) return;
    state = result.when(
      data: (snapshot) => AsyncValue.data(snapshot.copyWith(isBusy: false)),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
      loading: () => current == null
          ? const AsyncValue.loading()
          : AsyncValue.data(current.copyWith(isBusy: false)),
    );
  }

  Future<void> refresh() {
    if (!mounted) return Future<void>.value();
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
      if (!mounted) return;

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
        // A passive screen paint or a generic foreground event must never
        // trigger an import from HealthKit/Health Connect. That import can
        // enumerate a large native history and was blocking unrelated routes.
        // `synchronize` remains an explicit action from Apps & Devices (or
        // immediately after a user grants permission).
        final loaded = await _gateway.load();
        if (!mounted) return;
        state = AsyncValue.data(loaded.copyWith(isBusy: false));
      } catch (error, stackTrace) {
        if (!mounted) return;
        // A lifecycle notification must not replace useful cached content with
        // a transient blank/error screen.
        // An empty initial state is not useful cached content. Preserve a real
        // prior snapshot, but expose the failed first status check so pages
        // can offer an honest retry instead of implying that no device exists.
        final hasUsableCachedSnapshot =
            previous != null &&
            (previous.deviceVerified ||
                previous.lastSyncAt != null ||
                previous.signals.isNotEmpty ||
                previous.stepHistory.isNotEmpty);
        state = hasUsableCachedSnapshot
            ? AsyncValue.data(
                previous.copyWith(
                  status: ConnectedHealthStatus.degraded,
                  failureCode: 'health_refresh_failed_offline_cache_preserved',
                  isBusy: false,
                ),
              )
            : AsyncValue.error(error, stackTrace);
      }
    } finally {
      _refreshTask = null;
    }
  }

  Future<void> synchronize() => _runMutation(
    _HealthMutation.synchronize,
    () async {
      try {
        return await _readNativeOnce().timeout(_synchronizationTimeout);
      } on TimeoutException {
        if (!mounted) return const ConnectedHealthSnapshot.unavailable();
        // Native reads cannot be cancelled safely once handed to HealthKit or
        // Health Connect. End the visible wait honestly instead of trapping
        // the whole Apps & Devices surface in a permanent busy state.
        return (state.value ?? const ConnectedHealthSnapshot.unavailable())
            .copyWith(
              status: ConnectedHealthStatus.degraded,
              failureCode: 'health_sync_timed_out',
            );
      }
    },
    transition: (current) => current.copyWith(
      status: ConnectedHealthStatus.syncing,
      clearFailure: true,
    ),
  );

  Future<void> requestPermissions() async {
    await _runMutation(_HealthMutation.permissions, () async {
      // Granting permission changes access only. Importing a native history is
      // intentionally deferred until the user presses Update watch.
      return _gateway.requestPermissions();
    });
  }

  Future<void> requestWeightWritePermission() async {
    await _runMutation(
      _HealthMutation.weightWritePermission,
      _gateway.requestWeightWritePermission,
    );
  }

  Future<void> revokePermissions() async {
    await _runMutation(_HealthMutation.revoke, _gateway.revokePermissions);
  }

  Future<void> openSystemSettings() async {
    await _runMutation(_HealthMutation.systemSettings, () async {
      await _gateway.openSystemSettings();
      if (!mounted) return const ConnectedHealthSnapshot.unavailable();
      return state.value ?? const ConnectedHealthSnapshot.unavailable();
    }, transition: (current) => current);
  }
}
