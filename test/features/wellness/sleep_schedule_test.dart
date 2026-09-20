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
}
