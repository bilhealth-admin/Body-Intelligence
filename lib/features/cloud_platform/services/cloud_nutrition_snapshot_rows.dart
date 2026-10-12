part of 'cloud_nutrition_snapshot_codec.dart';

Map<String, Object?> _wireRow(Map<String, dynamic> source) {
  final result = Map<String, Object?>.of(source)
    ..remove('id')
    ..remove('mealId')
    ..remove('foodId')
    ..remove('syncStatus');
  for (final key in ['date', 'createdAt', 'updatedAt', 'deletedAt']) {
    final value = result[key];
    if (value is int) {
      result[key] = DateTime.fromMillisecondsSinceEpoch(
        value,
        isUtc: true,
      ).toIso8601String();
    }
  }
  return result;
}

DateTime _date(Object? value) {
  if (value is! String || !value.endsWith('Z')) {
    throw const FormatException('Cloud nutrition dates require UTC.');
  }
  final date = DateTime.tryParse(value);
  if (date == null) {
    throw const FormatException('Invalid cloud nutrition date.');
  }
  return date.toUtc();
}

Map<String, dynamic> _localRow(Object? source, Set<String> keys) {
  final value = _objectMap(source);
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      !value.keys.toSet().containsAll(keys)) {
    throw const FormatException('Unsupported cloud nutrition row fields.');
  }
  final result = <String, dynamic>{...value, 'id': 0, 'syncStatus': 'synced'};
  for (final key in ['date', 'createdAt', 'updatedAt', 'deletedAt']) {
    if (value.containsKey(key) && value[key] != null) {
      result[key] = _date(value[key]).millisecondsSinceEpoch;
    }
  }
  return result;
}

const _commonRowKeys = {
  'uuid',
  'createdAt',
  'updatedAt',
  'deletedAt',
  'revision',
};
const _foodRowKeys = {
  ..._commonRowKeys,
  'name',
  'arabicName',
  'category',
  'keywords',
  'barcode',
  'servingSize',
  'servingUnit',
  'calories',
  'protein',
  'carbs',
  'fats',
  'fiber',
  'sugar',
  'potassium',
  'sodium',
  'calcium',
  'iron',
  'magnesium',
  'phosphorus',
  'vitaminC',
  'nutrientEvidenceMask',
  'verified',
  'isCustom',
  'source',
  'foodEvidenceJson',
};
const _mealRowKeys = {..._commonRowKeys, 'date', 'dayKey', 'name', 'type'};
const _itemRowKeys = {
  ..._commonRowKeys,
  'foodUuid',
  'quantity',
  'position',
  'calories',
  'protein',
  'carbs',
  'fats',
  'fiber',
  'sodium',
  'potassium',
  'calcium',
  'magnesium',
  'phosphorus',
  'sugar',
  'nutrientEvidenceMask',
  'foodSourceSnapshot',
  'foodEvidenceJson',
  'foodVerifiedSnapshot',
  'servingSizeSnapshot',
  'servingUnitSnapshot',
};

void _numbers(Iterable<double> values) {
  if (values.any((value) => !value.isFinite || value < 0 || value > 1e12)) {
    throw const FormatException('Invalid cloud nutrient projection.');
  }
}

extension _CloudNutritionRows on CloudNutritionSnapshotCodec {
  void _validateFood(Food food) {
    _text(food.uuid, max: 512);
    _text(food.name, max: 500);
    _text(food.source);
    _text(food.servingUnit, max: 100);
    _numbers([
      food.servingSize,
      food.calories,
      food.protein,
      food.carbs,
      food.fats,
      food.fiber,
      food.sugar,
      food.sodium,
      food.potassium,
      food.calcium,
      food.magnesium,
      food.phosphorus,
      food.iron,
      food.vitaminC,
    ]);
    if (food.servingSize <= 0 ||
        food.revision < 1 ||
        food.nutrientEvidenceMask < 0 ||
        !FoodBasisEvidence.read(food, ownerKey: _ownerKey).isValid) {
      throw const FormatException('Invalid cloud food evidence.');
    }
  }

