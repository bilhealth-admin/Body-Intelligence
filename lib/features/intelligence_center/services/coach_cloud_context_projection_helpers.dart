part of 'coach_cloud_privacy_boundary.dart';

Map<String, Object?> _projectCoachProfile(
  Map<String, Object?> profile,
  Set<CoachCloudContextCategory> categories, {
  bool strictCategoryScope = false,
}) {
  final keys = <String>{};
  if (categories.contains(
    CoachCloudContextCategory.weightMeasurementsAndGoal,
  )) {
    keys.addAll(const <String>{
      'age',
      'gender',
      'heightCm',
      'currentWeightKg',
      'targetWeightKg',
      'waistCm',
      'neckCm',
      'hipCm',
      'chestCm',
      'armCm',
      'thighCm',
      'selectedGoals',
      'goalConsumers',
    });
  }
  if (categories.contains(CoachCloudContextCategory.nutritionAndWater)) {
    keys.add('dietaryPreferences');
    if (!strictCategoryScope) {
      keys.addAll(const <String>{
        'age',
        'gender',
        'heightCm',
        'currentWeightKg',
        'targetWeightKg',
        'activityLevel',
        'dietaryPreferences',
        'selectedGoals',
        'goalConsumers',
      });
    }
  }
  if (categories.contains(CoachCloudContextCategory.trainingAndActivity)) {
    keys.addAll(const <String>{'activityLevel', 'exercises'});
    if (!strictCategoryScope) {
      keys.addAll(const <String>{
        'age',
        'gender',
        'heightCm',
        'currentWeightKg',
        'activityLevel',
        'exercises',
        'selectedGoals',
        'goalConsumers',
      });
    }
  }
  if (!strictCategoryScope &&
      categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
    keys.addAll(const <String>{'selectedGoals', 'goalConsumers'});
  }
  return <String, Object?>{
    for (final key in keys)
      if (profile.containsKey(key) && profile[key] != null) key: profile[key],
  };
}

