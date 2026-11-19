import 'dart:convert';
import 'app_database.dart';
import 'meal_food_evidence.dart';
import 'nutrient_evidence.dart';
import 'vision_estimate_evidence.dart';
import '../../features/nutrition/domain/unified_food.dart';

/// A frozen local nutrition observation, never entitlement or model accuracy.
/// Unknown aggregate values remain nullable. Original per-food estimates stay
/// in their immutable meal envelopes; closing never rewrites those envelopes.
class FinalVisionNutrition {
  FinalVisionNutrition({
    required this.ownerKey,
    required this.dayKey,
    required this.logUuid,
    required this.closedAtUtc,
    required Map<FoodNutrient, double?> nutrients,
    required this.directNetCarbohydrates,
  }) : nutrients = Map.unmodifiable(nutrients) {
    if (!RegExp(r'^account_[0-9a-f]{24}$').hasMatch(ownerKey) ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dayKey) ||
        DateTime.tryParse(dayKey)?.toIso8601String().substring(0, 10) !=
            dayKey ||
        logUuid.isEmpty ||
        logUuid.length > 240 ||
        !closedAtUtc.isUtc ||
        nutrients.length != FoodNutrient.values.length) {
      throw const FormatException('Invalid closed photo nutrition binding.');
    }
    for (final value in [...nutrients.values, directNetCarbohydrates]) {
      if (value != null && (!value.isFinite || value < 0 || value > 1e13)) {
        throw const FormatException('Invalid closed photo nutrient.');
      }
    }
  }
  static const schema = 'bil.vision.estimate.closed-day.v1';
  final String ownerKey, dayKey, logUuid;
  final DateTime closedAtUtc;
  final Map<FoodNutrient, double?> nutrients;
  final double? directNetCarbohydrates;
  static bool containsVision(Iterable<MealFoodEvidence> rows) => rows.any(
    (row) => row.item.foodSourceSnapshot == VisionFoodEvidence.source,
  );

  /// Legacy day arithmetic is retained unless this day includes a Gemini row.
  static double? netForRows(List<MealFoodEvidence> rows) {
    if (rows.isEmpty) return null;
    var total = 0.0;
    for (final row in rows) {
      double? value;
      if (row.item.foodSourceSnapshot == VisionFoodEvidence.source) {
        value = row.isValid ? row.directNetCarbohydrates : null;
      } else {
        final carbs = row.value(TrackedNutrient.carbohydrates),
            fiber = row.value(TrackedNutrient.fiber);
        value = carbs == null || fiber == null
            ? null
            : (carbs - fiber).clamp(0, double.infinity).toDouble();
      }
      if (value == null) return null;
      total += value;
      if (!total.isFinite) return null;
    }
    return total;
  }

  factory FinalVisionNutrition.capture({
    required String ownerKey,
    required DailyLog log,
    required List<MealFoodEvidence> rows,
    FinalVisionNutrition? previous,
  }) {
    // A prior snapshot proves lineage only. Never copy its nutrient values
    // into a later close after its last live Vision row has been removed.
    final sameLineage =
        previous != null &&
        previous.ownerKey == ownerKey &&
        previous.dayKey == log.dayKey &&
        previous.logUuid == log.uuid;
    if (previous != null && !sameLineage) {
      throw const FormatException('Conflicting photo-day lineage.');
    }
    if (log.lifecycleState != 'closed' ||
        log.closedAt == null ||
        (!containsVision(rows) && !sameLineage)) {
      throw const FormatException(
        'Photo snapshot requires an actually closed photo day.',
      );
    }
    double? complete(FoodNutrient nutrient) {
      if (rows.isEmpty) return null;
      var total = 0.0;
      for (final row in rows) {
        final value = row.fullValue(nutrient);
        if (value == null) return null;
        total += value;
      }
      return total;
    }

    return FinalVisionNutrition(
      ownerKey: ownerKey,
      dayKey: log.dayKey,
      logUuid: log.uuid,
      closedAtUtc: log.closedAt!.toUtc(),
      nutrients: {for (final n in FoodNutrient.values) n: complete(n)},
      directNetCarbohydrates: netForRows(rows),
    );
  }
  bool matches(DailyLog log, String owner) =>
      ownerKey == owner &&
      dayKey == log.dayKey &&
      logUuid == log.uuid &&
      log.lifecycleState == 'closed' &&
      log.closedAt?.toUtc() == closedAtUtc &&
      log.calories == nutrients[FoodNutrient.calories]?.round() &&
      log.protein == nutrients[FoodNutrient.protein]?.round() &&
      log.carbs == nutrients[FoodNutrient.carbohydrates]?.round() &&
      log.fats == nutrients[FoodNutrient.fat]?.round() &&
      log.finalFiber == nutrients[FoodNutrient.fiber] &&
      (log.finalNutrientEvidenceMask ?? 0) ==
          (nutrients[FoodNutrient.fiber] == null
              ? 0
              : NutrientEvidenceMask.bit(TrackedNutrient.fiber));
  String encode() => jsonEncode({
    'schema': schema,
    'ownerKey': ownerKey,
    'dayKey': dayKey,
    'logUuid': logUuid,
    'closedAt': closedAtUtc.toIso8601String(),
    'nutrients': {for (final n in FoodNutrient.values) n.name: nutrients[n]},
    'directNetCarbohydrates': directNetCarbohydrates,
  });
  factory FinalVisionNutrition.decode(String raw) {
    if (utf8.encode(raw).length > 65536) {
      throw const FormatException('Closed photo snapshot too large.');
    }
    final row = jsonDecode(raw);
    if (row is! Map<String, dynamic> ||
        row.length != 7 ||
        row['schema'] != schema ||
        !row.keys.toSet().containsAll({
          'schema',
          'ownerKey',
          'dayKey',
          'logUuid',
          'closedAt',
          'nutrients',
          'directNetCarbohydrates',
        }) ||
        row['ownerKey'] is! String ||
        row['dayKey'] is! String ||
        row['logUuid'] is! String ||
        row['closedAt'] is! String) {
      throw const FormatException('Invalid closed photo snapshot.');
    }
    final values = row['nutrients'];
    if (values is! Map<String, dynamic> ||
        values.length != FoodNutrient.values.length ||
        values.keys.any(
          (key) => !FoodNutrient.values.any((n) => n.name == key),
        )) {
      throw const FormatException('Invalid closed nutrients.');
    }
    double? number(Object? value) {
      if (value == null) return null;
      if (value is! num) {
        throw const FormatException('Invalid closed nutrient.');
      }
      return value.toDouble();
    }

    final closed = DateTime.tryParse(row['closedAt'] as String);
    if (closed == null || !closed.isUtc) {
      throw const FormatException('Invalid closed time.');
    }
    return FinalVisionNutrition(
      ownerKey: row['ownerKey'] as String,
      dayKey: row['dayKey'] as String,
      logUuid: row['logUuid'] as String,
      closedAtUtc: closed,
      nutrients: {
        for (final n in FoodNutrient.values) n: number(values[n.name]),
      },
      directNetCarbohydrates: number(row['directNetCarbohydrates']),
    );
  }
}
