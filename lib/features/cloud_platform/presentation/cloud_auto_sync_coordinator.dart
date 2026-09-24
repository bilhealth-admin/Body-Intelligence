import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/environment/app_environment.dart';
import '../../../data/database/database_provider.dart';
import '../providers/cloud_sync_providers.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!AppEnvironment.supabaseRuntimeReady) return;
    final database = ref.read(databaseProvider);
    _watch(database.select(database.userProfile).watch());
    _watch(database.select(database.weightEntries).watch());
    _watch(database.select(database.waterEntries).watch());
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((value) => value != ConnectivityResult.none)) _schedule();
    });
  }

  void _watch(Stream<Object?> stream) {
    var initial = true;
    _subscriptions.add(
      stream.listen((_) {
        if (initial) {
          initial = false;
          return;
        }
        _schedule();
      }),
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(_sync()));
  }

  Future<void> _sync() async {
    if (_running || !mounted) return;
    _running = true;
    try {
      await ref
          .read(cloudManualSyncServiceProvider)
          .runOnce()
          .timeout(const Duration(seconds: 12));
    } on Object {
      // Durable dirty/outbox state remains owner-bound for the next retry.
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
