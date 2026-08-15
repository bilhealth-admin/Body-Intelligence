import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/localization/app_localizations.dart';
import '../domain/daily_reminder.dart';
import 'bil_notification_service.dart';
import 'daily_reminder_store.dart';

/// Keeps the optional 24-hour return reminder aligned with real app absence.
/// It never requests permission or enables itself; the user controls that in
/// the notification center. Resuming the app always clears a pending prompt.
class InactivityReminderCoordinator extends StatefulWidget {
  const InactivityReminderCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<InactivityReminderCoordinator> createState() =>
      _InactivityReminderCoordinatorState();
}

class _InactivityReminderCoordinatorState
    extends State<InactivityReminderCoordinator>
    with WidgetsBindingObserver {
  final _store = DailyReminderStore();
  final _notifications = BilNotificationService(
    FlutterLocalNotificationsPlugin(),
  );
  bool _backgroundHandled = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_cancelSafely());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _generation += 1;
      _backgroundHandled = false;
      unawaited(_cancelSafely());
      return;
    }
    if (state != AppLifecycleState.paused || _backgroundHandled) return;
    _backgroundHandled = true;
    final generation = ++_generation;
    unawaited(_scheduleIfEnabled(generation));
  }

  Future<void> _scheduleIfEnabled(int generation) async {
    try {
      final reminders = await _store.load();
      if (generation != _generation || !_backgroundHandled) return;
      final enabled = reminders.any(
        (item) =>
            item.kind == DailyReminderKind.returnAfter24Hours && item.enabled,
      );
      if (!enabled) {
        await _notifications.cancelReturnAfter24Hours();
        return;
      }
      await _notifications.scheduleReturnAfter24Hours(
        leftAt: DateTime.now(),
        languageCode: AppLocalizations.activeLocale.languageCode,
      );
      if (generation != _generation || !_backgroundHandled) {
        await _cancelSafely();
      }
    } on Object {
      // Lifecycle work must never interrupt or crash the user's foreground
      // session. The next resume/background transition safely retries.
    }
  }

  Future<void> _cancelSafely() async {
    try {
      await _notifications.cancelReturnAfter24Hours();
    } on Object {
      // A platform-channel failure is retried on the next lifecycle edge.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
