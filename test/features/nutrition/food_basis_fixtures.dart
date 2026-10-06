import 'dart:convert';

import 'package:body_intelligence_log/data/database/app_database.dart';
import 'package:body_intelligence_log/data/database/nutrient_evidence.dart';
import 'package:body_intelligence_log/features/intelligence_center/domain/food_v2/coach_food_v2.dart';

const basisNutrients = <FoodNutrient, double?>{
  FoodNutrient.calories: 123,
  FoodNutrient.protein: 10,
  FoodNutrient.carbohydrates: 12,
  FoodNutrient.fat: 3,
  FoodNutrient.fiber: 4,
  FoodNutrient.sugar: 5,
  FoodNutrient.sodium: 200,
  FoodNutrient.potassium: 300,
  FoodNutrient.calcium: 100,
  FoodNutrient.magnesium: 50,
  FoodNutrient.phosphorus: 80,
  FoodNutrient.iron: 2,
  FoodNutrient.vitaminC: 8,
};

CoachFoodSnapshot basisSnapshot({
  Map<FoodNutrient, double?> values = basisNutrients,
  CoachFoodSourceKind kind = CoachFoodSourceKind.label,
  String? ownerKey,
  double basisGrams = 40,
}) => CoachFoodSnapshot(
  identity: 'fixture-food-identity',
  name: 'Cooked food',
  preparedState: 'cooked',
  basisGrams: basisGrams,
  nutrients: CoachFoodNutrients(values),
  source: CoachFoodSourceEvidence(
    kind: kind,
    ref: 'fixture://nutrition-label',
    revision: 'label-2',
    ownerKey: ownerKey,
    confidence: CoachFoodConfidence(score: .8, basis: 'fixture source audit'),
  ),
);

Food basisFood({
  CoachFoodSnapshot? snapshot,
  bool includeEvidence = true,
  String? raw,
}) {
  final food = snapshot ?? basisSnapshot();
  double value(FoodNutrient nutrient) => food.nutrients[nutrient] ?? 0;
  final now = DateTime(2026, 10, 6);
  return Food(
    id: 1,
    uuid: 'database-row-uuid',
    name: food.name,
    category: includeEvidence ? 'coach_snapshot' : 'Test',
    keywords: 'cooked,food',
    servingSize: food.basisGrams,
    servingUnit: 'g',
    calories: value(FoodNutrient.calories),
    protein: value(FoodNutrient.protein),
    carbs: value(FoodNutrient.carbohydrates),
    fats: value(FoodNutrient.fat),
    fiber: value(FoodNutrient.fiber),
    sugar: value(FoodNutrient.sugar),
    sodium: value(FoodNutrient.sodium),
    potassium: value(FoodNutrient.potassium),
    calcium: value(FoodNutrient.calcium),
    magnesium: value(FoodNutrient.magnesium),
    phosphorus: value(FoodNutrient.phosphorus),
    iron: value(FoodNutrient.iron),
    vitaminC: value(FoodNutrient.vitaminC),
    nutrientEvidenceMask: NutrientEvidenceMask.fromValues(
      calories: food.nutrients[FoodNutrient.calories],
      protein: food.nutrients[FoodNutrient.protein],
      carbohydrates: food.nutrients[FoodNutrient.carbohydrates],
      fat: food.nutrients[FoodNutrient.fat],
      fiber: food.nutrients[FoodNutrient.fiber],
      sugar: food.nutrients[FoodNutrient.sugar],
      sodium: food.nutrients[FoodNutrient.sodium],
      potassium: food.nutrients[FoodNutrient.potassium],
      calcium: food.nutrients[FoodNutrient.calcium],
      magnesium: food.nutrients[FoodNutrient.magnesium],
      phosphorus: food.nutrients[FoodNutrient.phosphorus],
    ),
    foodEvidenceJson: includeEvidence
        ? raw ??
              jsonEncode({'schema': 'bil.food.basis.v1', 'food': food.toJson()})
        : null,
    source: includeEvidence
        ? 'coach_food_v2:${food.source.kind.wireName}'
        : 'local',
    verified: false,
    isCustom: false,
    createdAt: now,
    updatedAt: now,
    revision: 1,
    syncStatus: 'local',
  );
}

Food replaceBasisNutrient(Food row, FoodNutrient nutrient, double value) =>
    switch (nutrient) {
      FoodNutrient.calories => row.copyWith(calories: value),
      FoodNutrient.protein => row.copyWith(protein: value),
      FoodNutrient.carbohydrates => row.copyWith(carbs: value),
      FoodNutrient.fat => row.copyWith(fats: value),
      FoodNutrient.fiber => row.copyWith(fiber: value),
      FoodNutrient.sugar => row.copyWith(sugar: value),
      FoodNutrient.sodium => row.copyWith(sodium: value),
      FoodNutrient.potassium => row.copyWith(potassium: value),
      FoodNutrient.calcium => row.copyWith(calcium: value),
      FoodNutrient.magnesium => row.copyWith(magnesium: value),
      FoodNutrient.phosphorus => row.copyWith(phosphorus: value),
      FoodNutrient.iron => row.copyWith(iron: value),
      FoodNutrient.vitaminC => row.copyWith(vitaminC: value),
    };
