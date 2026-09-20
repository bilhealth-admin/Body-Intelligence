part of 'bil_notification_service.dart';

const _dailyGroupSummaryNotificationId = 7199;

extension BilNotificationPlatformInitialization on BilNotificationService {
  Future<void> _initializeNotificationPlatform() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on tz.LocationNotFoundException {
      tz.setLocalLocation(tz.UTC);
    }
    final platform = defaultTargetPlatform;
    final supportsNotificationNavigation =
        !kIsWeb && BilNotificationNavigation.supportsPlatform(platform);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_bil_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: supportsNotificationNavigation
          ? (response) {
              if (response.notificationResponseType ==
                  NotificationResponseType.notificationDismissed) {
                return;
              }
              BilNotificationNavigation.handlePayload(response.payload);
            }
          : null,
    );
    _initialized = true;
    if (!supportsNotificationNavigation ||
        !BilNotificationService._launchDetailsHandledPlatforms.add(platform)) {
      return;
    }
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        BilNotificationNavigation.handlePayload(
          launch?.notificationResponse?.payload,
        );
      }
    } on Object {
      // Scheduling remains usable if the native platform cannot report launch
      // metadata. A later service instance may retry the one-time lookup.
      BilNotificationService._launchDetailsHandledPlatforms.remove(platform);
    }
  }
}

extension BilDailyNotificationGrouping on BilNotificationService {
  /// Adds one Android InboxStyle summary only when at least two daily
  /// reminders are enabled. Child notifications remain the alerting items;
  /// the summary is silent and exists solely to keep the system shade tidy.
  Future<void> scheduleDailyGroupSummary(
    List<DailyReminder> reminders, {
    required String languageCode,
    NotificationDeliveryPreferences preferences =
        const NotificationDeliveryPreferences(),
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await initialize();
    await _plugin.cancel(id: _dailyGroupSummaryNotificationId);

    final enabled = reminders
        .where(
          (item) =>
              item.enabled && item.kind != DailyReminderKind.returnAfter24Hours,
        )
        .toList(growable: false);
    if (enabled.length < 2 ||
        (preferences.quietHoursEnabled &&
            preferences.quietStartMinutes == preferences.quietEndMinutes)) {
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final occurrences = <tz.TZDateTime>[
      for (final reminder in enabled)
        _nextDailyOccurrence(reminder, preferences, now),
    ]..sort();
    final copies = <(String, String)>[
      for (final reminder in enabled) _copy(reminder.kind, languageCode),
    ];
    final lines = <String>[for (final copy in copies) '${copy.$1}: ${copy.$2}'];
    final body = copies.map((copy) => copy.$1).join(' · ');

    await _plugin.zonedSchedule(
      id: _dailyGroupSummaryNotificationId,
      title: '🔔 BIL',
      body: body,
      scheduledDate: occurrences.first,
      notificationDetails: NotificationDetails(
        android: BilAndroidNotificationPresentation.dailySummary(
          title: '🔔 BIL',
          body: body,
          lines: lines,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: BilNotificationPayload.dashboard,
    );
  }
}

tz.TZDateTime _nextDailyOccurrence(
  DailyReminder reminder,
  NotificationDeliveryPreferences preferences,
  tz.TZDateTime now,
) {
  var at = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    reminder.hour,
    reminder.minute,
  );
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  if (!preferences.isQuietAt(at.hour, at.minute)) return at;

  final endHour = preferences.quietEndMinutes ~/ 60;
  final endMinute = preferences.quietEndMinutes % 60;
  var quietEnd = tz.TZDateTime(
    tz.local,
    at.year,
    at.month,
    at.day,
    endHour,
    endMinute,
  );
  if (!quietEnd.isAfter(at)) quietEnd = quietEnd.add(const Duration(days: 1));
  return quietEnd;
}
