class CoachWeightPoint {
  const CoachWeightPoint({
    required this.at,
    required this.kg,
    this.measurementContext,
  });

  final DateTime at;
  final double kg;
  final String? measurementContext;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'kg': kg,
    if (measurementContext != null && measurementContext!.isNotEmpty)
      'measurementContext': measurementContext,
  };
}

class CoachNutritionDay {
  const CoachNutritionDay({
    required this.day,
    required this.meals,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sodium,
    this.knownTotals = const <String>{
      'caloriesKcal',
      'proteinG',
      'carbsG',
      'fatG',
      'sodiumMg',
    },
  });

  final String day;
  final List<Map<String, Object?>> meals;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sodium;
  final Set<String> knownTotals;

  Map<String, Object?> toJson() => {
    'day': day,
    'totals': {
      if (knownTotals.contains('caloriesKcal')) 'caloriesKcal': calories,
      if (knownTotals.contains('proteinG')) 'proteinG': protein,
      if (knownTotals.contains('carbsG')) 'carbsG': carbs,
      if (knownTotals.contains('fatG')) 'fatG': fat,
      if (knownTotals.contains('sodiumMg')) 'sodiumMg': sodium,
    },
    'knownTotals': knownTotals.toList(growable: false),
    'meals': meals,
  };
}

class CoachContextSnapshot {
  const CoachContextSnapshot({
    required this.generatedAt,
    required this.profile,
    required this.weights,
    required this.nutritionDays,
    required this.waterHistory,
    required this.computedHealth,
    this.canonicalIntelligence = const <String, Object?>{},
    this.decisionMemory = const <Map<String, Object?>>[],
    this.explicitMemories = const <Map<String, Object?>>[],
    this.activityHistory = const <Map<String, Object?>>[],
    this.bodyContextHistory = const <Map<String, Object?>>[],
    this.personalExperiments = const <Map<String, Object?>>[],
  });

  final DateTime generatedAt;
  final Map<String, Object?> profile;
  final List<CoachWeightPoint> weights;
  final List<CoachNutritionDay> nutritionDays;
  final List<Map<String, Object?>> waterHistory;
  final Map<String, Object?> computedHealth;
  final Map<String, Object?> canonicalIntelligence;
  final List<Map<String, Object?>> decisionMemory;
  final List<Map<String, Object?>> explicitMemories;
  final List<Map<String, Object?>> activityHistory;
  final List<Map<String, Object?>> bodyContextHistory;
  final List<Map<String, Object?>> personalExperiments;

  /// A truthful, non-personal context used when optional repository context
  /// cannot be prepared. Cloud AI availability must not depend on the user
  /// already having profile, meal, weight, or water records.
  factory CoachContextSnapshot.empty({DateTime? generatedAt}) {
    return CoachContextSnapshot(
      generatedAt: generatedAt ?? DateTime.now(),
      profile: const <String, Object?>{},
      weights: const <CoachWeightPoint>[],
      nutritionDays: const <CoachNutritionDay>[],
      waterHistory: const <Map<String, Object?>>[],
      computedHealth: const <String, Object?>{},
      canonicalIntelligence: const <String, Object?>{},
      decisionMemory: const <Map<String, Object?>>[],
      explicitMemories: const <Map<String, Object?>>[],
      activityHistory: const <Map<String, Object?>>[],
      bodyContextHistory: const <Map<String, Object?>>[],
      personalExperiments: const <Map<String, Object?>>[],
    );
  }

  /// Minimal identity safe for personalization; auth and contact data stay out.
  Map<String, Object?> get minimalIdentity {
    final value = profile['displayName']?.toString().trim();
    return <String, Object?>{
      if (value != null && value.isNotEmpty) 'displayName': value,
    };
  }

