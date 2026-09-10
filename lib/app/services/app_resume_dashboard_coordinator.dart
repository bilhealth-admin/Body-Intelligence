import 'package:flutter/material.dart';

/// Distinguishes a meaningful return from transient permission sheets and
/// short task switches. Duplicate hidden/paused callbacks keep the earliest
/// background timestamp so platform lifecycle ordering cannot extend it.
final class MeaningfulResumePolicy {
  MeaningfulResumePolicy({
    this.threshold = const Duration(minutes: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration threshold;
  final DateTime Function() _now;
  DateTime? _backgroundedAt;

  bool handle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundedAt ??= _now();
        return false;
      case AppLifecycleState.inactive:
        // Native permission and picker sheets commonly emit inactive without
        // backgrounding the app. Preserve the current route and user input.
        return false;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt == null) return false;
        return _now().difference(backgroundedAt) >= threshold;
    }
  }
}

class AppResumeDashboardCoordinator extends StatefulWidget {
  const AppResumeDashboardCoordinator({
    required this.child,
    required this.onMeaningfulResume,
    this.threshold = const Duration(minutes: 30),
    this.now,
    super.key,
  });

  final Widget child;
  final VoidCallback onMeaningfulResume;
  final Duration threshold;
  final DateTime Function()? now;

  @override
  State<AppResumeDashboardCoordinator> createState() =>
      _AppResumeDashboardCoordinatorState();
}

class _AppResumeDashboardCoordinatorState
    extends State<AppResumeDashboardCoordinator>
    with WidgetsBindingObserver {
  late MeaningfulResumePolicy _policy;
  int _resumeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _policy = _createPolicy();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(AppResumeDashboardCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threshold != widget.threshold ||
        oldWidget.now != widget.now) {
      _policy = _createPolicy();
    }
  }

  MeaningfulResumePolicy _createPolicy() =>
      MeaningfulResumePolicy(threshold: widget.threshold, now: widget.now);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final generation = ++_resumeGeneration;
    if (!_policy.handle(state)) return;
    // Let MediaQuery and the native viewport settle before refreshing data.
    // Never replace the route synchronously inside a lifecycle callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _resumeGeneration &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        widget.onMeaningfulResume();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
