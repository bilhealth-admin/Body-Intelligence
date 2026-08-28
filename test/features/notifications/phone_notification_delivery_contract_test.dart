import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android can deliver and restore scheduled BIL notifications', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationReceiver'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
  });

  test('notification settings expose a real permission and delivery check', () {
    final service = File(
      'lib/features/notifications/services/bil_notification_service.dart',
    ).readAsStringSync();
    final page = File(
      'lib/features/notifications/presentation/notification_settings_page.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/features/notifications/presentation/notification_settings_actions.dart',
    ).readAsStringSync();
    final presentation = File(
      'lib/features/notifications/services/bil_android_notification_presentation.dart',
    ).readAsStringSync();
    final platform = File(
      'lib/features/notifications/services/bil_daily_notification_grouping.dart',
    ).readAsStringSync();

    expect(service, contains('areNotificationsEnabled()'));
    expect(service, contains('permissionState()'));
    expect(service, contains('pendingNotificationIds()'));
    expect(service, contains('openSystemSettings()'));
    expect(service, contains('showActivationConfirmation'));
    expect(service, contains('fastingOngoingNotificationId'));
    expect(service, contains('usesChronometer: true'));
    expect(service, contains('chronometerCountDown: true'));
    expect(service, contains('timeoutAfter: remainingMillis'));
    expect(
      service,
      contains('!target.isAfter(DateTime.now())'),
      reason: 'An expired fast must not leave an ongoing notification.',
    );
    expect(service, contains('scheduleFastingHydration'));
    expect(service, contains('cancelFastingSessionNotifications'));
    expect(service, contains('scheduleSleepSchedule'));
    expect(service, contains('sleepWindDownNotificationId'));
    expect(service, contains('sleepBedtimeNotificationId'));
    expect(service, contains('sleepWakeNotificationId'));
    expect(
      service,
      contains('matchDateTimeComponents: DateTimeComponents.time'),
    );
    expect(service, contains("'bil_system_check'"));
    expect(
      platform,
      contains("AndroidInitializationSettings('ic_stat_bil_notification')"),
    );
    expect(presentation, contains("smallIcon = 'ic_stat_bil_notification'"));
    expect(presentation, contains('BigTextStyleInformation'));
    expect(presentation, contains('InboxStyleInformation'));
    expect(presentation, contains('NotificationVisibility.private'));
    expect(actions, contains('scheduleDailyGroupSummary'));
    expect(page, contains("Key('notification-phone-check')"));
    expect(actions, contains('_sendNotificationCheck'));
    expect(actions, contains('showActivationConfirmation'));
    expect(actions, contains('await _refreshSystemStatus()'));
    expect(actions, isNot(contains('_service.areNotificationsEnabled()')));
  });
}