  Map<String, num>? nutritionRemainingFor(DateTime localDay) {
    final day =
        '${localDay.year.toString().padLeft(4, '0')}-'
        '${localDay.month.toString().padLeft(2, '0')}-'
        '${localDay.day.toString().padLeft(2, '0')}';
    CoachNutritionDay? consumed;
    for (final value in nutritionDays) {
      if (value.day == day) {
        consumed = value;
        break;
      }
    }
    final raw = computedHealth['dailyTargets'];
    if (raw is! Map) return null;
    if (consumed != null &&
        !consumed.knownTotals.containsAll(const <String>{
          'caloriesKcal',
          'proteinG',
          'carbsG',
          'fatG',
        })) {
      return null;
    }
    num remaining(String targetKey, num eaten) =>
        (((raw[targetKey] as num?) ?? 0) - eaten).clamp(0, double.infinity);
    return <String, num>{
      'caloriesKcal': remaining('caloriesKcal', consumed?.calories ?? 0),
      'proteinG': remaining('proteinG', consumed?.protein ?? 0),
      'carbsG': remaining('carbsG', consumed?.carbs ?? 0),
      'fatG': remaining('fatG', consumed?.fat ?? 0),
    };
  }

  Map<String, Object?> toJson() => {
    'schema': 'bil.coach-context.v2',
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'profile': profile,
    'weight': {
      'today': _weightAtDaysAgo(0),
      'yesterday': _weightAtDaysAgo(1),
      'sevenDaysAgo': _weightAtDaysAgo(7),
      'summary': _weightSummary(),
      'history': weights.map((item) => item.toJson()).toList(growable: false),
    },
    'nutritionHistory': nutritionDays
        .map((item) => item.toJson())
        .toList(growable: false),
    'waterHistory': waterHistory,
    'computedHealth': computedHealth,
    'canonicalIntelligence': canonicalIntelligence,
    'decisionMemory': decisionMemory,
    'explicitMemories': explicitMemories,
    'activityHistory': activityHistory,
    'bodyContextHistory': bodyContextHistory,
    'personalExperiments': personalExperiments,
  };

  /// Compact, deterministic facts computed from the complete weight series.
  ///
  /// Remote Coach requests intentionally send only a recent row-level sample,
  /// but full-range questions must still know the true first/latest values and
  /// month-by-month shape. This summary keeps that grounding without uploading
  /// an unbounded list of measurements.
  Map<String, Object?> _weightSummary() {
    if (weights.isEmpty) {
      return const <String, Object?>{'recordCount': 0, 'monthly': []};
    }
    final chronological = [...weights]
      ..sort((left, right) => left.at.compareTo(right.at));
    var minimum = chronological.first;
    var maximum = chronological.first;
    final grouped = <String, List<CoachWeightPoint>>{};
    for (final point in chronological) {
      if (point.kg < minimum.kg) minimum = point;
      if (point.kg > maximum.kg) maximum = point;
      final month =
          '${point.at.year.toString().padLeft(4, '0')}-'
          '${point.at.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(month, () => <CoachWeightPoint>[]).add(point);
    }
    final monthly = grouped.entries
        .map((entry) {
          final points = entry.value;
          var low = points.first.kg;
          var high = points.first.kg;
          for (final point in points.skip(1)) {
            if (point.kg < low) low = point.kg;
            if (point.kg > high) high = point.kg;
          }
          return <String, Object?>{
            'month': entry.key,
            'recordCount': points.length,
            'start': points.first.toJson(),
            'end': points.last.toJson(),
            'minimumKg': low,
            'maximumKg': high,
            'changeKg': points.last.kg - points.first.kg,
          };
        })
        .toList(growable: false);
    final boundedMonthly = monthly.length <= 24
        ? monthly
        : <Map<String, Object?>>[
            monthly.first,
            ...monthly.skip(monthly.length - 23),
          ];
    final first = chronological.first;
    final latest = chronological.last;
    return <String, Object?>{
      'recordCount': chronological.length,
      'firstRecorded': first.toJson(),
      'latestRecorded': latest.toJson(),
      'minimum': minimum.toJson(),
      'maximum': maximum.toJson(),
      'totalChangeKg': latest.kg - first.kg,
      'monthly': boundedMonthly,
      'monthlyCoverageComplete': monthly.length <= 24,
    };
  }

  Map<String, Object?>? _weightAtDaysAgo(int days) {
    final target = DateTime.now().subtract(Duration(days: days));
    for (final point in weights) {
      if (point.at.year == target.year &&
          point.at.month == target.month &&
          point.at.day == target.day) {
        return point.toJson();
      }
    }
    return null;
  }
}
