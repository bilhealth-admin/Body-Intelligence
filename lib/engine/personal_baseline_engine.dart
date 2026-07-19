enum BaselineConfidence { insufficient, low, medium, high }

class PersonalBaselineReport {
  const PersonalBaselineReport({
    required this.confidence,
    required this.baselineDays,
    required this.currentDays,
    required this.comparisons,
    required this.missingEvidence,
  });

  final BaselineConfidence confidence;
  final int baselineDays;
  final int currentDays;
  final List<BaselineComparison> comparisons;
  final List<String> missingEvidence;

  bool get sufficient => confidence != BaselineConfidence.insufficient;
}

class BaselineComparison {
  const BaselineComparison({
    required this.metric,
    required this.baseline,
    required this.current,
    required this.unit,
  });

  final String metric;
  final double baseline;
  final double current;
  final String unit;

  double get change => current - baseline;
}

class PersonalBaselineEngine {
  const PersonalBaselineEngine._();

  static PersonalBaselineReport evaluate({
    required Map<String, double> caloriesByDay,
    required Map<String, double> proteinByDay,
    required Map<String, double> sodiumByDay,
    required Map<String, double> waterByDay,
    required Map<String, double> weightByDay,
    required String currentStartDay,
  }) {
    final sources = <String, ({Map<String, double> values, String unit})>{
      'Calories': (values: caloriesByDay, unit: 'kcal'),
      'Protein': (values: proteinByDay, unit: 'g'),
      'Sodium': (values: sodiumByDay, unit: 'mg'),
      'Water': (values: waterByDay, unit: 'ml'),
      'Weight': (values: weightByDay, unit: 'kg'),
    };
    final comparisons = <BaselineComparison>[];
    var baselineDays = 0;
    var currentDays = 0;
    final missing = <String>[];

    for (final entry in sources.entries) {
      final current = entry.value.values.entries
          .where((row) => row.key.compareTo(currentStartDay) >= 0)
          .map((row) => row.value)
          .toList();
      final baseline = entry.value.values.entries
          .where((row) => row.key.compareTo(currentStartDay) < 0)
          .map((row) => row.value)
          .toList();
      baselineDays = baseline.length > baselineDays
          ? baseline.length
          : baselineDays;
      currentDays = current.length > currentDays ? current.length : currentDays;
      if (baseline.length < 7 || current.length < 3) {
        missing.add('${entry.key}: needs 7 earlier and 3 recent days');
        continue;
      }
      double mean(List<double> values) =>
          values.reduce((a, b) => a + b) / values.length;
      comparisons.add(
        BaselineComparison(
          metric: entry.key,
          baseline: mean(baseline),
          current: mean(current),
          unit: entry.value.unit,
        ),
      );
    }

    final confidence = comparisons.isEmpty
        ? BaselineConfidence.insufficient
        : baselineDays >= 21 && currentDays >= 7 && comparisons.length >= 3
        ? BaselineConfidence.high
        : comparisons.length >= 2
        ? BaselineConfidence.medium
        : BaselineConfidence.low;
    return PersonalBaselineReport(
      confidence: confidence,
      baselineDays: baselineDays,
      currentDays: currentDays,
      comparisons: comparisons,
      missingEvidence: missing,
    );
  }
}
