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

class FoodQualityRecord {
  final UnifiedFood food;
  final FoodQualityAssessment assessment;

  const FoodQualityRecord({required this.food, required this.assessment});
}

class FoodQualityAudit {
  final int totalFoods;
  final int highConfidenceCount;
  final int mediumConfidenceCount;
  final int lowConfidenceCount;
  final List<FoodQualityRecord> records;

  const FoodQualityAudit({
    required this.totalFoods,
    required this.highConfidenceCount,
    required this.mediumConfidenceCount,
    required this.lowConfidenceCount,
    required this.records,
  });

  int countFor(FoodConfidenceLevel level) => switch (level) {
    FoodConfidenceLevel.high => highConfidenceCount,
    FoodConfidenceLevel.medium => mediumConfidenceCount,
    FoodConfidenceLevel.low => lowConfidenceCount,
  };
}

class FoodQualityAuditEngine {
  const FoodQualityAuditEngine._();

  static FoodQualityAudit audit(
    Iterable<UnifiedFood> foods, {
    FoodConfidenceLevel? maximumConfidence,
    FoodQualityIssue? issue,
    int limit = 1000,
  }) {
    if (limit <= 0) {
      return const FoodQualityAudit(
        totalFoods: 0,
        highConfidenceCount: 0,
        mediumConfidenceCount: 0,
        lowConfidenceCount: 0,
        records: <FoodQualityRecord>[],
      );
    }

    final all = foods
        .map(
          (food) => FoodQualityRecord(
            food: food,
            assessment: FoodQualityEngine.assess(food),
          ),
        )
        .toList(growable: false);

    final high = all
        .where(
          (record) => record.assessment.confidence == FoodConfidenceLevel.high,
        )
        .length;
    final medium = all
        .where(
          (record) =>
              record.assessment.confidence == FoodConfidenceLevel.medium,
        )
        .length;
    final low = all
        .where(
          (record) => record.assessment.confidence == FoodConfidenceLevel.low,
        )
        .length;

    var filtered = all.where((record) {
      if (maximumConfidence != null &&
          _rank(record.assessment.confidence) > _rank(maximumConfidence)) {
        return false;
      }
      if (issue != null && !record.assessment.issues.contains(issue)) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((left, right) {
      final scoreOrder = left.assessment.score.compareTo(
        right.assessment.score,
      );
      if (scoreOrder != 0) return scoreOrder;
      final issueOrder = right.assessment.issues.length.compareTo(
        left.assessment.issues.length,
      );
      if (issueOrder != 0) return issueOrder;
      return left.food.name.toLowerCase().compareTo(
        right.food.name.toLowerCase(),
      );
    });

    return FoodQualityAudit(
      totalFoods: all.length,
      highConfidenceCount: high,
      mediumConfidenceCount: medium,
      lowConfidenceCount: low,
      records: List<FoodQualityRecord>.unmodifiable(filtered.take(limit)),
    );
  }

  static int _rank(FoodConfidenceLevel level) => switch (level) {
    FoodConfidenceLevel.low => 0,
    FoodConfidenceLevel.medium => 1,
    FoodConfidenceLevel.high => 2,
  };
}
