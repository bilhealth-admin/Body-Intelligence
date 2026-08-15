import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PreferencesRepository preferences;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    preferences = PreferencesRepository(database);
  });

  tearDown(() => database.close());

  test('fasting snapshot set and removal commit together', () async {
    await preferences.mutate(
      set: const {
        'wellness_fasting_session_v2': '{"session":1}',
        'wellness_fasting_started_at': '2026-08-13T10:00:00Z',
        'wellness_fasting_target_hours': '12',
      },
    );

    expect(await preferences.get('wellness_fasting_session_v2'), isNotNull);
    await preferences.mutate(
      set: const {
        'wellness_fasting_history_v1': '[{"history":1}]',
        'wellness_fasting_last_minutes': '30',
      },
      remove: const [
        'wellness_fasting_session_v2',
        'wellness_fasting_started_at',
      ],
    );

    expect(await preferences.get('wellness_fasting_session_v2'), isNull);
    expect(await preferences.get('wellness_fasting_started_at'), isNull);
    expect(await preferences.get('wellness_fasting_history_v1'), isNotNull);
    expect(await preferences.get('wellness_fasting_last_minutes'), '30');
  });

  test('invalid mutation rolls back every preference write', () async {
    await expectLater(
      preferences.mutate(set: const {'valid': 'new', '  ': 'invalid'}),
      throwsArgumentError,
    );
    expect(await preferences.get('valid'), isNull);
  });
}
