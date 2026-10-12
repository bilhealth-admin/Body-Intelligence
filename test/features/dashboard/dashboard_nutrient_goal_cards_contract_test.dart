import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrient_daily_references.dart';
import 'package:body_intelligence_log/features/nutrition/domain/nutrition_goal_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard technical guards do not approve an unusual dietary goal', () {
    // Storage guards and nutritional interpretation have separate jobs. A
    // representable old value must survive, but cannot silently become a target.
    expect(validDashboardNutrientGoal('goal.fiber', 9000), isTrue);
    final snapshot = NutritionGoalSnapshot.resolve({
      'goal.fiber': '9000',
    }, NutrientDailyReferences.values);
    final fiber = snapshot.goals['goal.fiber']!;
    expect(fiber.value, isNull);
    expect(fiber.status, NutritionGoalStatus.reviewRequired);
    expect(fiber.raw, '9000');
    expect(fiber.warning, isNotNull);
    expect(fiber.source, isNot('fda_label_dv_2026_10_11'));
    expect(validDashboardNutrientGoal('goal.fiber', 35), isTrue);
    expect(validDashboardNutrientGoal('goal.fiber', 1000001), isFalse);
    expect(validDashboardNutrientGoal('goal.fiber', -1), isFalse);
    expect(validDashboardNutrientGoal('goal.sodium', 1e12), isFalse);
    expect(validDashboardNutrientGoal('goal.sodium', 2300), isTrue);
    expect(validDashboardNutrientGoal('goal.potassium', double.nan), isFalse);
    expect(
      validDashboardNutrientGoal('goal.potassium', double.infinity),
      isFalse,
    );
    expect(validDashboardNutrientGoal('goal.proteinGrams', 2501), isFalse);
    expect(validDashboardNutrientGoal('goal.unknownUnit', 1), isFalse);
  });

  test('dashboard nutrient cards have direct extended-locale copy', () {
    const keys = <String>{
      'Nutrient goals',
      'Protein',
      'Carbohydrates',
      'Fat',
      'Fiber',
      'Sodium',
      'Potassium',
      'Goal or nutrition evidence is unavailable',
      'Edit goal',
    };
    const reviewedIdentity = <String>{
      'Protein|de',
      'Protein|id',
      'Protein|ms',
      'Protein|nl',
      'Protein|pl',
      'Potassium|de',
      'Potassium|id',
      'Potassium|ms',
      'Potassium|nl',
      'Potassium|pl',
    };
    for (final key in keys) {
      final values = ExtendedRuntimeCopy.values[key];
      expect(values, isNotNull, reason: key);
      for (final locale in ExtendedRuntimeCopy.supported) {
        final value = values![locale]?.trim();
        expect(value, isNotNull, reason: '$key|$locale');
        expect(value, isNotEmpty, reason: '$key|$locale');
        if (!reviewedIdentity.contains('$key|$locale')) {
          expect(value, isNot(key), reason: '$key|$locale');
        }
      }
    }
  });
}
