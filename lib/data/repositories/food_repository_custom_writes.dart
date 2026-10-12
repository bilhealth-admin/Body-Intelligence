part of 'food_repository.dart';

extension _FoodCustomWrites on FoodRepository {
  Future<int> _addCustomFood({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? arabicName,
    String? barcode,
    double? servingSize,
    String? servingUnit,
    bool isCustom = true,
    String source = 'local',
    bool verified = false,
    String keywords = '',
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
    String? uuid,
    bool caloriesKnown = true,
    bool proteinKnown = true,
    bool carbsKnown = true,
    bool fatsKnown = true,
    bool Function()? isCurrent,
  }) async {
    if (additionalNutrients.keys.any(
      (n) => n.index <= FoodNutrient.vitaminC.index,
    )) {
      throw ArgumentError(
        'Additional nutrients cannot replace the core fields.',
      );
    }
    if (isCurrent != null && !isCurrent()) {
      throw StateError('Food edit owner changed.');
    }
    final normalizedBarcode = _optional(barcode);
    if (isCustom && normalizedBarcode != null) {
      _validateCustomBarcode(normalizedBarcode);
    }
    if (isCustom && (servingSize == null || servingUnit == null)) {
      throw ArgumentError(
        'Custom foods require an explicit serving size and serving unit',
      );
    }
    final effectiveServingSize = servingSize ?? 100;
    final normalizedServingUnit = _validateServingUnit(servingUnit ?? 'g');
    _validateNutritionBounds(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      phosphorus: phosphorus,
    );
    _validateFood(
      name: name,
      servingSize: effectiveServingSize,
      nutrients: [
        calories,
        protein,
        carbs,
        fats,
        fiber ?? 0,
        sugar ?? 0,
        sodium ?? 0,
        potassium ?? 0,
        calcium ?? 0,
        magnesium ?? 0,
        phosphorus ?? 0,
        iron ?? 0,
        vitaminC ?? 0,
        ...additionalNutrients.values.map((value) => value ?? 0),
      ],
    );
    // Open/migrate the lazy database before entering the serialized barcode
    // check+insert transaction. Initializing the schema from inside the first
    // transaction can deadlock NativeDatabase during cold-start tests.
    await (_database.select(_database.foods)..limit(1)).get();
    return _database.transaction(() async {
      if (isCurrent != null && !isCurrent()) {
        throw StateError('Food edit owner changed.');
      }
      if (isCustom && normalizedBarcode != null) {
        await _ensureBarcodeAvailable(normalizedBarcode);
      }
      final id = await _database
          .into(_database.foods)
          .insert(
            FoodsCompanion.insert(
              uuid: uuid == null ? const Value.absent() : Value(uuid),
              name: name.trim(),
              arabicName: Value(_optional(arabicName)),
              category: Value(category),
              keywords: Value(keywords.trim()),
              barcode: Value(normalizedBarcode),
              servingSize: Value(effectiveServingSize),
              servingUnit: Value(normalizedServingUnit),
              calories: calories,
              protein: protein,
              carbs: carbs,
              fats: fats,
              fiber: Value(fiber ?? 0),
              sugar: Value(sugar ?? 0),
              potassium: Value(potassium ?? 0),
              sodium: Value(sodium ?? 0),
              calcium: Value(calcium ?? 0),
              iron: Value(iron ?? 0),
              magnesium: Value(magnesium ?? 0),
              phosphorus: Value(phosphorus ?? 0),
              nutrientEvidenceMask: Value(
                NutrientEvidenceMask.fromValues(
                  fiber: fiber,
                  sugar: sugar,
                  sodium: sodium,
                  potassium: potassium,
                  calcium: calcium,
                  magnesium: magnesium,
                  phosphorus: phosphorus,
                  calories: caloriesKnown ? calories : null,
                  protein: proteinKnown ? protein : null,
                  carbohydrates: carbsKnown ? carbs : null,
                  fat: fatsKnown ? fats : null,
                ),
              ),
              vitaminC: Value(vitaminC ?? 0),
              verified: Value(verified),
              isCustom: Value(isCustom),
              source: Value(source.trim().isEmpty ? 'local' : source.trim()),
            ),
          );
      if (isCustom) {
        final row = await (_database.select(
          _database.foods,
        )..where((r) => r.id.equals(id))).getSingle();
        await _writeCatalogEvidence(row, {
          FoodNutrient.calories: caloriesKnown ? calories : null,
          FoodNutrient.protein: proteinKnown ? protein : null,
          FoodNutrient.carbohydrates: carbsKnown ? carbs : null,
          FoodNutrient.fat: fatsKnown ? fats : null,
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
        });
      }
      if (isCurrent != null && !isCurrent()) {
        throw StateError('Food edit owner changed.');
      }
      return id;
    });
  }

