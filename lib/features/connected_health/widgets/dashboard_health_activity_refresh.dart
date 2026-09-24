import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connected_health_provider.dart';

/// The first dashboard follows startup for existing users and completion for
/// new users. Offer unanswered iOS Health questions there once, then read only
/// consented daily activity totals. Full history stays an explicit action.
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
    if (!mounted) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await controller.requestStartupPermissions();
    }
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
