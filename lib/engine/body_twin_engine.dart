class BodyTwinScenario {
  const BodyTwinScenario({
    required this.dailyCalories,
    required this.expectedWeeklyKg,
    required this.cautiousLowKg,
    required this.cautiousHighKg,
    required this.assumptions,
  });

  final int dailyCalories;
  final double expectedWeeklyKg;
  final double cautiousLowKg;
  final double cautiousHighKg;
  final List<String> assumptions;
}

class BodyTwinReport {
  const BodyTwinReport({
    required this.sufficient,
    required this.requiredData,
    this.scenario,
  });

  final bool sufficient;
  final List<String> requiredData;
  final BodyTwinScenario? scenario;
}

class BodyTwinEngine {
  const BodyTwinEngine._();

  static BodyTwinReport simulate({
    required int calorieTarget,
    required int tdee,
    required int weightDays,
    required int nutritionDays,
    required int observationDays,
  }) {
    final required = <String>[
      if (observationDays < 14) '${14 - observationDays} more observation days',
      if (weightDays < 7) '${7 - weightDays} more weight days',
      if (nutritionDays < 7) '${7 - nutritionDays} more nutrition days',
    ];
    if (required.isNotEmpty) {
      return BodyTwinReport(sufficient: false, requiredData: required);
    }
    // 7700 kcal/kg is used only as a cautious planning approximation. It is
    // not presented as measured tissue change or medical prediction.
    final expected = ((calorieTarget - tdee) * 7) / 7700;
    final uncertainty = 0.2 + expected.abs() * 0.35;
    return BodyTwinReport(
      sufficient: true,
      requiredData: const [],
      scenario: BodyTwinScenario(
        dailyCalories: calorieTarget,
        expectedWeeklyKg: expected,
        cautiousLowKg: expected - uncertainty,
        cautiousHighKg: expected + uncertainty,
        assumptions: const [
          'Logged intake is reasonably complete',
          'Activity and measurement conditions remain broadly similar',
          'Scale change cannot identify fat or muscle with certainty',
        ],
      ),
    );
  }
}
