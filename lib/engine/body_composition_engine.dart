import 'dart:math' as math;

enum BodyCompositionIssue {
  missingGender,
  unsupportedGender,
  missingAge,
  invalidAge,
  missingHeight,
  invalidHeight,
  missingWeight,
  invalidWeight,
  missingNeck,
  invalidNeck,
  missingWaist,
  invalidWaist,
  missingHip,
  invalidHip,
  invalidBodyFat,
}

enum BodyFatEstimateMethod { circumferenceHodgdonBeckett, bmiAgeFallback }

enum EstimateUncertainty { lower, higher }

class BodyCompositionMetric {
  const BodyCompositionMetric.available(
    this.value, {
    this.method,
    this.uncertainty = EstimateUncertainty.lower,
  }) : issue = null;

  const BodyCompositionMetric.unavailable(this.issue)
    : value = null,
      method = null,
      uncertainty = EstimateUncertainty.higher;

  final double? value;
  final BodyCompositionIssue? issue;
  final BodyFatEstimateMethod? method;
  final EstimateUncertainty uncertainty;

  bool get isAvailable => value != null;
}

class BodyCompositionResult {
  const BodyCompositionResult({
    required this.bodyMassIndex,
    required this.waistToHeightRatio,
    required this.bodyFatPercentage,
    required this.leanBodyMassKg,
  });

  final BodyCompositionMetric bodyMassIndex;
  final BodyCompositionMetric waistToHeightRatio;
  final BodyCompositionMetric bodyFatPercentage;

  /// Retained source-compatible name. Numerically this is fat-free mass:
  /// body weight minus estimated fat mass.
  final BodyCompositionMetric leanBodyMassKg;

  BodyCompositionMetric get fatFreeMassKg => leanBodyMassKg;
}

class BodyCompositionEngine {
  const BodyCompositionEngine._();

  static BodyCompositionResult calculate({
    required String? gender,
    required int? age,
    required double? heightCm,
    required double? currentWeightKg,
    required double? neckCm,
    required double? waistCm,
    double? hipCm,
  }) {
    final bmi = _bodyMassIndex(
      heightCm: heightCm,
      currentWeightKg: currentWeightKg,
    );
    final bodyFat = _bodyFatPercentage(
      gender: gender,
      age: age,
      heightCm: heightCm,
      neckCm: neckCm,
      waistCm: waistCm,
      hipCm: hipCm,
      bmi: bmi,
    );
    final leanMass = _leanBodyMass(
      currentWeightKg: currentWeightKg,
      bodyFat: bodyFat,
    );
    return BodyCompositionResult(
      bodyMassIndex: bmi,
      waistToHeightRatio: _waistToHeightRatio(
        heightCm: heightCm,
        waistCm: waistCm,
      ),
      bodyFatPercentage: bodyFat,
      leanBodyMassKg: leanMass,
    );
  }

