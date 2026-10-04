import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum NotificationCategory {
  newMessage,
  friendRequest,
  friendAccepted,
  friendWorkout,
  friendStreak,
  stepGoal,
}

class NotificationDeliveryPreferences {
  // These are the only categories implemented by the production push RPCs.
  // The reference-only categories stay unavailable rather than promising a
  // delivery producer that does not exist.
  static const supportedCategories = {
    NotificationCategory.newMessage,
    NotificationCategory.friendRequest,
    NotificationCategory.friendAccepted,
  };

  const NotificationDeliveryPreferences({
    this.enabledCategories = supportedCategories,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 7 * 60,
  });

  final Set<NotificationCategory> enabledCategories;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  bool allows(NotificationCategory category) =>
      supportedCategories.contains(category) &&
      enabledCategories.contains(category);

  Map<String, bool> get pushCategoryParameters => {
    'p_message_enabled': allows(NotificationCategory.newMessage),
    'p_friend_request_enabled': allows(NotificationCategory.friendRequest),
    'p_friend_accepted_enabled': allows(NotificationCategory.friendAccepted),
  };

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
    // setString updates the SDK cache even when platform persistence fails.
    // Reload the actual device record before interpreting an opt-out.
    await preferences.reload();
    final encoded = preferences.getString(key);
    if (encoded == null) return const NotificationDeliveryPreferences();
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final names = (value['enabledCategories'] as List<dynamic>)
          .cast<String>();
      final enabledCategories = names
          .map(NotificationCategory.values.byName)
          .where(NotificationDeliveryPreferences.supportedCategories.contains)
          .toSet();
      return NotificationDeliveryPreferences(
        enabledCategories: enabledCategories,
        quietHoursEnabled: value['quietHoursEnabled'] as bool? ?? false,
        quietStartMinutes: value['quietStartMinutes'] as int? ?? 22 * 60,
        quietEndMinutes: value['quietEndMinutes'] as int? ?? 7 * 60,
      );
    } on Object {
      // Existing unreadable state must not silently turn notifications ON.
      return const NotificationDeliveryPreferences(enabledCategories: {});
    }
  }

  Future<void> save(NotificationDeliveryPreferences value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      key,
      jsonEncode({
        'enabledCategories': value.enabledCategories
            .where(NotificationDeliveryPreferences.supportedCategories.contains)
            .map((e) => e.name)
            .toList(),
        'quietHoursEnabled': value.quietHoursEnabled,
        'quietStartMinutes': value.quietStartMinutes,
        'quietEndMinutes': value.quietEndMinutes,
      }),
    );
    if (!saved) {
      throw StateError('Notification preferences were not persisted');
    }
  }
}
