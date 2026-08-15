import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '24-hour reminder is opt-in, scheduled on pause, and cancelled on resume',
    () {
      final source = File(
        'lib/features/notifications/services/inactivity_reminder_coordinator.dart',
      ).readAsStringSync();
      final service = File(
        'lib/features/notifications/services/bil_notification_service.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('DailyReminderKind.returnAfter24Hours && item.enabled'),
      );
      expect(service, contains('leftAt.add(const Duration(hours: 24))'));
      expect(source, contains('scheduleReturnAfter24Hours('));
      expect(source, contains('cancelReturnAfter24Hours()'));
      expect(source, contains('AppLifecycleState.paused'));
      expect(source, contains('AppLifecycleState.resumed'));
    },
  );
}
