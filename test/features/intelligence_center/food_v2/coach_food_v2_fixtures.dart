import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';
import 'package:flutter_test/flutter_test.dart';

const syntheticNutrients = <FoodNutrient, double?>{
  FoodNutrient.calories: 160,
  FoodNutrient.protein: 7,
  FoodNutrient.carbohydrates: 25,
  FoodNutrient.fat: 3,
  FoodNutrient.fiber: 4,
  FoodNutrient.sugar: 2,
  FoodNutrient.sodium: 0,
  FoodNutrient.potassium: 130,
  FoodNutrient.calcium: 30,
  FoodNutrient.magnesium: 14,
  FoodNutrient.phosphorus: 88,
  FoodNutrient.iron: 1.2,
  FoodNutrient.vitaminC: 12,
};

CoachFoodSnapshot syntheticFood({
  Map<FoodNutrient, double?> nutrients = syntheticNutrients,
  String identity = 'synthetic-food',
  String preparedState = 'cooked',
  CoachFoodSourceKind kind = CoachFoodSourceKind.reference,
  String ref = 'synthetic:test-only-reference',
  String revision = 'fixture-v1',
  String? ownerKey,
  CoachFoodConfidence? sourceConfidence,
}) => CoachFoodSnapshot(
  identity: identity,
  name: 'Synthetic test food; not a nutrition reference',
  preparedState: preparedState,
  basisGrams: 100,
  nutrients: CoachFoodNutrients(nutrients),
  source: CoachFoodSourceEvidence(
    kind: kind,
    ref: ref,
    revision: revision,
    ownerKey: ownerKey,
    confidence: sourceConfidence,
  ),
);

CoachFoodQuantity syntheticQuantity(double grams) =>
    CoachFoodQuantities.declaredGrams(
      grams,
      description: 'Synthetic declared grams',
    );

CoachFoodPortion syntheticPortion({
  CoachFoodSnapshot? food,
  double grams = 100,
}) => CoachFoodPortion(
  food: food ?? syntheticFood(),
  quantity: syntheticQuantity(grams),
);

CoachFoodOwnerScope syntheticOwner({String ownerKey = 'account-a'}) {
  final stamp = CoachFoodOwnerStamp(ownerKey: ownerKey, epoch: 0);
  return CoachFoodOwnerScope(captured: stamp, readCurrent: () => stamp);
}

Matcher foodError(String code) =>
    isA<CoachFoodContractError>().having((error) => error.code, 'code', code);
