// Actual immutable SQLite reads. No mutable Food catalog and no writes.
import 'package:drift/drift.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/database_scope.dart';
import '../../../data/database/date_keys.dart';
import '../../../data/database/meal_food_evidence.dart';
import '../../../data/repositories/daily_log_repository.dart';
import '../domain/coach_message_presentation.dart';
import '../domain/food_v2/coach_food_v2.dart';
import 'coach_meal_read_parser.dart';

final class CoachMessageNutritionReader {
  const CoachMessageNutritionReader(this.database, {required this.clock});
  final AppDatabase database;
  final DateTime Function() clock;

  Future<CoachMessagePresentation?> readMeals(
    CoachMealReadRequest request, {
    required void Function() checkAccess,
  }) async {
    checkAccess();
    if (request.columns.isEmpty || request.columns.length > 3) {
      throw const FormatException('Choose one meal or a bounded comparison');
    }
    final requestedColumns = List<CoachMealReadColumnRequest>.unmodifiable(
      request.columns,
    );
    final owner = LocalDatabaseScope.keyForOwner(database.localOwnerId);
    final captured = clock().toUtc();
    return database.transaction(() async {
      checkAccess();
      final columns = <CoachVisualNutritionColumn>[];
      for (final requested in requestedColumns) {
        final rows = await _itemsForDay(
          requested.day,
          type: requested.mealType,
          checkAccess: checkAccess,
        );
        checkAccess();
        final evidence = rows
            .map((row) => MealFoodEvidence.read(row, ownerKey: owner))
            .toList(growable: false);
        columns.add(
          _column(
            title: requested.mealType,
            mealType: requested.mealType,
            day: requested.day,
            evidence: evidence,
            captured: captured,
          ),
        );
      }
      checkAccess();
      final days = requestedColumns.map((x) => dayKeyFor(x.day)).toList()
        ..sort();
      return CoachMessagePresentation.localRead(
        ownerKey: owner,
        capturedAtUtc: captured,
        kind: request.compare
            ? CoachVisualKind.comparison
            : CoachVisualKind.nutrition,
        title: request.compare ? 'Meal comparison' : 'Meal nutrition',
        fromDay: days.first,
        throughDay: days.last,
        columns: columns,
      );
    });
  }

