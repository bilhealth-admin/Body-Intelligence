import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/database_scope.dart';
import '../../../data/database/food_basis_evidence.dart';
import '../../../data/database/meal_food_evidence.dart';
import '../../../data/repositories/first_meal_milestone.dart';
import '../../../data/repositories/nutrition_goal_schedule_repository.dart';
import '../../../data/repositories/preferences_repository.dart';
import '../../nutrition/domain/nutrition_goal_snapshot.dart';
import '../../recipe_import/domain/trusted_recipe.dart';
import '../../recipe_import/repositories/trusted_recipe_repository.dart';
import '../../recipe_import/services/trusted_recipe_parser.dart';
import 'local_data_account_boundary.dart';

part 'cloud_nutrition_snapshot_rows.dart';
part 'cloud_nutrition_snapshot_collections.dart';

/// A logical cloud identity never contains a device-local SQLite row number.
final class CloudNutritionSnapshot {
  const CloudNutritionSnapshot({
    required this.scope,
    required this.type,
    required this.id,
    required this.deleted,
    required this.data,
  });

  final String scope, type, id;
  final bool deleted;
  final Map<String, Object?> data;
  String get key => '$scope:$type:$id';

  Map<String, Object?> toJson() => {
    'scope': scope,
    'type': type,
    'id': id,
    'deleted': deleted,
    'data': data,
  };

  factory CloudNutritionSnapshot.fromJson(Map<String, Object?> value) {
    if (value.keys.toSet().difference(const {
          'scope',
          'type',
          'id',
          'deleted',
          'data',
        }).isNotEmpty ||
        value['scope'] is! String ||
        value['type'] is! String ||
        value['id'] is! String ||
        value['deleted'] is! bool) {
      throw const FormatException('Invalid cloud nutrition record.');
    }
    return CloudNutritionSnapshot(
      scope: value['scope']! as String,
      type: value['type']! as String,
      id: value['id']! as String,
      deleted: value['deleted']! as bool,
      data: _objectMap(value['data']),
    );
  }
}

/// SQLite side of the separately consented nutrition/goal cloud contract.
/// Server revision comparison and pending-local preimages belong to the sync
/// engine. This codec never resolves conflicts using a wall clock.
final class CloudNutritionSnapshotCodec {
  CloudNutritionSnapshotCodec(
    this.database, {
    required this.ownerId,
    required this.ownerIsCurrent,
  });

  static const schema = 'bil.nutrition.snapshot.v1';
  static const referenceVersion = 'fda_label_dv_2026_10_11';
  static const referencePreference = 'goal.cloudReferenceVersion.v1';
  static const _foodDeletionPrefix = 'cloud.restore.foodDeletion.v1.';
  final AppDatabase database;
  final String ownerId;
  final bool Function() ownerIsCurrent;

  String get _ownerKey => LocalDatabaseScope.keyForOwner(ownerId);
  Map<String, Object?> get _header => {'schema': schema, 'ownerId': ownerId};

  /// Resetting all overrides is an editable empty snapshot, not a permanent
  /// tombstone for this account's one nutrition-goals identity.
  CloudNutritionSnapshot emptyGoalsSnapshot() => CloudNutritionSnapshot(
    scope: 'goals',
    type: 'goals',
    id: 'nutrition-goals',
    deleted: false,
    data: {
      ..._header,
      'referenceVersion': referenceVersion,
      'values': const <String, String>{},
    },
  );

  Future<void> _checkOwner() async {
    if (!ownerIsCurrent() ||
        ownerId.trim().isEmpty ||
        database.localOwnerId != ownerId ||
        await LocalDataAccountBoundary(database).readBoundOwnerId() !=
            ownerId ||
        !ownerIsCurrent()) {
      throw StateError('nutrition_cloud_owner_changed');
    }
  }

