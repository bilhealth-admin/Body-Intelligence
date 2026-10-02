import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connected_health_provider.dart';

/// Restores previously verified health evidence and refreshes daily activity
/// only for users who already granted the relevant platform access.
/// Native Health permissions are requested only from an explicit user action
/// in Apps & Devices; passive dashboard startup never opens a permission sheet.
class DashboardHealthActivityRefresh extends ConsumerStatefulWidget {
  const DashboardHealthActivityRefresh({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<DashboardHealthActivityRefresh> createState() =>
      _DashboardHealthActivityRefreshState();
}

class _DashboardHealthActivityRefreshState
    extends ConsumerState<DashboardHealthActivityRefresh>
    with WidgetsBindingObserver {
  Future<void>? _refreshTask;
  Timer? _foregroundTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start the local-only projection read immediately. Native activity refresh
    // waits for the first rendered frame, but permission prompts are never
    // initiated from this passive dashboard lifecycle.
    unawaited(
      ref.read(connectedHealthProvider.notifier).restoreCachedSnapshot(),
    );
    _schedule();
    _startForegroundTimer();
  }

  void _startForegroundTimer() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _schedule(),
    );
  }

  void _schedule() {
    if (kIsWeb ||
        !{
          TargetPlatform.iOS,
          TargetPlatform.android,
        }.contains(defaultTargetPlatform)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshTask ??= _refresh().whenComplete(() => _refreshTask = null);
      }
    });
  }

  Future<void> _refresh() async {
    final controller = ref.read(connectedHealthProvider.notifier);
    await controller.restoreCachedSnapshot();
    if (mounted) await controller.refreshDailyActivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _schedule();
      _startForegroundTimer();
      return;
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
