part of 'meal_repository.dart';

extension _MealFoodPortionWrites on MealRepository {
  MealItemsCompanion _mealFoodPortionValues(
    Food food,
    double quantity, {
    required bool quantityInGrams,
  }) {
    final basis = FoodBasisEvidence.read(food, ownerKey: _coachOwnerKey);
    if (!basis.isValid) {
      throw const CoachMealConflict(CoachMealConflictReason.invalidEvidence);
    }
    if (basis.catalog != null && basis.snapshot == null) {
      if (quantityInGrams) {
        throw StateError(
          'A volume/count basis requires an explicit conversion before grams.',
        );
      }
      final unit = UnitFoodEvidence(
        identity: food.uuid,
        name: food.name,
        source: food.source,
        ownerKey: _coachOwnerKey,
        basisQuantity: food.servingSize,
        unit: food.servingUnit,
        quantity: quantity,
        nutrients: basis.catalog!.nutrients,
      );
      double v(FoodNutrient n) => unit.value(n) ?? 0;
      return MealItemsCompanion(
        quantity: Value(quantity),
        calories: Value(v(FoodNutrient.calories)),
        protein: Value(v(FoodNutrient.protein)),
        carbs: Value(v(FoodNutrient.carbohydrates)),
        fats: Value(v(FoodNutrient.fat)),
        fiber: Value(v(FoodNutrient.fiber)),
        sugar: Value(v(FoodNutrient.sugar)),
        sodium: Value(v(FoodNutrient.sodium)),
        potassium: Value(v(FoodNutrient.potassium)),
        calcium: Value(v(FoodNutrient.calcium)),
        magnesium: Value(v(FoodNutrient.magnesium)),
        phosphorus: Value(v(FoodNutrient.phosphorus)),
        nutrientEvidenceMask: Value(
          TrackedNutrient.values.fold<int>(
            0,
            (mask, n) => unit.value(MealFoodEvidence.foodNutrient(n)) == null
                ? mask
                : mask | NutrientEvidenceMask.bit(n),
          ),
        ),
        foodSourceSnapshot: Value(unit.sourceLabel),
        foodVerifiedSnapshot: const Value(false),
        servingSizeSnapshot: Value(unit.basisQuantity),
        servingUnitSnapshot: Value(unit.unit),
        foodEvidenceJson: Value(unit.encodeForStorage()),
      );
    }
    if (basis.snapshot case final snapshot?) {
      // A validated modern Food has an explicit gram basis. Keep its full
      // immutable provenance even when it is selected outside AI Coach.
      return _coachFoodValues(
        CoachFoodPortion(
          food: snapshot,
          quantity: CoachFoodQuantity(
            grams: quantityInGrams || !basis.isCatalog
                ? quantity
                : quantity * snapshot.basisGrams / food.servingSize,
            evidence: CoachFoodQuantityEvidence(
              kind: CoachFoodQuantityKind.userDeclared,
              description: 'User selected this food and its quantity in grams.',
            ),
          ),
        ),
      );
    }
    final adapted = _foodAdapter.adapt(food);
    final portion = quantityInGrams
        ? _nutritionEngine.calculate(food: adapted, grams: quantity)
        : _nutritionEngine.calculateServingUnits(
            food: adapted,
            amount: quantity,
            unit: food.servingUnit,
          );
    double value(FoodNutrient nutrient) => portion.valueOrZero(nutrient);
    return MealItemsCompanion(
      quantity: Value(quantity),
      calories: Value(value(FoodNutrient.calories)),
      protein: Value(value(FoodNutrient.protein)),
      carbs: Value(value(FoodNutrient.carbohydrates)),
      fats: Value(value(FoodNutrient.fat)),
      fiber: Value(value(FoodNutrient.fiber)),
      sugar: Value(value(FoodNutrient.sugar)),
      sodium: Value(value(FoodNutrient.sodium)),
      potassium: Value(value(FoodNutrient.potassium)),
      calcium: Value(value(FoodNutrient.calcium)),
      magnesium: Value(value(FoodNutrient.magnesium)),
      phosphorus: Value(value(FoodNutrient.phosphorus)),
      nutrientEvidenceMask: Value(portion.nutrientEvidenceMask),
      foodSourceSnapshot: Value(food.source),
      foodVerifiedSnapshot: Value(food.verified),
      servingSizeSnapshot: Value(
        quantityInGrams ? adapted.serving.grams : food.servingSize,
      ),
      servingUnitSnapshot: Value(quantityInGrams ? 'g' : food.servingUnit),
    );
  }

  Future<void> _verifyAddedFoodEvidence(int itemId) async {
    final item = await _mealItem(itemId);
    if (!MealFoodEvidence.read(item, ownerKey: _coachOwnerKey).isValid) {
      throw const CoachMealConflict(
        CoachMealConflictReason.readbackUnavailable,
      );
    }
  }
}
