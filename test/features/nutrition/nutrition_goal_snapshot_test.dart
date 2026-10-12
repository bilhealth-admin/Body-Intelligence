import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';
import 'package:body_intelligence_log/features/nutrition/domain/macro_goal_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final defaults = {
    ...NutrientDailyReferences.values,
    ...const {
      'goal.calories': 1000.0,
      'goal.carbsPercent': 45.0,
      'goal.proteinPercent': 20.0,
      'goal.fatPercent': 35.0,
    },
  };
  test(
    'new profile separates FDA label values from profile energy without halving minerals',
    () {
      final snapshot = NutritionGoalSnapshot.resolve({}, defaults);
      expect(snapshot.goals['goal.carbsGrams']!.value, 112.5);
      expect(snapshot.goals['goal.proteinGrams']!.value, 50);
      expect(
        snapshot.goals['goal.fatGrams']!.value,
        closeTo(38.888888, .000001),
      );
      expect(snapshot.goals['goal.vitaminAMcg']!.value, 900);
      expect(snapshot.goals['goal.calciumMg']!.value, 1300);
      expect(snapshot.goals['goal.sugar']!.value, isNull);
      expect(
        snapshot.goals['goal.sugar']!.status,
        NutritionGoalStatus.unspecified,
      );
      expect(snapshot.goals['goal.sodium']!.kind, NutritionGoalKind.upperLimit);
      expect(snapshot.goals['goal.proteinPercent']!.unit, '% energy');
    },
  );
  test(
    'owner screenshot values remain preserved and labelled saved, never BIL recommendations',
    () {
      final stored = {
        'goal.fiber': '979',
        'goal.sugar': '765',
        'goal.transFat': '89',
        'goal.saturatedFat': '54',
        'goal.cholesterol': '799',
      };
      final snapshot = NutritionGoalSnapshot.resolve(stored, defaults);
      for (final key in stored.keys) {
        expect(snapshot.goals[key]!.value, isNull);
        expect(snapshot.goals[key]!.status, NutritionGoalStatus.reviewRequired);
        expect(snapshot.original[key], stored[key]);
        expect(snapshot.goals[key]!.warning, isNotNull);
      }
    },
  );
  test('malformed/negative/infinite stored values do not become defaults', () {
    for (final text in ['bad', '-1', 'Infinity', 'NaN', '999999999999999999']) {
      final snapshot = NutritionGoalSnapshot.resolve({
        'goal.fiber': text,
      }, defaults);
      expect(snapshot.goals['goal.fiber']!.status, NutritionGoalStatus.invalid);
      expect(snapshot.goals['goal.fiber']!.value, isNull);
      expect(snapshot.goals['goal.fiber']!.raw, text);
      expect(snapshot.goals['goal.fiber']!.suggestion, 28);
    }
  });
  test(
    'storage failure differs from unspecified and never yields proposals as active goals',
    () {
      final snapshot = NutritionGoalSnapshot.resolve(
        {},
        defaults,
        storageFailed: true,
      );
      for (final goal in snapshot.goals.values) {
        expect(goal.status, NutritionGoalStatus.storageFailure);
        expect(goal.value, isNull);
      }
    },
  );
  test(
    'intentional zero differs from unknown and no mass-unit mixing occurs',
    () {
      final snapshot = NutritionGoalSnapshot.resolve({
        'goal.sugar': '0',
        'goal.cholesterol': '799',
      }, defaults);
      expect(
        snapshot.goals['goal.sugar']!.status,
        NutritionGoalStatus.intentionalZero,
      );
      expect(snapshot.goals['goal.sugar']!.value, 0);
      expect(snapshot.goals['goal.transFat']!.value, isNull);
      expect(
        snapshot.goals['goal.cholesterol']!.warning,
        'above_label_reference',
      );
    },
  );
  test(
    'all four release35 legacy percent keys remain unknown without an evidenced denominator',
    () {
      final old = {
        for (final key in NutritionGoalSnapshot.legacyKeys.values) key: '10',
      };
      final snapshot = NutritionGoalSnapshot.resolve(old, defaults);
      for (final key in NutritionGoalSnapshot.legacyKeys.keys) {
        expect(snapshot.goals[key]!.status, NutritionGoalStatus.legacyUnknown);
        expect(snapshot.goals[key]!.value, isNull);
        expect(snapshot.goals[key]!.legacyRaw, '10');
      }
      final reopened = NutritionGoalSnapshot.resolve(old, defaults);
      expect(reopened.original, old);
      final newer = NutritionGoalSnapshot.resolve({
        ...old,
        'goal.vitaminCMg': '90',
        'goal.origin.goal.vitaminCMg': 'manual_override',
      }, defaults);
      expect(newer.goals['goal.vitaminCMg']!.value, 90);
      expect(newer.goals['goal.vitaminCMg']!.source, 'manual_override');
      expect(newer.original['goal.vitaminC'], '10');
    },
  );
  test(
    'corrupt or contradictory macro group never presents a half repaired allocation',
    () {
      for (final stored in [
        {'goal.calories': 'NaN'},
        {
          'goal.carbsPercent': '70',
          'goal.proteinPercent': '20',
          'goal.fatPercent': '20',
        },
        {'goal.fatGrams': '54'},
      ]) {
        final snapshot = NutritionGoalSnapshot.resolve(stored, defaults);
        for (final key in NutritionGoalSnapshot.macroKeys) {
          expect(snapshot.goals[key]!.value, isNull);
          expect(snapshot.goals[key]!.needsReview, true);
        }
        expect(snapshot.original, stored);
      }
    },
  );
  test(
    'independent subtype limits are not summed; only same-unit parent relationships warn',
    () {
      final snapshot = NutritionGoalSnapshot.resolve({
        'goal.saturatedFat': '20',
        'goal.monounsaturatedFat': '25',
        'goal.polyunsaturatedFat': '25',
        'goal.cholesterol': '300',
      }, defaults);
      expect(snapshot.goals['goal.saturatedFat']!.warning, isNull);
      expect(snapshot.goals['goal.monounsaturatedFat']!.warning, isNull);
      expect(snapshot.goals['goal.cholesterol']!.warning, isNull);
    },
  );
  test(
    'Arabic Persian and explicit decimals parse; ambiguous separators are rejected',
    () {
      expect(NutritionGoalSnapshot.parse('١١٢٫٥'), 112.5);
      expect(NutritionGoalSnapshot.parse('۵۰٫۲'), 50.2);
      expect(NutritionGoalSnapshot.parse('50,2'), 50.2);
      for (final text in [
        '1,000',
        '1.000',
        '1,2.3',
        '١٬٠٠٠',
        'NaN',
        'Infinity',
        '-1',
        '1e300',
        '12 3',
      ]) {
        expect(NutritionGoalSnapshot.parse(text), isNull);
      }
    },
  );
  test(
    'repeated gram edits preserve full precision and lock modes without rounding creep',
    () {
      var allocation = const MacroGoalAllocation(1000, 45, 20, 35);
      for (var i = 0; i < 100; i++) {
        allocation = allocation.edit(
          MacroGoal.carbohydrate,
          112.5,
          inGrams: true,
          locked: {MacroGoal.protein},
        );
        allocation = allocation.withCalories(
          2000,
          locked: {MacroGoal.protein},
          gramLocks: {MacroGoal.protein},
        );
        allocation = allocation.withCalories(
          1000,
          locked: {MacroGoal.protein},
          gramLocks: {MacroGoal.protein},
        );
      }
      expect(allocation.grams(MacroGoal.protein), closeTo(50, 1e-9));
      expect(allocation.grams(MacroGoal.fat), closeTo(38.88888888888889, 1e-9));
    },
  );
  test(
    'owner screenshot outliers are preserved but not presented as active reliable targets',
    () {
      final original = {
        'goal.fiber': '979',
        'goal.sugar': '765',
        'goal.transFat': '89',
        'goal.saturatedFat': '54',
        'goal.cholesterol': '799',
      };
      final snapshot = NutritionGoalSnapshot.resolve(original, defaults);
      for (final entry in original.entries) {
        expect(snapshot.goals[entry.key]!.value, isNull, reason: entry.key);
        expect(snapshot.goals[entry.key]!.needsReview, isTrue);
        expect(snapshot.original[entry.key], entry.value);
      }
      expect(snapshot.goals['goal.fiber']!.suggestion, 28);
      expect(snapshot.goals['goal.sugar']!.suggestion, isNull);
      expect(snapshot.goals['goal.transFat']!.suggestion, isNull);
    },
  );
  test(
    'unusual manual target requires explicit acknowledgment of its current unit and comparison',
    () {
      final saved = {'goal.fiber': '979'};
      final review = NutritionGoalSnapshot.resolve(
        saved,
        defaults,
      ).goals['goal.fiber']!;
      final confirmed = NutritionGoalSnapshot.resolve({
        ...saved,
        'goal.origin.goal.fiber': 'manual_override',
        'goal.confirmed.goal.fiber': review.reviewToken!,
      }, defaults);
      expect(confirmed.goals['goal.fiber']!.value, 979);
      expect(confirmed.goals['goal.fiber']!.source, 'manual_override');
      final changed = NutritionGoalSnapshot.resolve({
        ...confirmed.original,
        'goal.fiber': '980',
      }, defaults);
      expect(changed.goals['goal.fiber']!.value, isNull);
      expect(changed.goals['goal.fiber']!.needsReview, isTrue);
    },
  );
  test(
    'outlier does not become active during cold profile loading; small decimals remain unambiguous',
    () {
      final cold = NutritionGoalSnapshot.resolve({
        'goal.fiber': '979',
        'goal.sugar': '765',
      }, NutrientDailyReferences.values);
      expect(cold.goals['goal.fiber']!.value, isNull);
      expect(cold.goals['goal.sugar']!.value, isNull);
      expect(NutritionGoalSnapshot.parse('0.001'), .001);
      expect(NutritionGoalSnapshot.parse('٠٫٠٠١'), .001);
    },
  );
}