  void _validateItem(MealItem item) {
    _text(item.uuid, max: 512);
    _text(item.foodSourceSnapshot);
    _text(item.servingUnitSnapshot, max: 100);
    _numbers([
      item.quantity,
      item.servingSizeSnapshot,
      item.calories,
      item.protein,
      item.carbs,
      item.fats,
      item.fiber,
      item.sugar,
      item.sodium,
      item.potassium,
      item.calcium,
      item.magnesium,
      item.phosphorus,
    ]);
    if (item.quantity <= 0 ||
        item.servingSizeSnapshot <= 0 ||
        item.revision < 1 ||
        item.position < 0 ||
        item.nutrientEvidenceMask < 0 ||
        !MealFoodEvidence.read(item, ownerKey: _ownerKey).isValid) {
      throw const FormatException('Invalid cloud meal evidence.');
    }
  }

  Food _decodeFood(Object? raw) {
    final food = Food.fromJson(_localRow(raw, _foodRowKeys));
    _validateFood(food);
    return food;
  }

  Future<Food?> _findFood(String uuid) => (database.select(
    database.foods,
  )..where((row) => row.uuid.equals(uuid))).getSingleOrNull();

  String _foodDeletionKey(String uuid) =>
      '${CloudNutritionSnapshotCodec._foodDeletionPrefix}${Uri.encodeComponent(uuid)}';

  CloudNutritionSnapshot _decodeFoodDeletion(String key, String raw) {
    final deletion = CloudNutritionSnapshot.fromJson(
      _objectMap(jsonDecode(raw)),
    );
    _validateSnapshot(deletion);
    if (deletion.scope != 'nutrition' ||
        deletion.type != 'food' ||
        !deletion.deleted ||
        key != _foodDeletionKey(deletion.id)) {
      throw const FormatException('Invalid local cloud food deletion.');
    }
    _foodDeletionTime(deletion);
    return deletion;
  }

  Future<CloudNutritionSnapshot?> _savedFoodDeletion(String uuid) async {
    final key = _foodDeletionKey(uuid);
    final raw = await PreferencesRepository(database).get(key);
    return raw == null ? null : _decodeFoodDeletion(key, raw);
  }

  Future<int> _putFood(Food food, {required bool dependency}) async {
    final existing = await _findFood(food.uuid);
    final deletion = await _savedFoodDeletion(food.uuid);
    if (!dependency && (deletion != null || existing?.deletedAt != null)) {
      throw const FormatException('Deleted cloud food cannot be resurrected.');
    }
    if (deletion != null) {
      food = food.copyWith(deletedAt: Value(_foodDeletionTime(deletion)));
    }
    // An old diary/recipe contains evidence for its own history; it does not
    // authorize replacing a newer editable catalog entry on this device.
    if (dependency && existing != null) {
      _validateFood(existing);
      if (deletion != null && existing.deletedAt == null) {
        await (database.update(
          database.foods,
        )..where((row) => row.id.equals(existing.id))).write(
          FoodsCompanion(
            deletedAt: Value(_foodDeletionTime(deletion)),
            syncStatus: const Value('synced'),
          ),
        );
      }
      return existing.id;
    }
    final value = food
        .toCompanion(false)
        .copyWith(
          id: existing == null ? const Value.absent() : Value(existing.id),
          syncStatus: const Value('synced'),
        );
    if (existing == null) return database.into(database.foods).insert(value);
    await (database.update(
      database.foods,
    )..where((row) => row.id.equals(existing.id))).write(value);
    return existing.id;
  }

  Future<Map<String, int>> _putDependencies(Object? raw) async {
    final mapping = <String, int>{};
    for (final definition in _list(raw)) {
      final food = _decodeFood(definition);
      if (mapping.containsKey(food.uuid)) {
        throw const FormatException('Duplicate cloud food identity.');
      }
      mapping[food.uuid] = await _putFood(food, dependency: true);
      await _checkOwner();
    }
    return mapping;
  }

  DateTime _deletionTime(CloudNutritionSnapshot snapshot) =>
      snapshot.data['deletedAt'] == null
      ? DateTime.now().toUtc()
      : _date(snapshot.data['deletedAt']);

  // V2 food deletion is produced from a real soft-deleted catalog row.
  // An absent date is corrupt metadata, not permission to invent a new time
  // on every capture/restart. Legacy meal/recipe tombstone handling stays below.
  DateTime _foodDeletionTime(CloudNutritionSnapshot snapshot) =>
      _date(snapshot.data['deletedAt']);

