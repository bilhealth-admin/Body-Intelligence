import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../domain/local_intelligence_runtime.dart';
import '../domain/decision_memory_history.dart';
import '../domain/decision_memory_record.dart' as ai;
import '../domain/decision_outcome_transition.dart';

/// Offline-only adapter that projects the existing local database into the
/// neutral chronological input required by the intelligence runtime.
final class LocalIntelligenceRepositoryAdapter {
  const LocalIntelligenceRepositoryAdapter(this.database);

  final AppDatabase database;

  Future<LocalIntelligenceTimeline> load({
    required DateTime asOf,
    int lookbackDays = 42,
  }) async {
    if (lookbackDays < 14 || lookbackDays > 180) {
      throw ArgumentError.value(lookbackDays, 'lookbackDays', 'must be 14–180');
    }
    final profile = await (database.select(
      database.userProfile,
    )..limit(1)).getSingleOrNull();
    if (profile == null || profile.deletedAt != null) {
      throw StateError('A local user profile is required for intelligence.');
    }

    final end = DateTime.utc(asOf.year, asOf.month, asOf.day);
    final start = end.subtract(Duration(days: lookbackDays - 1));
    final weights =
        await (database.select(database.weightEntries)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.date.isBiggerOrEqualValue(start) &
                  row.date.isSmallerOrEqualValue(end),
            ))
            .get();
    final waters =
        await (database.select(database.waterEntries)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.occurredAt.isBiggerOrEqualValue(start) &
                  row.occurredAt.isSmallerOrEqualValue(asOf.toUtc()),
            ))
            .get();
    final meals =
        await (database.select(database.meals)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.date.isBiggerOrEqualValue(start) &
                  row.date.isSmallerOrEqualValue(end),
            ))
            .get();
    final mealIds = meals.map((meal) => meal.id).toSet();
    final items = mealIds.isEmpty
        ? <MealItem>[]
        : await (database.select(database.mealItems)..where(
                (row) => row.deletedAt.isNull() & row.mealId.isIn(mealIds),
              ))
              .get();
    final logs =
        await (database.select(database.dailyLogs)..where(
              (row) =>
                  row.date.isBiggerOrEqualValue(start) &
                  row.date.isSmallerOrEqualValue(end),
            ))
            .get();
    final contexts =
        await (database.select(database.lifeContextEntries)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.useInInsights.equals(true) &
                  row.occurredAt.isBiggerOrEqualValue(start) &
                  row.occurredAt.isSmallerOrEqualValue(asOf.toUtc()),
            ))
            .get();

    final weightByDay = <String, double>{
      for (final row in weights) _key(row.date): row.weight,
    };
    final waterByDay = <String, int>{};
    for (final row in waters) {
      waterByDay.update(
        _key(row.occurredAt),
        (value) => value + row.amountMl,
        ifAbsent: () => row.amountMl,
      );
    }
    final mealDayById = {for (final meal in meals) meal.id: _key(meal.date)};
    final nutrients = <String, _Nutrients>{};
    for (final item in items) {
      final key = mealDayById[item.mealId];
      if (key == null) continue;
      nutrients.putIfAbsent(key, _Nutrients.new).add(item);
    }
    final logsByDay = {for (final row in logs) _key(row.date): row};
    final contextsByDay = <String, List<String>>{};
    for (final row in contexts) {
      contextsByDay
          .putIfAbsent(_key(row.occurredAt), () => <String>[])
          .add(row.type);
    }

    final memoryRows =
        await (database.select(database.decisionMemories)..where(
              (row) =>
                  row.deletedAt.isNull() &
                  row.surfacedAt.isSmallerOrEqualValue(asOf.toUtc()),
            ))
            .get();
    final decisionHistory = memoryRows
        .map((row) {
          final state = switch (row.response) {
            'done' => DecisionOutcomeState.succeeded,
            'dismissed' || 'notSuitable' => DecisionOutcomeState.failed,
            _ => DecisionOutcomeState.pending,
          };
          return DecisionMemoryHistory(
            record: ai.DecisionMemoryRecord(
              id: row.uuid,
              createdAt: row.surfacedAt,
              decisionKey: row.recommendationKey,
              selectedAction: row.title,
              rationale: row.reason,
              confidence: switch (row.confidence) {
                'high' => 0.9,
                'medium' => 0.7,
                _ => 0.5,
              },
              evidenceIds: const <String>['local-decision-memory'],
              outcomeState: row.response,
            ),
            currentState: state,
            transitions: const <DecisionOutcomeTransition>[],
          );
        })
        .toList(growable: false);

    final days = <LocalDailyPhysiology>[];
    for (var offset = 0; offset < lookbackDays; offset++) {
      final day = start.add(Duration(days: offset));
      final key = _key(day);
      final nutrient = nutrients[key] ?? _Nutrients();
      final log = logsByDay[key];
      days.add(
        LocalDailyPhysiology(
          day: day,
          weightKg: weightByDay[key],
          caloriesKcal: nutrient.calories,
          proteinG: nutrient.protein,
          carbsG: nutrient.carbs,
          fatG: nutrient.fat,
          sodiumMg: nutrient.sodium,
          potassiumMg: nutrient.potassium,
          waterMl: waterByDay[key] ?? 0,
          sleepHours: log?.sleepHours,
          steps: log?.steps,
          contextTypes: contextsByDay[key] ?? const <String>[],
        ),
      );
    }

    return LocalIntelligenceTimeline(
      age: profile.age,
      heightCm: profile.height,
      gender: profile.gender,
      activityLevel: profile.activityLevel,
      targetWeightKg: profile.targetWeight,
      waistCm: profile.waist,
      neckCm: profile.neck,
      days: days,
      decisionHistory: decisionHistory,
    );
  }

  static String _key(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
  }
}

final class _Nutrients {
  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;
  double sodium = 0;
  double potassium = 0;

  void add(MealItem item) {
    calories += item.calories;
    protein += item.protein;
    carbs += item.carbs;
    fat += item.fats;
    sodium += item.sodium;
    potassium += item.potassium;
  }
}
