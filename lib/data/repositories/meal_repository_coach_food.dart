part of 'meal_repository.dart';

extension _CoachFoodWrites on MealRepository {
  void _checkCoachFoodOwner(
    CoachFoodPortion portion,
    CoachMealOwnerScope scope,
  ) {
    scope.check(_database.localOwnerId);
    for (final source in [
      portion.food.source,
      if (portion.quantity.evidence.conversion case final conversion?)
        conversion.source,
    ]) {
      if (source.ownerKey != null && source.ownerKey != _coachOwnerKey) {
        throw const CoachMealConflict(CoachMealConflictReason.ownerChanged);
      }
    }
  }

  Future<List<int>> _insertCoachFoods(
    CoachMealCommand command,
    CoachMealOwnerScope scope,
    List<Meal> createdMeals,
  ) async {
    final args = command.arguments;
    final review = CoachFoodReview(
      (args['portions']! as List).map(CoachFoodPortion.fromJson),
    );
    for (final portion in review.items) {
      _checkCoachFoodOwner(portion, scope);
    }
    final day = args['day']! as String;
    await _requireCoachOpenDay(day, scope);
    final date = DateTime.parse(day);
    final clock = args['occurredAt'] == null
        ? DateTime.now()
        : DateTime.parse(args['occurredAt']! as String);
    final meal = await _coachDestination(
      date: DateTime(date.year, date.month, date.day, clock.hour, clock.minute),
      type: args['mealType']! as String,
      scope: scope,
      createdMeals: createdMeals,
    );
    var position = await _nextCoachPosition(meal.id, scope);
    final ids = <int>[];
    for (final portion in review.items) {
      _checkCoachFoodOwner(portion, scope);
      final foodId = await _insertCoachFoodBasis(portion, scope);
      ids.add(
        await _coachAwait(
          () => _database
              .into(_database.mealItems)
              .insert(
                _coachFoodValues(portion).copyWith(
                  mealId: Value(meal.id),
                  foodId: Value(foodId),
                  position: Value(position++),
                ),
              ),
          scope,
        ),
      );
    }
    return ids;
  }

  Future<int> _insertCoachFoodBasis(
    CoachFoodPortion portion,
    CoachMealOwnerScope scope,
  ) {
    final food = portion.food;
    double value(FoodNutrient nutrient) => food.nutrients[nutrient] ?? 0;
    return _coachAwait(
      () => _database
          .into(_database.foods)
          .insert(
            FoodsCompanion.insert(
              name: food.name,
              category: const Value('coach_snapshot'),
              servingSize: Value(food.basisGrams),
              servingUnit: const Value('g'),
              calories: value(FoodNutrient.calories),
              protein: value(FoodNutrient.protein),
              carbs: value(FoodNutrient.carbohydrates),
              fats: value(FoodNutrient.fat),
              fiber: Value(value(FoodNutrient.fiber)),
              sugar: Value(value(FoodNutrient.sugar)),
              sodium: Value(value(FoodNutrient.sodium)),
              potassium: Value(value(FoodNutrient.potassium)),
              calcium: Value(value(FoodNutrient.calcium)),
              magnesium: Value(value(FoodNutrient.magnesium)),
              phosphorus: Value(value(FoodNutrient.phosphorus)),
              iron: Value(value(FoodNutrient.iron)),
              vitaminC: Value(value(FoodNutrient.vitaminC)),
              nutrientEvidenceMask: Value(MealFoodEvidence.mask(portion)),
              source: Value(MealFoodEvidence.sourceLabel(portion)),
              foodEvidenceJson: Value(
                jsonEncode({
                  'schema': 'bil.food.basis.v1',
                  'food': food.toJson(),
                }),
              ),
              // Source kind is provenance, not an unearned verification grant.
              verified: const Value(false),
            ),
          ),
      scope,
    );
  }

  MealItemsCompanion _coachFoodValues(CoachFoodPortion portion) {
    final values = portion.nutrients;
    double value(FoodNutrient nutrient) => values[nutrient] ?? 0;
    return MealItemsCompanion(
      quantity: Value(portion.quantity.grams),
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
      nutrientEvidenceMask: Value(MealFoodEvidence.mask(portion)),
      foodSourceSnapshot: Value(MealFoodEvidence.sourceLabel(portion)),
      foodEvidenceJson: Value(portion.encodeForStorage()),
      foodVerifiedSnapshot: const Value(false),
      servingSizeSnapshot: Value(portion.food.basisGrams),
      servingUnitSnapshot: const Value('g'),
      syncStatus: const Value('pending'),
    );
  }

  void _verifyCoachFoodReadback(
    CoachMealCommand command,
    List<CoachMealSnapshot> after,
  ) {
    final List<CoachFoodPortion> expected;
    if (command.kind == CoachMealCommandKind.foods) {
      expected = (command.arguments['portions']! as List)
          .map(CoachFoodPortion.fromJson)
          .toList();
    } else if (command.kind == CoachMealCommandKind.replacement) {
      expected = [CoachFoodPortion.fromJson(command.arguments['replacement'])];
    } else {
      return;
    }
    if (after.length != expected.length) {
      throw const CoachMealConflict(
        CoachMealConflictReason.readbackUnavailable,
      );
    }
    for (var index = 0; index < expected.length; index++) {
      final actual = MealFoodEvidence.read(
        after[index].item,
        ownerKey: _coachOwnerKey,
      );
      if (!actual.isValid || actual.portion?.digest != expected[index].digest) {
        throw const CoachMealConflict(
          CoachMealConflictReason.readbackUnavailable,
        );
      }
    }
  }

  Future<bool> _updateCoachFoodQuantity(MealItem item, double grams) async {
    final evidence = MealFoodEvidence.read(item, ownerKey: _coachOwnerKey);
    if (!evidence.isValid) {
      throw const CoachMealConflict(CoachMealConflictReason.invalidEvidence);
    }
    final original = evidence.portion;
    if (original == null) return false;
    final revised = CoachFoodPortion(
      food: original.food,
      quantity: CoachFoodQuantity(
        grams: grams,
        evidence: CoachFoodQuantityEvidence(
          kind: CoachFoodQuantityKind.userDeclared,
          description: 'User corrected the logged quantity in grams.',
        ),
      ),
      identityConfidence: original.identityConfidence,
    );
    final values = _coachFoodValues(revised).copyWith(
      updatedAt: Value(DateTime.now()),
      revision: Value(item.revision + 1),
    );
    final affected =
        await (_database.update(_database.mealItems)..where(
              (row) =>
                  row.id.equals(item.id) &
                  row.uuid.equals(item.uuid) &
                  row.revision.equals(item.revision),
            ))
            .write(values);
    if (affected != 1) {
      throw const CoachMealConflict(CoachMealConflictReason.staleItem);
    }
    final saved = await _mealItem(item.id);
    if (MealFoodEvidence.read(
          saved,
          ownerKey: _coachOwnerKey,
        ).portion?.digest !=
        revised.digest) {
      throw const CoachMealConflict(
        CoachMealConflictReason.readbackUnavailable,
      );
    }
    return true;
  }
}
