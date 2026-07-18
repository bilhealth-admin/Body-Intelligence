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
    String keywords = '',
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
    double potassium = 0,
    double calcium = 0,
    double magnesium = 0,
    double iron = 0,
    double vitaminC = 0,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'A food name is required');
    }
    if (servingSize <= 0 ||
        calories < 0 ||
        protein < 0 ||
        carbs < 0 ||
        fats < 0 ||
        fiber < 0 ||
        sugar < 0 ||
        sodium < 0 ||
        potassium < 0 ||
        calcium < 0 ||
        magnesium < 0 ||
        iron < 0 ||
        vitaminC < 0) {
      throw ArgumentError('Food quantities and nutrients must be non-negative');
    }
    final rowId = await _database
        .into(_database.foods)
        .insert(
          FoodsCompanion.insert(
            name: name.trim(),
            arabicName: Value(arabicName),
            category: Value(category),
            keywords: Value(keywords.trim()),
            barcode: Value(barcode),
            servingSize: Value(servingSize),
            servingUnit: Value(servingUnit),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: Value(fiber),
            sugar: Value(sugar),
            potassium: Value(potassium),
            sodium: Value(sodium),
            calcium: Value(calcium),
            iron: Value(iron),
            magnesium: Value(magnesium),
            vitaminC: Value(vitaminC),
            verified: const Value(false),
            isCustom: Value(isCustom),
          ),
        );

    return rowId;
  }

  Stream<List<Food>> watchFavorites() {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.favorites,
              _database.favorites.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(_database.foods.name)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_database.foods)).toList(),
    );
  }

  Stream<List<Food>> watchRecent({int limit = 20}) {
    final query =
        _database.select(_database.foods).join([
            innerJoin(
              _database.recentFoods,
              _database.recentFoods.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(_database.foods.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(_database.recentFoods.lastUsedAt)])
          ..limit(limit);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_database.foods)).toList(),
    );
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
    final active = _database.foods.deletedAt.isNull();
    final condition = normalized.isEmpty
        ? active
        : active &
              (_database.foods.name.lower().like('%$normalized%') |
                  _database.foods.arabicName.lower().like('%$normalized%') |
                  _database.foods.keywords.lower().like('%$normalized%') |
                  _database.foods.barcode.equals(normalized));
    final selection =
        _database.select(_database.foods).join([
            leftOuterJoin(
              _database.recentFoods,
              _database.recentFoods.foodId.equalsExp(_database.foods.id),
            ),
            leftOuterJoin(
              _database.favorites,
              _database.favorites.foodId.equalsExp(_database.foods.id),
            ),
          ])
          ..where(condition)
          ..orderBy([
            OrderingTerm.desc(_database.recentFoods.useCount),
            OrderingTerm.desc(_database.favorites.id),
            OrderingTerm.desc(_database.foods.verified),
            OrderingTerm.asc(_database.foods.name),
          ])
          ..limit(limit);
    return selection.get().then(
      (rows) => rows.map((row) => row.readTable(_database.foods)).toList(),
    );
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
