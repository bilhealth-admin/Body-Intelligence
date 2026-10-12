import 'dart:convert';

import '../../data/database/app_database.dart';
import '../../data/database/meal_food_evidence.dart';
import '../../features/nutrition/domain/unified_food.dart';

class LocalDataLifecycleService {
  const LocalDataLifecycleService(this.database);

  final AppDatabase database;

  Future<String> exportJson({required String displayUnits}) async {
    final profile = await database
        .select(database.userProfile)
        .getSingleOrNull();
    final tables = <String, Future<List<dynamic>>>{
      'goals': database.select(database.goals).get(),
      'planSettings': database.select(database.planSettings).get(),
      'weights': database.select(database.weightEntries).get(),
      'dailyLogs': database.select(database.dailyLogs).get(),
      'foods': database.select(database.foods).get(),
      'favorites': database.select(database.favorites).get(),
      'recentFoods': database.select(database.recentFoods).get(),
      'meals': database.select(database.meals).get(),
      'mealItems': database.select(database.mealItems).get(),
      'waterEntries': database.select(database.waterEntries).get(),
      'lifeContext': database.select(database.lifeContextEntries).get(),
      'decisionMemory': database.select(database.decisionMemories).get(),
      'decisionOutcomeTransitions': database
          .select(database.decisionOutcomeTransitions)
          .get(),
      'personalExperiments': database
          .select(database.personalExperiments)
          .get(),
      'challenges': database.select(database.challenges).get(),
      'preferences': database.select(database.preferences).get(),
    };
    final resolved = <String, Object?>{};
    for (final entry in tables.entries) {
      final rows = await entry.value;
      resolved[entry.key] = rows
          .map((row) => (row as dynamic).toJson() as Map<String, dynamic>)
          .toList();
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'BIL local export v3',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'schemaVersion': database.schemaVersion,
      'canonicalUnits': const {
        'weight': 'kg',
        'height': 'cm',
        'water': 'ml',
        'nutrientMass': 'g or mg as identified by field',
      },
      'selectedDisplayUnits': displayUnits,
      'profile': profile?.toJson(),
      ...resolved,
    });
  }

  /// Produces the three portable CSV datasets promised by the export screen.
  /// Values come directly from the local evidence tables; no health values are
  /// inferred or reformatted beyond RFC-4180 escaping.
  Future<Map<String, String>> exportCsvFiles({
    DateTime? from,
    DateTime? to,
  }) async {
    final range = LocalExportDateRange(from: from, to: to);
    final weights = (await database.select(database.weightEntries).get())
        .where((row) => row.deletedAt == null && range.contains(row.date))
        .toList(growable: false);
    final meals = (await database.select(database.meals).get())
        .where((row) => row.deletedAt == null && range.contains(row.date))
        .toList(growable: false);
    final mealIds = meals.map((row) => row.id).toSet();
    final mealItems = (await database.select(database.mealItems).get())
        .where((row) => row.deletedAt == null && mealIds.contains(row.mealId))
        .toList(growable: false);
    final dailyLogs = (await database.select(database.dailyLogs).get())
        .where((row) => range.contains(row.date))
        .toList(growable: false);

    return {
      'BIL-progress.csv': _csvForRows(
        weights
            .map(
              (row) => {
                'recordType': 'weight',
                'date': row.date,
                'weightKg': row.weight,
                'measurementContext': row.measurementContext,
                'note': row.note,
              },
            )
            .toList(),
        const ['recordType', 'date', 'weightKg', 'measurementContext', 'note'],
      ),
      'BIL-meal-nutrition.csv': _csvForRows(
        [
          ...meals.map(
            (row) => {
              'recordType': 'meal',
              'date': row.date,
              'mealId': row.id,
              'mealType': row.type,
              'mealName': row.name,
            },
          ),
          ...mealItems.map(
            (row) => {
              'recordType': 'mealItem',
              'mealId': row.mealId,
              'foodId': row.foodId,
              'quantity': row.quantity,
              'calories': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.calories),
              'proteinG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.protein),
              'carbohydratesG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.carbohydrates),
              'fatG': MealFoodEvidence.read(row).fullValue(FoodNutrient.fat),
              'fiberG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.fiber),
              'sodiumMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.sodium),
              'sugarG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.sugar),
              'potassiumMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.potassium),
              'calciumMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.calcium),
              'ironMg': MealFoodEvidence.read(row).fullValue(FoodNutrient.iron),
              'magnesiumMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.magnesium),
              'phosphorusMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.phosphorus),
              'vitaminCMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.vitaminC),
              'saturatedFatG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.saturatedFat),
              'polyunsaturatedFatG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.polyunsaturatedFat),
              'monounsaturatedFatG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.monounsaturatedFat),
              'transFatG': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.transFat),
              'cholesterolMg': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.cholesterol),
              'vitaminAMcgRae': MealFoodEvidence.read(
                row,
              ).fullValue(FoodNutrient.vitaminA),
              'quantityUnit': row.servingUnitSnapshot,
              'foodName': MealFoodEvidence.read(row).foodName,
              'foodEvidenceJson': row.foodEvidenceJson,
              'nutrientEvidenceMask': row.nutrientEvidenceMask,
              'foodSource': row.foodSourceSnapshot,
              'foodVerified': row.foodVerifiedSnapshot,
              'loggedAt': row.createdAt,
            },
          ),
        ],
        const [
          'recordType',
          'date',
          'mealId',
          'mealType',
          'mealName',
          'foodId',
          'quantity',
          'calories',
          'proteinG',
          'carbohydratesG',
          'fatG',
          'fiberG',
          'sodiumMg',
          'sugarG',
          'potassiumMg',
          'calciumMg',
          'ironMg',
          'magnesiumMg',
          'phosphorusMg',
          'vitaminCMg',
          'saturatedFatG',
          'polyunsaturatedFatG',
          'monounsaturatedFatG',
          'transFatG',
          'cholesterolMg',
          'vitaminAMcgRae',
          'quantityUnit',
          'foodName',
          'foodEvidenceJson',
          'nutrientEvidenceMask',
          'foodSource',
          'foodVerified',
          'loggedAt',
        ],
      ),
      'BIL-exercise.csv': _csvForRows(
        dailyLogs
            .map(
              (row) => {
                'recordType': 'dailyExerciseNote',
                'date': row.date,
                'exerciseNotes': row.exerciseNotes,
                'steps': row.steps,
              },
            )
            .toList(),
        const ['recordType', 'date', 'exerciseNotes', 'steps'],
      ),
    };
  }

  String _csvForRows(List<Map<String, dynamic>> rows, List<String> ordered) {
    String escape(Object? value) {
      final text = value == null
          ? ''
          : value is DateTime
          ? value.toUtc().toIso8601String()
          : '$value';
      return '"${text.replaceAll('"', '""')}"';
    }

    return <String>[
      ordered.map(escape).join(','),
      for (final row in rows)
        ordered.map((header) => escape(row[header])).join(','),
    ].join('\r\n');
  }

  Future<void> clearAll() => database.transaction(() async {
    await database.delete(database.decisionOutcomeTransitions).go();
    await database.delete(database.decisionMemories).go();
    await database.delete(database.lifeContextEntries).go();
    await database.delete(database.personalExperiments).go();
    await database.delete(database.challenges).go();
    await database.delete(database.mealItems).go();
    await database.delete(database.meals).go();
    await database.delete(database.favorites).go();
    await database.delete(database.recentFoods).go();
    await database.delete(database.waterEntries).go();
    await database.delete(database.planSettings).go();
    await database.delete(database.goals).go();
    await database.delete(database.weightEntries).go();
    await database.delete(database.dailyLogs).go();
    await database.delete(database.userProfile).go();
    await database.delete(database.foods).go();
    await database.delete(database.preferences).go();
  });
}

/// Inclusive local-calendar range for owner-requested portable exports.
class LocalExportDateRange {
  LocalExportDateRange({DateTime? from, DateTime? to})
    : from = from == null ? null : DateTime(from.year, from.month, from.day),
      to = to == null
          ? null
          : DateTime(to.year, to.month, to.day, 23, 59, 59, 999) {
    if (this.from != null && this.to != null && this.from!.isAfter(this.to!)) {
      throw ArgumentError('Export start date must not be after end date.');
    }
  }

  final DateTime? from;
  final DateTime? to;

  bool contains(DateTime value) =>
      (from == null || !value.isBefore(from!)) &&
      (to == null || !value.isAfter(to!));
}
