import 'package:body_intelligence_log/features/daily_log/domain/food_log_meal_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Food Log exposes four explicit meal destinations', () {
    expect(foodLogMealTypes, const ['breakfast', 'lunch', 'dinner', 'snack']);
    expect(normalizeFoodLogMealType(null), 'breakfast');
    expect(normalizeFoodLogMealType('lunch'), 'lunch');
    expect(normalizeFoodLogMealType('not-a-meal'), 'breakfast');
    expect(foodLogMealTitle('snack'), 'Snacks');
  });
}
