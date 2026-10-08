import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/body_measurement_repository.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/meal_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/health_query_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/intelligence_message.dart';
import 'package:body_intelligence_log/features/intelligence_center/services/coach_catalog_grounding.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _BoundedDailyLogs daily;
  late _BoundedWeights weights;
  late CoachHealthQueries queries;
  final day = DateTime(2026, 10, 7, 12);
  void allow() {}
  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      localOwnerId: 'synthetic-owner-a',
    );
    daily = _BoundedDailyLogs(database);
    weights = _BoundedWeights(database);
    queries = CoachHealthQueries(
      database,
      dailyLogs: daily,
      weights: weights,
      clock: () => day,
    );
  });
  tearDown(() => database.close());

  test('rejects unbounded windows and invalid limits before reading', () async {
    for (final through in [DateTime(2026, 11, 7), DateTime(2026, 10, 6)]) {
      await expectLater(
        queries.execute(
          topic: 'sleep',
          from: day,
          through: through,
          checkAccess: allow,
        ),
        throwsArgumentError,
      );
    }
    for (final limit in [0, 32]) {
      await expectLater(
        queries.execute(
          topic: 'sleep',
          from: day,
          through: day,
          limit: limit,
          checkAccess: allow,
        ),
        throwsArgumentError,
      );
    }
    await expectLater(
      queries.execute(
        topic: 'all_history',
        from: day,
        through: day,
        checkAccess: allow,
      ),
      throwsArgumentError,
    );
    expect(daily.readDays, isEmpty);
    expect(weights.readDays, isEmpty);
  });

  test(
    'empty closed day returns persisted state with unknown nutrition',
    () async {
      await daily.startDay(day);
      await daily.closeDay(day);
      final result = await queries.execute(
        topic: 'daily',
        from: DateTime(2026, 10, 6),
        through: day,
        checkAccess: allow,
      );
      final row = _rows(result).single;
      expect(row['state'], 'closed');
      expect(row['caloriesKcal'], isNull);
      expect(row['proteinG'], isNull);
      expect(row['netCarbohydratesG'], isNull);
      expect(result['missingDays'], ['2026-10-06']);
      expect(await database.select(database.meals).get(), isEmpty);
      expect(await database.select(database.foods).get(), isEmpty);
      expect((await daily.getForDay(day))?.lifecycleState, 'closed');
    },
  );

  test(
    'daily projection retains known zero separately from unknown macro',
    () async {
      await MealRepository(database).addQuickMacroEntry(
        date: day,
        mealType: 'lunch',
        calories: 500,
        protein: 0,
        carbohydrates: 0,
        fat: 0,
        caloriesKnown: true,
        proteinKnown: false,
        carbohydratesKnown: true,
        fatKnown: false,
      );
      final result = await queries.execute(
        topic: 'daily',
        from: day,
        through: day,
        checkAccess: allow,
      );
      final row = _rows(result).single;
      expect(row['caloriesKcal'], 500);
      expect(row['proteinG'], isNull);
      expect(row['carbohydratesG'], 0);
      expect(row['fatG'], isNull);
      expect(row['fiberG'], isNull);
      expect(row.containsKey('sodiumMg'), isFalse);
    },
  );

  test(
    'no sleep is absent while explicit zero sleep is a recorded value',
    () async {
      final absent = await queries.execute(
        topic: 'sleep',
        from: day,
        through: day,
        checkAccess: allow,
      );
      expect(absent['status'], 'no_data');
      expect(_rows(absent), isEmpty);
      await daily.updateSleepHours(date: day, sleepHours: 0);
      final present = await queries.execute(
        topic: 'sleep',
        from: day,
        through: day,
        checkAccess: allow,
      );
      expect(present['status'], 'recorded');
      expect((_rows(present).single['manual'] as Map)['hours'], 0);
      expect(_rows(present).single['connected'], isNull);
    },
  );

  test(
    '31 civil days use only per-day reads, preserve gaps, limit newest rows',
    () async {
      for (final entry in [
        (DateTime(2026, 2, 28, 12), 110.0),
        (DateTime(2026, 3, 1, 12), 93.0),
        (DateTime(2026, 3, 15, 12), 92.0),
        (DateTime(2026, 3, 31, 12), 91.0),
        (DateTime(2026, 4, 1, 12), 70.0),
      ]) {
        await weights.addWeight(entry.$2, date: entry.$1);
      }
      weights.readDays.clear();
      final result = await queries.execute(
        topic: 'weight',
        from: DateTime(2026, 3, 1, 23),
        through: DateTime(2026, 3, 31, 1),
        limit: 2,
        checkAccess: allow,
      );
      expect(weights.readDays.length, 31);
      expect(weights.readDays.toSet().length, 31);
      expect(weights.readDays.first, '2026-03-31');
      expect(weights.readDays.last, '2026-03-01');
      expect(result['queriedDays'], 31);
      expect(result['matchedDays'], 3);
      expect(result['truncated'], isTrue);
      expect((result['missingDays'] as List).length, 28);
      expect(_rows(result).map((row) => row['day']), [
        '2026-03-31',
        '2026-03-15',
      ]);
      expect(daily.readDays, isEmpty);
    },
  );

  test(
    'calendar iteration remains unique across autumn DST boundary',
    () async {
      final result = await queries.execute(
        topic: 'weight',
        from: DateTime(2026, 10, 20, 23),
        through: DateTime(2026, 11, 19, 1),
        checkAccess: allow,
      );
      expect(weights.readDays.toSet().length, 31);
      expect(weights.readDays.first, '2026-11-19');
      expect(weights.readDays.last, '2026-10-20');
      expect(result['status'], 'no_data');
      expect(_rows(result), isEmpty);
    },
  );

  test(
    'progress uses established confidence and does not infer from one reading',
    () async {
      await weights.addWeight(85, date: DateTime(2026, 9, 1, 12));
      var result = await queries.execute(
        topic: 'progress',
        from: DateTime(2026, 9, 1),
        through: DateTime(2026, 9, 22),
        checkAccess: allow,
      );
      expect((result['analysis'] as Map)['confidence'], 'insufficient');
      expect((result['analysis'] as Map)['weeklyDirectionKg'], isNull);
      for (var index = 1; index < 8; index++) {
        await weights.addWeight(
          85 - index * 0.3,
          date: DateTime(2026, 9, 1 + index * 3, 12),
        );
      }
      result = await queries.execute(
        topic: 'progress',
        from: DateTime(2026, 9, 1),
        through: DateTime(2026, 9, 22),
        limit: 2,
        checkAccess: allow,
      );
      final analysis = result['analysis'] as Map;
      expect(analysis['engine'], 'ProgressAnalysis');
      expect(analysis['confidence'], 'medium');
      expect(analysis['sampleCount'], 8);
      expect(analysis['spanDays'], 21);
      expect(analysis['weeklyDirectionKg'], closeTo(-0.7, 0.000001));
      expect(analysis.containsKey('projectedGoalDate'), isFalse);
      expect(_rows(result).length, 2);
      expect(
        analysis['sampleScope'],
        'all_recorded_weights_in_requested_window',
      );
    },
  );

  test(
    'partial measurements keep null fields and omit deleted records',
    () async {
      final repository = BodyMeasurementRepository(database);
      await repository.saveForDay(date: day, neckCm: 38, waistCm: 88);
      final previous = DateTime(2026, 10, 6);
      await repository.saveForDay(date: previous, chestCm: 101);
      await repository.deleteForDay(previous);
      final result = await queries.execute(
        topic: 'measurements',
        from: previous,
        through: day,
        checkAccess: allow,
      );
      final row = _rows(result).single;
      expect(row['neckCm'], 38);
      expect(row['waistCm'], 88);
      expect(row['chestCm'], isNull);
      expect(result['missingDays'], ['2026-10-06']);
      expect(daily.readDays, isEmpty);
      expect(weights.readDays, isEmpty);
    },
  );

  test(
    'weight query excludes private photo paths and free-text notes',
    () async {
      await weights.addWeight(
        85,
        date: day,
        note: 'private synthetic note',
        progressPhotoPath: '/private/synthetic/photo.jpg',
        measurementContext: 'morning',
      );
      final result = await queries.execute(
        topic: 'weight',
        from: day,
        through: day,
        checkAccess: allow,
      );
      expect(_rows(result).single['measurementContext'], 'morning');
      expect(jsonEncode(result), isNot(contains('private')));
    },
  );

  test('denied access cannot start a repository read', () async {
    await expectLater(
      queries.execute(
        topic: 'sleep',
        from: day,
        through: day,
        checkAccess: () => throw StateError('permission_denied'),
      ),
      throwsStateError,
    );
    expect(daily.readDays, isEmpty);
  });

  test('owner ABA and permission revocation discard awaited data', () async {
    await daily.updateSleepHours(date: day, sleepHours: 7);
    var owner = 'a';
    var epoch = 0;
    final capturedEpoch = epoch;
    daily.afterRead = () {
      owner = 'b';
      epoch++;
      owner = 'a';
      epoch++;
    };
    await expectLater(
      queries.execute(
        topic: 'sleep',
        from: DateTime(2026, 10, 6),
        through: day,
        checkAccess: () {
          if (owner != 'a' || epoch != capturedEpoch) {
            throw StateError('owner_changed');
          }
        },
      ),
      throwsStateError,
    );
    expect(daily.readDays.length, 1);
    var permitted = true;
    daily.afterRead = () => permitted = false;
    await expectLater(
      queries.execute(
        topic: 'sleep',
        from: day,
        through: day,
        checkAccess: () {
          if (!permitted) throw StateError('permission_changed');
        },
      ),
      throwsStateError,
    );
  });

  test('repository read failure is never presented as no data', () async {
    daily.failRead = true;
    await expectLater(
      queries.execute(
        topic: 'sleep',
        from: day,
        through: day,
        checkAccess: allow,
      ),
      throwsStateError,
    );
    expect(await database.select(database.dailyLogs).get(), isEmpty);
  });

  test(
    'catalog lookup bounds text and routes without reading health history',
    () async {
      final catalogQueries = CoachHealthQueries(
        database,
        dailyLogs: daily,
        weights: weights,
        contentLookup: ({required question, required locale}) async =>
            CoachCatalogGroundingResult(
              text: List.filled(1700, '🌱').join(),
              evidence: const ['workout_catalog:walk'],
              links: const [
                IntelligenceMessageLink(
                  id: 'walk',
                  label: 'Walk',
                  route: '/wellness/workouts/routines?item=walk',
                  kind: IntelligenceMessageLinkKind.workout,
                ),
              ],
            ),
      );
      final result = await catalogQueries.searchContent(
        question: 'walking workout',
        locale: 'en',
        checkAccess: allow,
      );
      expect((result['text'] as String).runes.length, 1600);
      expect(result['textTruncated'], isTrue);
      expect((result['rows'] as List).length, 1);
      expect(result['mutationsPerformed'], 0);
      expect(result['healthRecordsRead'], 0);
      expect(daily.readDays, isEmpty);
      expect(weights.readDays, isEmpty);
    },
  );

  test(
    'catalog routes are validated and account changes reject its result',
    () async {
      var epoch = 0;
      final catalogQueries = CoachHealthQueries(
        database,
        contentLookup: ({required question, required locale}) async {
          epoch++;
          return const CoachCatalogGroundingResult(
            text: 'untrusted text',
            evidence: [],
            links: [
              IntelligenceMessageLink(
                id: 'walk',
                label: 'External',
                route: 'https://example.test/private',
                kind: IntelligenceMessageLinkKind.workout,
              ),
            ],
          );
        },
      );
      final filtered = await catalogQueries.searchContent(
        question: 'workout',
        locale: 'en',
        checkAccess: allow,
      );
      expect(filtered['status'], 'no_matching_content');
      expect(filtered['rows'], isEmpty);
      expect(filtered['text'], isEmpty);
      final captured = epoch;
      await expectLater(
        catalogQueries.searchContent(
          question: 'workout',
          locale: 'en',
          checkAccess: () {
            if (epoch != captured) throw StateError('owner_changed');
          },
        ),
        throwsStateError,
      );
    },
  );
}

List<Map<String, Object?>> _rows(Map<String, Object?> result) =>
    (result['rows'] as List).cast<Map<String, Object?>>();

class _BoundedDailyLogs extends DailyLogRepository {
  _BoundedDailyLogs(super.database);
  final readDays = <String>[];
  void Function()? afterRead;
  bool failRead = false;
  @override
  Future<DailyLog?> getForDay(DateTime date) async {
    readDays.add(dayKeyFor(date));
    if (failRead) throw StateError('synthetic_read_failure');
    final result = await super.getForDay(date);
    afterRead?.call();
    return result;
  }

  @override
  Future<List<DailyLog>> getAll() =>
      throw StateError('Unbounded daily query is forbidden');
}

class _BoundedWeights extends WeightRepository {
  _BoundedWeights(super.database);
  final readDays = <String>[];
  @override
  Future<WeightEntry?> getForDay(DateTime date) {
    readDays.add(dayKeyFor(date));
    return super.getForDay(date);
  }

  @override
  Future<List<WeightEntry>> getAll() =>
      throw StateError('Unbounded weight query is forbidden');
}
