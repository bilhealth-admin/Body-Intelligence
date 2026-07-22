import '../domain/unified_food.dart';
import 'food_search_normalizer.dart';

enum FoodDuplicateKind { identicalIdentity, highConfidence, possible, none }

class FoodDuplicateAssessment {
  final FoodDuplicateKind kind;
  final double score;
  final List<String> reasons;

  const FoodDuplicateAssessment({
    required this.kind,
    required this.score,
    required this.reasons,
  });

  bool get shouldAutoMerge => false;
}

class FoodDeduplicationEngine {
  const FoodDeduplicationEngine._();

  static FoodDuplicateAssessment compare(UnifiedFood left, UnifiedFood right) {
    final reasons = <String>[];
    var score = 0.0;

    if (left.id == right.id) {
      return const FoodDuplicateAssessment(
        kind: FoodDuplicateKind.identicalIdentity,
        score: 1,
        reasons: <String>['same-stable-id'],
      );
    }

    final leftBarcode = FoodSearchNormalizer.normalizeBarcode(
      left.barcode ?? '',
    );
    final rightBarcode = FoodSearchNormalizer.normalizeBarcode(
      right.barcode ?? '',
    );
    if (leftBarcode.isNotEmpty && leftBarcode == rightBarcode) {
      reasons.add('same-barcode');
      score += 0.7;
    }

    final leftName = FoodSearchNormalizer.normalize(left.name);
    final rightName = FoodSearchNormalizer.normalize(right.name);
    final leftArabic = FoodSearchNormalizer.normalize(left.arabicName ?? '');
    final rightArabic = FoodSearchNormalizer.normalize(right.arabicName ?? '');
    if (leftName.isNotEmpty && leftName == rightName) {
      reasons.add('same-primary-name');
      score += 0.35;
    } else if (leftArabic.isNotEmpty && leftArabic == rightArabic) {
      reasons.add('same-arabic-name');
      score += 0.35;
    }

    final servingDifference = (left.serving.grams - right.serving.grams).abs();
    final servingReference = left.serving.grams > right.serving.grams
        ? left.serving.grams
        : right.serving.grams;
    if (servingReference > 0 && servingDifference / servingReference <= 0.02) {
      reasons.add('similar-serving-basis');
      score += 0.1;
    }

    final nutrientSimilarity = _coreNutrientSimilarity(left, right);
    if (nutrientSimilarity >= 0.95) {
      reasons.add('very-similar-core-nutrition');
      score += 0.2;
    } else if (nutrientSimilarity >= 0.8) {
      reasons.add('similar-core-nutrition');
      score += 0.1;
    }

    final bounded = score.clamp(0, 1).toDouble();
    final kind = bounded >= 0.8
        ? FoodDuplicateKind.highConfidence
        : bounded >= 0.45
        ? FoodDuplicateKind.possible
        : FoodDuplicateKind.none;
    return FoodDuplicateAssessment(
      kind: kind,
      score: bounded,
      reasons: List.unmodifiable(reasons),
    );
  }

  static double _coreNutrientSimilarity(UnifiedFood left, UnifiedFood right) {
    const nutrients = <FoodNutrient>[
      FoodNutrient.calories,
      FoodNutrient.protein,
      FoodNutrient.carbohydrates,
      FoodNutrient.fat,
    ];
    var total = 0.0;
    var compared = 0;
    for (final nutrient in nutrients) {
      final a = left.knownValue(nutrient);
      final b = right.knownValue(nutrient);
      if (a == null || b == null) continue;
      final reference = a.abs() > b.abs() ? a.abs() : b.abs();
      final similarity = reference == 0 ? 1.0 : 1 - ((a - b).abs() / reference);
      total += similarity.clamp(0, 1);
      compared++;
    }
    return compared == 0 ? 0 : total / compared;
  }
}
