class CoachWeightPoint {
  const CoachWeightPoint({required this.at, required this.kg});

  final DateTime at;
  final double kg;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'kg': kg,
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
  });

  final String day;
  final List<Map<String, Object?>> meals;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sodium;

  Map<String, Object?> toJson() => {
    'day': day,
    'totals': {
      'caloriesKcal': calories,
      'proteinG': protein,
      'carbsG': carbs,
      'fatG': fat,
      'sodiumMg': sodium,
    },
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
  });

  final DateTime generatedAt;
  final Map<String, Object?> profile;
  final List<CoachWeightPoint> weights;
  final List<CoachNutritionDay> nutritionDays;
  final List<Map<String, Object?>> waterHistory;
  final Map<String, Object?> computedHealth;

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
    'schema': 'bil.coach-context.v1',
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'profile': profile,
    'weight': {
      'today': _weightAtDaysAgo(0),
      'yesterday': _weightAtDaysAgo(1),
      'sevenDaysAgo': _weightAtDaysAgo(7),
      'history': weights.map((item) => item.toJson()).toList(growable: false),
    },
    'nutritionHistory': nutritionDays
        .map((item) => item.toJson())
        .toList(growable: false),
    'waterHistory': waterHistory,
    'computedHealth': computedHealth,
  };

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