  Future<List<CloudNutritionSnapshot>> capture({
    required Set<String> scopes,
  }) async {
    await _checkOwner();
    return database.transaction(() async {
      await _checkOwner();
      final output = <CloudNutritionSnapshot>[];
      if (scopes.contains('nutrition')) {
        final meals = await database.select(database.meals).get();
        final items = await database.select(database.mealItems).get();
        final recipes = await TrustedRecipeRepository(
          PreferencesRepository(database),
        ).load();
        // The installed search catalog may contain hundreds of thousands of
        // foods. Backup reads only user foods and actual diary dependencies.
        final foods =
            await (database.select(database.foods)..where(
                  (food) =>
                      food.isCustom.equals(true) |
                      food.id.isInQuery(
                        database.selectOnly(database.mealItems)
                          ..addColumns([database.mealItems.foodId]),
                      ),
                ))
                .get();
        final byUuid = {for (final food in foods) food.uuid: food};
        final recipeReferences = {
          for (final recipe in recipes)
            for (final ingredient in recipe.recipe.ingredients)
              if (ingredient.sourceRecordId != null)
                ingredient.sourceRecordId!.startsWith('local:')
                    ? ingredient.sourceRecordId!.substring(6)
                    : ingredient.sourceRecordId!,
        }.difference(byUuid.keys.toSet()).toList();
        for (var offset = 0; offset < recipeReferences.length; offset += 500) {
          final references = recipeReferences.skip(offset).take(500).toList();
          final dependencies = await (database.select(
            database.foods,
          )..where((food) => food.uuid.isIn(references))).get();
          for (final food in dependencies) {
            byUuid[food.uuid] = food;
          }
        }
        final byId = {for (final food in byUuid.values) food.id: food};
        final byMeal = <int, List<MealItem>>{};
        for (final item in items) {
          (byMeal[item.mealId] ??= <MealItem>[]).add(item);
        }
        final includedFoods = <String>{
          for (final food in foods.where((row) => row.isCustom)) food.uuid,
        };
        for (final meal in meals) {
          final children = [...?byMeal[meal.id]]
            ..sort((a, b) => a.uuid.compareTo(b.uuid));
          final dependencies = <String, Food>{};
          for (final item in children) {
            final food = byId[item.foodId];
            if (food == null) throw const FormatException('Missing meal food.');
            _validateItem(item);
            _validateFood(food);
            dependencies[food.uuid] = food;
            includedFoods.add(food.uuid);
          }
          output.add(
            CloudNutritionSnapshot(
              scope: 'nutrition',
              type: 'meal',
              id: meal.uuid,
              deleted: meal.deletedAt != null,
              data: meal.deletedAt != null
                  ? {
                      ..._header,
                      'deletedAt': meal.deletedAt!.toUtc().toIso8601String(),
                    }
                  : {
                      ..._header,
                      'meal': _wireRow(meal.toJson()),
                      'items': [
                        for (final item in children)
                          {
                            ..._wireRow(item.toJson()),
                            'foodUuid': byId[item.foodId]!.uuid,
                          },
                      ],
                      'foods': _foodDefinitions(dependencies.values),
                    },
            ),
          );
        }
        for (final recipe in recipes) {
          final dependencies = <Food>[];
          for (final ingredient in recipe.recipe.ingredients) {
            final ref = ingredient.sourceRecordId;
            if (ref == null) continue;
            final uuid = ref.startsWith('local:') ? ref.substring(6) : ref;
            final food = byUuid[uuid];
            if (food == null && ref.startsWith('local:')) {
              throw const FormatException('Missing recipe ingredient food.');
            }
            if (food != null) {
              dependencies.add(food);
              includedFoods.add(food.uuid);
            }
          }
          output.add(
            CloudNutritionSnapshot(
              scope: 'nutrition',
              type: 'recipe',
              id: recipe.id,
              deleted: false,
              data: {
                ..._header,
                'recipe': recipe.toJson(),
                'foods': _foodDefinitions(dependencies),
              },
            ),
          );
        }
        for (final food in byUuid.values.where(
          (row) => includedFoods.contains(row.uuid),
        )) {
          _validateFood(food);
          output.add(
            CloudNutritionSnapshot(
              scope: 'nutrition',
              type: 'food',
              id: food.uuid,
              deleted: food.deletedAt != null,
              data: food.deletedAt != null
                  ? {
                      ..._header,
                      'deletedAt': food.deletedAt!.toUtc().toIso8601String(),
                    }
                  : {..._header, 'food': _wireRow(food.toJson())},
            ),
          );
        }
      }
      if (scopes.contains('nutrition')) {
        // A fresh device may receive the deletion before any food definition.
        // Keep that identity durable without inventing a zero-valued catalog
        // row. Historical dependencies may supply evidence later, not revive it.
        final markers = await (database.select(
          database.preferences,
        )..where((row) => row.key.like('$_foodDeletionPrefix%'))).get();
        final capturedFoodIds = output
            .where((row) => row.type == 'food')
            .map((row) => row.id)
            .toSet();
        for (final marker in markers) {
          final deletion = _decodeFoodDeletion(marker.key, marker.value);
          if (!capturedFoodIds.contains(deletion.id)) output.add(deletion);
        }
      }
      if (scopes.contains('goals')) {
        final rows = await database.select(database.preferences).get();
        final values = <String, String>{
          for (final row in rows.where((row) => _goalKey(row.key)))
            row.key: row.value,
        };
        if (values.isNotEmpty) {
          output.add(
            CloudNutritionSnapshot(
              scope: 'goals',
              type: 'goals',
              id: 'nutrition-goals',
              deleted: false,
              data: {
                ..._header,
                'referenceVersion':
                    rows
                        .where((r) => r.key == referencePreference)
                        .firstOrNull
                        ?.value ??
                    referenceVersion,
                'values': values,
              },
            ),
          );
        }
      }
      await _checkOwner();
      output.sort((a, b) => a.key.compareTo(b.key));
      return List.unmodifiable(output);
    });
  }

