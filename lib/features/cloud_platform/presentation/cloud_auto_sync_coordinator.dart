import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/database/database_provider.dart';
import '../../../data/database/app_database.dart';
import '../providers/cloud_sync_providers.dart';
import '../services/cloud_manual_sync_service.dart';

/// The guarded production service remains the sole transport implementation.
/// Keeping its trigger as a provider lets isolated SQLite scheduling tests hold
/// a run without replacing account authorization or the platform service.
final cloudAutoSyncRunnerProvider =
    Provider<Future<CloudManualSyncResult> Function()>((ref) {
      return ref.watch(cloudManualSyncServiceProvider).runOnce;
    });

final cloudAutoSyncConnectivityChangesProvider =
    Provider<Stream<List<ConnectivityResult>>>((ref) {
      return Connectivity().onConnectivityChanged;
    });

/// Process-wide bridge used by explicit sign-out entry points.
///
/// It performs only a bounded best-effort flush. Durable owner-bound pending
/// rows remain intact when offline or when the deadline expires.
final class CloudBeforeSignOutSync {
  CloudBeforeSignOutSync._();

  static Future<void> Function()? _runner;

  static void install(Future<void> Function() runner) => _runner = runner;

  static void uninstall() => _runner = null;

  static Future<void> runBounded() async {
    final runner = _runner;
    if (runner == null) return;
    try {
      await runner().timeout(const Duration(seconds: 12));
    } on Object {
      // Sign-out must remain available offline. The durable queue is retained.
    }
  }
}

/// Best-effort transport trigger for durable, supported local mutations.
/// Local writes are authoritative and are never awaited by this widget.
class CloudAutoSyncCoordinator extends ConsumerStatefulWidget {
  const CloudAutoSyncCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CloudAutoSyncCoordinator> createState() =>
      _CloudAutoSyncCoordinatorState();
}

class _CloudAutoSyncCoordinatorState
    extends ConsumerState<CloudAutoSyncCoordinator>
    with WidgetsBindingObserver {
  final _subscriptions = <StreamSubscription<Object?>>[];
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _debounce;
  bool _running = false;
  bool _queuedMutation = false;
  int _visit = 0;
  int _automaticContinuations = 0;
  AppDatabase? _boundDatabase;
  ProviderSubscription<AppDatabase>? _databaseBinding;
  static const _maximumAutomaticContinuations = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CloudBeforeSignOutSync.install(_sync);
    if (!AppEnvironment.supabaseRuntimeReady) return;
    _databaseBinding = ref.listenManual<AppDatabase>(
      databaseProvider,
      (_, database) => _bindDatabase(database),
      fireImmediately: true,
    );
    _connectivity = ref.read(cloudAutoSyncConnectivityChangesProvider).listen((
      results,
    ) {
      if (results.any((value) => value != ConnectivityResult.none)) _schedule();
    });
  }

  void _bindDatabase(AppDatabase database) {
    if (identical(database, _boundDatabase)) return;
    _boundDatabase = database;
    _visit++;
    _debounce?.cancel();
    _queuedMutation = false;
    _automaticContinuations = 0;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _watch(database.select(database.userProfile).watch());
    _watch(database.select(database.weightEntries).watch());
    _watch(database.select(database.waterEntries).watch());
    _watch(database.select(database.foods).watch());
    _watch(database.select(database.meals).watch());
    _watch(database.select(database.mealItems).watch());
    // Distinct content avoids a restore/status preference writing a perpetual
    // sync loop. New scopes remain gated by explicit consent in the service.
    _watch(
      database
          .select(database.preferences)
          .watch()
          .map(
            (rows) => {
              for (final row in rows.where(
                (r) =>
                    r.key.startsWith('goal.') ||
                    r.key == 'goals.nutritionSchedule.v1' ||
                    r.key == 'nutrition.trustedRecipes.v1',
              ))
                row.key: row.value,
            },
          )
          .distinct(mapEquals),
    );
  }

  void _watch(Stream<Object?> stream) {
    final visit = _visit;
    var initial = true;
    _subscriptions.add(
      stream.listen((_) {
        if (!mounted || visit != _visit) return;
        if (initial) {
          initial = false;
          return;
        }
        _schedule();
      }),
    );
  }

  void _schedule({bool continuation = false}) {
    if (!mounted) return;
    if (!continuation) _automaticContinuations = 0;
    if (_running) {
      _queuedMutation = true;
      return;
    }
    final visit = _visit;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      if (mounted && visit == _visit) unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    if (!mounted) return;
    if (_running) {
      _queuedMutation = true;
      return;
    }
    _debounce?.cancel();
    _running = true;
    _queuedMutation = false;
    final operation = _runForVisit(_visit);
    try {
      await operation.timeout(const Duration(seconds: 12));
    } on Object {
      // The caller is bounded; SDK work retains the fence until it settles.
    }
  }

  Future<void> _runForVisit(int visit) async {
    var continuePending = false;
    try {
      final result = await ref.read(cloudAutoSyncRunnerProvider).call();
      if (mounted &&
          visit == _visit &&
          result.ownerId == _boundDatabase?.localOwnerId) {
        continuePending =
            result.disposition == CloudManualSyncDisposition.partial &&
            result.conflicts == 0 &&
            (result.reason == 'pending_local_changes' ||
                result.reason == 'page_limit') &&
            (result.pending > 0 || result.pushed > 0 || result.pulled > 0) &&
            _automaticContinuations < _maximumAutomaticContinuations;
      }
    } on Object {
      // Durable state remains available for a fresh mutation or user retry.
    } finally {
      _running = false;
      if (mounted) {
        if (_queuedMutation) {
          _queuedMutation = false;
          _schedule();
        } else if (continuePending && visit == _visit) {
          _automaticContinuations++;
          _schedule(continuation: true);
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    CloudBeforeSignOutSync.uninstall();
    WidgetsBinding.instance.removeObserver(this);
    _visit++;
    _queuedMutation = false;
    _databaseBinding?.close();
    _debounce?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_connectivity?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
