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

List<CoachNutritionDay> _coachNutritionDays(List<MealWithItems> meals) {
  final byDay = <String, List<MealWithItems>>{};
  for (final meal in meals) {
    final date = meal.meal.date;
    final day =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    byDay.putIfAbsent(day, () => []).add(meal);
  }
  final nutrition = <CoachNutritionDay>[];
  for (final entry in byDay.entries) {
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var sodium = 0.0;
    var itemCount = 0;
    final knownTotals = <String>{
      'caloriesKcal',
      'proteinG',
      'carbsG',
      'fatG',
      'sodiumMg',
    };
    final mealJson = <Map<String, Object?>>[];
    for (final meal in entry.value) {
      final items = <Map<String, Object?>>[];
      for (final item in meal.items) {
        itemCount += 1;
        bool knows(TrackedNutrient nutrient) =>
            NutrientEvidenceMask.contains(item.nutrientEvidenceMask, nutrient);
        if (!knows(TrackedNutrient.calories)) {
          knownTotals.remove('caloriesKcal');
        }
        if (!knows(TrackedNutrient.protein)) {
          knownTotals.remove('proteinG');
        }
        if (!knows(TrackedNutrient.carbohydrates)) {
          knownTotals.remove('carbsG');
        }
        if (!knows(TrackedNutrient.fat)) knownTotals.remove('fatG');
        if (!knows(TrackedNutrient.sodium)) knownTotals.remove('sodiumMg');
        calories += item.calories;
        protein += item.protein;
        carbs += item.carbs;
        fat += item.fats;
        sodium += item.sodium;
        items.add({
          'itemId': item.id,
          'food': meal.foodsById[item.foodId]?.name ?? 'historical-food',
          'quantity': item.quantity,
          if (knows(TrackedNutrient.calories)) 'caloriesKcal': item.calories,
          if (knows(TrackedNutrient.protein)) 'proteinG': item.protein,
          if (knows(TrackedNutrient.carbohydrates)) 'carbsG': item.carbs,
          if (knows(TrackedNutrient.fat)) 'fatG': item.fats,
          if (knows(TrackedNutrient.sodium)) 'sodiumMg': item.sodium,
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
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        sodium: sodium,
        knownTotals: itemCount == 0 ? const <String>{} : knownTotals,
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
      final day =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
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
