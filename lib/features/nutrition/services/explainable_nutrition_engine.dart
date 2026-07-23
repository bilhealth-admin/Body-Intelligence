import '../domain/unified_food.dart';
import 'nutrition_calculation_engine.dart';

enum NutritionExplanationState { known, missing }

enum NutritionValueOrigin {
  foundation,
  openFoodFacts,
  branded,
  custom,
  legacy,
  unknown,
}

class NutrientExplanation {
  final FoodNutrient nutrient;
  final NutritionExplanationState state;
  final NutritionValueOrigin origin;
  final double basisGrams;
  final double requestedGrams;
  final double? basisValue;
  final double? calculatedValue;
  final double calculationFactor;
  final List<String> reasons;

  const NutrientExplanation({
    required this.nutrient,
    required this.state,
    required this.origin,
    required this.basisGrams,
    required this.requestedGrams,
    required this.basisValue,
    required this.calculatedValue,
    required this.calculationFactor,
    required this.reasons,
  });

  bool get isKnown => state == NutritionExplanationState.known;
}

class ExplainableNutritionReport {
  final String foodId;
  final String foodName;
  final NutritionValueOrigin origin;
  final double requestedGrams;
  final String basisLabel;
  final Map<FoodNutrient, NutrientExplanation> nutrients;
  final List<String> summaryReasons;

  const ExplainableNutritionReport({
    required this.foodId,
    required this.foodName,
    required this.origin,
    required this.requestedGrams,
    required this.basisLabel,
    required this.nutrients,
    required this.summaryReasons,
  });

  NutrientExplanation explanationFor(FoodNutrient nutrient) =>
      nutrients[nutrient] ??
      NutrientExplanation(
        nutrient: nutrient,
        state: NutritionExplanationState.missing,
        origin: origin,
        basisGrams: requestedGrams,
        requestedGrams: requestedGrams,
        basisValue: null,
        calculatedValue: null,
        calculationFactor: 1,
        reasons: const <String>['nutrient-not-present-in-report'],
      );
}

class ExplainableNutritionEngine {
  final NutritionCalculationEngine _nutritionEngine;

  const ExplainableNutritionEngine({
    NutritionCalculationEngine nutritionEngine =
        const NutritionCalculationEngine(),
  }) : _nutritionEngine = nutritionEngine;

  ExplainableNutritionReport explain({
    required UnifiedFood food,
    double? grams,
  }) {
    final requestedGrams = grams ?? food.serving.grams;
    if (!requestedGrams.isFinite || requestedGrams <= 0) {
      throw ArgumentError.value(
        requestedGrams,
        'grams',
        'Must be finite and greater than 0',
      );
    }
    if (!food.serving.grams.isFinite || food.serving.grams <= 0) {
      throw StateError('Food ${food.id} has an invalid gram basis');
    }

    final origin = _originFor(food);
    final portion = _nutritionEngine.calculate(
      food: food,
      grams: requestedGrams,
    );
    final factor = requestedGrams / food.serving.grams;
    final explanations = <FoodNutrient, NutrientExplanation>{};

    for (final nutrient in FoodNutrient.values) {
      final basis = food.nutrient(nutrient);
      final calculated = portion.nutrient(nutrient);
      final reasons = <String>[
        'source:${origin.name}',
        'basis:${food.serving.grams}g',
        'requested:${requestedGrams}g',
      ];

      if (basis.isKnown) {
        reasons.add(
          factor == 1 ? 'used-known-basis-value' : 'scaled-from-known-basis',
        );
      } else {
        reasons.add('source-did-not-provide-this-nutrient');
        reasons.add('missing-is-not-zero');
      }

      explanations[nutrient] = NutrientExplanation(
        nutrient: nutrient,
        state: basis.isKnown
            ? NutritionExplanationState.known
            : NutritionExplanationState.missing,
        origin: origin,
        basisGrams: food.serving.grams,
        requestedGrams: requestedGrams,
        basisValue: basis.nullableValue,
        calculatedValue: calculated.nullableValue,
        calculationFactor: factor,
        reasons: List<String>.unmodifiable(reasons),
      );
    }

    return ExplainableNutritionReport(
      foodId: food.id,
      foodName: food.preferredDisplayName,
      origin: origin,
      requestedGrams: requestedGrams,
      basisLabel: '${food.serving.amount} ${food.serving.unit}',
      nutrients: Map<FoodNutrient, NutrientExplanation>.unmodifiable(
        explanations,
      ),
      summaryReasons: List<String>.unmodifiable(<String>[
        'source:${origin.name}',
        food.verified
            ? 'source-record-is-verified'
            : 'source-record-is-unverified',
        factor == 1 ? 'requested-basis-quantity' : 'requested-scaled-quantity',
      ]),
    );
  }

  NutritionValueOrigin _originFor(UnifiedFood food) {
    final label = food.sourceLabel.trim().toLowerCase();
    if (label == 'openfoodfacts' || label == 'open-food-facts') {
      return NutritionValueOrigin.openFoodFacts;
    }
    return switch (food.source) {
      FoodDataSource.foundation => NutritionValueOrigin.foundation,
      FoodDataSource.branded => NutritionValueOrigin.branded,
      FoodDataSource.custom => NutritionValueOrigin.custom,
      FoodDataSource.legacy => NutritionValueOrigin.legacy,
      FoodDataSource.unknown => NutritionValueOrigin.unknown,
    };
  }
}
