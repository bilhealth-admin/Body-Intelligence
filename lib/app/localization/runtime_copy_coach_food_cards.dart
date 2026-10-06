import 'bil_locale_policy.dart';

part 'runtime_copy_coach_food_cards_0.dart';
part 'runtime_copy_coach_food_cards_1.dart';
part 'runtime_copy_coach_food_cards_2.dart';
part 'runtime_copy_coach_food_cards_3.dart';

/// Authored missing food review/receipt copy for the 25 supported locales.
/// Existing runtime translations are preserved before this bank is consulted.
abstract final class CoachFoodCardRuntimeCopy {
  static const sources = <String>[
    "Unknown",
    "Estimated",
    "Food details",
    "Nutrition details",
    "Receipt actions",
    "Estimated portion",
    "Photo unavailable",
    "Yes, log it",
    "Adjust",
    "Working…",
    "Sources",
    "Source confidence",
    "Identity confidence",
    "Quantity confidence",
    "View in Daily Log",
    "This food receipt is unavailable. Review your Daily Log.",
    "Your account changed. Return to Coach to continue.",
    "The action could not be completed. Your review is kept.",
    "This meal changed. Review the current entry before editing or undoing.",
    "This review is closed.",
    "Entry undone",
    "Meal updated",
    "Entry removed",
    "Meal moved",
    "Calorie entry saved",
    "Nutrition entry saved",
    "Unknown food",
    "Meal",
    "Great! I’ll log your {meal}. Here’s what I understood:",
    "Shall I log this to your {meal}?",
    "{meal} logged",
    "Reference",
    "Food label",
    "Your fixed values",
    "Calculated recipe",
    "Protein",
    "Carbs",
    "Fat",
    "Sugar",
    "Calcium",
    "Phosphorus",
    "Iron",
    "Vitamin C",
    "ml",
    "1 item",
    "{count} items",
    "g",
  ];

  static const rows = <String, List<String>>{
    'en': sources,
    ..._coachFoodCardRows0,
    ..._coachFoodCardRows1,
    ..._coachFoodCardRows2,
    ..._coachFoodCardRows3,
  };

  static String? resolve(String source, String localeTag) {
    final index = sources.indexOf(source);
    if (index < 0) return null;
    final tag = BilLocalePolicy.canonicalSupportedTag(localeTag);
    final row = rows[tag];
    if (row == null || row.length != sources.length) {
      throw StateError('Incomplete Coach food card copy for $tag');
    }
    return row[index];
  }

  static bool get balanced =>
      sources.toSet().length == sources.length &&
      rows.keys.toSet().containsAll(BilLocalePolicy.productionTags) &&
      BilLocalePolicy.productionTags.toSet().containsAll(rows.keys) &&
      rows.values.every(
        (row) =>
            row.length == sources.length &&
            row.every((value) => value.isNotEmpty),
      );
}
