import '../domain/unified_food.dart';

enum FoodQualityIssue {
  missingArabicName,
  missingCategory,
  missingBarcode,
  missingServingBasis,
  missingCoreNutrition,
  missingOptionalNutrition,
  unverified,
  unknownSource,
}

enum FoodConfidenceLevel { low, medium, high }

class FoodQualityAssessment {
  final double score;
  final FoodConfidenceLevel confidence;
  final List<FoodQualityIssue> issues;

  const FoodQualityAssessment({
    required this.score,
    required this.confidence,
    required this.issues,
  });
}

class FoodQualityEngine {
  const FoodQualityEngine._();

  static FoodQualityAssessment assess(UnifiedFood food) {
    var score = 100.0;
    final issues = <FoodQualityIssue>[];

    void deduct(FoodQualityIssue issue, double points) {
      issues.add(issue);
      score -= points;
    }

    if (food.arabicName?.trim().isEmpty ?? true) {
      deduct(FoodQualityIssue.missingArabicName, 4);
    }
    if (food.category?.trim().isEmpty ?? true) {
      deduct(FoodQualityIssue.missingCategory, 5);
    }
    if (food.source == FoodDataSource.branded &&
        (food.barcode?.trim().isEmpty ?? true)) {
      deduct(FoodQualityIssue.missingBarcode, 8);
    }
    if (!food.serving.grams.isFinite || food.serving.grams <= 0) {
      deduct(FoodQualityIssue.missingServingBasis, 30);
    }

    const core = <FoodNutrient>{
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    };
    if (core.any((nutrient) => !food.hasEvidence(nutrient))) {
      deduct(FoodQualityIssue.missingCoreNutrition, 35);
    }

    const optional = <FoodNutrient>{
      FoodNutrient.fiber,
      FoodNutrient.sugar,
      FoodNutrient.sodium,
      FoodNutrient.potassium,
      FoodNutrient.calcium,
      FoodNutrient.magnesium,
    };
    final optionalKnown = optional.where(food.hasEvidence).length;
    if (optionalKnown < optional.length) {
      deduct(
        FoodQualityIssue.missingOptionalNutrition,
        (optional.length - optionalKnown) * 2,
      );
    }
    if (!food.verified) deduct(FoodQualityIssue.unverified, 10);
    if (food.source == FoodDataSource.unknown) {
      deduct(FoodQualityIssue.unknownSource, 12);
    }

    final bounded = score.clamp(0, 100).toDouble();
    final confidence = bounded >= 80
        ? FoodConfidenceLevel.high
        : bounded >= 55
        ? FoodConfidenceLevel.medium
        : FoodConfidenceLevel.low;
    return FoodQualityAssessment(
      score: bounded,
      confidence: confidence,
      issues: List.unmodifiable(issues),
    );
  }
}