  Future<CoachMessagePresentation> readDay(
    DateTime day, {
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final owner = LocalDatabaseScope.keyForOwner(database.localOwnerId);
    final captured = clock().toUtc();
    return database.transaction(() async {
      final ledger = await DailyLogRepository(database).readLedger(day);
      checkAccess();
      final rows = await _itemsForDay(day, checkAccess: checkAccess);
      final evidence = rows
          .map((row) => MealFoodEvidence.read(row, ownerKey: owner))
          .toList(growable: false);
      final detailed = _column(
        title: 'Day nutrition',
        day: day,
        evidence: evidence,
        captured: captured,
      );
      // Preserve canonical saved ledger values (not re-calculated closed days).
      // Extended nutrients come from immutable food details and retain their
      // separate source tag. If unsupported/missing they remain unavailable.
      final core = <String, double?>{
        'calories': ledger.calories,
        'protein': ledger.protein,
        'carbohydrates': ledger.carbohydrates,
        'fat': ledger.fat,
        'fiber': ledger.fiber,
      };
      final metrics = detailed.metrics
          .map((metric) {
            // Open-day complete totals are intentionally null when one item is
            // missing. Retain the explicitly labelled known subtotal + coverage.
            // Closed canonical null remains unknown and must never fall back.
            if (ledger.state != DayLifecycleState.closed ||
                !core.containsKey(metric.id)) {
              return metric;
            }
            final amount = core[metric.id];
            if (amount == null || !amount.isFinite || amount < 0) {
              return CoachVisualMetric.localRead(
                id: metric.id,
                knownSubtotal: null,
                knownItems: 0,
                missingItems: 1,
                estimated: false,
              );
            }
            return CoachVisualMetric.localRead(
              id: metric.id,
              knownSubtotal: amount,
              knownItems: 1,
              missingItems: 0,
              estimated: metric.estimated,
            );
          })
          .toList(growable: false);
      // Do not take a legacy-derived net number without a normalized source
      // definition. _column uses the established v1 FoodNutrients getter only
      // for validated modern portion/unit/recipe schemas.
      checkAccess();
      return CoachMessagePresentation.localRead(
        ownerKey: owner,
        capturedAtUtc: captured,
        kind: CoachVisualKind.nutrition,
        title: 'Day nutrition',
        fromDay: dayKeyFor(day),
        throughDay: dayKeyFor(day),
        columns: [
          CoachVisualNutritionColumn(
            title: 'Day nutrition',
            dayKey: dayKeyFor(day),
            metrics: metrics,
            sourceKinds: {
              ledger.state == DayLifecycleState.closed
                  ? 'saved_day_ledger'
                  : 'known_food_subtotal',
              'immutable_food_details',
              ...detailed.sourceKinds,
            }.toList(growable: false),
            sourceRevisions: detailed.sourceRevisions,
            sourceRevisionCount: detailed.sourceRevisionCount,
            capturedAtUtc: captured,
          ),
        ],
      );
    });
  }

  Future<List<MealItem>> _itemsForDay(
    DateTime day, {
    String? type,
    required void Function() checkAccess,
  }) async {
    checkAccess();
    final meals =
        await (database.select(database.meals)..where(
              (row) =>
                  row.dayKey.equals(dayKeyFor(day)) &
                  row.deletedAt.isNull() &
                  (type == null ? const Constant(true) : row.type.equals(type)),
            ))
            .get();
    checkAccess();
    if (meals.isEmpty) return const [];
    final items =
        await (database.select(database.mealItems)
              ..where(
                (row) =>
                    row.mealId.isIn(meals.map((x) => x.id)) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.mealId),
                (row) => OrderingTerm.asc(row.position),
                (row) => OrderingTerm.asc(row.id),
              ])
              ..limit(10001))
            .get();
    checkAccess();
    if (items.length > 10000) {
      throw const FormatException(
        'Nutrition read exceeds the bounded snapshot',
      );
    }
    return items;
  }

  CoachVisualNutritionColumn _column({
    required String title,
    required DateTime day,
    required List<MealFoodEvidence> evidence,
    required DateTime captured,
    String? mealType,
  }) {
    // One bounded read projection for all message cards/tables/copy. Each amount
    // is the existing immutable MealFoodEvidence fullValue19 calculation;
    // widgets never rescale portions or recalculate a historical catalog food.
    final metrics = <CoachVisualMetric>[];
    for (final nutrient in FoodNutrient.values) {
      metrics.add(
        _aggregate(evidence, nutrient.name, (row) => row.fullValue(nutrient)),
      );
    }
    metrics.add(_aggregate(evidence, 'netCarbohydrates', _normalizedNet));
    final sourceKinds = <String>{};
    final revisions = <String>{};
    for (final row in evidence) {
      final portion = row.portion;
      if (portion != null) {
        sourceKinds.add(portion.food.source.kind.wireName);
        revisions.add(portion.food.source.revision);
        if (portion.quantity.evidence.kind == CoachFoodQuantityKind.estimated) {
          sourceKinds.add('estimated_portion');
        }
      } else if (row.recipe != null) {
        sourceKinds.add('calculated_recipe');
      } else if (row.unit != null) {
        sourceKinds.add('declared_unit');
      } else {
        sourceKinds.add(
          row.isValid ? 'legacy_recorded' : 'unavailable_evidence',
        );
      }
    }
    // Never truncate a provenance list and pretend it is complete. Revisions
    // are kept only as bounded metadata; sources themselves stay real.
    return CoachVisualNutritionColumn(
      title: title,
      dayKey: dayKeyFor(day),
      mealType: mealType,
      metrics: metrics,
      sourceKinds: sourceKinds.toList(growable: false),
      sourceRevisions: revisions.take(30).toList(growable: false),
      sourceRevisionCount: revisions.length,
      capturedAtUtc: captured,
    );
  }

  CoachVisualMetric _aggregate(
    List<MealFoodEvidence> rows,
    String id,
    double? Function(MealFoodEvidence) read,
  ) {
    var total = 0.0, known = 0, missing = 0;
    var estimated = false;
    for (final row in rows) {
      final value = read(row);
      if (value == null || !value.isFinite || value < 0) {
        missing++;
        continue;
      }
      total += value;
      known++;
      estimated |=
          row.portion?.food.source.kind == CoachFoodSourceKind.estimated ||
          row.portion?.quantity.evidence.kind ==
              CoachFoodQuantityKind.estimated;
    }
    if (!total.isFinite) {
      return CoachVisualMetric.localRead(
        id: id,
        knownSubtotal: null,
        knownItems: 0,
        missingItems: rows.length,
      );
    }
    return CoachVisualMetric.localRead(
      id: id,
      knownSubtotal: known == 0 ? null : total,
      knownItems: known,
      missingItems: missing,
      estimated: estimated,
    );
  }

  double? _normalizedNet(MealFoodEvidence row) {
    // Valid normalized v1 contract: total carbohydrate includes fiber.
    // Legacy arithmetic is intentionally not promoted to a defined net fact.
    if (!row.isValid) return null;
    try {
      if (row.portion case final portion?) {
        return portion.nutrients.netCarbohydrates;
      }
      if (row.recipe case final recipe?) {
        final value = recipe.perServing.netCarbohydrates;
        return value == null ? null : value * recipe.servings;
      }
      if (row.unit case final unit?) {
        final value = unit.nutrients.netCarbohydrates;
        return value == null
            ? null
            : value * unit.quantity / unit.basisQuantity;
      }
    } on CoachFoodContractError {
      return null;
    }
    return null;
  }
}
