import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android owns the outer notification surface. This class supplies a
/// consistent BIL identity and an expanded, privacy-conscious presentation
/// without imitating an in-app card or a specific OEM skin.
class BilAndroidNotificationPresentation {
  const BilAndroidNotificationPresentation._();

  static const brandColor = Color(0xFF0877F9);
  static const smallIcon = 'ic_stat_bil_notification';
  static const brandLine = 'BIL · Body Intelligence Log';
  static const dailyGroupKey =
      'com.bilhealth.bodyintelligencelog.DAILY_REMINDERS';

  static AndroidNotificationDetails rich({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    String? groupKey,
    bool ongoing = false,
    bool autoCancel = true,
    bool usesChronometer = false,
    bool chronometerCountDown = false,
    int? when,
    int? timeoutAfter,
    bool showWhen = true,
    bool playSound = true,
    bool enableVibration = true,
    AndroidNotificationCategory category = AndroidNotificationCategory.reminder,
  }) => AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    icon: smallIcon,
    color: brandColor,
    visibility: NotificationVisibility.private,
    category: category,
    subText: brandLine,
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: brandLine,
    ),
    importance: importance,
    priority: priority,
    groupKey: groupKey,
    ongoing: ongoing,
    autoCancel: autoCancel,
    usesChronometer: usesChronometer,
    chronometerCountDown: chronometerCountDown,
    when: when,
    timeoutAfter: timeoutAfter,
    showWhen: showWhen,
    playSound: playSound,
    enableVibration: enableVibration,
  );

  static AndroidNotificationDetails dailySummary({
    required String title,
    required String body,
    required List<String> lines,
  }) => AndroidNotificationDetails(
    'bil_daily_health',
    'Daily reminders',
    channelDescription:
        'Private daily reminders you choose in Body Intelligence Log.',
    icon: smallIcon,
    color: brandColor,
    visibility: NotificationVisibility.private,
    category: AndroidNotificationCategory.reminder,
    subText: brandLine,
    styleInformation: InboxStyleInformation(
      lines,
      contentTitle: title,
      summaryText: brandLine,
    ),
    groupKey: dailyGroupKey,
    setAsGroupSummary: true,
    groupAlertBehavior: GroupAlertBehavior.children,
    silent: true,
    onlyAlertOnce: true,
  );
}
