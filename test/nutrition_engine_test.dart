import 'package:body_intelligence_log/engine/nutrition_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NutritionEngine', () {
    test('calculates portion nutrition from serving size', () {
      final totals = NutritionEngine.calculateFoodPortion(
        quantity: 200,
        servingSize: 100,
        calories: 250,
        protein: 20,
        carbs: 30,
        fats: 10,
      );

      expect(totals.calories, closeTo(500, 0.001));
      expect(totals.protein, closeTo(40, 0.001));
      expect(totals.carbs, closeTo(60, 0.001));
      expect(totals.fats, closeTo(20, 0.001));
    });
  });
}
