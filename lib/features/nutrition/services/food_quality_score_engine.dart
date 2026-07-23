import '../domain/unified_food.dart';
import 'food_quality_engine.dart';

enum FoodProfileBand { limitedEvidence, lower, moderate, higher }

enum FoodQualityScoreReason {
  proteinDensity,
  fiberDensity,
  highSugarDensity,
  highSodiumDensity,
  completeCoreNutrition,
  missingCoreNutrition,
  limitedOptionalEvidence,
  verifiedSource,
  unverifiedSource,
}

class FoodQualityScore {
  final double profileScore;
  final FoodProfileBand band;
  final double evidenceConfidence;
  final FoodQualityAssessment dataQuality;
  final List<FoodQualityScoreReason> reasons;

  const FoodQualityScore({
    required this.profileScore,
    required this.band,
    required this.evidenceConfidence,
    required this.dataQuality,
    required this.reasons,
  });

  bool get hasSufficientEvidence => band != FoodProfileBand.limitedEvidence;
}

/// Produces a conservative, explainable nutrient-profile score.
///
/// The score is not a medical diagnosis and intentionally keeps nutritional
/// profile separate from source/data confidence. Missing nutrients are never
/// interpreted as zero.
class FoodQualityScoreEngine {
  const FoodQualityScoreEngine._();

  static FoodQualityScore score(UnifiedFood food) {
    final dataQuality = FoodQualityEngine.assess(food);
    final reasons = <FoodQualityScoreReason>[];

    const core = <FoodNutrient>[
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    ];
    final knownCore = core.where(food.hasEvidence).length;
    final optionalKnown = <FoodNutrient>[
      FoodNutrient.fiber,
      FoodNutrient.sugar,
      FoodNutrient.sodium,
    ].where(food.hasEvidence).length;

    if (knownCore < core.length) {
      reasons.add(FoodQualityScoreReason.missingCoreNutrition);
      return FoodQualityScore(
        profileScore: 50,
        band: FoodProfileBand.limitedEvidence,
        evidenceConfidence: _confidence(
          knownCore: knownCore,
          optionalKnown: optionalKnown,
          verified: food.verified,
        ),
        dataQuality: dataQuality,
        reasons: List<FoodQualityScoreReason>.unmodifiable(reasons),
      );
    }

    reasons.add(FoodQualityScoreReason.completeCoreNutrition);
    var score = 50.0;

    final basisGrams = food.serving.grams;
    if (!basisGrams.isFinite || basisGrams <= 0) {
      return FoodQualityScore(
        profileScore: 50,
        band: FoodProfileBand.limitedEvidence,
        evidenceConfidence: 0,
        dataQuality: dataQuality,
        reasons: const <FoodQualityScoreReason>[
          FoodQualityScoreReason.missingCoreNutrition,
        ],
      );
    }

    double per100(FoodNutrient nutrient) =>
        food.knownValue(nutrient)! * 100 / basisGrams;

    final protein = per100(FoodNutrient.protein);
    if (protein >= 10) {
      score += 15;
      reasons.add(FoodQualityScoreReason.proteinDensity);
    } else if (protein >= 5) {
      score += 8;
      reasons.add(FoodQualityScoreReason.proteinDensity);
    }

    final fiber = food.knownValue(FoodNutrient.fiber);
    if (fiber != null) {
      final fiberPer100 = fiber * 100 / basisGrams;
      if (fiberPer100 >= 6) {
        score += 15;
        reasons.add(FoodQualityScoreReason.fiberDensity);
      } else if (fiberPer100 >= 3) {
        score += 8;
        reasons.add(FoodQualityScoreReason.fiberDensity);
      }
    }

    final sugar = food.knownValue(FoodNutrient.sugar);
    if (sugar != null) {
      final sugarPer100 = sugar * 100 / basisGrams;
      if (sugarPer100 >= 22.5) {
        score -= 18;
        reasons.add(FoodQualityScoreReason.highSugarDensity);
      } else if (sugarPer100 >= 10) {
        score -= 8;
        reasons.add(FoodQualityScoreReason.highSugarDensity);
      }
    }

    final sodium = food.knownValue(FoodNutrient.sodium);
    if (sodium != null) {
      final sodiumPer100 = sodium * 100 / basisGrams;
      if (sodiumPer100 >= 600) {
        score -= 18;
        reasons.add(FoodQualityScoreReason.highSodiumDensity);
      } else if (sodiumPer100 >= 300) {
        score -= 8;
        reasons.add(FoodQualityScoreReason.highSodiumDensity);
      }
    }

    if (optionalKnown < 2) {
      reasons.add(FoodQualityScoreReason.limitedOptionalEvidence);
    }
    reasons.add(
      food.verified
          ? FoodQualityScoreReason.verifiedSource
          : FoodQualityScoreReason.unverifiedSource,
    );

    final bounded = score.clamp(0, 100).toDouble();
    return FoodQualityScore(
      profileScore: bounded,
      band: bounded >= 70
          ? FoodProfileBand.higher
          : bounded >= 45
          ? FoodProfileBand.moderate
          : FoodProfileBand.lower,
      evidenceConfidence: _confidence(
        knownCore: knownCore,
        optionalKnown: optionalKnown,
        verified: food.verified,
      ),
      dataQuality: dataQuality,
      reasons: List<FoodQualityScoreReason>.unmodifiable(reasons),
    );
  }

  static double _confidence({
    required int knownCore,
    required int optionalKnown,
    required bool verified,
  }) {
    final raw =
        knownCore / 4 * 0.65 + optionalKnown / 3 * 0.25 + (verified ? 0.10 : 0);
    return raw.clamp(0, 1).toDouble();
  }
}
