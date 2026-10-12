part of 'meal_repository.dart';

extension _MealRecipeServingWrites on MealRepository {
  /// Calculated catalog nutrition remains explicitly unverified. The caller
  /// supplies a content-addressed [foodUuid], so later recipe edits cannot
  /// mutate an older diary snapshot.
  Future<int> _writeCalculatedRecipeServing({
    required DateTime date,
    required String mealType,
    required String foodUuid,
    required String recipeName,
    required String source,
    required double calories,
    required double protein,
    required double carbohydrates,
    required double fat,
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? phosphorus,
    double? iron,
    double? vitaminC,
    Map<FoodNutrient, double?> additionalNutrients = const {},
    double servings = 1,
  }) async {
    if (!const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw ArgumentError.value(mealType, 'mealType', 'Unsupported meal type');
    }
    if (!servings.isFinite || servings <= 0 || servings > 100) {
      throw ArgumentError.value(servings, 'servings');
    }
    final nutrients = [
      calories,
      protein,
      carbohydrates,
      fat,
      ...[
        fiber,
        sugar,
        sodium,
        potassium,
        calcium,
        magnesium,
        phosphorus,
        iron,
        vitaminC,
      ].whereType<double>(),
    ];
    if (foodUuid.trim().isEmpty ||
        recipeName.trim().isEmpty ||
        source.trim().isEmpty ||
        nutrients.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Recipe snapshot fields must be finite and valid.');
    }
    if (additionalNutrients.keys.any(
      (n) => n.index <= FoodNutrient.vitaminC.index,
    )) {
      throw ArgumentError('Additional nutrients cannot replace core values.');
    }
    final evidence = NutrientEvidenceMask.fromValues(
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      phosphorus: phosphorus,
    );
    final recipeEvidence = RecipeServingEvidence(
      identity: foodUuid.trim(),
      name: recipeName.trim(),
      source: source.trim(),
      ownerKey: _coachOwnerKey,
      servings: servings,
      perServing: CoachFoodNutrients({
        FoodNutrient.calories: calories,
        FoodNutrient.protein: protein,
        FoodNutrient.carbohydrates: carbohydrates,
        FoodNutrient.fat: fat,
        FoodNutrient.fiber: fiber,
        FoodNutrient.sugar: sugar,
        FoodNutrient.sodium: sodium,
        FoodNutrient.potassium: potassium,
        FoodNutrient.calcium: calcium,
        FoodNutrient.magnesium: magnesium,
        FoodNutrient.phosphorus: phosphorus,
        FoodNutrient.iron: iron,
        FoodNutrient.vitaminC: vitaminC,
        ...additionalNutrients,
      }),
    );
    return _database.transaction(() async {
      await _requireOpenDayForMeals(dayKeyFor(date));
      final firstFoodMilestone = await _firstFoodMilestoneBeforeInsert();
      var food =
          await (_database.select(_database.foods)
                ..where((row) => row.uuid.equals(foodUuid))
                ..limit(1))
              .getSingleOrNull();
      if (food == null) {
        final id = await _database
            .into(_database.foods)
            .insert(
              FoodsCompanion.insert(
                uuid: Value(foodUuid),
                name: recipeName.trim(),
                category: const Value('calculated-recipe'),
                servingSize: const Value(1),
                servingUnit: const Value('serving'),
                calories: calories,
                protein: protein,
                carbs: carbohydrates,
                fats: fat,
                fiber: Value(fiber ?? 0),
                sugar: Value(sugar ?? 0),
                sodium: Value(sodium ?? 0),
                potassium: Value(potassium ?? 0),
                calcium: Value(calcium ?? 0),
                magnesium: Value(magnesium ?? 0),
                phosphorus: Value(phosphorus ?? 0),
                iron: Value(iron ?? 0),
                vitaminC: Value(vitaminC ?? 0),
                nutrientEvidenceMask: Value(evidence),
                source: Value(source.trim()),
                verified: const Value(false),
                isCustom: const Value(true),
              ),
            );
        food = await (_database.select(
          _database.foods,
        )..where((row) => row.id.equals(id))).getSingle();
      } else {
        final exactSnapshot =
            food.name == recipeName.trim() &&
            food.category == 'calculated-recipe' &&
            food.servingSize == 1 &&
            food.servingUnit == 'serving' &&
            food.calories == calories &&
            food.protein == protein &&
            food.carbs == carbohydrates &&
            food.fats == fat &&
            food.fiber == (fiber ?? 0) &&
            food.sugar == (sugar ?? 0) &&
            food.sodium == (sodium ?? 0) &&
            food.potassium == (potassium ?? 0) &&
            food.calcium == (calcium ?? 0) &&
            food.magnesium == (magnesium ?? 0) &&
            food.phosphorus == (phosphorus ?? 0) &&
            food.iron == (iron ?? 0) &&
            food.vitaminC == (vitaminC ?? 0) &&
            food.nutrientEvidenceMask == evidence &&
            food.source == source.trim() &&
            !food.verified &&
            food.deletedAt == null;
        if (!exactSnapshot) {
          throw StateError(
            'Recipe snapshot identity conflicts with stored food',
          );
        }
      }
      final mealId = await createMeal(
        date: date,
        name: mealType,
        type: mealType,
      );
      final siblings =
          await (_database.select(_database.mealItems)..where(
                (item) => item.mealId.equals(mealId) & item.deletedAt.isNull(),
              ))
              .get();
      final position =
          siblings.fold<int>(
            0,
            (maximum, item) =>
                item.position > maximum ? item.position : maximum,
          ) +
          1;
      await _database
          .into(_database.mealItems)
          .insert(
            MealItemsCompanion.insert(
              mealId: mealId,
              foodId: food.id,
              quantity: Value(servings),
              position: Value(position),
              calories: Value(calories * servings),
              protein: Value(protein * servings),
              carbs: Value(carbohydrates * servings),
              fats: Value(fat * servings),
              fiber: Value((fiber ?? 0) * servings),
              sugar: Value((sugar ?? 0) * servings),
              sodium: Value((sodium ?? 0) * servings),
              potassium: Value((potassium ?? 0) * servings),
              calcium: Value((calcium ?? 0) * servings),
              magnesium: Value((magnesium ?? 0) * servings),
              phosphorus: Value((phosphorus ?? 0) * servings),
              nutrientEvidenceMask: Value(evidence),
              foodSourceSnapshot: Value(recipeEvidence.sourceLabel),
              foodEvidenceJson: Value(recipeEvidence.encodeForStorage()),
              foodVerifiedSnapshot: const Value(false),
              servingSizeSnapshot: const Value(1),
              servingUnitSnapshot: const Value('serving'),
            ),
          );
      await _firstFoodMilestoneAfterInsert(firstFoodMilestone);
      return mealId;
    });
  }

  /// Records a user-entered calorie/macro snapshot without inventing a food.
  ///
  /// The timestamp is preserved in the immutable food snapshot label because
  /// legacy meal items do not have a dedicated occurred-at column.
}
