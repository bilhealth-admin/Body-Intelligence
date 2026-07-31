class WeeklyReview {
  const WeeklyReview({
    required this.trackedDays,
    required this.weightDays,
    required this.nutritionDays,
    required this.waterDays,
    required this.contextDays,
    required this.summary,
    required this.nextDecision,
    required this.missingData,
  });

  final int trackedDays;
  final int weightDays;
  final int nutritionDays;
  final int waterDays;
  final int contextDays;
  final String summary;
  final String nextDecision;
  final List<String> missingData;
}

class WeeklyReviewEngine {
  const WeeklyReviewEngine._();

  static WeeklyReview evaluate({
    required int weightDays,
    required int nutritionDays,
    required int waterDays,
    required int contextDays,
    required double? weeklyWeightChangeKg,
  }) {
    final trackedDays = [
      weightDays,
      nutritionDays,
      waterDays,
    ].reduce((a, b) => a > b ? a : b);
    final missing = <String>[
      if (weightDays < 4) 'At least 4 weight days improve trend interpretation',
      if (nutritionDays < 5) 'More complete meal days improve intake context',
      if (waterDays < 5) 'More hydration days improve adherence context',
    ];
    final summary = weeklyWeightChangeKg == null
        ? 'There is not enough comparable weight evidence for a weekly direction.'
        : 'Smoothed weekly direction: ${weeklyWeightChangeKg >= 0 ? '+' : ''}${weeklyWeightChangeKg.toStringAsFixed(2)} kg. This does not identify fat or muscle change.';
    final nextDecision = missing.isNotEmpty
        ? 'Improve one missing data source before changing the plan.'
        : 'Keep the plan stable and compare another complete week.';
    return WeeklyReview(
      trackedDays: trackedDays,
      weightDays: weightDays,
      nutritionDays: nutritionDays,
      waterDays: waterDays,
      contextDays: contextDays,
      summary: summary,
      nextDecision: nextDecision,
      missingData: missing,
    );
  }
}
