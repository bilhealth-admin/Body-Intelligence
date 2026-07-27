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
  invalidBodyFat,
}

class BodyCompositionMetric {
  const BodyCompositionMetric.available(this.value) : issue = null;

  const BodyCompositionMetric.unavailable(this.issue) : value = null;

  final double? value;
  final BodyCompositionIssue? issue;

  bool get isAvailable => value != null;
}

class BodyCompositionResult {
  const BodyCompositionResult({
    required this.bodyMassIndex,
    required this.bodyFatPercentage,
    required this.leanBodyMassKg,
  });

  final BodyCompositionMetric bodyMassIndex;
  final BodyCompositionMetric bodyFatPercentage;
  final BodyCompositionMetric leanBodyMassKg;
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
      bmi: bmi,
    );
    final leanMass = _leanBodyMass(
      currentWeightKg: currentWeightKg,
      bodyFat: bodyFat,
    );
    return BodyCompositionResult(
      bodyMassIndex: bmi,
      bodyFatPercentage: bodyFat,
      leanBodyMassKg: leanMass,
    );
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

    // Exact shipped US Navy circumference path for men.
    if (male) {
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
      if (neckCm == null) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.missingNeck,
        );
      }
      if (!neckCm.isFinite || neckCm <= 0 || waistCm <= neckCm) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.invalidNeck,
        );
      }
      final denominator =
          1.0324 -
          0.19077 * (math.log(waistCm - neckCm) / math.ln10) +
          0.15456 * (math.log(heightCm) / math.ln10);
      final estimate = 495 / denominator - 450;
      if (!estimate.isFinite) {
        return const BodyCompositionMetric.unavailable(
          BodyCompositionIssue.invalidBodyFat,
        );
      }
      return BodyCompositionMetric.available(estimate.clamp(3, 60));
    }

    // Exact shipped female behavior: BMI-age fallback because hip
    // circumference is not collected by the product.
    if (!bmi.isAvailable) {
      return BodyCompositionMetric.unavailable(bmi.issue!);
    }
    if (age == null) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.missingAge,
      );
    }
    if (age <= 0) {
      return const BodyCompositionMetric.unavailable(
        BodyCompositionIssue.invalidAge,
      );
    }
    const sexOffset = 0;
    return BodyCompositionMetric.available(
      ((1.20 * bmi.value!) + (0.23 * age) - (10.8 * sexOffset) - 5.4).clamp(
        3,
        60,
      ),
    );
  }

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
