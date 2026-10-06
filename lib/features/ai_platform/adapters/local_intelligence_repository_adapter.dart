import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_scope.dart';
import '../../../data/database/meal_food_evidence.dart';
import '../../../data/database/nutrient_evidence.dart';
import '../../../engine/nutrient_evidence_engine.dart';
import '../../daily_log/domain/daily_body_context_codec.dart';
import '../domain/local_intelligence_runtime.dart';
import '../domain/decision_memory_history.dart';
import '../domain/decision_memory_record.dart' as ai;
import '../domain/decision_outcome_transition.dart' as ai_outcome;

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
      nutrients
          .putIfAbsent(key, _Nutrients.new)
          .add(
            MealFoodEvidence.read(
              item,
              ownerKey: LocalDatabaseScope.keyForOwner(database.localOwnerId),
            ),
          );
    }
    final logsByDay = {for (final row in logs) _key(row.date): row};
    final contextsByDay = <String, List<String>>{};
    for (final row in contexts) {
      contextsByDay
          .putIfAbsent(_key(row.occurredAt), () => <String>[])
          .add(row.type);
    }
    for (final row in logs) {
      contextsByDay
          .putIfAbsent(row.dayKey, () => <String>[])
          .addAll(DailyBodyContextCodec.engineTypes(row.notes));
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
            'done' => ai_outcome.DecisionOutcomeState.succeeded,
            'dismissed' ||
            'notSuitable' => ai_outcome.DecisionOutcomeState.failed,
            _ => ai_outcome.DecisionOutcomeState.pending,
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
            transitions: const <ai_outcome.DecisionOutcomeTransition>[],
          );
        })
        .toList(growable: false);

    final days = <LocalDailyPhysiology>[];
    for (var offset = 0; offset < lookbackDays; offset++) {
      final day = start.add(Duration(days: offset));
      final key = _key(day);
      final nutrient = nutrients[key] ?? _Nutrients();
      final log = logsByDay[key];
      final contextTypes = contextsByDay[key]?.toSet().toList() ?? <String>[];
      contextTypes.sort();
      days.add(
        LocalDailyPhysiology(
          day: day,
          weightKg: weightByDay[key],
          caloriesKcal: nutrient.total(TrackedNutrient.calories),
          proteinG: nutrient.total(TrackedNutrient.protein),
          carbsG: nutrient.total(TrackedNutrient.carbohydrates),
          fatG: nutrient.total(TrackedNutrient.fat),
          sodiumMg: nutrient.total(TrackedNutrient.sodium),
          potassiumMg: nutrient.total(TrackedNutrient.potassium),
          hasNutritionItems: nutrient.hasItems,
          waterMl: waterByDay[key] ?? 0,
          sleepHours: log?.sleepHours,
          steps: log?.steps,
          contextTypes: contextTypes,
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
  final _items = <MealFoodEvidence>[];

  bool get hasItems => _items.isNotEmpty;

  void add(MealFoodEvidence item) => _items.add(item);

  double? total(TrackedNutrient nutrient) {
    final values = _items.map((item) => item.value(nutrient));
    return NutrientEvidenceEngine.total([
      for (final value in values)
        NutrientObservation(value: value ?? 0, available: value != null),
    ]).completeTotal;
  }
}