  Future<void> _updateCustomFood({
    required int id,
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? arabicName,
    String? barcode,
    required double servingSize,
    required String servingUnit,
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? phosphorus,
    double? iron,
    double? vitaminC,
    String? source,
    Map<FoodNutrient, double?> additionalNutrients = const {},
    bool caloriesKnown = true,
    bool proteinKnown = true,
    bool carbsKnown = true,
    bool fatsKnown = true,
    bool Function()? isCurrent,
  }) async {
    if (additionalNutrients.keys.any(
      (n) => n.index <= FoodNutrient.vitaminC.index,
    )) {
      throw ArgumentError(
        'Additional nutrients cannot replace the core fields.',
      );
    }
    if (isCurrent != null && !isCurrent()) {
      throw StateError('Food edit owner changed.');
    }
    final normalizedBarcode = _optional(barcode);
    if (normalizedBarcode != null) {
      _validateCustomBarcode(normalizedBarcode);
    }
    final normalizedServingUnit = _validateServingUnit(servingUnit);
    _validateNutritionBounds(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
      potassium: potassium,
      calcium: calcium,
      magnesium: magnesium,
      phosphorus: phosphorus,
    );
    _validateFood(
      name: name,
      servingSize: servingSize,
      nutrients: [
        calories,
        protein,
        carbs,
        fats,
        fiber ?? 0,
        sugar ?? 0,
        sodium ?? 0,
        potassium ?? 0,
        calcium ?? 0,
        magnesium ?? 0,
        phosphorus ?? 0,
        iron ?? 0,
        vitaminC ?? 0,
        ...additionalNutrients.values.map((v) => v ?? 0),
      ],
    );
    await (_database.select(_database.foods)..limit(1)).get();
    await _database.transaction(() async {
      if (isCurrent != null && !isCurrent()) {
        throw StateError('Food edit owner changed.');
      }
      if (normalizedBarcode != null) {
        await _ensureBarcodeAvailable(normalizedBarcode, excludingId: id);
      }
      final existing = await _customFood(id);
      await (_database.update(
        _database.foods,
      )..where((row) => row.id.equals(id))).write(
        FoodsCompanion(
          name: Value(name.trim()),
          arabicName: Value(_optional(arabicName)),
          category: Value(category),
          barcode: Value(normalizedBarcode),
          servingSize: Value(servingSize),
          servingUnit: Value(normalizedServingUnit),
          calories: Value(calories),
          protein: Value(protein),
          carbs: Value(carbs),
          fats: Value(fats),
          fiber: Value(fiber ?? 0),
          sugar: Value(sugar ?? 0),
          sodium: Value(sodium ?? 0),
          potassium: Value(potassium ?? 0),
          calcium: Value(calcium ?? 0),
          magnesium: Value(magnesium ?? 0),
          phosphorus: Value(phosphorus ?? 0),
          iron: Value(iron ?? 0),
          vitaminC: Value(vitaminC ?? 0),
          source: source == null
              ? const Value.absent()
              : Value(source.trim().isEmpty ? 'local' : source.trim()),
          nutrientEvidenceMask: Value(
            NutrientEvidenceMask.fromValues(
              fiber: fiber,
              sugar: sugar,
              sodium: sodium,
              potassium: potassium,
              calcium: calcium,
              magnesium: magnesium,
              phosphorus: phosphorus,
              calories: caloriesKnown ? calories : null,
              protein: proteinKnown ? protein : null,
              carbohydrates: carbsKnown ? carbs : null,
              fat: fatsKnown ? fats : null,
            ),
          ),
          updatedAt: Value(DateTime.now()),
          revision: Value(existing.revision + 1),
          syncStatus: const Value('pending'),
        ),
      );
      final row = await (_database.select(
        _database.foods,
      )..where((r) => r.id.equals(id))).getSingle();
      final prior = FoodBasisEvidence.read(existing);
      await _writeCatalogEvidence(row, {
        FoodNutrient.calories: caloriesKnown ? calories : null,
        FoodNutrient.protein: proteinKnown ? protein : null,
        FoodNutrient.carbohydrates: carbsKnown ? carbs : null,
        FoodNutrient.fat: fatsKnown ? fats : null,
        FoodNutrient.fiber: fiber,
        FoodNutrient.sugar: sugar,
        FoodNutrient.sodium: sodium,
        FoodNutrient.potassium: potassium,
        FoodNutrient.calcium: calcium,
        FoodNutrient.magnesium: magnesium,
        FoodNutrient.phosphorus: phosphorus,
        FoodNutrient.iron: iron,
        FoodNutrient.vitaminC: vitaminC,
        for (final n in FoodNutrient.values.where(
          (n) => n.index > FoodNutrient.vitaminC.index,
        ))
          n: additionalNutrients.containsKey(n)
              ? additionalNutrients[n]
              : prior.value(n),
      });
      if (isCurrent != null && !isCurrent()) {
        throw StateError('Food edit owner changed.');
      }
    });
  }
}
