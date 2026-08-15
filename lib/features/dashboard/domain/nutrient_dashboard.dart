import '../../../data/database/nutrient_evidence.dart';

enum NutrientDashboardPreset {
  caloriesAndMacros,
  heartHealthy,
  carbConscious,
  custom;

  static NutrientDashboardPreset parse(String? value) => switch (value) {
    'Heart healthy' => heartHealthy,
    'Low carb' => carbConscious,
    'Custom' => custom,
    _ => caloriesAndMacros,
  };

  List<TrackedNutrient> get evidenceMetrics => switch (this) {
    heartHealthy => const [TrackedNutrient.sodium, TrackedNutrient.fiber],
    carbConscious || custom => const [
      TrackedNutrient.carbohydrates,
      TrackedNutrient.sugar,
      TrackedNutrient.fiber,
    ],
    caloriesAndMacros => const [],
  };
}

enum NutrientDashboardMetric {
  saturatedFat,
  sodium,
  fiber,
  carbohydrates,
  sugar,
}

class NutrientDashboardSample {
  const NutrientDashboardSample({
    required this.evidenceMask,
    required this.values,
  });
  final int evidenceMask;
  final Map<TrackedNutrient, double> values;
}

class EvidencedNutrientValue {
  const EvidencedNutrientValue({required this.value, required this.complete});
  final double? value;
  final bool complete;
}

abstract final class NutrientDashboardEvidence {
  static EvidencedNutrientValue total(
    Iterable<NutrientDashboardSample> samples,
    TrackedNutrient nutrient,
  ) {
    final rows = samples.toList(growable: false);
    if (rows.isEmpty ||
        rows.any(
          (row) =>
              !NutrientEvidenceMask.contains(row.evidenceMask, nutrient) ||
              !row.values.containsKey(nutrient),
        )) {
      return const EvidencedNutrientValue(value: null, complete: false);
    }
    return EvidencedNutrientValue(
      value: rows.fold<double>(0, (sum, row) => sum + row.values[nutrient]!),
      complete: true,
    );
  }
}

class NutrientDashboardGoalSet {
  const NutrientDashboardGoalSet({
    required this.saturatedFatG,
    required this.sodiumMg,
    required this.fiberG,
    required this.carbohydratesG,
    required this.sugarG,
  });
  final double? saturatedFatG, sodiumMg, fiberG, carbohydratesG, sugarG;
}

enum NutrientProgressState { unknown, below, near, reached, exceeded }

abstract final class NutrientProgressPolicy {
  static NutrientProgressState evaluate({
    required double? value,
    required double goal,
    required bool minimumGoal,
  }) {
    if (value == null || goal <= 0) return NutrientProgressState.unknown;
    final ratio = value / goal;
    if (minimumGoal) {
      if (ratio >= 1) return NutrientProgressState.reached;
      return ratio >= .8
          ? NutrientProgressState.near
          : NutrientProgressState.below;
    }
    if (ratio > 1) return NutrientProgressState.exceeded;
    return ratio >= .8
        ? NutrientProgressState.near
        : NutrientProgressState.below;
  }
}
