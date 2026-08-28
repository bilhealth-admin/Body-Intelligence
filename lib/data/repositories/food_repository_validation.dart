part of 'food_repository.dart';

extension FoodRepositoryMaintenance on FoodRepository {
  Future<void> recordRecent(int foodId) async {
    final existing = await (_database.select(
      _database.recentFoods,
    )..where((row) => row.foodId.equals(foodId))).getSingleOrNull();
    await _database
        .into(_database.recentFoods)
        .insertOnConflictUpdate(
          RecentFoodsCompanion.insert(
            foodId: Value(foodId),
            lastUsedAt: Value(DateTime.now()),
            useCount: Value((existing?.useCount ?? 0) + 1),
          ),
        );
  }

  Future<void> deleteAll() async {
    await _database.delete(_database.foods).go();
  }

  Future<Food> _customFood(int id) async {
    final food =
        await (_database.select(_database.foods)..where(
              (row) =>
                  row.id.equals(id) &
                  row.isCustom.equals(true) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (food == null) throw StateError('Custom food $id does not exist');
    return food;
  }

  void _validateCustomBarcode(String barcode) {
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
      throw ArgumentError.value(
        barcode,
        'barcode',
        'A custom barcode must contain 8 to 14 digits',
      );
    }
  }

  String _validateServingUnit(String value) {
    final unit = value.trim();
    if (unit.isEmpty ||
        unit.length > 24 ||
        !RegExp(r'^[\p{L}][\p{L}\p{N} ._-]*$', unicode: true).hasMatch(unit)) {
      throw ArgumentError.value(
        value,
        'servingUnit',
        'A short serving unit is required',
      );
    }
    return unit;
  }

  void _validateNutritionBounds({
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double? phosphorus,
  }) {
    final macroValues = [protein, carbs, fats, fiber ?? 0, sugar ?? 0];
    final microValues = [
      sodium ?? 0,
      potassium ?? 0,
      calcium ?? 0,
      magnesium ?? 0,
      phosphorus ?? 0,
    ];
    if (calories > 10000 ||
        macroValues.any((value) => value > 2000) ||
        microValues.any((value) => value > 1000000)) {
      throw ArgumentError('Food nutrition values exceed supported bounds');
    }
  }

  Future<void> _ensureBarcodeAvailable(
    String barcode, {
    int? excludingId,
  }) async {
    final query = _database.select(_database.foods)
      ..where(
        (row) =>
            row.barcode.equals(barcode) &
            row.deletedAt.isNull() &
            (excludingId == null
                ? const Constant(true)
                : row.id.equals(excludingId).not()),
      );
    if (await query.getSingleOrNull() != null) {
      throw StateError('A food with this barcode already exists');
    }
  }

  void _validateFood({
    required String name,
    required double servingSize,
    required List<double> nutrients,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'A food name is required');
    }
    if (!servingSize.isFinite ||
        servingSize <= 0 ||
        servingSize > 100000 ||
        nutrients.any(
          (value) => !value.isFinite || value < 0 || value > 1000000,
        )) {
      throw ArgumentError('Food quantities and nutrients must be valid');
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
