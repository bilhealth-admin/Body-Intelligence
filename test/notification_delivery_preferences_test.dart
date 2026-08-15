import 'dart:io';

import 'package:body_intelligence_log/features/notifications/domain/notification_delivery_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category preferences gate lock-screen presentation', () {
    final preferences = NotificationDeliveryPreferences(
      enabledCategories: const {NotificationCategory.newMessage},
    );
    expect(
      preferences.shouldPresent(
        NotificationCategory.newMessage,
        DateTime(2026, 8, 10, 12),
      ),
      isTrue,
    );
    expect(
      preferences.shouldPresent(
        NotificationCategory.friendRequest,
        DateTime(2026, 8, 10, 12),
      ),
      isFalse,
    );
  });

  test('overnight quiet hours suppress presentation across midnight', () {
    const preferences = NotificationDeliveryPreferences(
      quietHoursEnabled: true,
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 7 * 60,
    );
    expect(preferences.isQuietAt(23, 0), isTrue);
    expect(preferences.isQuietAt(6, 59), isTrue);
    expect(preferences.isQuietAt(7, 0), isFalse);
    expect(preferences.isQuietAt(14, 0), isFalse);
  });

  test('settings and scheduler consume the persisted delivery contract', () {
    final page = File(
      'lib/features/notifications/presentation/notification_settings_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/notifications/services/bil_notification_service.dart',
    ).readAsStringSync();
    for (final category in NotificationCategory.values) {
      expect(page, contains('NotificationCategory.${category.name}'));
    }
    expect(page, contains('quietHoursEnabled'));
    expect(page, contains('_deliveryStore.save'));
    expect(service, contains('preferences.isQuietAt'));
    expect(service, contains('quietEndMinutes'));
  });
}
