import 'dart:convert';

import 'package:body_intelligence_log/features/notifications/domain/daily_reminder.dart';
import 'package:body_intelligence_log/features/notifications/services/daily_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'every global reminder is opt-in and independently represented',
    () async {
      final reminders = await DailyReminderStore().load();
      expect(
        reminders.map((item) => item.kind).toSet(),
        DailyReminderKind.values.toSet(),
      );
      expect(
        reminders,
        everyElement(
          isA<DailyReminder>().having(
            (item) => item.enabled,
            'enabled',
            isFalse,
          ),
        ),
      );
    },
  );

  test(
    'older saved lists gain new disabled categories without losing choices',
    () async {
      SharedPreferences.setMockInitialValues({
        'bil.daily-reminders.v1': jsonEncode([
          {'kind': 'water', 'hour': 17, 'minute': 0, 'enabled': true},
        ]),
      });
      final reminders = await DailyReminderStore().load();
      expect(
        reminders
            .singleWhere((item) => item.kind == DailyReminderKind.water)
            .enabled,
        isTrue,
      );
      expect(
        reminders
            .singleWhere((item) => item.kind == DailyReminderKind.sleep)
            .enabled,
        isFalse,
      );
      expect(
        reminders
            .singleWhere(
              (item) => item.kind == DailyReminderKind.returnAfter24Hours,
            )
            .enabled,
        isFalse,
      );
    },
  );

  test('invalid stored rows do not erase valid choices', () async {
    SharedPreferences.setMockInitialValues({
      'bil.daily-reminders.v1': jsonEncode([
        {'kind': 'water', 'hour': 17, 'minute': 0, 'enabled': true},
        {'kind': 'weight', 'hour': 99, 'minute': 0, 'enabled': true},
        {'kind': 'future-kind', 'hour': 8, 'minute': 0, 'enabled': true},
      ]),
    });
    final reminders = await DailyReminderStore().load();
    expect(
      reminders
          .singleWhere((item) => item.kind == DailyReminderKind.water)
          .enabled,
      isTrue,
    );
    expect(
      reminders
          .singleWhere((item) => item.kind == DailyReminderKind.weight)
          .enabled,
      isFalse,
    );
  });
}
