import 'dart:async';

import 'package:flutter/widgets.dart';

import 'cloud_manual_sync_service.dart';

/// Keeps the durable cloud outbox moving while the authenticated product shell
/// is active. Local writes remain authoritative; a failed attempt is harmless
/// because the dirty row and encrypted outbox entry stay on disk for retry.
final class CloudAutoSyncController with WidgetsBindingObserver {
  CloudAutoSyncController({
    required this.runSync,
    this.interval = const Duration(seconds: 30),
  });

  final Future<CloudManualSyncResult> Function() runSync;
  final Duration interval;

  Timer? _timer;
  Future<void>? _inFlight;
  bool _disposed = false;
  bool _active = true;

  bool get isRunning => !_disposed;

  void start() {
    if (_disposed || _timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _active = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _timer = Timer.periodic(interval, (_) {
      if (_active) unawaited(requestSync());
    });
    if (_active) unawaited(requestSync());
  }

  /// Best-effort flush. It is deliberately not the sole durability boundary:
  /// iOS and Android may terminate the process without granting an exit hook.
  Future<void> requestSync() {
    if (_disposed || !_active || _inFlight != null) return Future<void>.value();
    final operation = _performSync();
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<void> _performSync() async {
    try {
      await runSync();
    } on Object {
      // Offline, missing consent, a rotated session, and a transient server
      // error are all retryable. Never clear the local dirty state here.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _active = true;
        unawaited(requestSync());
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Start one final best-effort pass before pausing. The durable outbox
        // remains the guarantee if the OS suspends or kills the process.
        if (_active) unawaited(requestSync());
        _active = false;
      case AppLifecycleState.inactive:
        // iOS can enter inactive briefly for system UI; keep the worker alive.
        break;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