  Future<void> _applyFood(CloudNutritionSnapshot snapshot) async {
    if (snapshot.deleted) {
      // Validate even a late duplicate before touching a previously valid
      // marker. The marker and row update share apply()'s SQLite transaction.
      _foodDeletionTime(snapshot);
      final prior = await _savedFoodDeletion(snapshot.id);
      if (prior == null) {
        await PreferencesRepository(
          database,
        ).set(_foodDeletionKey(snapshot.id), jsonEncode(snapshot.toJson()));
      }
      final deletion = prior ?? snapshot;
      final existing = await _findFood(snapshot.id);
      if (existing == null) return;
      await (database.update(
        database.foods,
      )..where((row) => row.id.equals(existing.id))).write(
        FoodsCompanion(
          deletedAt: Value(_foodDeletionTime(deletion)),
          syncStatus: const Value('synced'),
        ),
      );
      return;
    }
    final food = _decodeFood(snapshot.data['food']);
    if (food.uuid != snapshot.id || food.deletedAt != null) {
      throw const FormatException('Cloud food identity mismatch.');
    }
    await _putFood(food, dependency: false);
  }

  Future<void> _applyMeal(CloudNutritionSnapshot snapshot) async {
    final existing = await (database.select(
      database.meals,
    )..where((row) => row.uuid.equals(snapshot.id))).getSingleOrNull();
    if (snapshot.deleted) {
      if (existing != null) {
        final deletedAt = Value(_deletionTime(snapshot));
        await (database.update(
          database.meals,
        )..where((row) => row.id.equals(existing.id))).write(
          MealsCompanion(
            deletedAt: deletedAt,
            syncStatus: const Value('synced'),
          ),
        );
        await (database.update(
          database.mealItems,
        )..where((row) => row.mealId.equals(existing.id))).write(
          MealItemsCompanion(
            deletedAt: deletedAt,
            syncStatus: const Value('synced'),
          ),
        );
      }
      await _retireHistoricalFirstFood();
      return;
    }
    final meal = Meal.fromJson(_localRow(snapshot.data['meal'], _mealRowKeys));
    if (meal.uuid != snapshot.id ||
        meal.deletedAt != null ||
        meal.revision < 1 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(meal.dayKey) ||
        !const {
          'breakfast',
          'lunch',
          'dinner',
          'snack',
          'other',
        }.contains(meal.type)) {
      throw const FormatException('Invalid cloud meal identity or civil day.');
    }
    _text(meal.name, max: 500);
    final foodIds = await _putDependencies(snapshot.data['foods']);
    final companion = meal
        .toCompanion(false)
        .copyWith(
          id: existing == null ? const Value.absent() : Value(existing.id),
          syncStatus: const Value('synced'),
        );
    final int mealId;
    if (existing == null) {
      mealId = await database.into(database.meals).insert(companion);
    } else {
      mealId = existing.id;
      await (database.update(
        database.meals,
      )..where((row) => row.id.equals(mealId))).write(companion);
    }
    final seen = <String>{};
    for (final raw in _list(snapshot.data['items'])) {
      final data = _localRow(raw, _itemRowKeys);
      final foodId = foodIds[data.remove('foodUuid')];
      if (foodId == null) {
        throw const FormatException('Missing cloud meal dependency.');
      }
      final item = MealItem.fromJson({
        ...data,
        'mealId': mealId,
        'foodId': foodId,
      });
      _validateItem(item);
      if (!seen.add(item.uuid)) {
        throw const FormatException('Duplicate cloud meal item.');
      }
      final prior = await (database.select(
        database.mealItems,
      )..where((row) => row.uuid.equals(item.uuid))).getSingleOrNull();
      if (prior != null && prior.mealId != mealId) {
        throw const FormatException('Cloud item belongs to a different meal.');
      }
      final itemValue = item
          .toCompanion(false)
          .copyWith(
            id: prior == null ? const Value.absent() : Value(prior.id),
            syncStatus: const Value('synced'),
          );
      if (prior == null) {
        await database.into(database.mealItems).insert(itemValue);
      } else {
        await (database.update(
          database.mealItems,
        )..where((row) => row.id.equals(prior.id))).write(itemValue);
      }
      await _checkOwner();
    }
    final children = await (database.select(
      database.mealItems,
    )..where((row) => row.mealId.equals(mealId))).get();
    if (children.any((item) => !seen.contains(item.uuid))) {
      throw const FormatException(
        'Meal aggregate omitted an existing item tombstone.',
      );
    }
    if (seen.isNotEmpty) await _retireHistoricalFirstFood();
  }

  Future<void> _retireHistoricalFirstFood() async {
    final preferences = PreferencesRepository(database);
    if (await preferences.get(firstMealCelebrationPreferenceKey) == null) {
      await preferences.set(firstMealCelebrationPreferenceKey, 'done');
    }
  }
}
