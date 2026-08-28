import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/user_profile_repository.dart';
import 'package:body_intelligence_log/features/ai_platform/adapters/local_intelligence_repository_adapter.dart';
import 'package:body_intelligence_log/features/daily_log/domain/daily_body_context_codec.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/coach_context_snapshot.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'structured body context crosses engine boundary without private text',
    () {
      final encoded = DailyBodyContextCodec.encode(
        selected: const {
          'travel',
          'psychologicalStress',
          'illnessSymptoms',
          'other',
        },
        note: 'private diary sentence',
        other: 'private other detail',
      );

      final decoded = DailyBodyContextCodec.decode(encoded);
      expect(decoded.note, 'private diary sentence');
      expect(decoded.other, 'private other detail');
      expect(DailyBodyContextCodec.engineTypes(encoded), {
        'travel',
        'stress',
        'illness',
        'other',
      });
      expect(
        DailyBodyContextCodec.engineTypes(encoded).join(' '),
        isNot(contains('private')),
      );
    },
  );

  test('nothing notable stays mutually exclusive', () {
    final encoded = DailyBodyContextCodec.encode(
      selected: const {'nothingNotable', 'poorSleep'},
    );

    expect(DailyBodyContextCodec.engineTypes(encoded), {'poorSleep'});
  });

  test('Coach payload carries structured body context', () {
    final empty = CoachContextSnapshot.empty(
      generatedAt: DateTime.utc(2026, 8, 23),
    );
    final snapshot = CoachContextSnapshot(
      generatedAt: empty.generatedAt,
      profile: empty.profile,
      weights: empty.weights,
      nutritionDays: empty.nutritionDays,
      waterHistory: empty.waterHistory,
      computedHealth: empty.computedHealth,
      bodyContextHistory: const [
        {
          'day': '2026-08-23',
          'types': ['travel', 'stress'],
        },
      ],
    );

    expect(snapshot.toJson()['bodyContextHistory'], isNotEmpty);
    expect(snapshot.toJson().toString(), isNot(contains('private diary')));
  });

  test(
    'persisted Body Context reaches the local intelligence timeline',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await UserProfileRepository(database).save(
        gender: 'male',
        age: 35,
        height: 178,
        currentWeight: 82,
        targetWeight: 76,
        activityLevel: 'moderate',
        exercises: true,
      );
      final day = DateTime.utc(2026, 8, 23);
      await DailyLogRepository(database).saveBodyContext(
        date: day,
        notes: DailyBodyContextCodec.encode(
          selected: const {'travel', 'poorSleep'},
          note: 'never leave this diary',
        ),
      );

      final timeline = await LocalIntelligenceRepositoryAdapter(
        database,
      ).load(asOf: day.add(const Duration(hours: 12)), lookbackDays: 14);
      final today = timeline.days.singleWhere(
        (row) =>
            row.day.year == day.year &&
            row.day.month == day.month &&
            row.day.day == day.day,
      );

      expect(today.contextTypes, ['poorSleep', 'travel']);
      expect(today.contextTypes.join(' '), isNot(contains('never leave')));
    },
  );
}
