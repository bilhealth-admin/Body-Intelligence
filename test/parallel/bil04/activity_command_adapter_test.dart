import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/date_keys.dart';
import 'package:body_intelligence_log/data/repositories/daily_log_repository.dart';
import 'package:body_intelligence_log/data/repositories/preferences_repository.dart';
import 'package:body_intelligence_log/data/repositories/weight_repository.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_activity_adapter.dart';
import 'package:body_intelligence_log/features/intelligence_center/app_commands/coach_activity_catalog.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DailyLogRepository dailyLogs;
  late WeightRepository weights;
  late PreferencesRepository preferences;
  late CoachActivityCommandAdapter adapter;
  final today = DateTime(2026, 10, 7);
  final now = DateTime(2026, 10, 7, 12, 34, 56, 123, 456);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    dailyLogs = DailyLogRepository(database);
    weights = WeightRepository(database);
    preferences = PreferencesRepository(database);
    adapter = CoachActivityCommandAdapter(
      dailyLogs: dailyLogs,
      restoreDailyLog: dailyLogs.restoreCoachRecord,
      weights: weights,
    );
  });
  tearDown(() => database.close());

  Future<Map<String, Object?>> resolve([
    Map<String, Object?> arguments = const {'workoutId': 'walk', 'minutes': 30},
  ]) => adapter.resolve(
    toolId: 'log_exercise',
    operationId: 'activity-test',
    arguments: arguments,
    now: now,
    checkAccess: _allowed,
  );

  Future<Map<String, Object?>> snapshot(Map<String, Object?> resolved) =>
      adapter.snapshot(resolved: resolved, checkAccess: _allowed);

  test('catalog projection matches the existing workout library exactly', () {
    final source = File(
      'lib/features/wellness/presentation/workout_library_page.dart',
    ).readAsStringSync();
    final matches = RegExp(
      r"_Workout\(\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',",
    ).allMatches(source);
    expect(
      coachActivityCatalog
          .map((entry) => [entry.id, entry.name, entry.nameAr, entry.category])
          .toList(),
      matches
          .map((match) => [for (var i = 1; i <= 4; i++) match.group(i)])
          .toList(),
    );
    expect(coachActivityCatalog, hasLength(18));
  });

  test('appends accepted schema and preserves unrelated day fields', () async {
    await database
        .into(database.dailyLogs)
        .insert(
          DailyLogsCompanion.insert(
            date: today,
            dayKey: dayKeyFor(today),
            notes: const Value('Private body context'),
            sleepHours: const Value(7.25),
            steps: const Value(6200),
            exerciseNotes: const Value('Legacy note retained'),
            lifecycleState: const Value('open'),
            calories: const Value(1750),
            protein: const Value(120),
            carbs: const Value(175),
            fats: const Value(58),
            finalFiber: const Value(26),
            finalNutrientEvidenceMask: const Value(8),
          ),
        );
    await weights.addWeight(80, date: today);
    await preferences.setMany({
      'goal.calories': '1750',
      'exerciseCaloriesInBudget': 'true',
    });
    final preferenceBefore = await database.select(database.preferences).get();
    final prior = await dailyLogs.getForDay(today);
    final proposal = await resolve();
    final before = await snapshot(proposal);

    await database.transaction(
      () => adapter.apply(
        resolved: proposal,
        before: before,
        checkAccess: _allowed,
      ),
    );

    final saved = (await dailyLogs.getForDay(today))!;
    final lines = saved.exerciseNotes!.split('\n');
    expect(lines.first, 'Legacy note retained');
    final entry = jsonDecode(lines.last) as Map;
    expect(entry.keys.toSet(), {'id', 'name', 'minutes', 'recordedAt'});
    expect(entry['id'], 'walk');
    expect(entry['name'], 'Brisk walk');
    expect(entry['minutes'], 30);
    expect(saved.id, prior!.id);
    expect(saved.uuid, prior.uuid);
    expect(saved.notes, prior.notes);
    expect(saved.sleepHours, prior.sleepHours);
    expect(saved.steps, prior.steps);
    expect(saved.lifecycleState, prior.lifecycleState);
    expect(saved.closedAt, prior.closedAt);
    expect(saved.calories, prior.calories);
    expect(saved.finalFiber, prior.finalFiber);
    expect(saved.finalNutrientEvidenceMask, prior.finalNutrientEvidenceMask);
    expect(await database.select(database.preferences).get(), preferenceBefore);
    final receipt = (await snapshot(proposal))['receipt'] as Map;
    expect(receipt['recorded'], isTrue);
    expect(receipt['matchingEntries'], 1);
    expect(receipt['affectsCalorieBudget'], isFalse);
    final estimate = receipt['energyEstimate'] as Map;
    expect(estimate['source'], 'manualEstimate');
    expect(estimate['estimatedCaloriesKcal'], closeTo(172, .0001));
    expect(estimate['weightDay'], '2026-10-07');
    expect(estimate['affectsCalorieBudget'], isFalse);
  });

  for (final marker in const ['state', 'timestamp']) {
    test(
      'closed exercise day marked by $marker requires explicit reopen',
      () async {
        await database
            .into(database.dailyLogs)
            .insert(
              DailyLogsCompanion.insert(
                date: today,
                dayKey: dayKeyFor(today),
                lifecycleState: Value(marker == 'state' ? 'closed' : 'open'),
                closedAt: Value(marker == 'timestamp' ? now : null),
                notes: const Value('Preserved closed day'),
              ),
            );
        final prior = (await dailyLogs.getForDay(today))!.toJson();
        final proposal = await resolve();
        final before = await snapshot(proposal);
        await expectLater(
          database.transaction(
            () => adapter.apply(
              resolved: proposal,
              before: before,
              checkAccess: _allowed,
            ),
          ),
          throwsStateError,
        );
        expect((await dailyLogs.getForDay(today))!.toJson(), prior);
        await dailyLogs.reopenDay(today);
        final reopened = await resolve();
        final reopenedBefore = await snapshot(reopened);
        await database.transaction(
          () => adapter.apply(
            resolved: reopened,
            before: reopenedBefore,
            checkAccess: _allowed,
          ),
        );
        expect((await dailyLogs.getForDay(today))!.exerciseNotes, isNotNull);
      },
    );
  }

  test('missing same-day evidence leaves calories unknown', () async {
    await weights.addWeight(81, date: DateTime(2026, 10, 6));
    final proposal = await resolve();
    expect(proposal['energyEstimate'], isNull);
    expect(await dailyLogs.getForDay(today), isNull);
    expect(
      (await snapshot(proposal))['receipt'],
      containsPair('recorded', false),
    );
  });

  test('historical date is frozen and shown on its actual local day', () async {
    final proposal = await resolve({
      'workoutId': 'swim',
      'name': 'سباحة',
      'minutes': 25,
      'date': '2026-10-06',
    });
    final before = await snapshot(proposal);
    await database.transaction(
      () => adapter.apply(
        resolved: proposal,
        before: before,
        checkAccess: _allowed,
      ),
    );
    expect(await dailyLogs.getForDay(today), isNull);
    final saved = (await dailyLogs.getForDay(DateTime(2026, 10, 6)))!;
    final entry = jsonDecode(saved.exerciseNotes!) as Map;
    final recordedAt = DateTime.parse(entry['recordedAt'] as String).toLocal();
    expect(dayKeyFor(recordedAt), '2026-10-06');
    expect(proposal['timePrecision'], 'day');
    expect(proposal['name'], 'Swimming');
    expect(await snapshot(proposal), await snapshot(proposal));
  });

  test(
    'unknown identities, invented energy and invalid inputs fail closed',
    () async {
      final invalid = <Map<String, Object?>>[
        {'workoutId': 'unknown', 'minutes': 30},
        {'workoutId': ' walk', 'minutes': 30},
        {'workoutId': 'WALK', 'minutes': 30},
        {'workoutId': 'walk', 'name': 'Run fast', 'minutes': 30},
        {'workoutId': 'walk', 'minutes': 4},
        {'workoutId': 'walk', 'minutes': 121},
        {'workoutId': 'walk', 'minutes': 30.0},
        {'workoutId': 'walk', 'minutes': '30'},
        {'workoutId': 'walk', 'minutes': 30, 'estimatedCaloriesKcal': 500},
        {'workoutId': 'walk', 'minutes': 30, 'date': '2026-02-30'},
        {'workoutId': 'walk', 'minutes': 30, 'date': '2026-10-08'},
      ];
      for (final arguments in invalid) {
        await expectLater(resolve(arguments), throwsArgumentError);
      }
      expect(await dailyLogs.getAll(), isEmpty);
    },
  );

  test('a concurrent daily editor makes a prepared exercise stale', () async {
    await dailyLogs.save(date: today, notes: 'before', steps: 1000);
    final proposal = await resolve();
    final before = await snapshot(proposal);
    await dailyLogs.saveBodyContext(date: today, notes: 'edited elsewhere');
    await expectLater(
      database.transaction(
        () => adapter.apply(
          resolved: proposal,
          before: before,
          checkAccess: _allowed,
        ),
      ),
      throwsStateError,
    );
    final current = (await dailyLogs.getForDay(today))!;
    expect(current.notes, 'edited elsewhere');
    expect(current.exerciseNotes, isNull);
  });

  test(
    'Undo restores the complete prior row and does not duplicate history',
    () async {
      await dailyLogs.save(
        date: today,
        notes: 'unchanged',
        steps: 5432,
        sleepHours: 6.75,
        exerciseNotes: 'A legacy exercise note',
      );
      final prior = (await dailyLogs.getForDay(today))!.toJson();
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await database.transaction(
        () => adapter.apply(
          resolved: proposal,
          before: before,
          checkAccess: _allowed,
        ),
      );
      final after = await snapshot(proposal);
      await database.transaction(
        () => adapter.compensate(
          resolved: proposal,
          before: before,
          after: after,
          checkAccess: _allowed,
        ),
      );
      expect((await dailyLogs.getForDay(today))!.toJson(), prior);
      expect(
        (await snapshot(proposal))['receipt'],
        containsPair('recorded', false),
      );
    },
  );

  test('Undo of a newly created exercise day restores absence', () async {
    final proposal = await resolve();
    final before = await snapshot(proposal);
    await database.transaction(
      () => adapter.apply(
        resolved: proposal,
        before: before,
        checkAccess: _allowed,
      ),
    );
    final after = await snapshot(proposal);
    await database.transaction(
      () => adapter.compensate(
        resolved: proposal,
        before: before,
        after: after,
        checkAccess: _allowed,
      ),
    );
    expect(await dailyLogs.getForDay(today), isNull);
  });

  test(
    'Undo refuses to replace later edits to the affected daily row',
    () async {
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await database.transaction(
        () => adapter.apply(
          resolved: proposal,
          before: before,
          checkAccess: _allowed,
        ),
      );
      final after = await snapshot(proposal);
      await dailyLogs.updateSleepHours(date: today, sleepHours: 8);
      await expectLater(
        database.transaction(
          () => adapter.compensate(
            resolved: proposal,
            before: before,
            after: after,
            checkAccess: _allowed,
          ),
        ),
        throwsStateError,
      );
      final current = (await dailyLogs.getForDay(today))!;
      expect(current.sleepHours, 8);
      expect(current.exerciseNotes, isNotNull);
    },
  );

  test(
    'a silent repository failure cannot produce a successful receipt',
    () async {
      final silent = _SilentExerciseRepository(database);
      adapter = CoachActivityCommandAdapter(
        dailyLogs: silent,
        restoreDailyLog: dailyLogs.restoreCoachRecord,
      );
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await expectLater(
        database.transaction(
          () => adapter.apply(
            resolved: proposal,
            before: before,
            checkAccess: _allowed,
          ),
        ),
        throwsStateError,
      );
      expect(await dailyLogs.getForDay(today), isNull);
    },
  );

  test('revocation during an evidence read prevents a proposal', () async {
    final suspended = Completer<WeightEntry?>();
    var current = true;
    adapter = CoachActivityCommandAdapter(
      dailyLogs: dailyLogs,
      restoreDailyLog: dailyLogs.restoreCoachRecord,
      weights: _DelayedWeightRepository(database, suspended.future),
    );
    final result = adapter.resolve(
      toolId: 'log_exercise',
      operationId: 'revoked-evidence',
      arguments: const {'workoutId': 'walk', 'minutes': 30},
      now: now,
      checkAccess: () {
        if (!current) throw StateError('Owner epoch revoked');
      },
    );
    current = false;
    suspended.complete(null);
    await expectLater(result, throwsStateError);
    expect(await dailyLogs.getAll(), isEmpty);
  });

  test(
    'revocation after the repository write rolls the native transaction back',
    () async {
      var current = true;
      adapter = CoachActivityCommandAdapter(
        dailyLogs: _RevokingExerciseRepository(database, () => current = false),
        restoreDailyLog: dailyLogs.restoreCoachRecord,
      );
      final proposal = await resolve();
      final before = await snapshot(proposal);
      await expectLater(
        database.transaction(
          () => adapter.apply(
            resolved: proposal,
            before: before,
            checkAccess: () {
              if (!current) throw StateError('Owner epoch revoked');
            },
          ),
        ),
        throwsStateError,
      );
      expect(await dailyLogs.getForDay(today), isNull);
    },
  );
}

void _allowed() {}

class _SilentExerciseRepository extends DailyLogRepository {
  _SilentExerciseRepository(super.database);

  @override
  Future<void> appendExerciseNotes({
    required DateTime date,
    required List<String> encodedEntries,
  }) async {}
}

class _DelayedWeightRepository extends WeightRepository {
  _DelayedWeightRepository(super.database, this.result);
  final Future<WeightEntry?> result;

  @override
  Future<WeightEntry?> getForDay(DateTime date) => result;
}

class _RevokingExerciseRepository extends DailyLogRepository {
  _RevokingExerciseRepository(super.database, this.revoke);
  final void Function() revoke;

  @override
  Future<void> appendExerciseNotes({
    required DateTime date,
    required List<String> encodedEntries,
  }) async {
    await super.appendExerciseNotes(date: date, encodedEntries: encodedEntries);
    revoke();
  }
}
