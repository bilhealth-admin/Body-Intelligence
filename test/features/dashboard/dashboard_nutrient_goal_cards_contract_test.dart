import 'package:body_intelligence_log/app/localization/runtime_copy_extended.dart';
import 'package:body_intelligence_log/features/dashboard/providers/dashboard_preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard nutrient goals reject corrupt persisted domains', () {
    expect(validDashboardNutrientGoal('goal.fiber', 9000), isFalse);
    expect(validDashboardNutrientGoal('goal.fiber', 35), isTrue);
    expect(validDashboardNutrientGoal('goal.sodium', 1e12), isFalse);
    expect(validDashboardNutrientGoal('goal.sodium', 2300), isTrue);
    expect(validDashboardNutrientGoal('goal.potassium', double.nan), isFalse);
    expect(validDashboardNutrientGoal('goal.proteinGrams', 1001), isFalse);
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