  Future<void> apply(CloudNutritionSnapshot snapshot) async {
    await _checkOwner();
    _validateSnapshot(snapshot);
    await database.transaction(() async {
      await _checkOwner();
      switch ((snapshot.scope, snapshot.type)) {
        case ('nutrition', 'food'):
          await _applyFood(snapshot);
        case ('nutrition', 'meal'):
          await _applyMeal(snapshot);
        case ('nutrition', 'recipe'):
          await _applyRecipe(snapshot);
        case ('goals', 'goals'):
          await _applyGoals(snapshot);
        default:
          throw const FormatException('Unsupported cloud nutrition type.');
      }
      await _checkOwner();
    });
  }

  void _validateSnapshot(CloudNutritionSnapshot snapshot) {
    if (snapshot.id.isEmpty ||
        snapshot.id.length > 512 ||
        snapshot.data['schema'] != schema ||
        snapshot.data['ownerId'] != ownerId ||
        (snapshot.scope == 'goals' && snapshot.id != 'nutrition-goals')) {
      throw const FormatException(
        'Invalid cloud nutrition identity or version.',
      );
    }
    if (utf8.encode(jsonEncode(snapshot.toJson())).length > 4 * 1024 * 1024) {
      throw const FormatException('Cloud nutrition record is too large.');
    }
  }

  List<Map<String, Object?>> _foodDefinitions(Iterable<Food> source) {
    final foods = {for (final food in source) food.uuid: food}.values.toList()
      ..sort((a, b) => a.uuid.compareTo(b.uuid));
    return [for (final food in foods) _wireRow(food.toJson())];
  }
}

Map<String, Object?> _objectMap(Object? raw) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    throw const FormatException('Expected cloud nutrition object.');
  }
  return Map<String, Object?>.from(raw);
}

String _text(Object? value, {int max = 4096}) {
  if (value is! String || value.isEmpty || value.length > max) {
    throw const FormatException('Invalid cloud nutrition text.');
  }
  return value;
}

List<Object?> _list(Object? value) {
  if (value is! List || value.length > 10000) {
    throw const FormatException('Invalid cloud nutrition list.');
  }
  return value.cast<Object?>();
}
