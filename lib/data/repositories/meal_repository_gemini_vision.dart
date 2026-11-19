part of 'meal_repository.dart';

/// A user-confirmed Gemini estimate is saved with its own immutable evidence,
/// never as a verified catalog match. No rows are written by analysis/review.
extension MealRepositoryGeminiVision on MealRepository {
  Future<int> addGeminiVisionMealAtomically({
    required DateTime date,
    required String mealType,
    required String ownerId,
    required String requestId,
    required List<ReviewedGeminiVisionEstimate> items,
    required bool Function() isCurrentOwner,
  }) async {
    void current() {
      if (ownerId.trim().isEmpty ||
          _database.localOwnerId != ownerId ||
          !isCurrentOwner()) {
        throw const CoachMealConflict(CoachMealConflictReason.ownerChanged);
      }
    }

    current();
    if (items.isEmpty ||
        items.length > 8 ||
        requestId.trim().isEmpty ||
        requestId.length > 128 ||
        !const {'breakfast', 'lunch', 'dinner', 'snack'}.contains(mealType)) {
      throw const FormatException('Invalid reviewed Gemini meal.');
    }
    final reviewed = List<ReviewedGeminiVisionEstimate>.unmodifiable(items);
    final seen = <int>{};
    final ownerKey = LocalDatabaseScope.keyForOwner(ownerId);
    final records = <({VisionFoodEvidence food, double quantity})>[];
    for (final item in reviewed) {
      final estimate = item.estimate;
      if (estimate.requestId != requestId || !seen.add(estimate.index)) {
        throw const FormatException('Mismatched photo estimate request.');
      }
      final basis = estimate.basis;
      if (basis == null) throw const FormatException('Missing estimate basis.');
      final quantity = mealImageReviewedQuantity(
        amount: item.amount,
        unit: item.unit,
        servingSize: basis.quantity,
        servingUnit: basis.unit,
      );
      if (quantity == null) {
        throw const FormatException('Incompatible estimate portion.');
      }
      final identity = const Uuid().v5(
        Namespace.url.value,
        '$ownerKey/gemini-vision-v2/$requestId/${estimate.index}',
      );
      final food = VisionFoodEvidence(
        identity: identity,
        ownerKey: ownerKey,
        estimate: estimate,
      );
      // Validate every scaled value before opening the transaction.
      VisionMealEvidence(food: food, quantity: quantity.quantity);
      records.add((food: food, quantity: quantity.quantity));
    }
    final requestDigest = sha256.convert(utf8.encode(requestId)).toString();
    final intent = _VisionCommitIntent(
      key: 'visionMealCommitV2.$ownerKey.$requestDigest',
      ownerScope: ownerKey,
      requestDigest: requestDigest,
      payloadDigest: sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'dayKey': dayKeyFor(date),
                'mealType': mealType,
                'items': [for (final item in reviewed) item.toJson()],
              }),
            ),
          )
          .toString(),
    );
    // Opening a lazy connection/schema inside its first transaction can wait
    // on itself. Warm it before the owner-bound atomic mutation.
    await _database.customSelect('SELECT 1').get();
    current();
    return _database.transaction(() async {
      current();
      final prior = await _visionCommittedMealId(intent);
      current();
      if (prior != null) return prior;
      final mealId = await createMeal(
        date: date,
        name: mealType,
        type: mealType,
      );
      current();
      for (final record in records) {
        final foodId = await _insertGeminiFood(record.food);
        current();
        await addMealItem(
          mealId: mealId,
          foodId: foodId,
          quantity: record.quantity,
          quantityInGrams: record.food.basisUnit == 'g',
        );
        current();
      }
      await _saveVisionCommitReceipt(intent, mealId);
      current();
      return mealId;
    });
  }

  /// A quantity edit changes only the reviewed amount. Keep the immutable
  /// owner-bound estimate, units, nullable micros and direct net in its envelope.
  Future<bool> _updateVisionFoodQuantity(MealItem item, double quantity) async {
    final original = MealFoodEvidence.read(
      item,
      ownerKey: _coachOwnerKey,
    ).vision;
    if (original == null) return false;
    final revised = VisionMealEvidence(food: original.food, quantity: quantity);
    double v(FoodNutrient n) => revised.value(n) ?? 0;
    final affected =
        await (_database.update(_database.mealItems)..where(
              (row) =>
                  row.id.equals(item.id) &
                  row.uuid.equals(item.uuid) &
                  row.revision.equals(item.revision),
            ))
            .write(
              MealItemsCompanion(
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
                nutrientEvidenceMask: Value(revised.mask),
                foodEvidenceJson: Value(revised.encode()),
                updatedAt: Value(DateTime.now()),
                revision: Value(item.revision + 1),
                syncStatus: const Value('pending'),
              ),
            );
    if (affected != 1) {
      throw const CoachMealConflict(CoachMealConflictReason.staleItem);
    }
    await _verifyAddedFoodEvidence(item.id);
    return true;
  }

  Future<int> _insertGeminiFood(VisionFoodEvidence evidence) {
    double v(FoodNutrient n) => evidence.value(n) ?? 0;
    return _database
        .into(_database.foods)
        .insert(
          FoodsCompanion.insert(
            uuid: Value(evidence.identity),
            name: evidence.estimate.name,
            category: const Value(VisionFoodEvidence.category),
            servingSize: Value(evidence.basisQuantity),
            servingUnit: Value(evidence.basisUnit),
            calories: v(FoodNutrient.calories),
            protein: v(FoodNutrient.protein),
            carbs: v(FoodNutrient.carbohydrates),
            fats: v(FoodNutrient.fat),
            fiber: Value(v(FoodNutrient.fiber)),
            sugar: Value(v(FoodNutrient.sugar)),
            sodium: Value(v(FoodNutrient.sodium)),
            potassium: Value(v(FoodNutrient.potassium)),
            calcium: Value(v(FoodNutrient.calcium)),
            magnesium: Value(v(FoodNutrient.magnesium)),
            phosphorus: Value(v(FoodNutrient.phosphorus)),
            iron: Value(v(FoodNutrient.iron)),
            vitaminC: Value(v(FoodNutrient.vitaminC)),
            nutrientEvidenceMask: Value(evidence.mask),
            source: const Value(VisionFoodEvidence.source),
            verified: const Value(false),
            isCustom: const Value(false),
            foodEvidenceJson: Value(evidence.encode()),
          ),
        );
  }
}
