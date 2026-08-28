import 'package:body_intelligence_log/features/notifications/domain/daily_reminder.dart';
import 'package:body_intelligence_log/features/notifications/domain/notification_delivery_preferences.dart';
import 'package:body_intelligence_log/features/notifications/presentation/notification_settings_page.dart';
import 'package:body_intelligence_log/features/notifications/services/bil_notification_service.dart';
import 'package:body_intelligence_log/features/notifications/services/daily_reminder_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('permission probe failure does not hide saved reminders', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: NotificationSettingsPage(
            reminderStore: _ReminderStore(),
            deliveryStore: _DeliveryStore(),
            notificationService: _NotificationService(probeFails: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Saved setting could not be loaded. Tap to retry.'),
      findsNothing,
    );
    expect(
      find.text('Permission status is unavailable. Check phone settings.'),
      findsOneWidget,
    );
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.byKey(const Key('add-reminder')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('daily-reminder-weight')),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('daily-reminder-weight')), findsOneWidget);
  });

  testWidgets('pending request is reported as scheduled on this phone', (
    tester,
  ) async {
    const reminder = DailyReminder(
      kind: DailyReminderKind.weight,
      hour: 8,
      minute: 0,
      enabled: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: NotificationSettingsPage(
            reminderStore: _ReminderStore(reminders: const [reminder]),
            deliveryStore: _DeliveryStore(),
            notificationService: _NotificationService(pendingIds: const {7100}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('daily-reminder-status-weight')),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('daily-reminder-status-weight')),
      findsOneWidget,
    );
    expect(find.text('Scheduled on this phone'), findsOneWidget);
  });
}

class _ReminderStore extends DailyReminderStore {
  _ReminderStore({this.reminders = DailyReminderStore.defaults});

  final List<DailyReminder> reminders;

  @override
  Future<List<DailyReminder>> load() async => reminders;

  @override
  Future<void> save(List<DailyReminder> reminders) async {}
}

class _DeliveryStore extends NotificationDeliveryPreferencesStore {
  @override
  Future<NotificationDeliveryPreferences> load() async =>
      const NotificationDeliveryPreferences();

  @override
  Future<void> save(NotificationDeliveryPreferences value) async {}
}

class _NotificationService extends BilNotificationService {
  _NotificationService({this.probeFails = false, this.pendingIds = const {}})
    : super(FlutterLocalNotificationsPlugin());

  final bool probeFails;
  final Set<int> pendingIds;

  @override
  Future<BilNotificationPermissionState> permissionState() async {
    if (probeFails) throw StateError('platform permission channel unavailable');
    return BilNotificationPermissionState.granted;
  }

  @override
  Future<Set<int>> pendingNotificationIds() async => pendingIds;
}
