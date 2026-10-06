part of 'coach_context_provider.dart';

// Keep analytics fail-closed: only these computed, category-neutral body-model
// fields may be exposed when analytics is selected. In particular, never copy
// the complete health map because it also contains nutrition, training, and
// habit payloads.
const Set<String> _coachHealthAnalyticsKeys = <String>{
  'bodyModelVersion',
  'goalDirection',
  'kilogramsToGoal',
  'bmrKcal',
  'tdeeKcal',
  'bmiScreeningValue',
  'waistToHeightRatio',
  'expectedBodyFatPercent',
  'expectedFatFreeMassKg',
  'bodyFatEstimateMethod',
  'bodyFatEstimateUncertainty',
  'bodyFatEstimateIssue',
  'healthyWaistScreeningUpperCm',
  'obesityRiskScreening',
  'notice',
  'healthCitationIds',
};

/// Applies the user's independent Coach-context category choices to health.
///
/// This public pure function exists so the privacy boundary can be verified
/// without constructing repositories or a provider container. Unknown and
/// future fields are excluded until they are deliberately classified here.
Map<String, Object?> scopeCoachHealthForFocus({
  required Map<String, Object?> health,
  required bool includeNutrition,
  required bool includeTraining,
  required bool includeHabits,
  required bool includeAnalytics,
}) {
  final scoped = <String, Object?>{
    if (health['status'] != null) 'status': health['status'],
  };

  if (includeAnalytics) {
    for (final key in _coachHealthAnalyticsKeys) {
      if (health.containsKey(key) && health[key] != null) {
        scoped[key] = health[key];
      }
    }
  }

  if (includeNutrition) {
    if (health['dailyTargets'] != null) {
      scoped['dailyTargets'] = health['dailyTargets'];
    }
    if (health['dailyTargetSources'] != null) {
      scoped['dailyTargetSources'] = health['dailyTargetSources'];
    }
    if (health['mealTargets'] != null) {
      scoped['mealTargets'] = health['mealTargets'];
    }
  }

  final source = health['today'];
  final today = source is! Map
      ? <String, Object?>{}
      : <String, Object?>{
          if (source['day'] != null) 'day': source['day'],
          if (includeNutrition && source['nutrition'] != null)
            'nutrition': source['nutrition'],
          if (includeTraining && source['exerciseEnergy'] != null)
            'exerciseEnergy': source['exerciseEnergy'],
          if (includeHabits && source['sleep'] != null)
            'sleep': source['sleep'],
          if (includeHabits && source['fasting'] != null)
            'fasting': source['fasting'],
          if (includeHabits && source['bodyContext'] != null)
            'bodyContext': source['bodyContext'],
        };
  scoped['today'] = today;
  return scoped;
}

Map<String, Object?> _scopeCoachHealth({
  required Map<String, Object?> health,
  required bool includeNutrition,
  required bool includeTraining,
  required bool includeHabits,
  required bool includeAnalytics,
}) {
  return scopeCoachHealthForFocus(
    health: health,
    includeNutrition: includeNutrition,
    includeTraining: includeTraining,
    includeHabits: includeHabits,
    includeAnalytics: includeAnalytics,
  );
}

String _coachLocalDayKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-'
    '${local.month.toString().padLeft(2, '0')}-'
    '${local.day.toString().padLeft(2, '0')}';

