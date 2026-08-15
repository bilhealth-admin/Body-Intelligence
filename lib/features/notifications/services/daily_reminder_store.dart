import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/daily_reminder.dart';

class DailyReminderStore {
  static const _key = 'bil.daily-reminders.v1';

  Future<List<DailyReminder>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return defaults;
    try {
      final rows = jsonDecode(encoded) as List<dynamic>;
      final parsed = <DailyReminder>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final kindName = row['kind'];
        final hour = row['hour'];
        final minute = row['minute'];
        final enabled = row['enabled'];
        if (kindName is! String ||
            hour is! int ||
            minute is! int ||
            enabled is! bool ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59) {
          continue;
        }
        final kind = DailyReminderKind.values
            .where((value) => value.name == kindName)
            .firstOrNull;
        if (kind == null || parsed.any((item) => item.kind == kind)) continue;
        parsed.add(
          DailyReminder(
            kind: kind,
            hour: hour,
            minute: minute,
            enabled: enabled,
          ),
        );
      }
      return [
        for (final fallback in defaults)
          parsed.where((item) => item.kind == fallback.kind).firstOrNull ??
              fallback,
      ];
    } on Object {
      return defaults;
    }
  }

  Future<void> save(List<DailyReminder> reminders) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(
        reminders
            .map(
              (item) => {
                'kind': item.kind.name,
                'hour': item.hour,
                'minute': item.minute,
                'enabled': item.enabled,
              },
            )
            .toList(growable: false),
      ),
    );
  }

  static const defaults = <DailyReminder>[
    DailyReminder(kind: DailyReminderKind.weight, hour: 8, minute: 0),
    DailyReminder(kind: DailyReminderKind.meals, hour: 14, minute: 0),
    DailyReminder(kind: DailyReminderKind.water, hour: 17, minute: 0),
    DailyReminder(kind: DailyReminderKind.sleep, hour: 22, minute: 0),
    DailyReminder(kind: DailyReminderKind.fasting, hour: 20, minute: 0),
    DailyReminder(kind: DailyReminderKind.weeklyReview, hour: 19, minute: 0),
    DailyReminder(
      kind: DailyReminderKind.returnAfter24Hours,
      hour: 0,
      minute: 0,
    ),
  ];
}
