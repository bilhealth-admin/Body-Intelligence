import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/nutrient_evidence.dart';

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
    double? fiber,
    double? sugar,
    double? sodium,
    double? potassium,
    double? calcium,
    double? magnesium,
    double iron = 0,
    double vitaminC = 0,
  }) async {
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
        iron,
        vitaminC,
      ],
    );
    final rowId = await _database
        .into(_database.foods)
        .insert(
          FoodsCompanion.insert(
            name: name.trim(),
            arabicName: Value(_optional(arabicName)),
            category: Value(category),
            keywords: Value(keywords.trim()),
            barcode: Value(_optional(barcode)),
            servingSize: Value(servingSize),
            servingUnit: Value(servingUnit),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: Value(fiber ?? 0),
            sugar: Value(sugar ?? 0),
            potassium: Value(potassium ?? 0),
            sodium: Value(sodium ?? 0),
            calcium: Value(calcium ?? 0),
            iron: Value(iron),
            magnesium: Value(magnesium ?? 0),
            nutrientEvidenceMask: Value(
              NutrientEvidenceMask.fromValues(
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                potassium: potassium,
                calcium: calcium,
                magnesium: magnesium,
              ),
            ),
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
    return (_database.select(_database.foods)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Food>> getFoods() {
    return (_database.select(_database.foods)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<void> updateCustomFood({
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
  }) async {
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
      ],
    );
    final existing = await _customFood(id);
    await (_database.update(
      _database.foods,
    )..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        name: Value(name.trim()),
        arabicName: Value(_optional(arabicName)),
        category: Value(category),
        barcode: Value(_optional(barcode)),
        servingSize: Value(servingSize),
        servingUnit: Value(
          servingUnit.trim().isEmpty ? 'g' : servingUnit.trim(),
        ),
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
        nutrientEvidenceMask: Value(
          NutrientEvidenceMask.fromValues(
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            potassium: potassium,
            calcium: calcium,
            magnesium: magnesium,
          ),
        ),
        updatedAt: Value(DateTime.now()),
        revision: Value(existing.revision + 1),
        syncStatus: const Value('pending'),
      ),
    );
  }

  Future<void> deleteCustomFood(int id) async {
    final existing = await _customFood(id);
    final now = DateTime.now();
    await (_database.update(
      _database.foods,
    )..where((row) => row.id.equals(id))).write(
      FoodsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        revision: Value(existing.revision + 1),
        syncStatus: const Value('pendingDelete'),
      ),
    );
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
            OrderingTerm.desc(_database.favorites.id),
            OrderingTerm.desc(_database.recentFoods.useCount),
            OrderingTerm.desc(_database.recentFoods.lastUsedAt),
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

  Future<bool> isFavorite(int foodId) async {
    final row = await (_database.select(
      _database.favorites,
    )..where((favorite) => favorite.foodId.equals(foodId))).getSingleOrNull();
    return row != null;
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
        nutrients.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Food quantities and nutrients must be valid');
    }
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