/// Builds Coach's existing five-nutrient view from saved item evidence.
/// Mutable catalog rows are used only for the names of legacy entries.
List<CoachNutritionDay> assembleCoachNutritionDays(List<MealWithItems> meals) {
  const nutrients = <String, TrackedNutrient>{
    'caloriesKcal': TrackedNutrient.calories,
    'proteinG': TrackedNutrient.protein,
    'carbsG': TrackedNutrient.carbohydrates,
    'fatG': TrackedNutrient.fat,
    'sodiumMg': TrackedNutrient.sodium,
  };
  final byDay = <String, List<MealWithItems>>{};
  for (final meal in meals) {
    byDay.putIfAbsent(meal.meal.dayKey, () => []).add(meal);
  }
  final nutrition = <CoachNutritionDay>[];
  for (final entry in byDay.entries) {
    final totals = <String, double?>{
      for (final key in nutrients.keys) key: 0.0,
    };
    var itemCount = 0;
    final mealJson = <Map<String, Object?>>[];
    for (final meal in entry.value) {
      final items = <Map<String, Object?>>[];
      for (final item in meal.items) {
        itemCount += 1;
        final evidence = MealFoodEvidence.read(item, ownerKey: meal.ownerKey);
        final portion = evidence.portion;
        final ownerAvailable = meal.ownerKey != null || !evidence.isModern;
        final values = <String, double?>{
          for (final nutrient in nutrients.entries)
            nutrient.key: ownerAvailable ? evidence.value(nutrient.value) : null,
        };
        for (final nutrient in values.entries) {
          final previous = totals[nutrient.key];
          final value = nutrient.value;
          final sum = previous == null || value == null
              ? null
              : previous + value;
          totals[nutrient.key] = sum != null && sum.isFinite ? sum : null;
        }
        final quickAdd = item.foodSourceSnapshot == 'quick_add';
        final foodName = (ownerAvailable ? portion?.food.name : null) ??
            (evidence.isModern ? null : meal.foodsById[item.foodId]?.name);
        items.add({
          'itemId': item.id,
          if (quickAdd) 'entryType': 'quick_add',
          if (!quickAdd) 'food': foodName ?? 'historical-food',
          if (!quickAdd && ownerAvailable && evidence.isValid)
            'quantity': item.quantity,
          for (final nutrient in values.entries)
            if (nutrient.value != null) nutrient.key: nutrient.value,
        });
      }
      mealJson.add({
        'type': meal.meal.type,
        'name': meal.meal.name,
        'items': items,
      });
    }
    nutrition.add(
      CoachNutritionDay(
        day: entry.key,
        meals: mealJson,
        calories: totals['caloriesKcal'] ?? 0,
        protein: totals['proteinG'] ?? 0,
        carbs: totals['carbsG'] ?? 0,
        fat: totals['fatG'] ?? 0,
        sodium: totals['sodiumMg'] ?? 0,
        knownTotals: itemCount == 0
            ? const <String>{}
            : {
                for (final total in totals.entries)
                  if (total.value != null) total.key,
              },
      ),
    );
  }
  nutrition.sort((a, b) => b.day.compareTo(a.day));
  return nutrition;
}

List<Map<String, Object?>> _coachActivityHistory(
  List<DailyLog> dailyLogs,
  ConnectedHealthSnapshot? connectedHealth,
) {
  List<Map<String, Object?>> exercisesFor(DailyLog log) {
    final result = <Map<String, Object?>>[];
    for (final line in (log.exerciseNotes ?? '').split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) {
          result.add(Map<String, Object?>.from(decoded));
        }
      } on Object {
        // Legacy free text is excluded from remote Coach context.
      }
    }
    return result.take(12).toList(growable: false);
  }

  final activityByDay = <String, Map<String, Object?>>{
    for (final log in dailyLogs.take(14))
      log.dayKey: <String, Object?>{
        'day': log.dayKey,
        if (log.sleepHours != null) ...{
          'sleepHours': log.sleepHours,
          'sleepSource': 'manual',
        },
        if (log.steps != null) 'steps': log.steps,
        if (exercisesFor(log).isNotEmpty) 'exercises': exercisesFor(log),
      },
  };
  if (connectedHealth?.deviceVerified == true) {
    for (final signal in connectedHealth!.signals) {
      if (signal.key != 'sleep' ||
          !signal.value.isFinite ||
          signal.value <= 0 ||
          signal.value > 14) {
        continue;
      }
      final local = signal.observedAt.toLocal();
      final day = _coachLocalDayKey(local);
      final row = activityByDay.putIfAbsent(
        day,
        () => <String, Object?>{'day': day},
      );
      final previousAt = DateTime.tryParse(
        row['sleepObservedAt']?.toString() ?? '',
      );
      if (previousAt == null || signal.observedAt.isAfter(previousAt)) {
        row
          ..['sleepHours'] = signal.value
          ..['sleepSource'] = 'connected_health'
          ..['sleepDeviceSource'] = signal.source
          ..['sleepObservedAt'] = signal.observedAt.toUtc().toIso8601String()
          ..['sleepLastSyncAt'] = connectedHealth.lastSyncAt
              ?.toUtc()
              .toIso8601String();
      }
    }
  }
  final activityHistory =
      activityByDay.values
          .where((day) => day.length > 1)
          .toList(growable: false)
        ..sort((a, b) => '${b['day']}'.compareTo('${a['day']}'));
  return activityHistory;
}