  static BodyCompositionMetric _waistToHeightRatio({
    required double? heightCm,
    required double? waistCm,
  }) {
    if (heightCm == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingHeight,
      );
    }
    if (!heightCm.isFinite || heightCm <= 0) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidHeight,
      );
    }
    if (waistCm == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingWaist,
      );
    }
    if (!waistCm.isFinite || waistCm <= 0) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidWaist,
      );
    }
    return BodyCompositionMetric.available(waistCm / heightCm);
  }

  static BodyCompositionMetric _bodyMassIndex({
    required double? heightCm,
    required double? currentWeightKg,
  }) {
    if (heightCm == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingHeight,
      );
    }
    if (!heightCm.isFinite || heightCm <= 0) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidHeight,
      );
    }
    if (currentWeightKg == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingWeight,
      );
    }
    if (!currentWeightKg.isFinite || currentWeightKg <= 0) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidWeight,
      );
    }
    final heightM = heightCm / 100;
    return BodyCompositionMetric.available(
      currentWeightKg / (heightM * heightM),
    );
  }

  static BodyCompositionMetric _bodyFatPercentage({
    required String? gender,
    required int? age,
    required double? heightCm,
    required double? neckCm,
    required double? waistCm,
    required double? hipCm,
    required BodyCompositionMetric bmi,
  }) {
    if (gender == null || gender.trim().isEmpty) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingGender,
      );
    }
    final normalizedGender = gender.trim().toLowerCase();
    final male = normalizedGender == 'male' || normalizedGender == 'ذكر';
    final female = normalizedGender == 'female' || normalizedGender == 'أنثى';
    if (!male && !female) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.unsupportedGender,
      );
    }

    // Classic Hodgdon-Beckett circumference estimate historically associated
    // with U.S. Navy body-composition screening. This is an estimate, not a
    // current service compliance calculation or a clinical measurement. If
    // optional circumferences are incomplete, the model remains useful by
    // falling back to the explicitly higher-uncertainty BMI/age/sex estimate.
    if (male && waistCm != null && neckCm != null) {
      if (!waistCm.isFinite || waistCm <= 0) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.invalidWaist,
        );
      }
      if (!neckCm.isFinite || neckCm <= 0 || waistCm <= neckCm) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.invalidNeck,
        );
      }
      if (heightCm == null) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.missingHeight,
        );
      }
      if (!heightCm.isFinite || heightCm <= 0) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.invalidHeight,
        );
      }
      final inchesPerCm = 1 / 2.54;
      final estimate =
          86.010 * _log10((waistCm - neckCm) * inchesPerCm) -
          70.041 * _log10(heightCm * inchesPerCm) +
          36.76;
      if (!estimate.isFinite || estimate <= 0 || estimate >= 75) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.invalidBodyFat,
        );
      }
      return BodyCompositionMetric.available(
        estimate,
        method: BodyFatEstimateMethod.circumferenceHodgdonBeckett,
      );
    }

    // The classic female Hodgdon-Beckett circumference estimate requires
    // waist + hips - neck. Never substitute or silently drop neck. When the
    // full set is absent, use the separately identified BMI-age estimate.
    if (waistCm != null || neckCm != null || hipCm != null) {
      final allCircumferencesPresent =
          waistCm != null && neckCm != null && hipCm != null;
      if (allCircumferencesPresent) {
        if (!waistCm.isFinite || waistCm <= 0) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.invalidWaist,
          );
        }
        if (!neckCm.isFinite || neckCm <= 0) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.invalidNeck,
          );
        }
        if (!hipCm.isFinite || hipCm <= 0) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.invalidHip,
          );
        }
        if (heightCm == null) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.missingHeight,
          );
        }
        if (!heightCm.isFinite || heightCm <= 0) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.invalidHeight,
          );
        }
        final inchesPerCm = 1 / 2.54;
        final circumference = (waistCm + hipCm - neckCm) * inchesPerCm;
        if (circumference <= 0) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.invalidBodyFat,
          );
        }
        final estimate =
            163.205 * _log10(circumference) -
            97.684 * _log10(heightCm * inchesPerCm) -
            78.387;
        if (!estimate.isFinite || estimate <= 0 || estimate >= 75) {
          return const BodyCompositionMetric.unavailable(
            BodyCompositionIssue.invalidBodyFat,
          );
        }
        return BodyCompositionMetric.available(
          estimate,
          method: BodyFatEstimateMethod.circumferenceHodgdonBeckett,
        );
      }
    }

    // Deurenberg adult BMI-age fallback (SEE 4.1 percentage points in the
    // source cohort). It is explicitly marked higher uncertainty and is not a
    // circumference result.
    if (!bmi.isAvailable) {
      return BodyCompositionMetric.unavailable(bmi.issue!);
    }
    if (age == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingAge,
      );
    }
    if (age < 16) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidAge,
      );
    }
    final sexOffset = male ? 1 : 0;
    final estimate =
        (1.20 * bmi.value!) + (0.23 * age) - (10.8 * sexOffset) - 5.4;
    if (!estimate.isFinite || estimate <= 0 || estimate >= 75) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidBodyFat,
      );
    }
    return BodyCompositionMetric.available(
      estimate,
      method: BodyFatEstimateMethod.bmiAgeFallback,
      uncertainty: EstimateUncertainty.higher,
    );
  }

  static double _log10(double value) => math.log(value) / math.ln10;

  static BodyCompositionMetric _leanBodyMass({
    required double? currentWeightKg,
    required BodyCompositionMetric bodyFat,
  }) {
    if (currentWeightKg == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingWeight,
      );
    }
    if (!currentWeightKg.isFinite || currentWeightKg <= 0) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidWeight,
      );
    }
    if (!bodyFat.isAvailable) {
      return BodyCompositionMetric.unavailable(bodyFat.issue!);
    }
    return BodyCompositionMetric.available(
      currentWeightKg * (1 - bodyFat.value! / 100),
    );
  }
}
