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
    heartHealthy => const [
      TrackedNutrient.sodium,
      TrackedNutrient.fiber,
      TrackedNutrient.potassium,
    ],
    carbConscious || custom => const [
      TrackedNutrient.carbohydrates,
      TrackedNutrient.sugar,
      TrackedNutrient.fiber,
    ],
    caloriesAndMacros => const [],
  };
}

enum NutrientDashboardMetric { sodium, fiber, potassium, carbohydrates, sugar }

class NutrientDashboardSample {
  const NutrientDashboardSample({
    required this.evidenceMask,
    required this.values,
    this.source,
  });
  final int evidenceMask;
  final Map<TrackedNutrient, double> values;
  final String? source;

  bool isKnown(TrackedNutrient nutrient) {
    final value = values[nutrient];
    if (value == null || !value.isFinite || value < 0) {
      return false;
    }
    final capturedSource = source;
    return capturedSource == null
        ? NutrientEvidenceMask.contains(evidenceMask, nutrient)
        : NutrientEvidenceMask.isKnown(
            mask: evidenceMask,
            source: capturedSource,
            nutrient: nutrient,
            value: value,
          );
  }
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
    // Unknown is not zero. Keep the strictly evidenced subtotal even if one
    // food is missing this nutrient; never call a partial sum complete.
    final known = rows.where((row) => row.isKnown(nutrient)).toList();
    if (known.isEmpty) {
      return const EvidencedNutrientValue(value: null, complete: false);
    }
    final subtotal = known.fold<double>(
      0,
      (sum, row) => sum + row.values[nutrient]!,
    );
    if (!subtotal.isFinite) {
      return const EvidencedNutrientValue(value: null, complete: false);
    }
    return EvidencedNutrientValue(
      value: subtotal,
      complete: known.length == rows.length,
    );
  }
}

class NutrientDashboardGoalSet {
  const NutrientDashboardGoalSet({
    required this.sodiumMg,
    required this.fiberG,
    required this.potassiumMg,
    required this.carbohydratesG,
    required this.sugarG,
  });
  final double? sodiumMg, fiberG, potassiumMg, carbohydratesG, sugarG;
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
