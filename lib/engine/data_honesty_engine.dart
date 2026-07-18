enum DataReliability { insufficient, emerging, useful, strong }

class DataHonestyReport {
  const DataHonestyReport({
    required this.score,
    required this.reliability,
    required this.strengths,
    required this.missing,
  });

  final int score;
  final DataReliability reliability;
  final List<String> strengths;
  final List<String> missing;
}

class DataHonestyEngine {
  const DataHonestyEngine._();

  static DataHonestyReport evaluate({
    required int observationDays,
    required int weightDays,
    required int nutritionDays,
    required int waterDays,
    required int consistentConditionDays,
  }) {
    if (observationDays <= 0) {
      return const DataHonestyReport(
        score: 0,
        reliability: DataReliability.insufficient,
        strengths: [],
        missing: [
          'No observation days yet',
          'Add weight, meals, and water to establish a baseline',
        ],
      );
    }
    final denominator = observationDays.clamp(1, 30);
    double coverage(int days) => (days.clamp(0, denominator) / denominator);
    final durationScore = (observationDays / 14).clamp(0.0, 1.0);
    final score =
        (100 *
                (durationScore * 0.2 +
                    coverage(weightDays) * 0.3 +
                    coverage(nutritionDays) * 0.3 +
                    coverage(waterDays) * 0.1 +
                    coverage(consistentConditionDays) * 0.1))
            .round()
            .clamp(0, 100);
    final strengths = <String>[
      if (weightDays >= 7) '$weightDays days with weight',
      if (nutritionDays >= 7) '$nutritionDays days with meal data',
      if (waterDays >= 7) '$waterDays days with hydration data',
      if (consistentConditionDays >= 5)
        '$consistentConditionDays comparable weigh-ins',
    ];
    final missing = <String>[
      if (observationDays < 14) 'At least 14 observation days improve trends',
      if (weightDays < 7)
        '${7 - weightDays} more weight days for a useful trend',
      if (nutritionDays < 7)
        '${7 - nutritionDays} more complete meal days for intake context',
      if (consistentConditionDays < 5)
        'Record similar measurement conditions on more days',
    ];
    return DataHonestyReport(
      score: score,
      reliability: observationDays < 7
          ? DataReliability.insufficient
          : switch (score) {
              < 55 => DataReliability.emerging,
              < 75 => DataReliability.useful,
              _ => DataReliability.strong,
            },
      strengths: strengths,
      missing: missing,
    );
  }
}