const Set<String> _weightComputedHealthKeys = <String>{
  'status',
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

Map<String, Object?> _projectComputedHealth(
  Map<String, Object?> health,
  Set<CoachCloudContextCategory> categories, {
  bool strictCategoryScope = false,
}) {
  if (categories.isEmpty) return const <String, Object?>{};
  final result = <String, Object?>{};
  if (health['status'] != null) result['status'] = health['status'];
  if (categories.contains(
    CoachCloudContextCategory.weightMeasurementsAndGoal,
  )) {
    for (final key in _weightComputedHealthKeys) {
      if (health.containsKey(key) && health[key] != null) {
        result[key] = health[key];
      }
    }
  }
  if (categories.contains(CoachCloudContextCategory.nutritionAndWater)) {
    for (final key in const <String>{
      'dailyTargets',
      'dailyTargetSources',
      'mealTargets',
    }) {
      if (health.containsKey(key) && health[key] != null) {
        result[key] = health[key];
      }
    }
  }
  if (!strictCategoryScope &&
      categories.contains(CoachCloudContextCategory.trainingAndActivity)) {
    for (final key in const <String>{'bmrKcal', 'tdeeKcal'}) {
      if (health.containsKey(key) && health[key] != null) {
        result[key] = health[key];
      }
    }
  }
  final source = health['today'];
  if (source is Map) {
    final today = <String, Object?>{};
    if (source['day'] != null) today['day'] = source['day'];
    if (categories.contains(CoachCloudContextCategory.nutritionAndWater) &&
        source['nutrition'] != null) {
      today['nutrition'] = source['nutrition'];
    }
    if (categories.contains(CoachCloudContextCategory.trainingAndActivity) &&
        source['exerciseEnergy'] != null) {
      today['exerciseEnergy'] = source['exerciseEnergy'];
    }
    if (categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
      for (final key in const <String>{'sleep', 'fasting', 'bodyContext'}) {
        if (source[key] != null) today[key] = source[key];
      }
    }
    if (today.isNotEmpty) result['today'] = today;
  }
  return result;
}

Map<String, Object?> _projectCanonicalIntelligence(
  Map<String, Object?> source,
) {
  const keys = <String>{
    'status',
    'canPresent',
    'confidence',
    'bodyTwin',
    'adaptiveTdeeKcal',
    'plateauRisk',
    'physiologicalNoise',
    'forecast',
  };
  return <String, Object?>{
    for (final key in keys)
      if (source.containsKey(key) && source[key] != null) key: source[key],
  };
}

List<Map<String, Object?>> _boundedNutritionDays(
  CoachContextSnapshot context,
) => context.nutritionDays
    .take(7)
    .map((day) {
      final value = day.toJson();
      final meals = (value['meals']! as List)
          .take(6)
          .map((rawMeal) {
            final meal = Map<String, Object?>.from(rawMeal as Map);
            final items = meal['items'];
            if (items is List) {
              meal['items'] = items.take(12).toList(growable: false);
            }
            return meal;
          })
          .toList(growable: false);
      return <String, Object?>{...value, 'meals': meals};
    })
    .toList(growable: false);

Map<String, Object?> _scopedActivityEntry(
  Map<String, Object?> source,
  Set<CoachCloudContextCategory> categories,
) {
  final keys = <String>{'day'};
  if (categories.contains(CoachCloudContextCategory.trainingAndActivity)) {
    keys.addAll(const <String>{'steps', 'exercises'});
  }
  if (categories.contains(CoachCloudContextCategory.sleepAndHabits)) {
    keys.addAll(const <String>{
      'sleepHours',
      'sleepSource',
      'sleepDeviceSource',
      'sleepObservedAt',
      'sleepLastSyncAt',
    });
  }
  return <String, Object?>{
    for (final key in keys)
      if (source.containsKey(key) && source[key] != null) key: source[key],
  };
}

List<Map<String, Object?>> _categoryRelevantEntries(
  List<Map<String, Object?>> source,
  Set<CoachCloudContextCategory> categories,
  int limit, {
  bool strictCategoryScope = false,
}) {
  if (categories.isEmpty) return const <Map<String, Object?>>[];
  return source
      .where((entry) {
        final entryCategories = _coachCloudCategoriesInText(jsonEncode(entry));
        return strictCategoryScope
            ? entryCategories.isNotEmpty &&
                  entryCategories.every(categories.contains)
            : entryCategories.any(categories.contains);
      })
      .take(limit)
      .toList(growable: false);
}

Map<String, Object?> _enforceCoachContextBudget(Map<String, Object?> source) {
  if (jsonEncode(source).length <= 19_000) return source;
  final bounded = Map<String, Object?>.from(source);
  final nutrition = bounded['nutritionHistory'];
  if (nutrition is List) {
    bounded['nutritionHistory'] = nutrition
        .whereType<Map>()
        .map(
          (day) => <String, Object?>{
            if (day['day'] != null) 'day': day['day'],
            if (day['totals'] != null) 'totals': day['totals'],
            if (day['knownTotals'] != null) 'knownTotals': day['knownTotals'],
          },
        )
        .toList(growable: false);
  }
  final weight = bounded['weight'];
  if (weight is Map) {
    final reduced = Map<String, Object?>.from(weight);
    final history = reduced['history'];
    if (history is List) {
      reduced['history'] = history.take(20).toList(growable: false);
    }
    bounded['weight'] = reduced;
  }
  for (final key in const <String>[
    'bodyContextHistory',
    'activityHistory',
    'decisionMemory',
    'explicitMemories',
    'personalExperiments',
  ]) {
    final values = bounded[key];
    if (values is List) bounded[key] = values.take(6).toList(growable: false);
  }
  var sanitized = sanitizeCoachCloudObject(bounded);
  if (jsonEncode(sanitized).length <= 19_000) return sanitized;
  // Retain summaries and current targets, but never exceed the server limit by
  // forwarding an unexpectedly large row-level record.
  for (final key in const <String>[
    'bodyContextHistory',
    'activityHistory',
    'decisionMemory',
    'explicitMemories',
    'personalExperiments',
    'nutritionHistory',
  ]) {
    sanitized.remove(key);
    if (jsonEncode(sanitized).length <= 19_000) return sanitized;
  }
  final reducedWeight = sanitized['weight'];
  if (reducedWeight is Map) {
    final weightSummary = Map<String, Object?>.from(reducedWeight)
      ..remove('history');
    sanitized['weight'] = weightSummary;
  }
  if (jsonEncode(sanitized).length <= 19_000) return sanitized;
  // Unknown oversized nested values fail closed individually.
  sanitized.remove('canonicalIntelligence');
  sanitized.remove('computedHealth');
  sanitized.remove('profile');
  return sanitizeCoachCloudObject(sanitized);
}
