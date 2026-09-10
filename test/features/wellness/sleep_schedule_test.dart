import 'package:body_intelligence_log/features/wellness/domain/sleep_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('sleep schedule persists local wall-clock and goal fields', () async {
    final store = SleepScheduleStore();
    const value = SleepSchedule(
      enabled: true,
      bedHour: 23,
      bedMinute: 15,
      wakeHour: 7,
      wakeMinute: 10,
      goalMinutes: 450,
      windDownMinutes: 45,
    );
    await store.save(value);
    final loaded = await store.load();
    expect(loaded.enabled, isTrue);
    expect(loaded.bedHour, 23);
    expect(loaded.bedMinute, 15);
    expect(loaded.wakeHour, 7);
    expect(loaded.wakeMinute, 10);
    expect(loaded.goalMinutes, 450);
    expect(loaded.windDownMinutes, 45);
  });

  test(
    'invalid or corrupt schedule fails local-first to safe disabled defaults',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SleepScheduleStore.storageKey: '{bad',
      });
      final loaded = await SleepScheduleStore().load();
      expect(loaded.enabled, isFalse);
      expect(loaded.isValid, isTrue);
    },
  );

  test('schedule validates realistic daily bounds', () {
    expect(const SleepSchedule.defaults().isValid, isTrue);
    expect(
      SleepSchedule.tryParse(
        '{"enabled":true,"bedHour":25,"bedMinute":0,'
        '"wakeHour":7,"wakeMinute":0,"goalMinutes":480,'
        '"windDownMinutes":30}',
      ),
      isNull,
    );
  });

  test('overnight window is calculated from local wall-clock values', () {
    const schedule = SleepSchedule(
      enabled: true,
      bedHour: 22,
      bedMinute: 30,
      wakeHour: 7,
      wakeMinute: 0,
      goalMinutes: 8 * 60,
      windDownMinutes: 30,
    );

    expect(schedule.scheduledWindowMinutes, 8 * 60 + 30);
    expect(schedule.issue, isNull);
  });

  test(
    'adult planning goal starts at seven hours without changing actuals',
    () {
      final sixHourGoal = const SleepSchedule.defaults().copyWith(
        goalMinutes: 6 * 60,
      );

      expect(sixHourGoal.issue, SleepScheduleIssue.invalidGoal);
      expect(sixHourGoal.isValid, isFalse);
    },
  );

  test(
    'legacy planning goal remains readable without becoming newly valid',
    () {
      final legacy = SleepSchedule.tryParse(
        '{"enabled":true,"bedHour":23,"bedMinute":0,'
        '"wakeHour":7,"wakeMinute":0,"goalMinutes":360,'
        '"windDownMinutes":30}',
      );

      expect(legacy, isNotNull);
      expect(legacy!.goalMinutes, 6 * 60);
      expect(legacy.isStorable, isTrue);
      expect(legacy.issue, SleepScheduleIssue.invalidGoal);
      expect(legacy.isValid, isFalse);
    },
  );

  test('same clock time and a goal longer than its window are explicit', () {
    final emptyWindow = const SleepSchedule.defaults().copyWith(
      bedHour: 7,
      bedMinute: 0,
    );
    final shortWindow = const SleepSchedule.defaults().copyWith(
      wakeHour: 5,
      wakeMinute: 30,
    );

    expect(emptyWindow.issue, SleepScheduleIssue.emptyWindow);
    expect(shortWindow.scheduledWindowMinutes, 7 * 60);
    expect(shortWindow.issue, SleepScheduleIssue.goalExceedsWindow);
  });

  test('legacy reminders can be disabled without rewriting the goal', () async {
    const encoded =
        '{"enabled":true,"bedHour":12,"bedMinute":30,'
        '"wakeHour":5,"wakeMinute":0,"goalMinutes":360,'
        '"windDownMinutes":15}';
    SharedPreferences.setMockInitialValues({
      SleepScheduleStore.storageKey: encoded,
    });
    final store = SleepScheduleStore();
    final legacy = await store.load();
    await store.save(legacy.copyWith(enabled: false));
    final saved = await store.load();
    expect(saved.enabled, isFalse);
    expect(saved.goalMinutes, 360);
    expect(saved.bedHour, 12);
    expect(saved.bedMinute, 30);
    expect(saved.wakeHour, 5);
    expect(saved.windDownMinutes, 15);
    expect(saved.issue, SleepScheduleIssue.invalidGoal);
    await expectLater(
      store.save(saved.copyWith(enabled: true)),
      throwsArgumentError,
    );
    expect((await store.load()).enabled, isFalse);
  });

  test(
    'opting out does not require correcting an empty legacy window',
    () async {
      final disabled = const SleepSchedule.defaults().copyWith(
        bedHour: 7,
        bedMinute: 0,
      );
      final store = SleepScheduleStore();
      await store.save(disabled);
      expect((await store.load()).enabled, isFalse);
      expect((await store.load()).issue, SleepScheduleIssue.emptyWindow);
      await expectLater(
        store.save(disabled.copyWith(enabled: true)),
        throwsArgumentError,
      );
      await expectLater(
        store.save(disabled.copyWith(bedHour: 25)),
        throwsArgumentError,
      );
    },
  );
}
