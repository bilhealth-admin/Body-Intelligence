import 'package:drift/drift.dart';

import '../database/app_database.dart';

class FoodRepository {
  final AppDatabase _database;

  FoodRepository(this._database);

  Future<int> addFood({
    required String name,
    required String category,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    String? arabicName,
    String? barcode,
    double servingSize = 100,
    String servingUnit = 'g',
    bool isCustom = true,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'A food name is required');
    }
    if (servingSize <= 0 ||
        calories < 0 ||
        protein < 0 ||
        carbs < 0 ||
        fats < 0) {
      throw ArgumentError('Food quantities and nutrients must be non-negative');
    }
    final rowId = await _database
        .into(_database.foods)
        .insert(
          FoodsCompanion.insert(
            name: name.trim(),
            arabicName: Value(arabicName),
            category: Value(category),
            barcode: Value(barcode),
            servingSize: Value(servingSize),
            servingUnit: Value(servingUnit),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: const Value(0),
            sugar: const Value(0),
            potassium: const Value(0),
            sodium: const Value(0),
            calcium: const Value(0),
            iron: const Value(0),
            magnesium: const Value(0),
            vitaminC: const Value(0),
            verified: const Value(false),
            isCustom: Value(isCustom),
          ),
        );

    return rowId;
  }

  Stream<List<Food>> watchFoods() {
    return (_database.select(
      _database.foods,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<List<Food>> getFoods() {
    return (_database.select(
      _database.foods,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<List<Food>> search(String query, {int limit = 50}) {
    final normalized = query.trim().toLowerCase();
    final selection = _database.select(_database.foods)
      ..where((row) {
        final active = row.deletedAt.isNull();
        if (normalized.isEmpty) return active;
        final pattern = '%$normalized%';
        return active &
            (row.name.lower().like(pattern) |
                row.arabicName.lower().like(pattern) |
                row.keywords.lower().like(pattern) |
                row.barcode.equals(normalized));
      })
      ..orderBy([(row) => OrderingTerm.asc(row.name)])
      ..limit(limit);
    return selection.get();
  }

  Future<void> setFavorite(int foodId, bool favorite) async {
    if (favorite) {
      await _database
          .into(_database.favorites)
          .insert(
            FavoritesCompanion.insert(foodId: foodId),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_database.delete(
        _database.favorites,
      )..where((row) => row.foodId.equals(foodId))).go();
    }
  }

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
}
