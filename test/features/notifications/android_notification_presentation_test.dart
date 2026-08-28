import 'dart:io';

import 'package:body_intelligence_log/features/notifications/domain/daily_reminder.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_android_notification_presentation.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_navigation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(BilNotificationNavigation.resetForTesting);

  test(
    'every Android reminder payload resolves to its direct audited route',
    () {
      const expected = <DailyReminderKind, String>{
        DailyReminderKind.weight: '/daily-check-in',
        DailyReminderKind.meals: '/daily-log?focus=meal',
        DailyReminderKind.water: '/daily-log/water',
        DailyReminderKind.sleep: '/wellness/sleep',
        DailyReminderKind.fasting: '/wellness/fasting',
        DailyReminderKind.weeklyReview: '/weekly-report',
        DailyReminderKind.returnAfter24Hours: '/dashboard',
      };

      for (final entry in expected.entries) {
        expect(
          BilNotificationNavigation.routeForPayload(
            BilNotificationPayload.forDaily(entry.key),
          ),
          entry.value,
          reason: entry.key.name,
        );
      }
    },
  );

  test(
    'legacy scheduled payloads survive upgrade and unsafe input is rejected',
    () {
      const legacy = <String, String>{
        'notification_activation_check': '/notification-settings',
        'weight': '/daily-check-in',
        'meals': '/daily-log?focus=meal',
        'water': '/daily-log/water',
        'fasting_target': '/wellness/fasting',
        'fasting_active': '/wellness/fasting',
        'fasting_hydration': '/wellness/fasting',
        'sleep_windDown': '/wellness/sleep',
        'sleep_bedtime': '/wellness/sleep',
        'sleep_wake': '/wellness/sleep',
        'return_after_24_hours': '/dashboard',
      };
      for (final entry in legacy.entries) {
        expect(
          BilNotificationNavigation.routeForPayload(entry.key),
          entry.value,
          reason: entry.key,
        );
      }

      expect(BilNotificationNavigation.routeForPayload(null), isNull);
      expect(BilNotificationNavigation.routeForPayload('/dashboard'), isNull);
      expect(
        BilNotificationNavigation.routeForPayload('https://bilhealth.com'),
        isNull,
      );
      expect(
        BilNotificationNavigation.routeForPayload('bil://unknown/route'),
        isNull,
      );
      expect(
        BilNotificationNavigation.routeForPayload(List.filled(513, 'x').join()),
        isNull,
      );
    },
  );

  test('notification tap waits safely until the app router is configured', () {
    final routes = <String>[];
    BilNotificationNavigation.handlePayload('bil://weekly-report');
    expect(routes, isEmpty);

    BilNotificationNavigation.configure(navigate: routes.add);
    expect(routes, const ['/weekly-report']);

    BilNotificationNavigation.handlePayload('bil://daily-log?focus=meal');
    expect(routes, const ['/weekly-report', '/daily-log?focus=meal']);
  });

  test('rich Android presentation uses BIL identity and BigTextStyle', () {
    final details = BilAndroidNotificationPresentation.rich(
      channelId: 'test_channel',
      channelName: 'Readable test channel',
      channelDescription: 'A clear channel description.',
      title: 'Your weekly review is ready',
      body: 'Review evidence before changing your plan.',
    );

    expect(details.channelId, 'test_channel');
    expect(details.channelName, 'Readable test channel');
    expect(details.channelDescription, 'A clear channel description.');
    expect(details.icon, 'ic_stat_bil_notification');
    expect(details.color?.toARGB32(), 0xFF0877F9);
    expect(details.visibility, NotificationVisibility.private);
    expect(details.category, AndroidNotificationCategory.reminder);
    expect(details.subText, 'BIL · Body Intelligence Log');
    expect(details.styleInformation, isA<BigTextStyleInformation>());
    final style = details.styleInformation! as BigTextStyleInformation;
    expect(style.contentTitle, 'Your weekly review is ready');
    expect(style.bigText, 'Review evidence before changing your plan.');
  });

  test('multiple daily reminders receive one silent InboxStyle summary', () {
    final details = BilAndroidNotificationPresentation.dailySummary(
      title: 'BIL',
      body: 'Today’s check-in · Log your meal',
      lines: const [
        'Today’s check-in: Log weight under consistent conditions.',
        'Log your meal: Capture what you ate while it is fresh.',
      ],
    );

    expect(details.groupKey, contains('DAILY_REMINDERS'));
    expect(details.setAsGroupSummary, isTrue);
    expect(details.groupAlertBehavior, GroupAlertBehavior.children);
    expect(details.silent, isTrue);
    expect(details.onlyAlertOnce, isTrue);
    expect(details.styleInformation, isA<InboxStyleInformation>());
    expect(
      (details.styleInformation! as InboxStyleInformation).lines,
      hasLength(2),
    );
  });

  test('small icon and Android tap wiring remain production safe', () {
    final icon = File(
      'android/app/src/main/res/drawable/ic_stat_bil_notification.xml',
    ).readAsStringSync();
    final platform = File(
      'lib/features/notifications/services/bil_daily_notification_grouping.dart',
    ).readAsStringSync();
    final presentation = File(
      'lib/features/notifications/services/bil_android_notification_presentation.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/features/notifications/services/inactivity_reminder_coordinator.dart',
    ).readAsStringSync();

    expect(icon, contains('<vector'));
    expect(icon, contains('android:fillColor="#FFFFFFFF"'));
    expect(icon, isNot(contains('<bitmap')));
    expect(icon, isNot(contains('<gradient')));
    expect(
      platform,
      contains("AndroidInitializationSettings('ic_stat_bil_notification')"),
    );
    expect(platform, contains('onDidReceiveNotificationResponse: isAndroid'));
    expect(platform, contains('getNotificationAppLaunchDetails()'));
    expect(platform, contains('payload: BilNotificationPayload.dashboard'));
    expect(presentation, contains('setAsGroupSummary: true'));
    expect(coordinator, contains('TargetPlatform.android'));
    expect(coordinator, contains('BilNotificationNavigation.configure'));
  });
}
