import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory {
  newMessage,
  friendRequest,
  friendWorkout,
  friendStreak,
  stepGoal,
}

class NotificationDeliveryPreferences {
  const NotificationDeliveryPreferences({
    this.enabledCategories = const {
      NotificationCategory.newMessage,
      NotificationCategory.friendRequest,
      NotificationCategory.friendWorkout,
      NotificationCategory.friendStreak,
      NotificationCategory.stepGoal,
    },
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
  });

  final Set<NotificationCategory> enabledCategories;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  bool allows(NotificationCategory category) =>
      enabledCategories.contains(category);

  bool shouldPresent(NotificationCategory category, DateTime localTime) =>
      allows(category) && !isQuietAt(localTime.hour, localTime.minute);

  bool isQuietAt(int hour, int minute) {
    if (!quietHoursEnabled) return false;
    final value = hour * 60 + minute;
    if (quietStartMinutes == quietEndMinutes) return true;
    return quietStartMinutes < quietEndMinutes
        ? value >= quietStartMinutes && value < quietEndMinutes
        : value >= quietStartMinutes || value < quietEndMinutes;
  }

  NotificationDeliveryPreferences copyWith({
    Set<NotificationCategory>? enabledCategories,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) => NotificationDeliveryPreferences(
    enabledCategories: enabledCategories ?? this.enabledCategories,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
    quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
  );
}

class NotificationDeliveryPreferencesStore {
  static const key = 'bil.notification-delivery-preferences.v1';

  Future<NotificationDeliveryPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null) return const NotificationDeliveryPreferences();
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final names = (value['enabledCategories'] as List<dynamic>)
          .cast<String>();
      return NotificationDeliveryPreferences(
        enabledCategories: names
            .map(NotificationCategory.values.byName)
            .toSet(),
        quietHoursEnabled: value['quietHoursEnabled'] as bool? ?? false,
        quietStartMinutes: value['quietStartMinutes'] as int? ?? 22 * 60,
        quietEndMinutes: value['quietEndMinutes'] as int? ?? 7 * 60,
      );
    } on Object {
      return const NotificationDeliveryPreferences();
    }
  }

  Future<void> save(NotificationDeliveryPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      key,
      jsonEncode({
        'enabledCategories': value.enabledCategories
            .map((e) => e.name)
            .toList(),
        'quietHoursEnabled': value.quietHoursEnabled,
        'quietStartMinutes': value.quietStartMinutes,
        'quietEndMinutes': value.quietEndMinutes,
      }),
    );
  }
}
